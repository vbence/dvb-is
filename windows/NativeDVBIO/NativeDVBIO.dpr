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

library NativeDVBIO;

uses
    JNI,
    SysUtils,
    Windows,
    ActiveX,
    StreamReader;

var
    FStreamReaders: TStreamReaderContainer;

procedure Throw(PEnv: PJNIEnv; Obj: JObject; Msg: String); stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    MID: JMethodID;
    Ex: JObject;
begin
    JVM := TJNIEnv.Create(PEnv);

    Cls := JVM.FindClass('java/io/IOException');
    // err?

    MID := JVM.GetMethodID(Cls, '<init>', '(Ljava/lang/String;)V');
    // err?

    Ex := JVM.NewObject(cls, MID, [Msg]);

    JVM.Throw(Ex);

    JVM.Free;

end;

procedure Java_org_czentral_dvb_io_NativeDVBIO_open(PEnv: PJNIEnv; Obj: JObject; Freq: JLong; Device: JString); stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;

    StreamReader: TStreamReader;
    ResourceID: Integer;
    FreqKhz: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);

    // BDA requires frequencies in Khz
    FreqKhz := Round(Freq / 1000);
    StreamReader := TStreamReader.Create(FreqKhz, JVM.JStringToString(Device));

    ResourceID := FStreamReaders.RegisterStreamReader(StreamReader);

    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    JVM.SetIntField(Obj, FID, ResourceID);

    try
        StreamReader.Start;
    except
        on E: Exception do
            Throw(PEnv, Obj, E.Message);
    end;
end;


procedure Java_org_czentral_dvb_io_NativeDVBIO_close(PEnv: PJNIEnv; Obj: JObject); stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;

    StreamReader: TStreamReader;
    ResourceID: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);
    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    ResourceID := JVM.GetIntField(Obj, FID);

    if ResourceID = 0 then begin
        Throw(PEnv, Obj, 'Stream not open.');
    end else begin
        StreamReader := FStreamReaders.GetByID(ResourceID);

        try
            StreamReader.Stop;
        except
            on E: Exception do
                Throw(PEnv, Obj, E.Message);
        end;

        FStreamReaders.RemoveByID(ResourceID);
        JVM.SetIntField(Obj, FID, 0);
    end;

    JVM.Free;
end;

function Java_org_czentral_dvb_io_NativeDVBIO_available(PEnv: PJNIEnv; Obj: JObject): JInt; stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;

    StreamReader: TStreamReader;
    ResourceID: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);
    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    ResourceID := JVM.GetIntField(Obj, FID);

    if ResourceID = 0 then begin
        Throw(PEnv, Obj, 'Stream not open.');
        Result := 0;
    end else begin
        StreamReader := FStreamReaders.GetByID(ResourceID);
        Result := StreamReader.GetDataLength;
    end;
end;

function Java_org_czentral_dvb_io_NativeDVBIO_isSignalPresent(PEnv: PJNIEnv; Obj: JObject): JBoolean; stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;

    StreamReader: TStreamReader;
    ResourceID: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);
    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    ResourceID := JVM.GetIntField(Obj, FID);

    if ResourceID = 0 then begin
        Throw(PEnv, Obj, 'Stream not open.');
        Result := false;
    end else begin
        StreamReader := FStreamReaders.GetByID(ResourceID);
        Result := StreamReader.IsSignalPresent;
    end;

end;

function Java_org_czentral_dvb_io_NativeDVBIO_isSignalLocked(PEnv: PJNIEnv; Obj: JObject): JBoolean; stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;

    StreamReader: TStreamReader;
    ResourceID: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);
    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    ResourceID := JVM.GetIntField(Obj, FID);

    if ResourceID = 0 then begin
        Throw(PEnv, Obj, 'Stream not open.');
        Result := false;
    end else begin
        StreamReader := FStreamReaders.GetByID(ResourceID);
        Result := StreamReader.IsSignalLocked;
    end;
end;

function Java_org_czentral_dvb_io_NativeDVBIO_getSignalStrength(PEnv: PJNIEnv; Obj: JObject): JInt; stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;

    StreamReader: TStreamReader;
    ResourceID: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);
    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    ResourceID := JVM.GetIntField(Obj, FID);

    if ResourceID = 0 then begin
        Throw(PEnv, Obj, 'Stream not open.');
        Result := 0;
    end else begin
        StreamReader := FStreamReaders.GetByID(ResourceID);
        Result := StreamReader.GetSignalStrength;
    end;

end;

function Java_org_czentral_dvb_io_NativeDVBIO_getSignalQuality(PEnv: PJNIEnv; Obj: JObject): JInt; stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;

    StreamReader: TStreamReader;
    ResourceID: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);
    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    ResourceID := JVM.GetIntField(Obj, FID);

    if ResourceID = 0 then begin
        Throw(PEnv, Obj, 'Stream not open.');
        Result := 0;
    end else begin
        StreamReader := FStreamReaders.GetByID(ResourceID);
        Result := StreamReader.GetSignalQuality;
    end;

end;

function Java_org_czentral_dvb_io_NativeDVBIO_read(PEnv: PJNIEnv; Obj: JObject; Buffer: JByteArray; Offset: JInt; Length: JInt): JInt; stdcall;
var
    JVM: TJNIEnv;
    Cls: JClass;
    FID: JFieldID;
    Elements: PJByte;
    isCopy: JBoolean;

    StreamReader: TStreamReader;
    ResourceID: Integer;
begin
    JVM := TJNIEnv.Create(PEnv);
    Cls := JVM.GetObjectClass(Obj);
    FID := JVM.GetFieldID(Cls, 'resourceID', 'I');
    ResourceID := JVM.GetIntField(Obj, FID);

    if ResourceID = 0 then begin

        Throw(PEnv, Obj, 'Stream not open.');
        Result := 0;

    end else begin

        StreamReader := FStreamReaders.GetByID(ResourceID);
        Elements := JVM.GetByteArrayElements(Buffer, isCopy);
        Result := StreamReader.Read(PByte(Elements), JVM.GetArrayLength(Buffer));
        JVM.ReleaseByteArrayElements(Buffer, Elements, 0);

    end;

    JVM.Free;
end;

function Java_org_czentral_dvb_io_NativeDVBIO_listDevices(PEnv: PJNIEnv; Cls: JClass): JString; stdcall;
var
    JVM: TJNIEnv;
    ListString: String;
begin
    JVM := TJNIEnv.Create(PEnv);

    ListString := '';
    try
        ListString := TStreamReader.ListDevices;
    except
        on E: Exception do
            Throw(PEnv, Cls, E.Message);
    end;

    Result := JVM.StringToJString(PAnsiChar(ListString));
end;

exports
    Java_org_czentral_dvb_io_NativeDVBIO_open,
    Java_org_czentral_dvb_io_NativeDVBIO_close,
    Java_org_czentral_dvb_io_NativeDVBIO_available,
    Java_org_czentral_dvb_io_NativeDVBIO_isSignalPresent,
    Java_org_czentral_dvb_io_NativeDVBIO_isSignalLocked,
    Java_org_czentral_dvb_io_NativeDVBIO_getSignalStrength,
    Java_org_czentral_dvb_io_NativeDVBIO_getSignalQuality,
    Java_org_czentral_dvb_io_NativeDVBIO_listDevices,
    Java_org_czentral_dvb_io_NativeDVBIO_read;

procedure DLLMain(reason: integer);
begin
    if reason = DLL_PROCESS_ATTACH then begin
        CoInitialize(nil);
        FStreamReaders := TStreamReaderContainer.Create;
    end;
end;

begin
   DllProc := @DLLMain;
   DllProc(DLL_PROCESS_ATTACH);
end.
