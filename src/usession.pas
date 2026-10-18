unit usession;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, FileUtil,
  ec_SyntAnal,
  ATSynEdit, ATSynEdit_Carets, ATSynEdit_Bookmarks, ATStrings, ATStringProc,
  ueditortab, usettings, uencoding, ulanguage, uutils;

function SaveSession(ATabs: TList; AActiveIndex: Integer;
  const ABackups: TBackupConfig): Boolean;
function LoadSessionJSON: TJSONObject;
procedure RestoreTabState(ATab: TEditorTab; AObj: TJSONObject;
  ALanguage: TLanguageManager);
procedure SaveTabBackup(ATab: TEditorTab; const ABackups: TBackupConfig);
procedure LoadTabBackup(ATab: TEditorTab; const ABackupFile: string);
procedure CleanupOldBackups(ATabs: TList; const ABackups: TBackupConfig);

implementation

function SessionBackupFileName(const AId: string; const ABackups: TBackupConfig): string;
begin
  Result := BackupDirFor(ABackups) + SafeFileName(AId) + '.txt';
end;

procedure SaveTabBackup(ATab: TEditorTab; const ABackups: TBackupConfig);
var
  MS: TMemoryStream;
  Dir: string;
begin
  if ATab.BackupFile = '' then
    ATab.BackupFile := SessionBackupFileName(ATab.SessionId, ABackups);
  Dir := ExtractFileDir(ATab.BackupFile);
  EnsureDir(Dir);
  MS := TMemoryStream.Create;
  try
    ATab.Editor.Strings.SaveToStream(MS, TATFileEncoding.UTF8, False);
    MS.SaveToFile(ATab.BackupFile);
  finally
    MS.Free;
  end;
end;

procedure LoadTabBackup(ATab: TEditorTab; const ABackupFile: string);
var
  OldDetect: Boolean;
begin
  OldDetect := ATab.Editor.Strings.EncodingDetect;
  try
    ATab.Editor.Strings.EncodingDetect := False;
    ATab.Editor.Strings.Encoding := TATFileEncoding.UTF8;
    ATab.Editor.Strings.SaveSignUtf8 := False;
    ATab.Editor.LoadFromFile(ABackupFile, []);
  finally
    ATab.Editor.Strings.EncodingDetect := OldDetect;
  end;
  ATab.Editor.Modified := True;
  ATab.UpdateCaption;
end;

function SaveSession(ATabs: TList; AActiveIndex: Integer;
  const ABackups: TBackupConfig): Boolean;
var
  Root, W, O: TJSONObject;
  Tabs, Bms: TJSONArray;
  i, j: Integer;
  Tab: TEditorTab;
  P: PATBookmarkItem;
  FileName: string;
  Data: TJSONData;
begin
  Result := False;
  Root := TJSONObject.Create;
  try
    Root.Add('active_tab', AActiveIndex);

    Tabs := TJSONArray.Create;
    for i := 0 to ATabs.Count - 1 do
    begin
      Tab := TEditorTab(ATabs[i]);
      if Tab.SessionId = '' then
        Tab.SessionId := NewSessionId;
      O := TJSONObject.Create;
      O.Add('id', Tab.SessionId);
      if Tab.FileName = '' then
        O.Add('kind', 'untitled')
      else
        O.Add('kind', 'file');
      O.Add('file', Tab.FileName);
      O.Add('title', Tab.BaseTitle);
      O.Add('encoding', Tab.Editor.EncodingName);
      O.Add('eol', EolName(Tab.Editor.Strings.Endings));
      O.Add('modified', Tab.Editor.Modified);
      O.Add('readonly', Tab.Editor.ModeReadOnly);
      O.Add('pinned', Tab.Pinned);
      O.Add('carets', Tab.Editor.Carets.AsString);
      O.Add('line_top', Tab.Editor.LineTop);
      O.Add('wrap', Ord(Tab.Editor.OptWrapMode));
      O.Add('scale', Tab.Editor.OptScaleFont);
      O.Add('folding', Tab.Editor.FoldingAsString);
      if Tab.Adapter <> nil then
      begin
        if Tab.Adapter.Lexer <> nil then
          O.Add('lexer', Tab.Adapter.Lexer.LexerName)
        else
          O.Add('lexer', '');
      end
      else
        O.Add('lexer', '');

      Bms := TJSONArray.Create;
      for j := 0 to Tab.Editor.Strings.Bookmarks.Count - 1 do
      begin
        P := Tab.Editor.Strings.Bookmarks.ItemPtr[j];
        if P <> nil then
          Bms.Add(P^.Data.LineNum);
      end;
      O.Add('bookmarks', Bms);
      Bms := TJSONArray.Create;
      for j := 0 to Tab.Editor.Strings.Bookmarks.Count - 1 do
      begin
        P := Tab.Editor.Strings.Bookmarks.ItemPtr[j];
        if P <> nil then
          Bms.Add(P^.Data.Kind);
      end;
      O.Add('bookmark_kinds', Bms);

      if Tab.Editor.Modified or (Tab.FileName = '') then
      begin
        SaveTabBackup(Tab, ABackups);
        O.Add('backup', ExtractFileName(Tab.BackupFile));
      end
      else
        O.Add('backup', '');

      Tabs.Add(O);
    end;
    Root.Add('tabs', Tabs);

    FileName := SessionFileName;
    EnsureDir(ExtractFileDir(FileName));
    if FileExists(FileName) then
      CopyFile(FileName, FileName + '.bak');
    AtomicWriteString(FileName, Root.FormatJSON);
    Result := True;
  finally
    Root.Free;
  end;
end;

function LoadSessionJSON: TJSONObject;
var
  S: string;
  Data: TJSONData;
  F: string;

  function TryLoad(const AFileName: string): TJSONObject;
  begin
    Result := nil;
    if not ReadTextFileSafe(AFileName, S) then Exit;
    try
      Data := GetJSON(S);
      if Data is TJSONObject then
        Result := TJSONObject(Data)
      else
        Data.Free;
    except
      Result := nil;
    end;
  end;

begin
  F := SessionFileName;
  Result := TryLoad(F);
  if Result = nil then
    Result := TryLoad(F + '.bak');
end;

procedure RestoreTabState(ATab: TEditorTab; AObj: TJSONObject;
  ALanguage: TLanguageManager);
var
  EncName, LexerName, S: string;
  Arr: TJSONArray;
  i, LineNum: Integer;
  D: TATBookmarkData;
  Lexer: TecSyntAnalyzer;
begin
  if ATab = nil then Exit;
  EncName := JsonStr(AObj, 'encoding', '');
  if EncName <> '' then
  begin
    try
      ATab.Editor.EncodingName := EncName;
    except
      // keep the detected encoding
    end;
  end;
  S := JsonStr(AObj, 'eol', '');
  if S <> '' then
    ATab.Editor.Strings.Endings := EolFromName(S);

  ATab.Editor.OptWrapMode := TATEditorWrapMode(JsonInt(AObj, 'wrap', Ord(TATEditorWrapMode.ModeOff)));
  ATab.Editor.OptScaleFont := JsonInt(AObj, 'scale', ATab.Editor.OptScaleFont);
  ATab.Editor.ModeReadOnly := JsonBool(AObj, 'readonly', False);
  ATab.Pinned := JsonBool(AObj, 'pinned', False);

  LexerName := JsonStr(AObj, 'lexer', '');
  if LexerName <> '' then
  begin
    Lexer := ALanguage.FindByName(LexerName);
    if Lexer <> nil then
      ATab.SetLexer(Lexer);
  end;

  S := JsonStr(AObj, 'folding', '');
  if S <> '' then
    ATab.Editor.FoldingAsString := S;

  ATab.Editor.Strings.Bookmarks.Clear;
  if AObj.Find('bookmarks') is TJSONArray then
    begin
      Arr := TJSONArray(AObj.Find('bookmarks'));
      for i := 0 to Arr.Count - 1 do
      begin
        LineNum := Arr.Items[i].AsInteger;
        D := Default(TATBookmarkData);
        D.LineNum := LineNum;
        D.Kind := 1;
        if (AObj.Find('bookmark_kinds') is TJSONArray) and
           (i < TJSONArray(AObj.Find('bookmark_kinds')).Count) then
          D.Kind := TJSONArray(AObj.Find('bookmark_kinds')).Items[i].AsInteger;
        if D.Kind < 1 then D.Kind := 1;
        D.ShowInBookmarkList := True;
        ATab.Editor.Strings.Bookmarks.Add(D);
      end;
    end;

  S := JsonStr(AObj, 'carets', '');
  if S <> '' then
    ATab.Editor.Carets.AsString := S;
  LineNum := JsonInt(AObj, 'line_top', 0);
  ATab.Editor.LineTopTodo := LineNum;
  if LineNum > 0 then
    ATab.Editor.LineTop := LineNum;

  if JsonBool(AObj, 'modified', False) then
    ATab.Editor.Modified := True
  else
    ATab.Editor.Modified := False;
  ATab.UpdateCaption;
end;

procedure CleanupOldBackups(ATabs: TList; const ABackups: TBackupConfig);
var
  SR: TSearchRec;
  i, Oldest, Age, BestAge: Integer;
  Keep, Files: TStringList;
  Tab: TEditorTab;
  BDir: string;
begin
  BDir := BackupDirFor(ABackups);
  if not DirectoryExists(BDir) then Exit;
  Keep := TStringList.Create;
  Files := TStringList.Create;
  try
    Keep.CaseSensitive := False;
    Files.CaseSensitive := False;
    for i := 0 to ATabs.Count - 1 do
    begin
      Tab := TEditorTab(ATabs[i]);
      if Tab.BackupFile <> '' then
        Keep.Add(ExtractFileName(Tab.BackupFile));
    end;
    if FindFirst(BDir + '*.txt', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory) = 0 then
          Files.Add(SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    while Files.Count > ABackups.Keep do
    begin
      Oldest := -1;
      BestAge := MaxInt;
      for i := 0 to Files.Count - 1 do
      begin
        if Keep.IndexOf(Files[i]) >= 0 then Continue;
        Age := FileAge(BDir + Files[i]);
        if (Age >= 0) and (Age < BestAge) then
        begin
          BestAge := Age;
          Oldest := i;
        end;
      end;
      if Oldest < 0 then Break;
      DeleteFile(BDir + Files[Oldest]);
      Files.Delete(Oldest);
    end;
  finally
    Keep.Free;
    Files.Free;
  end;
end;

end.
