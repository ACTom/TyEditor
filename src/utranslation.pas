unit utranslation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, Translations, uutils;

function EffectiveLanguage(const ASetting: string): string;
function AvailableLanguages: TStringList;
function LanguageDisplayName(const AID: string): string;
procedure LoadTranslation(const ALang: string);
function Tr(const AText: string): string;

implementation

var
  FMap: TStringList;
  FLoadedLang: string;

function EffectiveLanguage(const ASetting: string): string;
var
  ID: TLanguageID;
begin
  if (ASetting <> '') and (not SameText(ASetting, 'auto')) then
    Exit(ASetting);
  ID := GetLanguageID;
  if SameText(ID.LanguageCode, 'zh') then
    Result := 'zh_CN'
  else
    Result := 'en';
end;

function AvailableLanguages: TStringList;
var
  SR: TSearchRec;
  S, ID: string;
  N: Integer;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.Add('auto');
  Result.Add('en');
  if FindFirst(GetLanguageDir + 'tyeditor.*.json', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        S := SR.Name;
        N := Pos('tyeditor.', S);
        if N = 1 then
        begin
          ID := Copy(S, Length('tyeditor.') + 1, Length(S));
          if LowerCase(Copy(ID, Length(ID) - 4, 5)) = '.json' then
            ID := Copy(ID, 1, Length(ID) - 5);
          if (ID <> '') and (Result.IndexOf(ID) < 0) then
            Result.Add(ID);
        end;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function LanguageDisplayName(const AID: string): string;
begin
  if SameText(AID, 'auto') then Result := Tr('auto (system)')
  else if SameText(AID, 'en') then Result := 'English'
  else if SameText(AID, 'zh_CN') then Result := '简体中文'
  else Result := AID;
end;

procedure LoadTranslation(const ALang: string);
var
  S, FileName: string;
  Data: TJSONData;
  Obj: TJSONObject;
  i: Integer;
begin
  if SameText(FLoadedLang, ALang) then Exit;
  FLoadedLang := ALang;
  FMap.Clear;
  if (ALang = '') or SameText(ALang, 'en') then Exit;
  FileName := GetLanguageDir + 'tyeditor.' + ALang + '.json';
  if not ReadTextFileSafe(FileName, S) then Exit;
  try
    Data := GetJSON(S);
    try
      if not (Data is TJSONObject) then Exit;
      Obj := TJSONObject(Data);
      for i := 0 to Obj.Count - 1 do
        FMap.Values[Obj.Names[i]] := Obj.Items[i].AsString;
    finally
      Data.Free;
    end;
  except
    // a broken translation file must never block the UI
  end;
end;

function Tr(const AText: string): string;
begin
  if FMap.IndexOfName(AText) >= 0 then
    Result := FMap.Values[AText]
  else
    Result := AText;
end;

initialization
  FMap := TStringList.Create;
  FMap.CaseSensitive := True;

finalization
  FMap.Free;

end.
