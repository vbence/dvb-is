(*
This file is part of NativeDVBIO by Varga Bence.

NativeDVBIO is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

NativeDVBIO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with NativeDVBIO.  If not, see <http://www.gnu.org/licenses/>.
*)

unit StreamReader;

interface

uses
    JNI,
    ActiveX,
    Windows,
    Forms,
    SysUtils,
    Classes,
    DirectShow9,
    DsUtil,
    StreamDumpFilter,
    GraphBuilder;

const
    CBufferSize = 1390 * 188; // 261320

type
    TStreamReader = class(TInterfacedObject, IStreamBuffer)
    public
        constructor Create(FreqKhz: Integer; Device: String);
        destructor Destruct;
        procedure Start;
        procedure Stop;
        procedure DataReceived(DataPointer: PByte; DataLength: Integer);
        function Read(TargetPointer: PByte; MaxLength: Integer): Integer;
        function GetDataLength: Integer;
        function IsSignalPresent: Boolean;
        function IsSignalLocked: Boolean;
        function GetSignalStrength: Integer;
        function GetSignalQuality: Integer;
        class function ListDevices: String;

    protected

        // tuning fields
        FCapturingGrpah: TCapturingGraph;
        FFreq: Integer;
        FDevice: String;

        // receiving fields
        FBuffer: Array of Byte;
        FDataStart: Integer;
        FDataLength: Integer;
        FBufferOverrun: Boolean;
        FRuns: Boolean;

        // lock
        FLock: TRTLCriticalSection;

        // efficient waiting (semaphore)
        FSemaphore: Cardinal;
    end;

    TStreamReaderID = class
    public
        constructor Create(ID: Integer; StreamReader: TStreamReader);
        function GetID: Integer;
        function GetStreamReader: TStreamReader;
    protected
        FID: Integer;
        FStreamReader: TStreamReader;
    end;

    TStreamReaderContainer = class
    public
        constructor Create;
        destructor Destruct;
        function RegisterStreamReader(StreamReader: TStreamReader): Integer;
        function GetByID(ID: Integer): TStreamReader;
        procedure RemoveByID(ID: Integer);
    protected
        FList: TList;
    end;

implementation

uses Math;

// TGUID as String
function Guid2String(id: TGUID): String;
var
    tmp: String;
    i: Integer;
begin
    tmp := '{';
    tmp := tmp + IntToHex(id.D1, 8);
    tmp := tmp + '-';
    tmp := tmp + IntToHex(id.D2, 4);
    tmp := tmp + '-';
    tmp := tmp + IntToHex(id.D3, 4);
    tmp := tmp + '-';
    for i := 0 to 1 do
        tmp := tmp + IntToHex(id.D4[i], 2);
    tmp := tmp + '-';
    for i := 2 to 7 do
        tmp := tmp + IntToHex(id.D4[i], 2);
    tmp := tmp + '}';
    Result := tmp;
end;

constructor TStreamReader.Create(FreqKhz: Integer; Device: String);
begin
    FCapturingGrpah := TCapturingGraph.Create;
    FFreq := FreqKhz;
    FDevice := Device;
    FDataStart := 0;
    FDataLength := 0;
    FBufferOverrun := false;
    FRuns := false;
    InitializeCriticalSection(FLock);
    FSemaphore := CreateSemaphore(nil, 0, 1, nil);
end;

destructor TStreamReader.Destruct;
begin
    Stop;
    CloseHandle(FSemaphore);
    DeleteCriticalSection(FLock);
    FCapturingGrpah.Free;
end;

procedure TStreamReader.Start;
begin
    if FRuns then
        raise Exception.Create('Reader already running.');

    SetLength(FBuffer, CBufferSize);
    FCapturingGrpah.BuildGraph(self, FFreq, FDevice);
    FRuns := true;
end;

procedure TStreamReader.Stop;
begin

    // ensure that no concurrent processes work on the buffer
    EnterCriticalSection(FLock);

    // (stopping and) destroying the graph
    FCapturingGrpah.DestroyGraph;

    // resetting the buffer
    FRuns := false;
    FDataStart := 0;
    FDataLength := 0;
    SetLength(FBuffer, 0);

    // release lock
    LeaveCriticalSection(FLock);
end;

procedure TStreamReader.DataReceived(DataPointer: PByte; DataLength: Integer);
const
    CPacketLength: Integer = 188;    
var
    Pointer, ToCopy: Integer;
begin

    // IF the reader is not running anymore
    if not FRuns then
        Exit;

    // IF buffer is full
    if FDataLength >= Length(FBuffer) then begin
        FBufferOverrun := true;
        Exit;
    end;

    FBufferOverrun := false;

    EnterCriticalSection(FLock);

    Pointer := (FDataStart + FDataLength) mod Length(FBuffer);

    // forward region
    if Pointer >= FDataStart then begin
        ToCopy := Min(DataLength, Length(FBuffer) - Pointer);

        // data copy
        CopyMemory(@FBuffer[Pointer], DataPointer, ToCopy);

        // adjusting fields
        Inc(FDataLength, ToCopy);

        // adjusting parameters
        Inc(DataPointer, ToCopy);
        Dec(DataLength, ToCopy);
    end;

    // there is still data left
    if DataLength > 0 then begin
        Pointer := (FDataStart + FDataLength) mod Length(FBuffer);
        ToCopy := Min(DataLength, FDataStart - Pointer);

        // we only copy full packets (multiple of 188 bytes)
        Dec(ToCopy, ToCopy mod CPacketLength);

        // data copy
        CopyMemory(@FBuffer[Pointer], DataPointer, ToCopy);
        
        // adjusting fields
        Inc(FDataLength, ToCopy);

        // adjusting parameters
        Inc(DataPointer, ToCopy);
        Dec(DataLength, ToCopy);

    end;

    // there is still data left (but no more space in the buffer)
    if DataLength > 0 then
        FBufferOverrun := true;

    LeaveCriticalSection(FLock);

    // signalling the semaphore (because .Read blocks threads if buffer was empty)
    if FDataLength > 0 then
        ReleaseSemaphore(FSemaphore, 1, nil);

end;

function TStreamReader.Read(TargetPointer: PByte; MaxLength: Integer): Integer;
var
    ToCopy: Integer;
    rc: Integer;
begin                           
    Result := 0;

    // if no data, we wait for the semaphore
    while FDataLength = 0 do begin

        (* But WHAT IF two (or more) threads are reading concurrently from this
         * object and BOTH of them are here, waiting for data? According to doc
         * WaitForSingleObject decreases the semaphore's count. So will the
         * other thread exit from the waiting state too, before the semaphore is
         * non-signalled (cout is zero) again, or only has a chance on the next
         * DataReceived to do so?
         *)

        // waiting for the reading thread to set the semaphore
        rc := WaitForSingleObject(FSemaphore, INFINITE);
        //WriteLn(rc);
        //sleep(100);
        //Write('.');

    end;

    EnterCriticalSection(FLock);

    repeat
        ToCopy := Min(MaxLength, Min(FDataLength, Length(FBuffer) - FDataStart));
        CopyMemory(TargetPointer, @FBuffer[FDataStart], ToCopy);

        Dec(FDataLength, ToCopy);
        FDataStart := (FDataStart + ToCopy) mod Length(FBuffer);
        Inc(Result, ToCopy);

        Inc(TargetPointer, ToCopy);
        Dec(MaxLength, ToCopy);
    until (MaxLength <= 0) or (FDataLength <= 0);

    LeaveCriticalSection(FLock);

end;

function TStreamReader.GetDataLength: Integer;
begin
    Result := FDataLength;
end;

constructor TStreamReaderID.Create(ID: Integer; StreamReader: TStreamReader);
begin
    FID := ID;
    FStreamReader := StreamReader;
end;

function TStreamReader.IsSignalPresent: Boolean;
var
    hr: HRESULT;
    SignalStatistics: IBDA_SignalStatistics;
    Present: LongBool;
begin
    Present := False;
    SignalStatistics := FCapturingGrpah.GetSignalStatistics;
    hr := SignalStatistics.get_SignalPresent(Present);
    if FAILED(hr) then
        raise Exception.Create('Getting if signal is present: ' + SysErrorMessage(hr));
    Result := Present;
end;

function TStreamReader.IsSignalLocked: Boolean;
var
    hr: HRESULT;
    SignalStatistics: IBDA_SignalStatistics;
    Locked: LongBool;
begin
    Locked := False;
    SignalStatistics := FCapturingGrpah.GetSignalStatistics;
    hr := SignalStatistics.get_SignalLocked(Locked);
    if FAILED(hr) then
        raise Exception.Create('Getting if signal is locked: ' + SysErrorMessage(hr));
    Result := Locked;
end;

function TStreamReader.GetSignalStrength: Integer;
var
    hr: HRESULT;
    SignalStatistics: IBDA_SignalStatistics;
    Strength: Integer;
begin
    Strength := 0;
    SignalStatistics := FCapturingGrpah.GetSignalStatistics;
    hr := SignalStatistics.get_SignalStrength(Strength);
    if FAILED(hr) then
        raise Exception.Create('Getting signal strength: ' + SysErrorMessage(hr));
    Result := Strength;
end;

function TStreamReader.GetSignalQuality: Integer;
var
    hr: HRESULT;
    SignalStatistics: IBDA_SignalStatistics;
    Quality: Integer;
begin
    Quality := 0;
    SignalStatistics := FCapturingGrpah.GetSignalStatistics;
    hr := SignalStatistics.get_SignalQuality(Quality);
    if FAILED(hr) then
        raise Exception.Create('Getting signal quality: ' + SysErrorMessage(hr));
    Result := Quality;
end;

class function TStreamReader.ListDevices: String;
const
    //SystemTypes: array[0..2] of DVBSystemType = (DVB_Satellite, DVB_Cable, DVB_Terrestrial);
    CLSID_NetworkProvider: TGUID = '{B2F3A67C-29DA-4c78-8831-091ED509A475}';
var
    // COM return code
    hr: HRESULT;

    // helper vars
    i, j: Integer;

    // device enumeration
    SysDevEnum: TSysDevEnum;
    Moniker: IMoniker;
    PropertyBag: IPropertyBag;
    DevPathOle: OleVariant;

    // test graph
    Builder: IGraphBuilder;
    NetworkProviders: array[0..2] of IBaseFilter;
    NetworkProviderGUIDS: array[0..2] of TGUID;
    //TuningSpaceGUIDS: array[0..2] of TGUID;
    Helper: TGraphHelper;
    Filter: IBaseFilter;
    Connected: Boolean;

begin
    Result := '';

    // network provider guids for certain network types
    NetworkProviderGUIDS[0] := CLSID_DVBSNetworkProvider;
    NetworkProviderGUIDS[1] := CLSID_DVBCNetworkProvider;
    NetworkProviderGUIDS[2] := CLSID_DVBTNetworkProvider;

    // Tuning spaces used by the netork tipes above
    //TuningSpaceGUIDS[0] := CLSID_DVBSTuningSpace;
    //TuningSpaceGUIDS[1] := CLSID_DVBTuningSpace;
    //TuningSpaceGUIDS[2] := CLSID_DVBTuningSpace;

     // creatring graph builder
    hr := CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC, IID_IGraphBuilder, Builder);
    if FAILED(hr) then
       raise Exception.Create('Creating IGraphBuilder: ' + SysErrorMessage(hr));

    // initializing helper (functions to insert and connect filters)
    Helper := TGraphHelper.Create(Builder);

    // creating network providers (one per system) and putting them into the graph
    for i:= 0 to Length(NetworkProviders) - 1 do begin

        // creating network provider
        hr := CoCreateInstance(NetworkProviderGUIDS[i], nil, CLSCTX_INPROC_SERVER, IID_IBaseFilter, NetworkProviders[i]);
        if FAILED(hr) then
           raise Exception.Create('Creating network provider: ' + SysErrorMessage(hr));

        // adding network provider to the graph
        hr := Builder.AddFilter(NetworkProviders[i], 'Network Provider');
        if FAILED(hr) then
           raise Exception.Create('Adding network provider to the graph: ' + SysErrorMessage(hr));

        (*
        // getting ITuner interface
        hr := NetworkProviders[i].QueryInterface(IID_ITuner, Tuner);
        if FAILED(hr) then
           raise Exception.Create('Getting interface ITuner: ' + SysErrorMessage(hr));

        // tuning space setup: CREATE
        hr := CoCreateInstance(TuningSpaceGUIDS[i], nil, CLSCTX_INPROC_SERVER, IID_IDVBTuningSpace, TuningSpace);
        if FAILED(hr) then
           raise Exception.Create('Creating tuning space: ' + SysErrorMessage(hr));

        // setting SystemType
        hr := TuningSpace.put_SystemType(SystemTypes[i]);
        if FAILED(hr) then
           raise Exception.Create('Setting system type: ' + SysErrorMessage(hr));

        // setting NetworkType
        hr := TuningSpace.put_NetworkType(GUIDToString(NetworkProviderGUIDS[i]));
        if FAILED(hr) then
           raise Exception.Create('Setting network type: ' + SysErrorMessage(hr));

        // setting tuning space
        hr := Tuner.put_TuningSpace(TuningSpace);
        if FAILED(hr) then
           raise Exception.Create('Setting tuning space of the network provider: ' + SysErrorMessage(hr));
        *)

    end;

    SysDevEnum := TSysDevEnum.Create;
    SysDevEnum.SelectGUIDCategory(KSCATEGORY_BDA_NETWORK_TUNER);
    for i := 0 to SysDevEnum.CountFilters - 1 do begin

        // append a separator if not the first interface
        if i > 0 then
            Result := Result + Chr(9);

        // storing device's friendly name
        Result := Result + StringReplace(SysDevEnum.Filters[i].FriendlyName, Chr(9), ' ', [rfReplaceAll]);

        Moniker := SysDevEnum.GetMoniker(i);

        // getting property bag
        hr := Moniker.BindToStorage(nil, nil, IID_IPropertyBag, PropertyBag);
        if FAILED(hr) then
            raise Exception.Create('Getting property bag: ' + SysErrorMessage(hr));

        // getting device path
        hr := PropertyBag.Read('DevicePath', DevPathOle, nil);
        if FAILED(hr) then
            raise Exception.Create('Getting DevicePath: ' + SysErrorMessage(hr));

        // storing device path
        Result := Result + Chr(9);
        Result := Result + StringReplace(String(DevPathOle), Chr(9), ' ', [rfReplaceAll]);

        // getting the current filter
        hr := Moniker.BindToObject(nil, nil, IID_IBaseFilter, Filter);
        if FAILED(hr) then
            raise Exception.Create('Getting filter from the moniker: ' + SysErrorMessage(hr));

        // add filter to the graph
        hr := Builder.AddFilter(Filter, PWideChar(WideString('Tuner')));
        if FAILED(hr) then
            raise Exception.Create('Adding filter to the graph: ' + SysErrorMessage(hr));

        // trying to connect our filter to various network providers
        Connected := FALSE;
        for j := 0 to Length(NetworkProviders) - 1 do begin

            hr := Helper.ConnectTo(IBaseFilter(NetworkProviders[j]), Filter);
            if SUCCEEDED(hr) then begin
                Connected := TRUE;
                Result := Result + Chr(9) + IntToStr(j);
                break;
            end;

        // for j
        end;

        // removing tuner
        hr := Builder.RemoveFilter(Filter);
        if FAILED(hr) then
            raise Exception.Create('Removing tuner from the graph: ' + SysErrorMessage(hr));

        // if we could not connect the filter to any of the network providers: unknown type
        if not Connected then
            Result := Result + Chr(9) + '-';

    // for i
    end;

    // destroying graph
    Helper.DestroyGraph(Builder);

    // freeing sys dev enmum
    FreeAndNil(SysDevEnum);
end;


function TStreamReaderID.GetID: Integer;
begin
    Result := FID;
end;


function TStreamReaderID.GetStreamReader: TStreamReader;
begin
    Result := FStreamReader
end;


constructor TStreamReaderContainer.Create;
begin
    Randomize;
    FList := TList.Create;
end;


destructor TStreamReaderContainer.Destruct;
begin
    FList.Free;
end;


function TStreamReaderContainer.RegisterStreamReader(StreamReader: TStreamReader): Integer;
var
    ID: Integer;
begin
    repeat
        ID := 1 + Random(2147483647);
    until GetByID(ID) = nil;
    FList.Add(TStreamReaderID.Create(ID, StreamReader));

    Result := ID;
end;


function TStreamReaderContainer.GetByID(ID: Integer): TStreamReader;
var
    i : Integer;
begin
    for i := 0 to FList.Count - 1 do begin
        if TStreamReaderID(FList.Items[i]).GetID = ID then begin
            Result := TStreamReaderID(FList.Items[i]).GetStreamReader;
            Exit;
        end;
    end;
    Result := nil;
end;


procedure TStreamReaderContainer.RemoveByID(ID: Integer);
var
    i : Integer;
begin
    for i := 0 to FList.Count - 1 do begin
        if TStreamReaderID(FList.Items[i]).GetID = ID then begin
            FList.Remove(FList.Items[i]);
            Exit;
        end;
    end;
end;

end.
