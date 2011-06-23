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

unit GraphBuilder;

interface

uses
  Windows, SysUtils, Variants, ActiveX, DirectShow9, DSUtil, StreamDumpFilter;

type
    TGraphHelper = class
    public
        constructor Create(GraphBuilder: IGraphBuilder);
        function ConnectTo(FilterOutput: IBaseFilter; FilterInput: IBaseFilter): HRESULT;
        function ConnectToNew(clsid: TGUID; var NewFilter: IBaseFilter; ExistingFilter: IBaseFilter): HRESULT;
        function ConnectToFirstApplicable(catid: TGUID; var NewFilter: IBaseFilter; ExistingFilter: IBaseFilter): HRESULT;
        function ConnectToDeviceWithPath(catid: TGUID; var NewFilter: IBaseFilter; ExistingFilter: IBaseFilter; DevicePath: String): HRESULT;
        function GetTopology(ExistingFilter: IBaseFilter; clsid: TGUID; var NewTopology: IUnknown): HRESULT;
        function DestroyGraph(GraphBuilder: IGraphBuilder): HRESULT;
    protected
        FGraphBuilder: IGraphBuilder;
        FCreateDevEnum: ICreateDevEnum;
    end;

    TCapturingGraph = class
    public
        NetworkProvider: IBaseFilter;
        constructor Create;
        procedure BuildGraph(StreamBuffer: IStreamBuffer; FreqKhz: LongInt; DevicePath: String);
        procedure DestroyGraph;
        function GetSignalStatistics(): IBDA_SignalStatistics;
    protected
        FMediaControl: IMediaControl;
        FRotEntry: LongInt;
        FGraphBuilder: IGraphBuilder;
        FSignalStatistics: IUnknown;
    end;


implementation

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
    for i := 0 to 1 do begin
        tmp := tmp + IntToHex(id.D4[i], 2);
    end;
    tmp := tmp + '-';
    for i := 2 to 7 do begin
        tmp := tmp + IntToHex(id.D4[i], 2);
    end;
    tmp := tmp + '}';
    Result := tmp;
end;


constructor TGraphHelper.Create(GraphBuilder: IGraphBuilder);
begin
    FGraphBuilder := GraphBuilder;
end;

// connecting filters by finding compatible pins
function TGraphHelper.ConnectTo(FilterOutput: IBaseFilter; FilterInput: IBaseFilter): HRESULT;
var
    // COM return code
    hr: HRESULT;

    // pins enumeration and information
    EnumOutputPins: IEnumPins;
    EnumInputPins: IEnumPins;
    PinOutput: IPin;
    PinInput: IPin;
    TempPin: IPin;
    TmpPinInfo: PIN_INFO;
begin
    // enumerating upstream filter's pins
    hr := FilterOutput.EnumPins(EnumOutputPins);
    if FAILED(hr) then
        raise Exception.Create('Enumerating upstream pins: ' + SysErrorMessage(hr));

    // iterate through upstream filter's pins
    while EnumOutputPins.Next(1, PinOutput, nil) = S_OK do begin

        // current upstream pin's info
        hr := PinOutput.QueryPinInfo(TmpPinInfo);
        if FAILED(hr) then
            raise Exception.Create('Getting upstream pin info.' + SysErrorMessage(hr));

        // getting the endpoint of the current upstream pin (if any)
        PinOutput.ConnectedTo(TempPin);

        // IF not connected AND it is an output pin
        if (TempPin = nil) and (TmpPinInfo.dir = PINDIR_OUTPUT) then begin

            // enumerating downstream filter's pins
            hr := FilterInput.EnumPins(EnumInputPins);
            if FAILED(hr) then
                raise Exception.Create('Enumerating downstream pins.' + SysErrorMessage(hr));

            // iterate through downstream filter's pins
            while EnumInputPins.Next(1, PinInput, nil) = S_OK do begin

                // current downstream pin's info
                hr := PinInput.QueryPinInfo(TmpPinInfo);
                if FAILED(hr) then
                    raise Exception.Create('Getting downstream pin info.' + SysErrorMessage(hr));

                // getting endpoint (if any)
                PinInput.ConnectedTo(TempPin);

                // IF not connected AND input pin
                if (TempPin = nil) and (TmpPinInfo.dir = PINDIR_INPUT) then begin

                    // trying to connect the two pins
                    hr := FGraphBuilder.ConnectDirect(PinOutput, PinInput, nil);

                    // IF successfully connected ...
                    if SUCCEEDED(hr) then begin
                        Result := S_OK;
                        Exit;
                    end;

                // if
                end;

            // while
            end;

        // if
        end;

    // while
    end;

    // have not found compatible pins: unsuccessful attempt
    Result := E_FAIL;
end;


// finds the first applicable filter from the given category, and connects it
// with the existing "ExistingFilter"
function TGraphHelper.ConnectToFirstApplicable(catid: TGUID; var NewFilter: IBaseFilter; ExistingFilter: IBaseFilter): HRESULT;
var
    // COM return code
    hr: HRESULT;

    // fiter listing and information
    EnumMoniker: IEnumMoniker;
    Moniker: IMoniker;
    PropertyBag: IPropertyBag;
    FriendlyNameOle: OleVariant;

    // currently ied filter
    Filter: IBaseFilter;
begin
    // placeholder for the resulting filter has to be empty
    if Assigned(NewFilter) then
       raise Exception.Create('Placeholder for the resulting filter has to be empty.');

    // creating SystemDeviceEnum if needed
    if not Assigned(FCreateDevEnum) then begin
        hr := CoCreateInstance(CLSID_SystemDeviceEnum, nil, CLSCTX_INPROC, IID_ICreateDevEnum, FCreateDevEnum);
        if FAILED(hr) then
            raise Exception.Create('Creating SystemDeviceEnum: ' + SysErrorMessage(hr));
    end;

    // obtaining class enumerator for the given filter class (clsid)
    hr := FCreateDevEnum.CreateClassEnumerator(catid, EnumMoniker, 0);
    // the call can return S_FALSE if no moniker exists, so explicitly check S_OK
    if hr <> S_OK then
        raise Exception.Create('Creating class enumerator: ' + SysErrorMessage(hr));

    // iterating thru filters of the category
    while(EnumMoniker.Next(1, Moniker, nil) = S_OK) do begin

        // obtain filter's friendly name
        hr := Moniker.BindToStorage(nil, nil, IID_IPropertyBag, PropertyBag);
        if FAILED(hr) then
            raise Exception.Create('Getting moniker (filter) properties: ' + SysErrorMessage(hr));

        // getting friendly name
        hr := PropertyBag.Read('FriendlyName', FriendlyNameOle, nil);
        if FAILED(hr) then begin
            hr := PropertyBag.Read('CLSID', FriendlyNameOle, nil);
            if FAILED(hr) then begin
                FriendlyNameOle := 'Unnamed Filter';
            end;
        end;

        // getting the current filter
        hr := Moniker.BindToObject(nil, nil, IID_IBaseFilter, Filter);
        if FAILED(hr) then
            raise Exception.Create('Getting filter from the moniker: ' + SysErrorMessage(hr));

        // add filter to the graph
        hr := FGraphBuilder.AddFilter(Filter, PWideChar(WideString(FriendlyNameOle)));
        if FAILED(hr) then
            raise Exception.Create('Adding filter to the graph: ' + SysErrorMessage(hr));

        // if an existing filter to connect with is given in param "ExistingFilter"
        if Assigned(ExistingFilter) then begin

            // attempt to connect
            hr := ConnectTo(ExistingFilter, Filter);

            // is connection successful?
            if SUCCEEDED(hr) then begin
                newFilter := Filter;
                Result := S_OK;
                Exit;
            end else begin
                hr := FGraphBuilder.RemoveFilter(Filter);
                if FAILED(hr) then
                   raise Exception.Create('Removing tried filter: ' + SysErrorMessage(hr));

            end;

        end else begin
            NewFilter := Filter;
            Result := S_OK;
            Exit;
        end;

    // while
    end;

    // no suitable filter found
    Result := E_FAIL;
end;

// finds the first applicable filter from the given category, and connects it
// with the existing "ExistingFilter"
function TGraphHelper.ConnectToDeviceWithPath(catid: TGUID; var NewFilter: IBaseFilter; ExistingFilter: IBaseFilter; DevicePath: String): HRESULT;
var
    // COM return code
    hr: HRESULT;

    // fiter listing and information
    EnumMoniker: IEnumMoniker;
    Moniker: IMoniker;
    PropertyBag: IPropertyBag;
    FriendlyNameOle: OleVariant;
    CurrentDevicePAthOle: OleVariant;

    // currently ied filter
    Filter: IBaseFilter;
begin
    // placeholder for the resulting filter has to be empty
    if Assigned(NewFilter) then
       raise Exception.Create('Placeholder for the resulting filter has to be empty.');

    // placeholder for the resulting filter has to be empty
    if DevicePath = ''  then
       raise Exception.Create('Empty DevicePath. (which is bad)');

    // creating SystemDeviceEnum if needed
    if not Assigned(FCreateDevEnum) then begin
        hr := CoCreateInstance(CLSID_SystemDeviceEnum, nil, CLSCTX_INPROC, IID_ICreateDevEnum, FCreateDevEnum);
        if FAILED(hr) then
            raise Exception.Create('Creating SystemDeviceEnum: ' + SysErrorMessage(hr));
    end;

    // obtaining class enumerator for the given filter class (clsid)
    hr := FCreateDevEnum.CreateClassEnumerator(catid, EnumMoniker, 0);
    // the call can return S_FALSE if no moniker exists, so explicitly check S_OK
    if hr <> S_OK then
        raise Exception.Create('Creating class enumerator: ' + SysErrorMessage(hr));

    // iterating thru filters of the category
    while(EnumMoniker.Next(1, Moniker, nil) = S_OK) do begin

        // obtain filter's friendly name
        hr := Moniker.BindToStorage(nil, nil, IID_IPropertyBag, PropertyBag);
        if FAILED(hr) then
            raise Exception.Create('Getting moniker (filter) properties: ' + SysErrorMessage(hr));

        // getting device path
        hr := PropertyBag.Read('DevicePath', CurrentDevicePathOle, nil);
        if FAILED(hr) then
            raise Exception.Create('Getting device path: ' + SysErrorMessage(hr));

        // is the device path what we are looking for?
        if WideString(CurrentDevicePathOle) = DevicePath then begin

            // getting friendly name
            hr := PropertyBag.Read('FriendlyName', FriendlyNameOle, nil);
            if FAILED(hr) then begin
                hr := PropertyBag.Read('CLSID', FriendlyNameOle, nil);
                if FAILED(hr) then begin
                    FriendlyNameOle := 'Unnamed Filter';
                end;
            end;

            // getting the current filter
            hr := Moniker.BindToObject(nil, nil, IID_IBaseFilter, Filter);
            if FAILED(hr) then
                raise Exception.Create('Getting filter from the moniker: ' + SysErrorMessage(hr));

            // add filter to the graph
            hr := FGraphBuilder.AddFilter(Filter, PWideChar(WideString(FriendlyNameOle)));
            if FAILED(hr) then
                raise Exception.Create('Adding filter to the graph: ' + SysErrorMessage(hr));

            // if an existing filter to connect with is given in param "ExistingFilter"
            if Assigned(ExistingFilter) then begin

                // attempt to connect
                hr := ConnectTo(ExistingFilter, Filter);

                // is connection successful?
                if SUCCEEDED(hr) then begin
                    newFilter := Filter;
                    Result := S_OK;
                    Exit;
                end else begin
                    hr := FGraphBuilder.RemoveFilter(Filter);
                    if FAILED(hr) then
                       raise Exception.Create('Removing tried filter: ' + SysErrorMessage(hr));

                    // we found the device but could not connect it (no more iteration needed)
                    Result := E_FAIL;
                    Exit;
                end;

            end else begin
                NewFilter := Filter;
                Result := S_OK;
                Exit;
            end;

        // if DevicePath
        end;

    // while
    end;

    // no suitable filter found
    Result := E_FAIL;
end;


function TGraphHelper.ConnectToNew(clsid: TGUID; var NewFilter: IBaseFilter; ExistingFilter: IBaseFilter): HRESULT;
var
    // COM return code
    hr: HRESULT;

    // filter creation and information
    Filter: IBaseFilter;
    FilterInfo: _FilterInfo;
begin
    // placeholder for the resulting filter has to be empty
    if Assigned(NewFilter) then
       raise Exception.Create('Placeholder for the resulting filter has to be empty.');

    // creating
    hr := CoCreateInstance(clsid, nil, CLSCTX_INPROC_SERVER, IID_IBaseFilter, Filter);
    if FAILED(hr) then
       raise Exception.Create('Creating filter: ' + SysErrorMessage(hr));

    // getting filter info (filter's name)
    Filter.QueryFilterInfo(FilterInfo);

    // adding to GraphBuilder
    hr := FGraphBuilder.AddFilter(Filter, FilterInfo.achName);
    if FAILED(hr) then
       raise Exception.Create('Adding to graph: ' + SysErrorMessage(hr));

    if Assigned(ExistingFilter) then begin

        // attempt to connect
        hr := ConnectTo(ExistingFilter, Filter);

        // IF sucessful
        if SUCCEEDED(hr) then begin

            // success
            NewFilter := Filter;
            Result := S_OK;
            Exit;

        end else begin

            // removing filter
            hr := FGraphBuilder.RemoveFilter(NewFilter);
            if FAILED(hr) then
               raise Exception.Create('Removing failing filter: ' + SysErrorMessage(hr));

            // destroying object
            FreeAndNil(Filter);
        end;

    end else begin

        // success
        NewFilter := Filter;
        Result := S_OK;
        Exit;
    end;

    Result := E_FAIL;
end;


function TGraphHelper.GetTopology(ExistingFilter: IBaseFilter; clsid: TGUID; var NewTopology: IUnknown): HRESULT;
const
    CMAXTYPECOUNT = 20;
    CMAXINTERFACECOUNT = 20;
var
    // COM return code
    hr: HRESULT;

    // cycle variables
    i, j: Integer;

    // helper variables
    TempInterface: IUnknown;
    FoundInterface: IUnknown;

    // topology variables
    Topology: IBDA_Topology;
    NodeTypeCount: Cardinal;
    NodeTypes: array[0..CMAXINTERFACECOUNT - 1] of Cardinal;
    NodeInterfaceCount: Cardinal;
    NodeInterfaces: array[0..CMAXTYPECOUNT - 1] of TGUID;

begin

    // Get IBDA_Topology interface
    hr := ExistingFilter.QueryInterface(IID_IBDA_Topology, Topology);
    if FAILED(hr) then
       raise Exception.Create('Getting filter topology: ' + SysErrorMessage(hr));

    // query node types in the topology (connecting pin0 to pin1)
    hr := Topology.GetNodeTypes(NodeTypeCount, CMAXTYPECOUNT, PULONG(@NodeTypes));
    if FAILED(hr) then
       raise Exception.Create('Getting topology node types: ' + SysErrorMessage(hr));

    // iterating thru node types
    for i := 0 to NodeTypeCount - 1 do begin

        // getting interfaces for the acual node type
        hr := Topology.GetNodeInterfaces(NodeTypes[i], NodeInterfaceCount, CMAXINTERFACECOUNT, @NodeInterfaces);
        if FAILED(hr) then
           raise Exception.Create('Getting node interfaces: ' + SysErrorMessage(hr));

        // listing interfaces for the current control node
        for j := 0 to NodeInterfaceCount -1 do begin

            // if the control node has the needed interface
            if IsEqualGUID(NodeInterfaces[j], clsid) then begin

                // getting the control node
                hr := Topology.GetControlNode(0, 1, NodeTypes[i], TempInterface);
                if FAILED(hr) then
                   raise Exception.Create('Getting control node: ' + SysErrorMessage(hr));

                // getting the interface asked by the caller
                hr := TempInterface.QueryInterface(clsid, FoundInterface);
                if FAILED(hr) then
                   raise Exception.Create('Getting the needed interface: ' + SysErrorMessage(hr));

                // all ok
                NewTopology := FoundInterface;
                Result := S_OK;
                Exit;

            // if IsEqualGUID
            end;

        // for j
        end;

    // for i
    end;

    // failure: no control node with the given interface found
    Result := E_FAIL;
end;

function TGraphHelper.DestroyGraph(GraphBuilder: IGraphBuilder): HRESULT;
var
    // COM return code helper
    hr: HRESULT;

    // helrs to handle the graph
    MediaControl: IMediaControl;
    Enum: IEnumFilters;
    Filter: IBaseFilter;
begin
    // get MediaControl interface from FGraphBuilder
    hr := FGraphBuilder.QueryInterface(IID_IMediaControl, MediaControl);
    if FAILED(hr) then
       raise Exception.Create('Getting IMediaControl: ' + SysErrorMessage(hr));

    // (trying to) stop the graph
    hr := MediaControl.Stop;
    if FAILED(hr) then
       raise Exception.Create('Stopping graph: ' + SysErrorMessage(hr));

    // remove all the filters from the graph
    GraphBuilder.EnumFilters(Enum);
    while Enum.Next(1, Filter, nil) = S_OK do begin
        FGraphBuilder.RemoveFilter(Filter);
        Filter := nil;
        Enum.Reset;
    end;

    Result := S_OK;
end;


constructor TCapturingGraph.Create();
begin
end;

(*
 * Building the filter graph:
 *
 *  NetworkProvider > Tuner > Capture          > Demux > Transport Information
 *                                    > InfTee         > Sections and Filters
 *
 *                                             > StreamDump (the real goal)
 *
 * The Demux and its children are needed by the Network Provider to do the
 * tuning (in fact TIF is needed). Quite illogical, but this is how it works...
 *)
procedure TCapturingGraph.BuildGraph(StreamBuffer: IStreamBuffer; FreqKhz: LongInt; DevicePath: String);
var

    // COM return code holder
    hr: HRESULT;

    // helper (building graph)
    Helper: TGraphHelper;

    // tuning objects
    TuningSpace: IDVBTuningSpace;
    //NetworkProvider: IBaseFilter;
    TempTuneRequest: ITuneRequest;
    TuneRequest: IDVBTuneRequest;
    DVBTLocator: IDVBTLocator;
    Tuner: ITuner;

    // filter chain objects
    TunerDevice: IBaseFilter;
    CaptureDevice: IBaseFilter;
    InfTee: IBaseFilter;
    Demux: IBaseFilter;
    TIF1: IBaseFilter;
    TIF2: IBaseFilter;
    StreamDump: TStreamDumpFilter;

begin

    // creatring graph builder
    hr := CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC, IID_IGraphBuilder, FGraphBuilder);
    if FAILED(hr) then
       raise Exception.Create('Creating IGraphBuilder: ' + SysErrorMessage(hr));

    // initializing helper (functions to insert and connect filters)
    Helper := TGraphHelper.Create(FGraphBuilder);

    // adding graph to ROT (running object table)
    hr := AddGraphToRot(FGraphBuilder, FRotEntry);
    if FAILED(hr) then
       raise Exception.Create('Adding graph to ROT: ' + SysErrorMessage(hr));


    // creating network provider
    hr := CoCreateInstance(CLSID_DVBTNetworkProvider, nil, CLSCTX_INPROC_SERVER, IID_IBaseFilter, NetworkProvider);
    if FAILED(hr) then
       raise Exception.Create('Creating network provider: ' + SysErrorMessage(hr));

    // adding network provider to the graph
    hr := FGraphBuilder.AddFilter(NetworkProvider, 'Network Provider');
    if FAILED(hr) then
       raise Exception.Create('Adding network provider to the graph: ' + SysErrorMessage(hr));

    // network provider as ITuner (We could have created it to point to an ITuner
    // but then the "NetworkProvider" name would not fit the object.)
    hr := NetworkProvider.QueryInterface(IID_ITuner, Tuner);
    if FAILED(hr) then
       raise Exception.Create('Getting interface ITuner: ' + SysErrorMessage(hr));


    // tuning space setup: CREATE
    hr := CoCreateInstance(CLSID_DVBTuningSpace, nil, CLSCTX_INPROC_SERVER, IID_IDVBTuningSpace, TuningSpace);
    if FAILED(hr) then
       raise Exception.Create('Creating tuning space: ' + SysErrorMessage(hr));

    // setting SystemType
    hr := TuningSpace.put_SystemType(DVB_Terrestrial);
    if FAILED(hr) then
       raise Exception.Create('Setting system type: ' + SysErrorMessage(hr));

    // setting NetworkType
    hr := TuningSpace.put_NetworkType(GUIDToString(CLSID_DVBTNetworkProvider));
    if FAILED(hr) then
       raise Exception.Create('Setting network type: ' + SysErrorMessage(hr));


    // creating tune request (only ITuneRequest, see the next step)
    hr := TuningSpace.CreateTuneRequest(TempTuneRequest);
    if FAILED(hr) then
       raise Exception.Create('Creating DVB-T tune request: ' + SysErrorMessage(hr));

    // since IDVBTuningSpace.CreateTuneRequest returns ITuneRequest we have to query the IDVBTuneRequest interface
    hr := TempTuneRequest.QueryInterface(IID_IDVBTuneRequest, TuneRequest);
    if FAILED(hr) then
       raise Exception.Create('Getting interface IDVBTuneRequest: ' + SysErrorMessage(hr));


    // create a locator (IDVBTLocator)
    hr := CoCreateInstance(CLSID_DVBTLocator, nil, CLSCTX_INPROC_SERVER, IID_IDVBTLocator, DVBTLocator);
    if FAILED(hr) then
       raise Exception.Create('Creating DVB-T locator: ' + SysErrorMessage(hr));

    // set up the locator (frequency, etc.)
    hr := DVBTLocator.put_CarrierFrequency(FreqKhz);
    if FAILED(hr) then
       raise Exception.Create('Setting frequency: ' + SysErrorMessage(hr));

    // set the request's locator
    hr := TuneRequest.put_Locator(DVBTLocator);
    if FAILED(hr) then
       raise Exception.Create('Adding locator to request: ' + SysErrorMessage(hr));


    // setting tune request
    hr := Tuner.put_TuneRequest(TuneRequest);
    if FAILED(hr) then
       raise Exception.Create('Adding request to tuner: ' + SysErrorMessage(hr));


    // create a tuner filter (compatible with the previously set up NetworkProvider)
    if DevicePath = '' then begin

        // try the first applicable device
        hr := Helper.ConnectToFirstApplicable(KSCATEGORY_BDA_NETWORK_TUNER, TunerDevice, NetworkProvider);
        if FAILED(hr) then
           raise Exception.Create('Loading first applicable tuner device: ' + SysErrorMessage(hr));

    end else begin

        // use one with the given DevicePath
        hr := Helper.ConnectToDeviceWithPath(KSCATEGORY_BDA_NETWORK_TUNER, TunerDevice, NetworkProvider, DevicePath);
        if FAILED(hr) then
           raise Exception.Create('Loading tuner device by path: ' + SysErrorMessage(hr));

    end;

    // create a capture device (the conjoint twin of the TunerDevice previously crteated)
    hr := Helper.ConnectToFirstApplicable(KSCATEGORY_BDA_RECEIVER_COMPONENT, CaptureDevice, TunerDevice);
    if FAILED(hr) then
       raise Exception.Create('Loading capture device: ' + SysErrorMessage(hr));


    // connecting InfTee filter
    hr := Helper.ConnectToNew(CLSID_InfTee, InfTee, CaptureDevice);
    if FAILED(hr) then
       raise Exception.Create('Loading Infinite Pin Tee: ' + SysErrorMessage(hr));


    // adding MPEG2Demultiplexer (and connecting it to InfTee)
    hr := Helper.ConnectToNew(CLSID_MPEG2Demultiplexer, Demux, InfTee);
    if FAILED(hr) then
       raise Exception.Create('Loading Demux: ' + SysErrorMessage(hr));


    // adding Transport Information to demux (togather with the following call
    // TIF and SaT filters are added, the ORDER is indetermined)
    hr := Helper.ConnectToFirstApplicable(KSCATEGORY_BDA_TRANSPORT_INFORMATION, TIF1, Demux);
    if FAILED(hr) then
       raise Exception.Create('Adding TIF(1): ' + SysErrorMessage(hr));

    // adding Sections and Tables to demux
    hr := Helper.ConnectToFirstApplicable(KSCATEGORY_BDA_TRANSPORT_INFORMATION, TIF2, Demux);
    if FAILED(hr) then
       raise Exception.Create('Adding TIF(2): ' + SysErrorMessage(hr));


    // creating StreamDump filter
    StreamDump := TStreamDumpFilter.Create(StreamBuffer);

    // adding StreamDump to graph
    hr := FGraphBuilder.AddFilter(StreamDump, 'StreamDump filter');
    if FAILED(hr) then
       raise Exception.Create('Adding StreamDumpFilter to graph: ' + SysErrorMessage(hr));

    // connecting to InTee
    hr := Helper.ConnectTo(InfTee, StreamDump);
    if FAILED(hr) then
       raise Exception.Create('Connecting StreamDumpFilter: ' + SysErrorMessage(hr));


    // getting SignalStrength topology
    hr := Helper.GetTopology(TunerDevice, IID_IBDA_SignalStatistics, FSignalStatistics);
    if FAILED(hr) then
       raise Exception.Create('Getting SignalStatistics topology: ' + SysErrorMessage(hr));


    // getting IMediaControl interface of the graph builder
    hr := FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);
    if FAILED(hr) then
       raise Exception.Create('Getting IMediaControl interface: ' + SysErrorMessage(hr));

    // running the graph
    hr := FMediaControl.run;
    if FAILED(hr) then
       raise Exception.Create('Running graph: ' + SysErrorMessage(hr));

end;


procedure TCapturingGraph.DestroyGraph;
var
    // COM return code helper
    hr: HRESULT;

    // helrs to handle the graph
    MediaControl: IMediaControl;
    Enum: IEnumFilters;
    Filter: IBaseFilter;
begin

    // remove grpah from ROT
    RemoveGraphFromRot(FRotEntry);

    // get MediaControl interface from FGraphBuilder
    hr := FGraphBuilder.QueryInterface(IID_IMediaControl, MediaControl);
    if FAILED(hr) then
       raise Exception.Create('Getting IMediaControl: ' + SysErrorMessage(hr));

    // (trying to) stop the graph
    hr := MediaControl.Stop;
    if FAILED(hr) then
       raise Exception.Create('Stopping graph: ' + SysErrorMessage(hr));

    // remove all the filters from the graph
    FGraphBuilder.EnumFilters(Enum);
    while Enum.Next(1, Filter, nil) = S_OK do begin
        FGraphBuilder.RemoveFilter(Filter);
        Filter := nil;
        Enum.Reset;
    end;

    FSignalStatistics := nil;

end;

function TCapturingGraph.GetSignalStatistics(): IBDA_SignalStatistics;
begin
    Result := IBDA_SignalStatistics(FSignalStatistics);
end;

end.

