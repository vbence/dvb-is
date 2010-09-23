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

unit StreamDumpFilter;

interface

uses
    BaseClass, ComObj, DirectShow9, SysUtils, Windows;

const
    CLSID_StreamDumpFilter: TGUID = '{4e829f01-c9af-48bc-aa3f-2543b5b27110}';

type
    IStreamBuffer = interface
        procedure DataReceived(DataPointer: PByte; DataLength: Integer);
    end;

    TStreamDumpInputPin = class(TBCRenderedInputPin)
    protected
        FLock: TBCCritSec;
        FStreamBuffer: IStreamBuffer;
    public
        function CheckMediaType(mt: PAMMediaType): HRESULT; override;
        function Receive(pSample: IMediaSample): HRESULT; override;
        constructor Create(StreamBuffer: IStreamBuffer; ObjectName: string; Filter: TBCBaseFilter; Lock: TBCCritSec; out hr: HRESULT; Name: WideString);
        destructor Destroy; override;
    end;


    TStreamDumpFilter = class(TBCBaseFilter, IUnknown)
    private
        FPin: TStreamDumpInputPin;
    public
        constructor Create(StreamBuffer: IStreamBuffer);
        destructor Destroy; override;
        function GetPin(Pins: Integer): TBCBasePin; override;
        function GetPinCount: integer; override;
    end;


implementation


constructor TStreamDumpInputPin.Create(StreamBuffer: IStreamBuffer; ObjectName: string; Filter: TBCBaseFilter; Lock: TBCCritSec; out hr: HRESULT; Name: WideString);
begin
  inherited Create(ObjectName, Filter, Lock, hr, Name);
  FLock := TBCCritSec.Create();
  FStreamBuffer := StreamBuffer;
end;


destructor TStreamDumpInputPin.Destroy();
begin
    inherited Destroy;
end;


function TStreamDumpInputPin.CheckMediaType(mt: PAMMediaType): HRESULT;
begin
    result := S_OK;
end;


function TStreamDumpInputPin.Receive(pSample: IMediaSample): HRESULT;
var
    DataPointer: PByte;
    DataLength : Integer;
begin
    pSample.GetPointer(DataPointer);
    DataLength := pSample.GetActualDataLength;
    FLock.Lock;
    try
        FStreamBuffer.DataReceived(DataPointer, DataLength);
    finally
        FLock.UnLock;
    end;
    Result := S_OK;
end;


constructor TStreamDumpFilter.Create(StreamBuffer: IStreamBuffer);
var
    hr: HRESULT;
begin
    inherited Create('StreamDumpFilter', nil, TBCCritSec.Create(), CLSID_StreamDumpFilter);
    FPin := TStreamDumpInputPin.Create(StreamBuffer, 'StreamDump Input Pin', self, TBCCritSec.Create(), hr, 'StreamDump Pin');
end;


destructor TStreamDumpFilter.Destroy;
begin
    FreeAndNil(FPin);
    inherited Destroy();
end;


function TStreamDumpFilter.GetPin(Pins: Integer): TBCBasePin;
begin
    Result := FPin;
end;


function TStreamDumpFilter.GetPinCount: integer;
begin
    Result := 1;
end;


end.
