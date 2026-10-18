program testencoding;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, SysUtils, EncConv, uencoding;

var
  Failures: Integer = 0;

procedure Check(const AName: string; const AData: RawByteString;
  AExpectedCodepage: TEncConvId; const AExpectedNamePart: string = '');
var
  D: TEncodingDetection;
begin
  D := DetectEncodingData(AData);
  if (D.Codepage <> AExpectedCodepage) or
     ((AExpectedNamePart <> '') and (Pos(AExpectedNamePart, D.Name) = 0)) then
  begin
    Inc(Failures);
    WriteLn(Format('FAIL %-18s expected cp=%s name~"%s", got cp=%s name="%s" display="%s" conf=%d',
      [AName, cEncConvNames[AExpectedCodepage], AExpectedNamePart,
       cEncConvNames[D.Codepage], D.Name, D.Display, D.Confidence]));
  end
  else
    WriteLn(Format('PASS %-18s cp=%s name="%s" conf=%d',
      [AName, cEncConvNames[D.Codepage], D.Name, D.Confidence]));
end;

function Utf16Bytes(const S: string; ABigEndian: Boolean): RawByteString;
var
  U: UnicodeString;
  i: Integer;
  W: Word;
begin
  Result := '';
  U := UTF8Decode(S);
  for i := 1 to Length(U) do
  begin
    W := Ord(U[i]);
    if ABigEndian then
      Result := Result + Char(W shr 8) + Char(W and $FF)
    else
      Result := Result + Char(W and $FF) + Char(W shr 8);
  end;
end;

var
  U8, Gbk, Big5, Sjis, Korean: RawByteString;
  U16LE, U16BE: RawByteString;
begin
  U8 := '这是中文测试。';
  Gbk := EncConvertFromUTF8(U8, eidCP936);
  Big5 := EncConvertFromUTF8('這是中文測試。', eidCP950);
  Sjis := EncConvertFromUTF8('これは日本語のテストです。', eidCP932);
  Korean := EncConvertFromUTF8('이것은 한국어 테스트입니다.', eidCP949);
  U16LE := #$FF#$FE + Utf16Bytes(U8, False);
  U16BE := #$FE#$FF + Utf16Bytes(U8, True);

  Check('ascii', 'plain text' + LineEnding, eidUTF8);
  Check('utf8', U8, eidUTF8);
  Check('utf8-bom', #$EF#$BB#$BF + U8, eidUTF8, 'with BOM');
  Check('gbk', Gbk, eidCP936);
  Check('big5', Big5, eidCP950);
  Check('shift-jis', Sjis, eidCP932);
  Check('euc-kr', Korean, eidCP949);
  Check('utf16le-bom', U16LE, eidUCS2LE, 'UTF-16 LE');
  Check('utf16be-bom', U16BE, eidUCS2BE, 'UTF-16 BE');

  if Failures > 0 then
  begin
    WriteLn(Format('RESULT %d failure(s)', [Failures]));
    Halt(1);
  end;
  WriteLn('RESULT ok');
end.
