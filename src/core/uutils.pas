unit uutils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LazFileUtils, fpjson;

{$I version.inc}

type
  TBackupConfig = record
    Dir: string;
    Keep: Integer;
  end;

function AppConfigDir: string;
function SessionFileName: string;
function SettingsFileName: string;
function MakeBackupConfig(const ADir: string; AKeep: Integer): TBackupConfig;
function DefaultBackupDir: string;
function BackupDirFor(const AConfig: TBackupConfig): string;
function RunningMarkerFileName: string;
function MacrosDir: string;
procedure EnsureDir(const ADir: string);
procedure AtomicWriteString(const AFileName, AText: string);
function ReadTextFileSafe(const AFileName: string; out AText: string): Boolean;
function NewSessionId: string;
function SafeFileName(const AName: string): string;
function FindResourcePath(const ARelative: string): string;
function GetLanguageDir: string;
function AppIconFileName: string;
function JsonStr(AObj: TJSONObject; const AName, ADefault: string): string;
function JsonInt(AObj: TJSONObject; const AName: string; ADefault: Integer): Integer;
function JsonBool(AObj: TJSONObject; const AName: string; ADefault: Boolean): Boolean;

implementation

var
  FSessionCounter: Integer = 0;

function AppConfigDir: string;
var
  NewDir, Parent, OldDir: string;
begin
  NewDir := IncludeTrailingPathDelimiter(GetAppConfigDir(False));

  { One-time migration from the former TyEdit name.  The old app stored its
    settings, session and backups under the same leaf directory name.  The
    running marker and instance queue are deliberately dropped. }
  if not DirectoryExists(NewDir) then
  begin
    Parent := ExtractFileDir(ExcludeTrailingPathDelimiter(NewDir));
    OldDir := IncludeTrailingPathDelimiter(Parent) + 'TyEdit' + PathDelim;
    if not DirectoryExists(OldDir) then
      OldDir := IncludeTrailingPathDelimiter(Parent) + 'tyedit' + PathDelim;
    if DirectoryExists(OldDir) then
    begin
      CopyDirTree(OldDir, NewDir, [], True);
      DeleteFile(NewDir + 'running.marker');
      DeleteDirectory(NewDir + 'instance', True, True);
    end;
  end;

  Result := NewDir;
end;

function SessionFileName: string;
begin
  Result := AppConfigDir + 'session.json';
end;

function SettingsFileName: string;
begin
  Result := AppConfigDir + 'settings.json';
end;

function MakeBackupConfig(const ADir: string; AKeep: Integer): TBackupConfig;
var
  D: string;
begin
  D := Trim(ADir);
  if D <> '' then
  begin
    if not FilenameIsAbsolute(D) then
      D := AppConfigDir + D;
    D := ExcludeTrailingPathDelimiter(ExpandFileName(D));
  end;
  if AKeep < 1 then
    AKeep := 1;
  Result.Dir := D;
  Result.Keep := AKeep;
end;

function DefaultBackupDir: string;
begin
  Result := AppConfigDir + 'backups' + PathDelim;
end;

function BackupDirFor(const AConfig: TBackupConfig): string;
begin
  if AConfig.Dir <> '' then
    Result := IncludeTrailingPathDelimiter(AConfig.Dir)
  else
    Result := DefaultBackupDir;
end;

function RunningMarkerFileName: string;
begin
  Result := AppConfigDir + 'running.marker';
end;

function MacrosDir: string;
begin
  Result := AppConfigDir + 'macros' + PathDelim;
end;

procedure EnsureDir(const ADir: string);
begin
  if ADir <> '' then
    ForceDirectories(ADir);
end;

procedure AtomicWriteString(const AFileName, AText: string);
var
  TempName: string;
  Stream: TFileStream;
  Data: RawByteString;
begin
  EnsureDir(ExtractFileDir(AFileName));
  TempName := AFileName + '.tmp';
  Data := AText;
  Stream := TFileStream.Create(TempName, fmCreate);
  try
    if Data <> '' then
      Stream.WriteBuffer(Data[1], Length(Data));
  finally
    Stream.Free;
  end;
  // POSIX rename replaces the target atomically. Windows rename fails when
  // the target exists, so only then remove it and retry.
  if not RenameFile(TempName, AFileName) then
  begin
    if (not FileExists(AFileName)) or (not DeleteFile(AFileName)) or
       (not RenameFile(TempName, AFileName)) then
    begin
      DeleteFile(TempName);
      raise Exception.CreateFmt('Cannot write %s', [AFileName]);
    end;
  end;
end;

function ReadTextFileSafe(const AFileName: string; out AText: string): Boolean;
var
  Stream: TFileStream;
  Data: RawByteString;
begin
  Result := False;
  AText := '';
  Data := '';
  if not FileExists(AFileName) then Exit;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Data, Stream.Size);
      if Stream.Size > 0 then
        Stream.ReadBuffer(Data[1], Stream.Size);
      AText := Data;
      Result := True;
    finally
      Stream.Free;
    end;
  except
    Result := False;
  end;
end;

function NewSessionId: string;
begin
  Inc(FSessionCounter);
  Result := FormatDateTime('yyyymmdd_hhnnss', Now) + '_' + IntToStr(FSessionCounter);
end;

function SafeFileName(const AName: string): string;
const
  BadChars = '/\:*?"<>|';
var
  i: Integer;
begin
  Result := AName;
  for i := 1 to Length(Result) do
    if Pos(Result[i], BadChars) > 0 then
      Result[i] := '_';
  if Result = '' then
    Result := 'untitled';
end;

function FindResourcePath(const ARelative: string): string;
var
  ExeDir, Dir, Candidate: string;
  i: Integer;

  function TryDir(const ABase: string; out APath: string): Boolean;
  begin
    Result := False;
    APath := '';
    if ABase = '' then Exit;
    Candidate := IncludeTrailingPathDelimiter(ABase) + ARelative;
    if FileExists(Candidate) or DirectoryExists(Candidate) then
    begin
      APath := Candidate;
      Result := True;
    end;
  end;

begin
  Result := '';
  ExeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  if TryDir(ExeDir, Result) then Exit;
  {$IFDEF DARWIN}
  if TryDir(ExtractFileDir(ExeDir) + PathDelim + 'Resources', Result) then Exit;
  {$ENDIF}
  if TryDir(ExtractFileDir(ExeDir), Result) then Exit;
  if TryDir(AppConfigDir, Result) then Exit;
  if TryDir(GetCurrentDir, Result) then Exit;
  Dir := ExeDir;
  for i := 1 to 8 do
  begin
    Dir := ExtractFileDir(ExcludeTrailingPathDelimiter(Dir));
    if Dir = '' then Break;
    if TryDir(Dir, Result) then Exit;
  end;
end;

function GetLanguageDir: string;
var
  P: string;
begin
  P := FindResourcePath('languages');
  if P <> '' then
    Result := IncludeTrailingPathDelimiter(P)
  else
    Result := 'languages' + PathDelim;
end;

function AppIconFileName: string;
begin
  {$IFDEF DARWIN}
  Result := FindResourcePath('data/icons/tyeditor-256.png');
  if Result <> '' then Exit;
  {$ENDIF}
  Result := FindResourcePath('data/icons/tyeditor.ico');
end;

function JsonStr(AObj: TJSONObject; const AName, ADefault: string): string;
begin
  if (AObj <> nil) and (AObj.IndexOfName(AName) >= 0) then
    Result := AObj.Get(AName, ADefault)
  else
    Result := ADefault;
end;

function JsonInt(AObj: TJSONObject; const AName: string; ADefault: Integer): Integer;
begin
  if (AObj <> nil) and (AObj.IndexOfName(AName) >= 0) then
    Result := AObj.Get(AName, ADefault)
  else
    Result := ADefault;
end;

function JsonBool(AObj: TJSONObject; const AName: string; ADefault: Boolean): Boolean;
begin
  if (AObj <> nil) and (AObj.IndexOfName(AName) >= 0) then
    Result := AObj.Get(AName, ADefault)
  else
    Result := ADefault;
end;

end.
