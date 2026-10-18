unit uencoding;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  ATSynEdit, ATStrings, ATStringProc, EncConv;

type
  TEncodingChoice = record
    Name: string;       // name accepted by TATSynEdit.EncodingName
    Display: string;
    Codepage: TEncConvId;
    WithBom: Boolean;
  end;
  TEncodingChoiceArray = array of TEncodingChoice;

  TEncodingDetection = record
    Name: string;       // name accepted by TATSynEdit.EncodingName
    Display: string;
    Codepage: TEncConvId;
    Confidence: Integer;
  end;

function EncodingChoices: TEncodingChoiceArray;
function EncodingChoiceByName(const AName: string): TEncodingChoice;
function DetectEncodingData(const AData: RawByteString): TEncodingDetection;
function DetectFileEncoding(const AFileName: string): TEncodingDetection;
function EncodingDisplayName(AEditor: TATSynEdit): string;
function EolName(AEnding: TATLineEnds): string;
function EolFromName(const AName: string): TATLineEnds;
function EolDisplayName(AEditor: TATSynEdit): string;
procedure SetEditorEncoding(AEditor: TATSynEdit; const AName: string;
  AMarkModified: Boolean = True);
procedure SetEditorEol(AEditor: TATSynEdit; AEnding: TATLineEnds;
  AMarkModified: Boolean = True);

function DefaultEol: TATLineEnds;

implementation

procedure AddChoice(var AList: TEncodingChoiceArray; const AName, ADisplay: string;
  ACodepage: TEncConvId; AWithBom: Boolean);
var
  N: Integer;
begin
  N := Length(AList);
  SetLength(AList, N + 1);
  AList[N].Name := AName;
  AList[N].Display := ADisplay;
  AList[N].Codepage := ACodepage;
  AList[N].WithBom := AWithBom;
end;

function EncodingChoices: TEncodingChoiceArray;
const
  AnsiNames: array[0..21] of TEncConvId = (
    eidCP1252, eidCP1251, eidCP1250, eidCP1253, eidCP1254, eidCP1255,
    eidCP1256, eidCP1257, eidCP1258, eidCP932, eidCP936, eidCP949,
    eidCP950, eidCP874, eidCP437, eidCP850, eidCP852, eidCP866,
    eidISO1, eidISO2, eidISO15, eidKOI8R);
var
  i: Integer;
  Cp: TEncConvId;
  D: string;
begin
  Result := nil;
  AddChoice(Result, 'UTF-8', 'UTF-8', eidUTF8, False);
  AddChoice(Result, 'UTF-8 with BOM', 'UTF-8 with BOM', eidUTF8, True);
  AddChoice(Result, 'UTF-16 LE', 'UTF-16 LE', eidUCS2LE, False);
  AddChoice(Result, 'UTF-16 LE with BOM', 'UTF-16 LE with BOM', eidUCS2LE, True);
  AddChoice(Result, 'UTF-16 BE', 'UTF-16 BE', eidUCS2BE, False);
  AddChoice(Result, 'UTF-16 BE with BOM', 'UTF-16 BE with BOM', eidUCS2BE, True);
  AddChoice(Result, 'UTF-32 LE', 'UTF-32 LE', eidUTF8, False);
  AddChoice(Result, 'UTF-32 LE with BOM', 'UTF-32 LE with BOM', eidUTF8, True);
  AddChoice(Result, 'UTF-32 BE', 'UTF-32 BE', eidUTF8, False);
  AddChoice(Result, 'UTF-32 BE with BOM', 'UTF-32 BE with BOM', eidUTF8, True);

  AddChoice(Result, cEncConvNames[EncConvGetANSI],
    'ANSI (' + cEncConvNames[EncConvGetANSI] + ')',
    EncConvGetANSI, False);
  for i := Low(AnsiNames) to High(AnsiNames) do
  begin
    Cp := AnsiNames[i];
    if Cp = EncConvGetANSI then Continue;
    D := cEncConvNames[Cp];
    if Cp = eidCP932 then D := D + ' / Shift-JIS'
    else if Cp = eidCP936 then D := D + ' / GBK'
    else if Cp = eidCP950 then D := D + ' / Big5'
    else if Cp = eidCP949 then D := D + ' / Korean'
    else if Cp = eidCP874 then D := D + ' / Thai';
    AddChoice(Result, cEncConvNames[Cp], 'ANSI ' + D,
      Cp, False);
  end;
end;

function EncodingChoiceByName(const AName: string): TEncodingChoice;
var
  C: TEncodingChoiceArray;
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  C := EncodingChoices;
  for i := 0 to High(C) do
    if SameText(C[i].Name, AName) or SameText(C[i].Display, AName) then
      Exit(C[i]);
  Result.Name := AName;
  Result.Display := AName;
  Result.Codepage := eidCP1252;
end;

function EncodingDisplayName(AEditor: TATSynEdit): string;
var
  St: TATStrings;
  Name: string;
begin
  Result := '';
  if AEditor = nil then Exit;
  St := AEditor.Strings;
  case St.Encoding of
    TATFileEncoding.ANSI:
      begin
        Name := cEncConvNames[St.EncodingCodepage];
        Result := 'ANSI (' + Name + ')';
      end;
    TATFileEncoding.UTF8:
      if St.SaveSignUtf8 then Result := 'UTF-8 with BOM' else Result := 'UTF-8';
    TATFileEncoding.UTF16LE:
      if St.SaveSignWide then Result := 'UTF-16 LE with BOM' else Result := 'UTF-16 LE';
    TATFileEncoding.UTF16BE:
      if St.SaveSignWide then Result := 'UTF-16 BE with BOM' else Result := 'UTF-16 BE';
    TATFileEncoding.UTF32LE:
      if St.SaveSignWide then Result := 'UTF-32 LE with BOM' else Result := 'UTF-32 LE';
    TATFileEncoding.UTF32BE:
      if St.SaveSignWide then Result := 'UTF-32 BE with BOM' else Result := 'UTF-32 BE';
  end;
end;

function EolName(AEnding: TATLineEnds): string;
begin
  case AEnding of
    TATLineEnds.Windows: Result := 'CRLF';
    TATLineEnds.Unix: Result := 'LF';
    TATLineEnds.Mac: Result := 'CR';
  else
    Result := 'NONE';
  end;
end;

function EolFromName(const AName: string): TATLineEnds;
begin
  if SameText(AName, 'CRLF') or SameText(AName, 'Windows') then
    Result := TATLineEnds.Windows
  else if SameText(AName, 'LF') or SameText(AName, 'Unix') then
    Result := TATLineEnds.Unix
  else if SameText(AName, 'CR') or SameText(AName, 'Mac') then
    Result := TATLineEnds.Mac
  else
    Result := TATLineEnds.None;
end;

function EolDisplayName(AEditor: TATSynEdit): string;
var
  St: TATStrings;
  Seen: set of TATLineEnds;
  E: TATLineEnds;
  i: Integer;
  N: Integer;
begin
  Result := 'NONE';
  if AEditor = nil then Exit;
  St := AEditor.Strings;
  Seen := [];
  N := 0;
  for i := 0 to St.Count - 1 do
  begin
    E := St.LinesEnds[i];
    if E <> TATLineEnds.None then
    begin
      Include(Seen, E);
      Inc(N);
    end;
  end;
  if N = 0 then Exit;
  if Seen = [TATLineEnds.Windows] then Result := 'CRLF'
  else if Seen = [TATLineEnds.Unix] then Result := 'LF'
  else if Seen = [TATLineEnds.Mac] then Result := 'CR'
  else
  begin
    Result := 'Mixed';
    if TATLineEnds.Windows in Seen then Result := Result + ' CRLF';
    if TATLineEnds.Unix in Seen then Result := Result + ' LF';
    if TATLineEnds.Mac in Seen then Result := Result + ' CR';
  end;
end;

{ ---------------------------------------------------------------------------
  Encoding detection

  BOM/UTF handling is deterministic.  For legacy multi-byte encodings we first
  validate the byte structure of the candidate codepage, then decode it and
  score the result.  This is deliberately conservative: ambiguous samples keep
  the caller's fallback instead of silently changing the bytes.
  --------------------------------------------------------------------------- }

function DetectionResult(const AName: string; AConfidence: Integer): TEncodingDetection;
var
  C: TEncodingChoice;
begin
  C := EncodingChoiceByName(AName);
  Result.Name := C.Name;
  Result.Display := C.Display;
  Result.Codepage := C.Codepage;
  Result.Confidence := AConfidence;
end;

function ChoiceForCodepage(ACodepage: TEncConvId): TEncodingChoice;
var
  C: TEncodingChoiceArray;
  i: Integer;
begin
  Result.Name := '';
  Result.Display := '';
  Result.Codepage := eidCP1252;
  Result.WithBom := False;
  C := EncodingChoices;
  for i := 0 to High(C) do
    if (C[i].Codepage = ACodepage) and (not C[i].WithBom) then
      Exit(C[i]);
  Result.Name := cEncConvNames[ACodepage];
  Result.Display := cEncConvNames[ACodepage];
  Result.Codepage := ACodepage;
end;

function NextUtf8CodePoint(const S: RawByteString; var AIndex: Integer;
  out ACode: Cardinal): Boolean;
var
  B1, B2, B3, B4: Byte;
begin
  Result := False;
  ACode := 0;
  if (AIndex < 1) or (AIndex > Length(S)) then Exit;
  B1 := Ord(S[AIndex]);
  if B1 < $80 then
  begin
    ACode := B1;
    Inc(AIndex);
    Exit(True);
  end;
  if (B1 < $C2) or (B1 > $F4) then Exit;
  if B1 <= $DF then
  begin
    if AIndex + 1 > Length(S) then Exit;
    B2 := Ord(S[AIndex + 1]);
    if (B2 and $C0) <> $80 then Exit;
    ACode := (Cardinal(B1 and $1F) shl 6) or (B2 and $3F);
    Inc(AIndex, 2);
    Exit(True);
  end;
  if B1 <= $EF then
  begin
    if AIndex + 2 > Length(S) then Exit;
    B2 := Ord(S[AIndex + 1]);
    B3 := Ord(S[AIndex + 2]);
    if ((B2 and $C0) <> $80) or ((B3 and $C0) <> $80) then Exit;
    if (B1 = $E0) and (B2 < $A0) then Exit;
    if (B1 = $ED) and (B2 >= $A0) then Exit;
    ACode := (Cardinal(B1 and $0F) shl 12) or
             (Cardinal(B2 and $3F) shl 6) or (B3 and $3F);
    Inc(AIndex, 3);
    Exit(True);
  end;
  if AIndex + 3 > Length(S) then Exit;
  B2 := Ord(S[AIndex + 1]);
  B3 := Ord(S[AIndex + 2]);
  B4 := Ord(S[AIndex + 3]);
  if ((B2 and $C0) <> $80) or ((B3 and $C0) <> $80) or
     ((B4 and $C0) <> $80) then Exit;
  if (B1 = $F0) and (B2 < $90) then Exit;
  if (B1 = $F4) and (B2 > $8F) then Exit;
  ACode := (Cardinal(B1 and $07) shl 18) or
           (Cardinal(B2 and $3F) shl 12) or
           (Cardinal(B3 and $3F) shl 6) or (B4 and $3F);
  Inc(AIndex, 4);
  Result := True;
end;

function IsValidUtf8(const S: RawByteString; out AHasMultibyte: Boolean): Boolean;
var
  I: Integer;
  Code: Cardinal;
begin
  AHasMultibyte := False;
  I := 1;
  while I <= Length(S) do
  begin
    if not NextUtf8CodePoint(S, I, Code) then Exit(False);
    if Code >= $80 then AHasMultibyte := True;
  end;
  Result := True;
end;

function IsHan(ACode: Cardinal): Boolean; inline;
begin
  Result := ((ACode >= $3400) and (ACode <= $4DBF)) or
            ((ACode >= $4E00) and (ACode <= $9FFF)) or
            ((ACode >= $F900) and (ACode <= $FAFF));
end;

function IsKana(ACode: Cardinal): Boolean; inline;
begin
  Result := (ACode >= $3040) and (ACode <= $30FF);
end;

function IsHangul(ACode: Cardinal): Boolean; inline;
begin
  Result := ((ACode >= $AC00) and (ACode <= $D7AF)) or
            ((ACode >= $1100) and (ACode <= $11FF));
end;

const
  FrequentHanzi: string =
    '的一是不了在人有我他这为之大来以个中上们到说国和地也子时道出而要于就下得可你年生自会那后能对着事其里所去行过家十用发天如然作方成者多日都三小军二无同么经法当起与好看学进种将还分此心前面又定见只主没公从';
  SimplifiedOnly: string =
    '这个们为说时国会对发后里么没过还经样与从学现点电门问间开关长东车见听话让给带处务动进种应该将报场员体几义无论些总机';
  TraditionalOnly: string =
    '這個們為說時國會對發後裡麼沒過還經樣與從學現點電門問間開關長東車見聽話讓給帶處務動進種應該將報場員體幾義無論些總機';
  FrequentHangul: string =
    '이다는을를의가에한국어테스트입니사시리도로은것수있하나저제그대정자보인일주말네요';

function ScoreDecoded(const S: string): Integer;
var
  I: Integer;
  Code: Cardinal;
  W: WideChar;
begin
  Result := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if not NextUtf8CodePoint(S, I, Code) then Exit(-10000);
    if Code = $FFFD then
      Dec(Result, 20)
    else if (Code < $20) and (Code <> 9) and (Code <> 10) and (Code <> 13) then
      Dec(Result, 15)
    else if (Code >= $80) and (Code <= $9F) then
      Dec(Result, 8)
    else if (Code >= $E000) and (Code <= $F8FF) then
      Dec(Result, 4)
    else
    begin
      Inc(Result);
      if IsHan(Code) then Inc(Result, 2)
      else if IsKana(Code) then Inc(Result, 4)
      else if IsHangul(Code) then Inc(Result, 2);
      if Code <= $FFFF then
      begin
        W := WideChar(Code);
        if Pos(UTF8Encode(W), FrequentHanzi) > 0 then Inc(Result, 3);
      end;
    end;
  end;
end;

function VariantScore(const S: string): Integer;
var
  I: Integer;
  Code: Cardinal;
  W: WideChar;
  Simp, Trad: Integer;
begin
  Simp := 0;
  Trad := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if not NextUtf8CodePoint(S, I, Code) then Break;
    if Code <= $FFFF then
    begin
      W := WideChar(Code);
      if Pos(UTF8Encode(W), SimplifiedOnly) > 0 then Inc(Simp);
      if Pos(UTF8Encode(W), TraditionalOnly) > 0 then Inc(Trad);
    end;
  end;
  Result := (Simp - Trad) * 3;
end;

function IsDbcsValid(const S: RawByteString; ACodepage: TEncConvId): Boolean;
var
  I, N: Integer;
  B, T: Byte;
begin
  I := 1;
  N := Length(S);
  while I <= N do
  begin
    B := Ord(S[I]);
    if B < $80 then
    begin
      Inc(I);
      Continue;
    end;
    case ACodepage of
      eidCP932:
        begin
          // Half-width katakana is a single byte in Shift-JIS.
          if (B >= $A1) and (B <= $DF) then
          begin
            Inc(I);
            Continue;
          end;
          if not (((B >= $81) and (B <= $9F)) or ((B >= $E0) and (B <= $FC))) then
            Exit(False);
          if I = N then Exit(False);
          T := Ord(S[I + 1]);
          if not ((T >= $40) and (T <= $FC) and (T <> $7F)) then Exit(False);
          Inc(I, 2);
        end;
      eidCP936:
        begin
          if not ((B >= $81) and (B <= $FE)) then Exit(False);
          if I = N then Exit(False);
          T := Ord(S[I + 1]);
          if not ((T >= $40) and (T <= $FE) and (T <> $7F)) then Exit(False);
          Inc(I, 2);
        end;
      eidCP950:
        begin
          if not ((B >= $81) and (B <= $FE)) then Exit(False);
          if I = N then Exit(False);
          T := Ord(S[I + 1]);
          if not (((T >= $40) and (T <= $7E)) or
                  ((T >= $A1) and (T <= $FE))) then Exit(False);
          Inc(I, 2);
        end;
      eidCP949:
        begin
          // Strict KS X 1001/EUC-KR for detection.  Windows-949 adds
          // low-trail pairs, but accepting those makes Chinese Big5/GBK data
          // look like Korean; the user can still select cp949 explicitly.
          if not ((B >= $A1) and (B <= $FE)) then Exit(False);
          if I = N then Exit(False);
          T := Ord(S[I + 1]);
          if not ((T >= $A1) and (T <= $FE)) then Exit(False);
          Inc(I, 2);
        end;
    else
      Exit(False);
    end;
  end;
  Result := True;
end;

function CommonHangulScore(const S: string): Integer;
var
  I: Integer;
  Code: Cardinal;
  W: WideChar;
begin
  Result := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if not NextUtf8CodePoint(S, I, Code) then Break;
    if (Code >= $AC00) and (Code <= $D7A3) then
    begin
      W := WideChar(Code);
      if Pos(UTF8Encode(W), FrequentHangul) > 0 then Inc(Result, 3);
    end;
  end;
end;

function CandidateScore(const AData: RawByteString; ACodepage: TEncConvId): Integer;
var
  U: string;
begin
  if not IsDbcsValid(AData, ACodepage) then Exit(-10000);
  try
    U := EncConvertToUTF8(AData, ACodepage);
  except
    Exit(-10000);
  end;
  if U = '' then Exit(-10000);
  Result := ScoreDecoded(U) + VariantScore(U);
  if ACodepage = eidCP949 then
    Inc(Result, CommonHangulScore(U));
end;

function LooksUtf16(const AData: RawByteString; out AName: string): Boolean;
var
  I, N, ZeroEven, ZeroOdd: Integer;
begin
  AName := '';
  N := Length(AData);
  if (N < 4) or Odd(N) then Exit(False);
  ZeroEven := 0;
  ZeroOdd := 0;
  I := 1;
  while I <= N do
  begin
    if Ord(AData[I]) = 0 then Inc(ZeroOdd);
    if Ord(AData[I + 1]) = 0 then Inc(ZeroEven);
    Inc(I, 2);
  end;
  if (ZeroOdd + ZeroEven) * 8 < N then Exit(False);
  if (ZeroOdd > ZeroEven * 3) and (ZeroOdd > 0) then
  begin
    AName := 'UTF-16 LE';
    Exit(True);
  end;
  if (ZeroEven > ZeroOdd * 3) and (ZeroEven > 0) then
  begin
    AName := 'UTF-16 BE';
    Exit(True);
  end;
end;

function DetectEncodingData(const AData: RawByteString): TEncodingDetection;
var
  N: Integer;
  HasMulti: Boolean;
  Utf16Name: string;
  Candidates: array[0..3] of TEncConvId;
  Scores: array[0..3] of Integer;
  Best, Second, BestIdx, I, Margin: Integer;
  C: TEncodingChoice;
begin
  Result.Name := '';
  Result.Display := '';
  Result.Codepage := eidCP1252;
  Result.Confidence := 0;
  N := Length(AData);
  if N = 0 then
    Exit(DetectionResult('UTF-8', 100));

  if (N >= 3) and (AData[1] = #$EF) and (AData[2] = #$BB) and (AData[3] = #$BF) then
    Exit(DetectionResult('UTF-8 with BOM', 100));
  if (N >= 4) and (AData[1] = #$FF) and (AData[2] = #$FE) and
     (AData[3] = #0) and (AData[4] = #0) then
    Exit(DetectionResult('UTF-32 LE with BOM', 100));
  if (N >= 4) and (AData[1] = #0) and (AData[2] = #0) and
     (AData[3] = #$FE) and (AData[4] = #$FF) then
    Exit(DetectionResult('UTF-32 BE with BOM', 100));
  if (N >= 2) and (AData[1] = #$FF) and (AData[2] = #$FE) then
    Exit(DetectionResult('UTF-16 LE with BOM', 100));
  if (N >= 2) and (AData[1] = #$FE) and (AData[2] = #$FF) then
    Exit(DetectionResult('UTF-16 BE with BOM', 100));

  if LooksUtf16(AData, Utf16Name) then
    Exit(DetectionResult(Utf16Name, 70));

  if IsValidUtf8(AData, HasMulti) then
  begin
    if HasMulti then
      Exit(DetectionResult('UTF-8', 96));
    Exit(DetectionResult('UTF-8', 100));
  end;

  Candidates[0] := eidCP936;
  Candidates[1] := eidCP950;
  Candidates[2] := eidCP932;
  Candidates[3] := eidCP949;
  Best := -10000;
  Second := -10000;
  BestIdx := -1;
  for I := 0 to High(Candidates) do
  begin
    Scores[I] := CandidateScore(AData, Candidates[I]);
    if Scores[I] > Best then
    begin
      Second := Best;
      Best := Scores[I];
      BestIdx := I;
    end
    else if Scores[I] > Second then
      Second := Scores[I];
  end;

  if (BestIdx >= 0) and (Best > 0) then
  begin
    if Second <= -10000 then
      Margin := Best
    else
      Margin := Best - Second;
    C := ChoiceForCodepage(Candidates[BestIdx]);
    Result.Name := C.Name;
    Result.Display := C.Display;
    Result.Codepage := C.Codepage;
    if Margin >= 8 then
      Result.Confidence := 85
    else if Margin >= 3 then
      Result.Confidence := 65
    else
      Result.Confidence := 45;
    Exit;
  end;

  // Unknown legacy 8-bit data: use the platform ANSI codepage, which is what
  // a plain text editor historically did.  Confidence is intentionally low.
  Result := DetectionResult(cEncConvNames[EncConvGetANSI], 20);
end;

function DetectFileEncoding(const AFileName: string): TEncodingDetection;
const
  MaxSample = 262144;
var
  F: TFileStream;
  Data: RawByteString;
  N: Integer;
begin
  Data := '';
  Result.Name := '';
  Result.Display := '';
  Result.Codepage := eidCP1252;
  Result.Confidence := 0;
  if not FileExists(AFileName) then Exit;
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      N := F.Size;
      if N > MaxSample then N := MaxSample;
      SetLength(Data, N);
      if N > 0 then
        F.ReadBuffer(Data[1], N);
    finally
      F.Free;
    end;
    Result := DetectEncodingData(Data);
  except
    Result.Name := '';
    Result.Display := '';
    Result.Codepage := eidCP1252;
    Result.Confidence := 0;
  end;
end;


procedure SetEditorEncoding(AEditor: TATSynEdit; const AName: string;
  AMarkModified: Boolean);
begin
  if (AEditor = nil) or (AName = '') then Exit;
  if SameText(AEditor.EncodingName, AName) then Exit;
  AEditor.EncodingName := AName;
  if AMarkModified and (not AEditor.ModeReadOnly) then
    AEditor.Modified := True;
end;

procedure SetEditorEol(AEditor: TATSynEdit; AEnding: TATLineEnds;
  AMarkModified: Boolean);
begin
  if AEditor = nil then Exit;
  AEditor.Strings.Endings := AEnding;
  if AMarkModified and (not AEditor.ModeReadOnly) then
    AEditor.Modified := True;
end;

function DefaultEol: TATLineEnds;
begin
  {$IFDEF WINDOWS}
  Result := TATLineEnds.Windows;
  {$ELSE}
  Result := TATLineEnds.Unix;
  {$ENDIF}
end;

end.
