unit upluginmanager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, FileUtil, LazFileUtils, zipper, uutils,
  upluginapi, upluginhost;

type
  TPluginManager = class
  private
    FHost: TPluginHost;
    FDisabled: TStringList;
    FConfigDir: string;
    FSettingsFile: string;
    FBundledDir: string;
    FUserDir: string;
    procedure LoadState;
    procedure SaveState;
    function SafeArchiveName(const AName: string): Boolean;
    function InstallRoot(const AFileName: string; out AError: string): Boolean;
  public
    constructor Create(const AConfigDir: string);
    destructor Destroy; override;
    procedure Reload(const ABundledDir, AUserDir: string);
    procedure SetLocale(const ALocale: string);
    function InstallPackage(const AFileName: string; out AError: string): Boolean;
    function UninstallPlugin(const AId: string; out AError: string): Boolean;
    function SetEnabled(const AId: string; AEnabled: Boolean): Boolean;
    function IsEnabled(const AId: string): Boolean;
    function FindPlugin(const AId: string): TPluginInfo;
    function Execute(APlugin: TPluginInfo; ACommand: TPluginCommand;
      ARequest: TJSONObject; out AResponse: TJSONObject; out AError: string): Boolean;
    procedure Refresh;
    function GetPlugins: TList;
    function GetErrors: TStringList;
    property Plugins: TList read GetPlugins;
    property Errors: TStringList read GetErrors;
    property UserDir: string read FUserDir;
  end;

implementation

constructor TPluginManager.Create(const AConfigDir: string);
begin
  inherited Create;
  FConfigDir := IncludeTrailingPathDelimiter(AConfigDir);
  FSettingsFile := FConfigDir + 'plugins.json';
  FDisabled := TStringList.Create;
  FDisabled.CaseSensitive := False;
  FHost := TPluginHost.Create;
  LoadState;
end;

destructor TPluginManager.Destroy;
begin
  FHost.Free;
  FDisabled.Free;
  inherited;
end;

procedure TPluginManager.LoadState;
var
  Text: string;
  Data: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
begin
  FDisabled.Clear;
  if not ReadTextFileSafe(FSettingsFile, Text) then Exit;
  try
    Data := GetJSON(Text);
    try
      if not (Data is TJSONObject) then Exit;
      Obj := TJSONObject(Data);
      if Obj.Find('disabled') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('disabled'));
        for i := 0 to Arr.Count - 1 do
          if Arr.Items[i].JSONType = jtString then
            FDisabled.Add(Arr.Items[i].AsString);
      end;
    finally
      Data.Free;
    end;
  except
    // A broken plugin state file must not prevent the editor from starting.
  end;
end;

procedure TPluginManager.SaveState;
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
  Text: string;
begin
  Obj := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;
    for i := 0 to FDisabled.Count - 1 do
      Arr.Add(FDisabled[i]);
    Obj.Add('disabled', Arr);
    Text := Obj.AsJSON;
    ForceDirectories(FConfigDir);
    AtomicWriteString(FSettingsFile, Text);
  finally
    Obj.Free;
  end;
end;

procedure TPluginManager.Reload(const ABundledDir, AUserDir: string);
var
  i: Integer;
  Plugin: TPluginInfo;
begin
  FBundledDir := ABundledDir;
  FUserDir := AUserDir;
  FHost.Reload(ABundledDir, AUserDir);
  for i := 0 to FHost.Plugins.Count - 1 do
  begin
    Plugin := TPluginInfo(FHost.Plugins[i]);
    Plugin.DisabledReason := Plugin.CompatibilityError;
    if Plugin.DisabledReason <> '' then
      Plugin.Enabled := False
    else
      Plugin.Enabled := FDisabled.IndexOf(Plugin.Id) < 0;
  end;
end;

procedure TPluginManager.Refresh;
begin
  Reload(FBundledDir, FUserDir);
end;

procedure TPluginManager.SetLocale(const ALocale: string);
begin
  FHost.SetLocale(ALocale);
end;

function TPluginManager.FindPlugin(const AId: string): TPluginInfo;
begin
  Result := FHost.FindPlugin(AId);
end;

function TPluginManager.Execute(APlugin: TPluginInfo; ACommand: TPluginCommand;
  ARequest: TJSONObject; out AResponse: TJSONObject; out AError: string): Boolean;
begin
  AResponse := nil;
  AError := '';
  if (APlugin = nil) or (not APlugin.Enabled) then
  begin
    AError := 'Plugin is disabled';
    Exit(False);
  end;
  if APlugin.CompatibilityError <> '' then
  begin
    AError := 'Plugin is not compatible: ' + APlugin.CompatibilityError;
    Exit(False);
  end;
  Result := FHost.Execute(APlugin, ACommand, ARequest, AResponse, AError);
end;

function TPluginManager.GetPlugins: TList;
begin
  Result := FHost.Plugins;
end;

function TPluginManager.GetErrors: TStringList;
begin
  Result := FHost.Errors;
end;

function TPluginManager.IsEnabled(const AId: string): Boolean;
var
  Plugin: TPluginInfo;
begin
  Plugin := FindPlugin(AId);
  if Plugin <> nil then
    Result := Plugin.Enabled
  else
    Result := FDisabled.IndexOf(AId) < 0;
end;

function TPluginManager.SetEnabled(const AId: string; AEnabled: Boolean): Boolean;
var
  Plugin: TPluginInfo;
  Index: Integer;
begin
  Result := False;
  Plugin := FindPlugin(AId);
  if Plugin = nil then Exit;
  if AEnabled and (Plugin.CompatibilityError <> '') then Exit;
  Plugin.Enabled := AEnabled;
  Index := FDisabled.IndexOf(AId);
  if AEnabled then
  begin
    if Index >= 0 then FDisabled.Delete(Index);
  end
  else if Index < 0 then
    FDisabled.Add(AId);
  SaveState;
  Result := True;
end;

function TPluginManager.SafeArchiveName(const AName: string): Boolean;
var
  S: string;
  Parts: TStringList;
  i: Integer;
begin
  S := StringReplace(AName, '\', '/', [rfReplaceAll]);
  if (S = '') or (S[1] = '/') or (Pos(':', S) > 0) then Exit(False);
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '/';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := S;
    for i := 0 to Parts.Count - 1 do
      if (Parts[i] = '..') or (Parts[i] = '') then
        if Parts[i] = '..' then Exit(False);
    Result := True;
  finally
    Parts.Free;
  end;
end;

function TPluginManager.InstallRoot(const AFileName: string;
  out AError: string): Boolean;
var
  UnZipper: TUnZipper;
  i: Integer;
  Entry: TFullZipFileEntry;
  Name: string;
begin
  Result := False;
  AError := '';
  if not FileExists(AFileName) then
  begin
    AError := 'Plugin package not found: ' + AFileName;
    Exit;
  end;
  UnZipper := TUnZipper.Create;
  try
    UnZipper.FileName := AFileName;
    UnZipper.UseUTF8 := True;
    try
      UnZipper.Examine;
    except
      on E: Exception do
      begin
        AError := 'Cannot read plugin package: ' + E.Message;
        Exit;
      end;
    end;
    for i := 0 to UnZipper.Entries.Count - 1 do
    begin
      Entry := TFullZipFileEntry(UnZipper.Entries[i]);
      if Entry.IsDirectory then Continue;
      if Entry.IsLink then
      begin
        AError := 'Plugin package contains a symbolic link';
        Exit;
      end;
      Name := Entry.UTF8ArchiveFileName;
      if not SafeArchiveName(Name) then
      begin
        AError := 'Plugin package contains an unsafe path: ' + Name;
        Exit;
      end;
    end;
    Result := True;
  finally
    UnZipper.Free;
  end;
end;

function TPluginManager.InstallPackage(const AFileName: string;
  out AError: string): Boolean;
var
  TempDir, ManifestFile, TargetDir, ManifestError: string;
  UnZipper: TUnZipper;
  Plugin: TPluginInfo;
begin
  Result := False;
  AError := '';
  if FUserDir = '' then
  begin
    AError := 'Plugin directory is not initialized';
    Exit;
  end;
  if not InstallRoot(AFileName, AError) then Exit;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'tyeditor-plugin-' + IntToStr(GetProcessID) + '-' + IntToStr(Random(MaxInt));
  if DirectoryExists(TempDir) then
    DeleteDirectory(TempDir, False, True);
  ForceDirectories(TempDir);
  try
    UnZipper := TUnZipper.Create;
    try
      UnZipper.FileName := AFileName;
      UnZipper.OutputPath := TempDir;
      UnZipper.UseUTF8 := True;
      try
        UnZipper.UnZipAllFiles;
      except
        on E: Exception do
        begin
          AError := 'Cannot extract plugin package: ' + E.Message;
          Exit;
        end;
      end;
    finally
      UnZipper.Free;
    end;

    ManifestFile := IncludeTrailingPathDelimiter(TempDir) + 'plugin.json';
    Plugin := ParsePluginManifest(ManifestFile, ManifestError);
    if Plugin = nil then
    begin
      AError := ManifestError;
      Exit;
    end;
    try
      TargetDir := IncludeTrailingPathDelimiter(FUserDir) + Plugin.Id;
      if DirectoryExists(TargetDir) and
        (not DeleteDirectory(TargetDir, False, True)) then
      begin
        AError := 'Cannot replace existing plugin: ' + TargetDir;
        Exit;
      end;
      ForceDirectories(FUserDir);
      if not CopyDirTree(TempDir, TargetDir, [cffCreateDestDirectory]) then
      begin
        AError := 'Cannot install plugin into ' + TargetDir;
        Exit;
      end;
      Result := True;
    finally
      Plugin.Free;
    end;
  finally
    if DirectoryExists(TempDir) then
      DeleteDirectory(TempDir, False, True);
    if (not Result) and (AError = '') then
      AError := 'Plugin package could not be installed';
  end;
end;

function TPluginManager.UninstallPlugin(const AId: string;
  out AError: string): Boolean;
var
  Plugin: TPluginInfo;
  TargetDir: string;
begin
  Result := False;
  AError := '';
  Plugin := FindPlugin(AId);
  if Plugin = nil then
  begin
    AError := 'Plugin not found: ' + AId;
    Exit;
  end;
  if Plugin.Bundled then
  begin
    AError := 'Bundled plugins cannot be uninstalled';
    Exit;
  end;
  TargetDir := ExcludeTrailingPathDelimiter(Plugin.Directory);
  if not DirectoryExists(TargetDir) then
  begin
    AError := 'Plugin directory not found: ' + TargetDir;
    Exit;
  end;
  if not DeleteDirectory(TargetDir, False, True) then
  begin
    AError := 'Cannot remove plugin directory: ' + TargetDir;
    Exit;
  end;
  SetEnabled(AId, True);
  Result := True;
end;

end.
