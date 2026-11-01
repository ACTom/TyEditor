unit upluginhost;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, FileUtil, LazFileUtils,
  upluginapi, upluginruntime;

type
  TPluginHost = class
  private
    FPlugins: TList;
    FErrors: TStringList;
    procedure Clear;
    procedure LoadDirectory(const ADirectory: string; ABundled: Boolean);
    function IndexOfPlugin(const AId: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reload(const ABundledDir, AUserDir: string);
    procedure SetLocale(const ALocale: string);
    function FindPlugin(const AId: string): TPluginInfo;
    function FindAction(const APluginId, AActionId: string): TPluginCommand;
    function Execute(APlugin: TPluginInfo; ACommand: TPluginCommand;
      ARequest: TJSONObject; out AResponse: TJSONObject; out AError: string): Boolean;
    property Plugins: TList read FPlugins;
    property Errors: TStringList read FErrors;
  end;

implementation

constructor TPluginHost.Create;
begin
  inherited Create;
  FPlugins := TList.Create;
  FErrors := TStringList.Create;
end;

destructor TPluginHost.Destroy;
begin
  Clear;
  FErrors.Free;
  FPlugins.Free;
  inherited;
end;

procedure TPluginHost.Clear;
var
  i: Integer;
begin
  for i := 0 to FPlugins.Count - 1 do
    TPluginInfo(FPlugins[i]).Free;
  FPlugins.Clear;
  FErrors.Clear;
end;

function TPluginHost.IndexOfPlugin(const AId: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FPlugins.Count - 1 do
    if SameText(TPluginInfo(FPlugins[i]).Id, AId) then
      Exit(i);
end;

procedure TPluginHost.LoadDirectory(const ADirectory: string; ABundled: Boolean);
var
  Files: TStringList;
  i, Index: Integer;
  Plugin, Existing: TPluginInfo;
  ErrorText: string;
begin
  if (ADirectory = '') or (not DirectoryExists(ADirectory)) then Exit;
  Files := TStringList.Create;
  try
    FindAllFiles(Files, ADirectory, 'plugin.json', True);
    Files.Sort;
    for i := 0 to Files.Count - 1 do
    begin
      Plugin := ParsePluginManifest(Files[i], ErrorText);
      if Plugin = nil then
      begin
        FErrors.Add(ErrorText);
        Continue;
      end;
      Plugin.Bundled := ABundled;
      Index := IndexOfPlugin(Plugin.Id);
      if Index < 0 then
        FPlugins.Add(Plugin)
      else
      begin
        Existing := TPluginInfo(FPlugins[Index]);
        if (not ABundled) and Existing.Bundled then
        begin
          FPlugins[Index] := Plugin;
          Existing.Free;
        end
        else
          Plugin.Free;
      end;
    end;
  finally
    Files.Free;
  end;
end;

procedure TPluginHost.Reload(const ABundledDir, AUserDir: string);
begin
  Clear;
  LoadDirectory(ABundledDir, True);
  if (AUserDir <> '') and (not SameFileName(ABundledDir, AUserDir)) then
    LoadDirectory(AUserDir, False);
end;

procedure TPluginHost.SetLocale(const ALocale: string);
var
  i: Integer;
begin
  for i := 0 to FPlugins.Count - 1 do
    TPluginInfo(FPlugins[i]).ActiveLocale := ALocale;
end;

function TPluginHost.FindPlugin(const AId: string): TPluginInfo;
var
  Index: Integer;
begin
  Index := IndexOfPlugin(AId);
  if Index >= 0 then
    Result := TPluginInfo(FPlugins[Index])
  else
    Result := nil;
end;

function TPluginHost.FindAction(const APluginId, AActionId: string): TPluginCommand;
var
  Plugin: TPluginInfo;
begin
  Plugin := FindPlugin(APluginId);
  if Plugin = nil then Exit(nil);
  Result := Plugin.FindCommand(AActionId);
end;

function TPluginHost.Execute(APlugin: TPluginInfo; ACommand: TPluginCommand;
  ARequest: TJSONObject; out AResponse: TJSONObject; out AError: string): Boolean;
var
  Runtime: TPluginRuntime;
  RuntimeError: string;
begin
  Result := False;
  AResponse := nil;
  AError := '';
  if (APlugin = nil) or (ACommand = nil) then
  begin
    AError := 'Plugin command is missing';
    Exit;
  end;
  Runtime := CreatePluginRuntime(APlugin, RuntimeError);
  if Runtime = nil then
  begin
    AError := RuntimeError;
    Exit;
  end;
  try
    Result := Runtime.Execute(APlugin, ARequest, AResponse, AError);
  finally
    Runtime.Free;
  end;
end;

end.
