program testplugins;
{$mode objfpc}{$H+}
uses
  SysUtils, fpjson, FileUtil, zipper, upluginapi, upluginhost, upluginmanager;

function Check(ACond: Boolean; const AMessage: string): Boolean;
begin
  Result := ACond;
  if not Result then
    WriteLn('FAIL: ', AMessage);
end;

function NewRequest(const APlugin, ACommand: string; const AText: string): TJSONObject;
var
  Context, Selection: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('api', PluginApiVersion);
  Result.Add('plugin', APlugin);
  Result.Add('command', ACommand);
  Context := TJSONObject.Create;
  Context.Add('text', AText);
  Selection := TJSONObject.Create;
  Selection.Add('text', AText);
  Selection.Add('start', 0);
  Selection.Add('end', Length(AText));
  Context.Add('selection', Selection);
  Result.Add('context', Context);
end;

function FirstActionText(AResponse: TJSONObject; out AKind: string): string;
var
  Arr: TJSONArray;
  Obj: TJSONObject;
begin
  Result := '';
  AKind := '';
  if not (AResponse.Find('actions') is TJSONArray) then Exit;
  Arr := TJSONArray(AResponse.Find('actions'));
  if Arr.Count = 0 then Exit;
  if not (Arr.Items[0] is TJSONObject) then Exit;
  Obj := TJSONObject(Arr.Items[0]);
  AKind := Obj.Get('type', Obj.Get('kind', ''));
  Result := Obj.Get('text', '');
end;

var
  Host: TPluginHost;
  Manager: TPluginManager;
  Plugin: TPluginInfo;
  Command: TPluginCommand;
  Request, Response: TJSONObject;
  ErrorText, Kind, Root, ConfigDir: string;
  ActionText: string;
  FixtureRoot, PackageRoot, IncompatRoot, PackageFile, BadFile: string;
  StartTick: QWord;
  Zip: TZipper;
begin
  Root := IncludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0)))) +
    '..' + PathDelim + 'data' + PathDelim + 'plugins';
  FixtureRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0)))) +
    'fixtures' + PathDelim + 'plugins';

  Host := TPluginHost.Create;
  try
    Host.Reload(Root, '');
    if not Check(Host.Errors.Count = 0, 'load errors: ' + Host.Errors.Text) then Halt(1);
    Plugin := Host.FindPlugin('sample.base64');
    if not Check(Plugin <> nil, 'sample.base64 missing') then Halt(2);
    Plugin.ActiveLocale := 'zh_CN';
    if not Check(Plugin.LocalizedName = 'Base64 工具', 'zh_CN plugin name not loaded') then Halt(3);
    Command := Plugin.FindCommand('encode');
    if not Check(Command <> nil, 'base64 encode command missing') then Halt(4);
    if not Check(Plugin.CommandTitle(Command) = '将选区编码为 Base64',
      'zh_CN command title not loaded') then Halt(5);

    Request := NewRequest('sample.base64', 'encode', 'hello');
    try
      if not Host.Execute(Plugin, Command, Request, Response, ErrorText) then
      begin
        WriteLn('base64 plugin error: ', ErrorText);
        Halt(6);
      end;
      try
        ActionText := FirstActionText(Response, Kind);
        if not Check((Kind = 'replace_selection') and (ActionText = 'aGVsbG8='),
          'unexpected base64 response: ' + Kind + ' / ' + ActionText) then Halt(7);
      finally
        Response.Free;
      end;
    finally
      Request.Free;
    end;

    Plugin := Host.FindPlugin('sample.jsonformat');
    if not Check(Plugin <> nil, 'sample.jsonformat missing') then Halt(8);
    Command := Plugin.FindCommand('format');
    if not Check(Command <> nil, 'json format command missing') then Halt(9);
    Request := NewRequest('sample.jsonformat', 'format', '{"b":1,"a":2}');
    TJSONObject(Request.Find('context')).Add('locale', 'en');
    Request.Add('options', TJSONObject.Create(['indent', '2', 'sort_keys', 'true']));
    try
      if not Host.Execute(Plugin, Command, Request, Response, ErrorText) then
      begin
        WriteLn('json plugin error: ', ErrorText);
        Halt(10);
      end;
      try
        ActionText := FirstActionText(Response, Kind);
        if not Check((Kind = 'replace_document') and (Pos('"a": 2', ActionText) > 0),
          'unexpected json response: ' + ActionText) then Halt(11);
      finally
        Response.Free;
      end;
    finally
      Request.Free;
    end;

    Host.Reload(Root, FixtureRoot);
    Plugin := Host.FindPlugin('test.pascaltest');
    if not Check(Plugin <> nil, 'PascalScript fixture missing') then Halt(15);
    Plugin.ActiveLocale := 'zh_CN';
    if not Check(Plugin.LocalizedName = 'Pascal 脚本测试',
      'PascalScript locale missing') then Halt(16);
    Command := Plugin.FindCommand('append');
    if not Check(Command <> nil, 'PascalScript command missing') then Halt(17);
    Request := NewRequest('test.pascaltest', 'append', 'hello');
    Request.Add('options', TJSONObject.Create(['suffix', 'X']));
    try
      if not Host.Execute(Plugin, Command, Request, Response, ErrorText) then
      begin
        WriteLn('PascalScript error: ', ErrorText);
        Halt(18);
      end;
      try
        ActionText := FirstActionText(Response, Kind);
        if not Check((Kind = 'replace_selection') and (ActionText = 'hello:X'),
          'unexpected PascalScript response: ' + Kind + ' / ' + ActionText) then Halt(19);
        if not Check(Response.Get('message', '') = 'script-ok',
          'PascalScript message missing') then Halt(20);
      finally
        Response.Free;
      end;
    finally
      Request.Free;
    end;

    Host.Reload(Root, FixtureRoot);
    Plugin := Host.FindPlugin('test.slow');
    if not Check(Plugin <> nil, 'slow fixture missing') then Halt(25);
    Command := Plugin.FindCommand('run');
    Request := NewRequest('test.slow', 'run', 'x');
    StartTick := GetTickCount64;
    try
      if Host.Execute(Plugin, Command, Request, Response, ErrorText) then
      begin
        WriteLn('FAIL: slow plugin unexpectedly succeeded');
        Halt(26);
      end;
      if not Check(Pos('timed out', LowerCase(ErrorText)) > 0,
        'timeout error missing: ' + ErrorText) then Halt(27);
      if not Check(GetTickCount64 - StartTick >= 900, 'timeout was too fast') then Halt(28);
    finally
      Request.Free;
    end;

    Plugin := Host.FindPlugin('test.badresponse');
    if not Check(Plugin <> nil, 'bad response fixture missing') then Halt(29);
    Command := Plugin.FindCommand('run');
    Request := NewRequest('test.badresponse', 'run', 'x');
    try
      if Host.Execute(Plugin, Command, Request, Response, ErrorText) then
      begin
        WriteLn('FAIL: bad response unexpectedly succeeded');
        Halt(30);
      end;
      if not Check(Pos('invalid plugin response', LowerCase(ErrorText)) > 0,
        'invalid response error missing: ' + ErrorText) then Halt(31);
    finally
      Request.Free;
    end;

    Plugin := Host.FindPlugin('sample.caesar');
    if not Check((Plugin <> nil) and (not Plugin.Bundled) and
      (Plugin.Name = 'User Caesar Override'), 'user override precedence failed') then Halt(32);

    ConfigDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
      'tyeditor-plugin-test-' + IntToStr(GetProcessID);
    ForceDirectories(ConfigDir);
    Manager := TPluginManager.Create(ConfigDir);
    try
      Manager.Reload(Root, IncludeTrailingPathDelimiter(ConfigDir) + 'plugins');
      if not Check(Manager.Plugins.Count >= 5, 'manager plugin count') then Halt(12);
      if not Check(Manager.SetEnabled('sample.base64', False), 'disable plugin') then Halt(13);
      Manager.Reload(Root, IncludeTrailingPathDelimiter(ConfigDir) + 'plugins');
      Plugin := Manager.FindPlugin('sample.base64');
      if not Check((Plugin <> nil) and (not Plugin.Enabled), 'disabled state not persisted') then Halt(14);
      Command := Plugin.FindCommand('encode');
      Request := NewRequest('sample.base64', 'encode', 'hello');
      try
        if Manager.Execute(Plugin, Command, Request, Response, ErrorText) then
        begin
          WriteLn('FAIL: disabled plugin executed');
          Halt(15);
        end;
        if not Check(Pos('disabled', LowerCase(ErrorText)) > 0,
          'disabled error missing: ' + ErrorText) then Halt(16);
      finally
        Request.Free;
      end;

      PackageRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0)))) +
        'fixtures' + PathDelim + 'package';
      PackageFile := IncludeTrailingPathDelimiter(ConfigDir) + 'test.typlugin';
      Zip := TZipper.Create;
      try
        Zip.FileName := PackageFile;
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(PackageRoot) + 'plugin.json', 'plugin.json');
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(PackageRoot) + 'main.ps', 'main.ps');
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(PackageRoot) + 'locales/en.json', 'locales/en.json');
        Zip.ZipAllFiles;
      finally
        Zip.Free;
      end;
      if not Check(Manager.InstallPackage(PackageFile, ErrorText),
        'package install: ' + ErrorText) then Halt(21);
      Manager.Refresh;
      Plugin := Manager.FindPlugin('test.package');
      if not Check((Plugin <> nil) and (not Plugin.Bundled), 'installed package not loaded') then Halt(22);
      if not Check(Manager.UninstallPlugin('test.package', ErrorText),
        'package uninstall: ' + ErrorText) then Halt(23);
      Manager.Refresh;
      if not Check(Manager.FindPlugin('test.package') = nil, 'uninstalled package still loaded') then Halt(24);

      IncompatRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0)))) +
        'fixtures' + PathDelim + 'package-incompatible';
      PackageFile := IncludeTrailingPathDelimiter(ConfigDir) + 'incompatible.typlugin';
      Zip := TZipper.Create;
      try
        Zip.FileName := PackageFile;
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(IncompatRoot) + 'plugin.json', 'plugin.json');
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(IncompatRoot) + 'main.ps', 'main.ps');
        Zip.ZipAllFiles;
      finally
        Zip.Free;
      end;
      if not Check(Manager.InstallPackage(PackageFile, ErrorText),
        'incompatible package install: ' + ErrorText) then Halt(28);
      Manager.Refresh;
      Plugin := Manager.FindPlugin('test.incompatible');
      if not Check((Plugin <> nil) and (not Plugin.Enabled) and
        (Plugin.DisabledReason <> ''), 'incompatible package not disabled') then Halt(29);
      if not Check(Manager.UninstallPlugin('test.incompatible', ErrorText),
        'incompatible package uninstall: ' + ErrorText) then Halt(30);
      Manager.Refresh;

      BadFile := IncludeTrailingPathDelimiter(ConfigDir) + 'unsafe.typlugin';
      Zip := TZipper.Create;
      try
        Zip.FileName := BadFile;
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(PackageRoot) + 'plugin.json', 'plugin.json');
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(PackageRoot) + 'main.ps', '../evil.txt');
        Zip.ZipAllFiles;
      finally
        Zip.Free;
      end;
      if not Check(not Manager.InstallPackage(BadFile, ErrorText), 'unsafe archive accepted') then Halt(25);
      if not Check(not FileExists(IncludeTrailingPathDelimiter(ConfigDir) + 'evil.txt'),
        'unsafe archive escaped install directory') then Halt(26);

      BadFile := IncludeTrailingPathDelimiter(ConfigDir) + 'missing-manifest.typlugin';
      Zip := TZipper.Create;
      try
        Zip.FileName := BadFile;
        Zip.Entries.AddFileEntry(IncludeTrailingPathDelimiter(PackageRoot) + 'main.ps', 'main.ps');
        Zip.ZipAllFiles;
      finally
        Zip.Free;
      end;
      if not Check(not Manager.InstallPackage(BadFile, ErrorText), 'archive without manifest accepted') then Halt(27);
    finally
      Manager.Free;
      DeleteDirectory(ConfigDir, False, True);
    end;

    WriteLn('RESULT ok');
  finally
    Host.Free;
  end;
end.
