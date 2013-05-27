unit uJSonStreamClientCoder;
////
///
///  �ַ���ת����UTF8���з���,����Ҳ��Ҫת�����з���
///   2013��5��25�� 09:41:24
///      ����ѹ������
////

interface

uses
  Classes, JSonStream, superobject, uClientSocket,
  uNetworkTools, uD10ClientSocket, uZipTools;

type
  TJSonStreamClientCoder = class(TSocketObjectCoder)
  public
    /// <summary>
    ///   ���뷢��
    /// </summary>
    /// <param name="pvSocket"> (TClientSocket) </param>
    /// <param name="pvObject"> (TObject) </param>
    procedure Encode(pvSocket: TClientSocket; pvObject: TObject); override;
    
    /// <summary>
    ///   ���ս���
    /// </summary>
    /// <returns> Boolean
    /// </returns>
    /// <param name="pvSocket"> (TClientSocket) </param>
    /// <param name="pvObject"> (TObject) </param>
    function Decode(pvSocket: TClientSocket; pvObject: TObject): Boolean; override;
  end;

implementation

uses
  Windows;

function TJSonStreamClientCoder.Decode(pvSocket: TClientSocket; pvObject:
    TObject): Boolean;
var
  lvJSonLength, lvStreamLength:Integer;
  lvData:String;
  lvStream:TStream;
  lvJsonStream:TJsonStream;
  lvBytes:TBytes;

  l:Integer;
  lvBufBytes:array[0..1023] of byte;
begin
  pvSocket.recvBuffer(@lvJSonLength, SizeOf(Integer));
  pvSocket.recvBuffer(@lvStreamLength, SizeOf(Integer));

  lvJSonLength := TNetworkTools.ntohl(lvJSonLength);
  lvStreamLength := TNetworkTools.ntohl(lvStreamLength);

  lvJsonStream := TJsonStream(pvObject);
  lvJsonStream.Clear(True);

  //��ȡjson�ַ���
  if lvJSonLength > 0 then
  begin
    SetLength(lvBytes, lvJSonLength);
    ZeroMemory(@lvBytes[0], lvJSonLength);
    pvSocket.recvBuffer(@lvBytes[0], lvJSonLength);

    lvData := TNetworkTools.Utf8Bytes2AnsiString(lvBytes);

    lvJsonStream.Json := SO(lvData);
  end;


  //��ȡ������ 
  if lvStreamLength > 0 then
  begin
    lvStream := lvJsonStream.Stream;
    lvStream.Size := 0;
    while lvStream.Size < lvStreamLength do
    begin
      l := pvSocket.recvBuffer(@lvBufBytes[0], SizeOf(lvBufBytes));
      lvStream.WriteBuffer(lvBufBytes, l);
    end;

    //��ѹ��
    if lvJsonStream.Json.B['config.stream.zip'] then
    begin
      //��ѹ
      TZipTools.unCompressStreamEX(lvJsonStream.Stream);
    end;
  end;
  Result := true;  
end;

procedure TJSonStreamClientCoder.Encode(pvSocket: TClientSocket; pvObject:
    TObject);
var
  lvJSonStream:TJsonStream;
  lvJSonLength:Integer;
  lvStreamLength:Integer;
  sData, lvTemp:String;
  lvStream:TStream;
  lvTempBuf:PAnsiChar;

  lvBytes, lvTempBytes:TBytes;
  
  l:Integer;
  lvBufBytes:array[0..1023] of byte;
begin
  if pvObject = nil then exit;
  lvJSonStream := TJsonStream(pvObject);
  
  //�Ƿ�ѹ����
  if (lvJSonStream.Stream <> nil) then
  begin
    if lvJSonStream.Json.O['config.stream.zip'] <> nil then
    begin
      if lvJSonStream.Json.B['config.stream.zip'] then
      begin
        //ѹ����
        TZipTools.compressStreamEx(lvJSonStream.Stream);
      end;
    end else if lvJSonStream.Stream.Size > 0 then
    begin
      //ѹ����
      TZipTools.compressStreamEx(lvJSonStream.Stream);
      lvJSonStream.Json.B['config.stream.zip'] := true;
    end;
  end;

  sData := lvJSonStream.JSon.AsJSon(True);


  lvBytes := TNetworkTools.ansiString2Utf8Bytes(sData);

  lvJSonLength := Length(lvBytes);
  lvStream := lvJSonStream.Stream;

  lvJSonLength := TNetworkTools.htonl(lvJSonLength);
  pvSocket.sendBuffer(@lvJSonLength, SizeOf(lvJSonLength));


  if lvStream <> nil then
  begin
    lvStreamLength := lvStream.Size;
  end else
  begin
    lvStreamLength := 0;
  end;

  lvStreamLength := TNetworkTools.htonl(lvStreamLength);
  pvSocket.sendBuffer(@lvStreamLength, SizeOf(lvStreamLength));




  //json bytes
  pvSocket.sendBuffer(@lvBytes[0], Length(lvBytes));

  if lvStream.Size > 0 then
  begin
    lvStream.Position := 0;
    repeat
      l := lvStream.Read(lvBufBytes, SizeOf(lvBufBytes));
      pvSocket.sendBuffer(@lvBufBytes[0], l);
    until (l = 0);
  end;
end;

end.