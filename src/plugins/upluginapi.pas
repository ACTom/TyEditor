unit upluginapi;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, FileUtil, LazFileUtils, uutils;

const
  PluginApiVersion = 1;
  PluginSchemaVersion = 1;
  PluginPackageExtension = '.typlugin';

type
  TPluginOptionKind = (pokChoice, pokString, pokBoolean);

  TPluginOption = class
  public
    Id: string;
    Caption: string;
    Kind: TPluginOptionKind;
    DefaultValue: string;
    Choices: TStringList;
    ChoiceLabels: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TPluginCommand = class
  public
    Id: string;
    Title: string;
    Scope: string;
    constructor Create;
  end;

  TPluginLocale = class
  public
    Language: string;
    Values: TStringList;
    constructor Create(const ALanguage: string);
    destructor Destroy; override;
    function Lookup(const AKey: string; out AValue: string): Boolean;
  end;

  TPluginInfo = class
  private
    function FindLocale(const ALanguage: string): TPluginLocale;
    function LookupLocale(const ALanguage, AKey: string; out AValue: string): Boolean;
  public
    SchemaVersion: Integer;
    ApiVersion: Integer;
    Id: string;
    Name: string;
    Description: string;
    Version: string;
    Publisher: string;
    License: string;
    Homepage: string;
    DefaultLocale: string;
    ActiveLocale: string;
    EditorConstraint: string;
    RuntimeType: string;
    Engine: string;
    EntryPoint: string;
    SymbolName: string;
    CommandLine: TStringList;
    Platforms: TStringList;
    Permissions: TStringList;
    Commands: TList;
    Options: TList;
    Locales: TList;
    Directory: string;
    TimeoutMs: Integer;
    Bundled: Boolean;
    Enabled: Boolean;
    DisabledReason: string;
    constructor Create;
    destructor Destroy; override;
    function Translate(const AKey, AFallback: string): string;
    function LocalizedName: string;
    function LocalizedDescription: string;
    function FindCommand(const AId: string): TPluginCommand;
    function FindOption(const AId: string): TPluginOption;
    function CommandTitle(ACommand: TPluginCommand): string;
    function OptionLabel(AOption: TPluginOption): string;
    function ChoiceLabel(AOption: TPluginOption; const AValue: string): string;
    function SupportsPlatform(const APlatform: string): Boolean;
    function CompatibilityError: string;
  end;

function CurrentPlatformID: string;
function ComparePluginVersions(const ALeft, ARight: string): Integer;
function VersionSatisfies(const AVersion, AConstraint: string): Boolean;
function ParsePluginManifest(const AFileName: string; out AError: string): TPluginInfo;
function LoadPluginLocales(APlugin: TPluginInfo; const ADirectory: string; out AError: string): Boolean;
function PluginRuntimeName(const AType: string): string;

implementation

{$I version.inc}


constructor TPluginOption.Create;
begin
  inherited Create;
  Choices := TStringList.Create;
  Choices.CaseSensitive := False;
  ChoiceLabels := TStringList.Create;
  ChoiceLabels.CaseSensitive := False;
  Kind := pokChoice;
end;

destructor TPluginOption.Destroy;
begin
  Choices.Free;
  ChoiceLabels.Free;
  inherited;
end;

constructor TPluginCommand.Create;
begin
  inherited Create;
  Scope := 'selection';
end;

constructor TPluginLocale.Create(const ALanguage: string);
begin
  inherited Create;
  Language := ALanguage;
  Values := TStringList.Create;
  Values.CaseSensitive := True;
end;

destructor TPluginLocale.Destroy;
begin
  Values.Free;
  inherited;
end;

function TPluginLocale.Lookup(const AKey: string; out AValue: string): Boolean;
var
  Index: Integer;
begin
  Index := Values.IndexOfName(AKey);
  Result := Index >= 0;
  if Result then
    AValue := Values.ValueFromIndex[Index]
  else
    AValue := '';
end;

constructor TPluginInfo.Create;
begin
  inherited Create;
  SchemaVersion := PluginSchemaVersion;
  ApiVersion := PluginApiVersion;
  DefaultLocale := 'en';
  ActiveLocale := 'en';
  RuntimeType := 'process';
  TimeoutMs := 10000;
  Enabled := True;
  CommandLine := TStringList.Create;
  Platforms := TStringList.Create;
  Platforms.CaseSensitive := False;
  Permissions := TStringList.Create;
  Permissions.CaseSensitive := False;
  Commands := TList.Create;
  Options := TList.Create;
  Locales := TList.Create;
end;

destructor TPluginInfo.Destroy;
var
  i: Integer;
begin
  for i := 0 to Commands.Count - 1 do
    TPluginCommand(Commands[i]).Free;
  for i := 0 to Options.Count - 1 do
    TPluginOption(Options[i]).Free;
  for i := 0 to Locales.Count - 1 do
    TPluginLocale(Locales[i]).Free;
  Commands.Free;
  Options.Free;
  Locales.Free;
  CommandLine.Free;
  Platforms.Free;
  Permissions.Free;
  inherited;
end;

function TPluginInfo.FindLocale(const ALanguage: string): TPluginLocale;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Locales.Count - 1 do
    if SameText(TPluginLocale(Locales[i]).Language, ALanguage) then
      Exit(TPluginLocale(Locales[i]));
end;

function TPluginInfo.LookupLocale(const ALanguage, AKey: string;
  out AValue: string): Boolean;
var
  Locale: TPluginLocale;
begin
  Locale := FindLocale(ALanguage);
  Result := (Locale <> nil) and Locale.Lookup(AKey, AValue);
  if not Result then
    AValue := '';
end;

function TPluginInfo.Translate(const AKey, AFallback: string): string;
var
  Base: string;
  P: Integer;
begin
  if LookupLocale(ActiveLocale, AKey, Result) then Exit;
  Base := ActiveLocale;
  P := Pos('_', Base);
  if P = 0 then P := Pos('-', Base);
  if P > 1 then
  begin
    Base := Copy(Base, 1, P - 1);
    if LookupLocale(Base, AKey, Result) then Exit;
  end;
  if LookupLocale(DefaultLocale, AKey, Result) then Exit;
  if LookupLocale('en', AKey, Result) then Exit;
  Result := AFallback;
end;

function TPluginInfo.LocalizedName: string;
begin
  Result := Translate('plugin.name', Name);
end;

function TPluginInfo.LocalizedDescription: string;
begin
  Result := Translate('plugin.description', Description);
end;

function TPluginInfo.FindCommand(const AId: string): TPluginCommand;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Commands.Count - 1 do
    if SameText(TPluginCommand(Commands[i]).Id, AId) then
      Exit(TPluginCommand(Commands[i]));
end;

function TPluginInfo.FindOption(const AId: string): TPluginOption;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Options.Count - 1 do
    if SameText(TPluginOption(Options[i]).Id, AId) then
      Exit(TPluginOption(Options[i]));
end;

function TPluginInfo.CommandTitle(ACommand: TPluginCommand): string;
begin
  if ACommand = nil then Exit('');
  Result := Translate('command.' + ACommand.Id + '.title', ACommand.Title);
end;

function TPluginInfo.OptionLabel(AOption: TPluginOption): string;
begin
  if AOption = nil then Exit('');
  Result := Translate('option.' + AOption.Id + '.label', AOption.Caption);
end;

function TPluginInfo.ChoiceLabel(AOption: TPluginOption;
  const AValue: string): string;
var
  Fallback: string;
begin
  if AOption = nil then Exit(AValue);
  Fallback := AOption.ChoiceLabels.Values[AValue];
  if Fallback = '' then Fallback := AValue;
  Result := Translate('option.' + AOption.Id + '.choice.' + AValue, Fallback);
end;

function TPluginInfo.SupportsPlatform(const APlatform: string): Boolean;
var
  i: Integer;
begin
  if Platforms.Count = 0 then Exit(True);
  for i := 0 to Platforms.Count - 1 do
  begin
    if SameText(Platforms[i], 'any') or SameText(Platforms[i], APlatform) then
      Exit(True);
  end;
  Result := False;
end;

function CurrentPlatformID: string;
begin
  {$IFDEF MSWINDOWS}
    {$IFDEF CPU64}
      Result := 'win64-x86_64';
    {$ELSE}
      Result := 'win32-i386';
    {$ENDIF}
  {$ELSE}
    {$IFDEF DARWIN}
      {$IFDEF CPUAARCH64}
        Result := 'darwin-aarch64';
      {$ELSE}
        Result := 'darwin-x86_64';
      {$ENDIF}
    {$ELSE}
      {$IFDEF CPUAARCH64}
        Result := 'linux-aarch64';
      {$ELSE}
        Result := 'linux-x86_64';
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
end;

function VersionParts(const AVersion: string): TStringList;
var
  S: string;
  i: Integer;
begin
  Result := TStringList.Create;
  S := AVersion;
  for i := 1 to Length(S) do
    if S[i] in ['-', '+'] then
    begin
      S := Copy(S, 1, i - 1);
      Break;
    end;
  Result.Delimiter := '.';
  Result.StrictDelimiter := True;
  Result.DelimitedText := S;
end;

function ComparePluginVersions(const ALeft, ARight: string): Integer;
var
  L, R: TStringList;
  i, A, B: Integer;
begin
  L := VersionParts(ALeft);
  R := VersionParts(ARight);
  try
    for i := 0 to 3 do
    begin
      if i < L.Count then A := StrToIntDef(L[i], 0) else A := 0;
      if i < R.Count then B := StrToIntDef(R[i], 0) else B := 0;
      if A <> B then
        Exit(A - B);
    end;
    Result := 0;
  finally
    L.Free;
    R.Free;
  end;
end;

function VersionSatisfies(const AVersion, AConstraint: string): Boolean;
var
  Tokens: TStringList;
  i: Integer;
  Token, Op, Ver: string;
  Cmp: Integer;
begin
  if Trim(AConstraint) = '' then Exit(True);
  Tokens := TStringList.Create;
  try
    Tokens.Delimiter := ' ';
    Tokens.StrictDelimiter := True;
    Tokens.DelimitedText := Trim(AConstraint);
    for i := 0 to Tokens.Count - 1 do
    begin
      Token := Trim(Tokens[i]);
      if Token = '' then Continue;
      Op := '';
      if Copy(Token, 1, 2) = '>=' then begin Op := '>='; Ver := Copy(Token, 3, MaxInt); end
      else if Copy(Token, 1, 2) = '<=' then begin Op := '<='; Ver := Copy(Token, 3, MaxInt); end
      else if Copy(Token, 1, 1) = '>' then begin Op := '>'; Ver := Copy(Token, 2, MaxInt); end
      else if Copy(Token, 1, 1) = '<' then begin Op := '<'; Ver := Copy(Token, 2, MaxInt); end
      else if Copy(Token, 1, 1) = '=' then begin Op := '='; Ver := Copy(Token, 2, MaxInt); end
      else begin Op := '='; Ver := Token; end;
      Cmp := ComparePluginVersions(AVersion, Trim(Ver));
      if ((Op = '>=') and (Cmp < 0)) or
         ((Op = '<=') and (Cmp > 0)) or
         ((Op = '>') and (Cmp <= 0)) or
         ((Op = '<') and (Cmp >= 0)) or
         ((Op = '=') and (Cmp <> 0)) then
        Exit(False);
    end;
    Result := True;
  finally
    Tokens.Free;
  end;
end;

function TPluginInfo.CompatibilityError: string;
begin
  Result := '';
  if not SupportsPlatform(CurrentPlatformID) then
    Result := Format('plugin does not support platform %s', [CurrentPlatformID])
  else if not VersionSatisfies(TyEditorVersion, EditorConstraint) then
    Result := Format('plugin requires TyEditor %s', [EditorConstraint]);
end;

function PluginRuntimeName(const AType: string): string;
begin
  Result := LowerCase(Trim(AType));
end;

procedure ReadStringArray(AValue: TJSONData; AList: TStringList);
var
  Arr: TJSONArray;
  i: Integer;
begin
  if AValue is TJSONArray then
  begin
    Arr := TJSONArray(AValue);
    for i := 0 to Arr.Count - 1 do
      if Arr.Items[i].JSONType = jtString then
        AList.Add(Arr.Items[i].AsString);
  end
  else if (AValue <> nil) and (AValue.JSONType = jtString) then
    AList.Add(AValue.AsString);
end;

function ParsePluginManifest(const AFileName: string;
  out AError: string): TPluginInfo;
var
  Text: string;
  Data: TJSONData;
  Obj, RT, Compat, ItemObj: TJSONObject;
  Arr: TJSONArray;
  i, j: Integer;
  s, TypeName, Scope, CmdId, CmdTitle, OptId, OptType: string;
  Opt: TPluginOption;
  Cmd: TPluginCommand;
  Choices: TJSONArray;
  Choice: TJSONData;
  ChoiceObj: TJSONObject;
begin
  Result := nil;
  AError := '';
  if not ReadTextFileSafe(AFileName, Text) then
  begin
    AError := 'Cannot read ' + AFileName;
    Exit;
  end;
  try
    Data := GetJSON(Text);
  except
    on E: Exception do
    begin
      AError := AFileName + ': ' + E.Message;
      Exit;
    end;
  end;
  try
    if not (Data is TJSONObject) then
    begin
      AError := AFileName + ': manifest must be a JSON object';
      Exit;
    end;
    Obj := TJSONObject(Data);
    Result := TPluginInfo.Create;
    Result.Directory := ExtractFileDir(AFileName);
    Result.SchemaVersion := Obj.Get('schema', PluginSchemaVersion);
    Result.ApiVersion := Obj.Get('api', PluginApiVersion);
    Result.Id := Trim(Obj.Get('id', ''));
    Result.Name := Trim(Obj.Get('name', ''));
    Result.Description := Obj.Get('description', '');
    Result.Version := Trim(Obj.Get('version', '1.0.0'));
    Result.Publisher := Obj.Get('publisher', '');
    Result.License := Obj.Get('license', '');
    Result.Homepage := Obj.Get('homepage', '');
    Result.DefaultLocale := Trim(Obj.Get('default_locale', 'en'));
    if Result.DefaultLocale = '' then Result.DefaultLocale := 'en';
    Result.ActiveLocale := Result.DefaultLocale;
    Result.TimeoutMs := Obj.Get('timeout_ms', 10000);
    if Result.TimeoutMs < 1000 then Result.TimeoutMs := 1000;
    Result.Bundled := False;

    if (Result.Id = '') or (Result.Name = '') then
    begin
      AError := AFileName + ': id and name are required';
      FreeAndNil(Result);
      Exit;
    end;
    if (Pos('/', Result.Id) > 0) or (Pos('\', Result.Id) > 0) or
       (Pos(':', Result.Id) > 0) or (Result.Id = '.') or
       (Result.Id = '..') then
    begin
      AError := AFileName + ': invalid plugin id';
      FreeAndNil(Result);
      Exit;
    end;
    if Result.SchemaVersion <> PluginSchemaVersion then
    begin
      AError := AFileName + ': unsupported package schema';
      FreeAndNil(Result);
      Exit;
    end;
    if Result.ApiVersion <> PluginApiVersion then
    begin
      AError := AFileName + ': unsupported plugin API version';
      FreeAndNil(Result);
      Exit;
    end;

    RT := nil;
    if Obj.Find('runtime') is TJSONObject then
      RT := TJSONObject(Obj.Find('runtime'));
    if RT <> nil then
    begin
      TypeName := LowerCase(Trim(RT.Get('type', 'process')));
      Result.RuntimeType := TypeName;
      Result.Engine := LowerCase(Trim(RT.Get('engine', '')));
      Result.EntryPoint := RT.Get('entry', '');
      Result.SymbolName := RT.Get('symbol', '');
      if RT.Find('command') <> nil then
        ReadStringArray(RT.Find('command'), Result.CommandLine);
    end
    else if Obj.Find('runtime') is TJSONString then
      Result.RuntimeType := LowerCase(Trim(TJSONString(Obj.Find('runtime')).AsString));

    if Result.CommandLine.Count = 0 then
    begin
      if Obj.Find('command') <> nil then
        ReadStringArray(Obj.Find('command'), Result.CommandLine)
      else if Obj.Get('command', '') <> '' then
        Result.CommandLine.Add(Obj.Get('command', ''));
    end;
    if Result.CommandLine.Count = 0 then
    begin
      if Obj.Find('args') is TJSONArray then
        for i := 0 to TJSONArray(Obj.Find('args')).Count - 1 do
          if TJSONArray(Obj.Find('args')).Items[i].JSONType = jtString then
            Result.CommandLine.Add(TJSONArray(Obj.Find('args')).Items[i].AsString);
    end;

    if Obj.Find('compatibility') is TJSONObject then
    begin
      Compat := TJSONObject(Obj.Find('compatibility'));
      Result.EditorConstraint := Compat.Get('editor', '');
      if Compat.Find('platforms') <> nil then
        ReadStringArray(Compat.Find('platforms'), Result.Platforms);
    end;
    if (Result.Platforms.Count = 0) and (Obj.Find('platforms') <> nil) then
      ReadStringArray(Obj.Find('platforms'), Result.Platforms);
    if Obj.Find('permissions') <> nil then
      ReadStringArray(Obj.Find('permissions'), Result.Permissions);

    if Result.RuntimeType = '' then Result.RuntimeType := 'process';
    if (Result.RuntimeType = 'process') and (Result.CommandLine.Count = 0) then
    begin
      AError := AFileName + ': process runtime requires command';
      FreeAndNil(Result);
      Exit;
    end;
    if Result.RuntimeType = 'pascalscript' then
    begin
      if Result.Engine = '' then Result.Engine := 'pascalscript';
      if Result.EntryPoint = '' then
      begin
        AError := AFileName + ': pascalscript runtime requires entry';
        FreeAndNil(Result);
        Exit;
      end;
    end;

    if Obj.Find('commands') is TJSONArray then
      Arr := TJSONArray(Obj.Find('commands'))
    else if Obj.Find('actions') is TJSONArray then
      Arr := TJSONArray(Obj.Find('actions'))
    else
      Arr := nil;
    if Arr <> nil then
    begin
      for i := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[i] is TJSONObject) then Continue;
        ItemObj := TJSONObject(Arr.Items[i]);
        CmdId := Trim(ItemObj.Get('id', ''));
        CmdTitle := Trim(ItemObj.Get('title', ItemObj.Get('label', '')));
        Scope := LowerCase(Trim(ItemObj.Get('scope', 'selection')));
        if (CmdId = '') or (CmdTitle = '') then Continue;
        if (Scope <> 'selection') and (Scope <> 'document') and (Scope <> 'none') then
          Scope := 'selection';
        Cmd := TPluginCommand.Create;
        Cmd.Id := CmdId;
        Cmd.Title := CmdTitle;
        Cmd.Scope := Scope;
        Result.Commands.Add(Cmd);
      end;
    end;
    if Result.Commands.Count = 0 then
    begin
      AError := AFileName + ': no valid commands';
      FreeAndNil(Result);
      Exit;
    end;

    if Obj.Find('options') is TJSONArray then
    begin
      Arr := TJSONArray(Obj.Find('options'));
      for i := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[i] is TJSONObject) then Continue;
        ItemObj := TJSONObject(Arr.Items[i]);
        OptId := Trim(ItemObj.Get('id', ''));
        if OptId = '' then Continue;
        Opt := TPluginOption.Create;
        Opt.Id := OptId;
        Opt.Caption := ItemObj.Get('label', OptId);
        Opt.DefaultValue := ItemObj.Get('default', '');
        OptType := LowerCase(Trim(ItemObj.Get('type', 'string')));
        if OptType = 'choice' then Opt.Kind := pokChoice
        else if OptType = 'bool' then Opt.Kind := pokBoolean
        else Opt.Kind := pokString;
        if ItemObj.Find('choices') is TJSONArray then
        begin
          Choices := TJSONArray(ItemObj.Find('choices'));
          for j := 0 to Choices.Count - 1 do
          begin
            Choice := Choices.Items[j];
            if Choice.JSONType = jtString then
            begin
              Opt.Choices.Add(Choice.AsString);
              Opt.ChoiceLabels.Values[Choice.AsString] := Choice.AsString;
            end
            else if Choice is TJSONObject then
            begin
              ChoiceObj := TJSONObject(Choice);
              s := ChoiceObj.Get('value', '');
              if s = '' then Continue;
              Opt.Choices.Add(s);
              Opt.ChoiceLabels.Values[s] := ChoiceObj.Get('label', s);
            end;
          end;
        end;
        if (Opt.Kind = pokChoice) and (Opt.Choices.Count = 0) then
          Opt.Kind := pokString;
        if Opt.DefaultValue = '' then
        begin
          if Opt.Kind = pokBoolean then Opt.DefaultValue := 'false'
          else if Opt.Choices.Count > 0 then Opt.DefaultValue := Opt.Choices[0];
        end;
        Result.Options.Add(Opt);
      end;
    end;

    if not LoadPluginLocales(Result, Result.Directory, s) then
    begin
      AError := AFileName + ': ' + s;
      FreeAndNil(Result);
      Exit;
    end;
  finally
    Data.Free;
  end;
end;

function LoadPluginLocales(APlugin: TPluginInfo; const ADirectory: string;
  out AError: string): Boolean;
var
  SR: TSearchRec;
  LocaleDir, FileName, Lang, Text: string;
  Data: TJSONData;
  Obj: TJSONObject;
  Locale: TPluginLocale;
  i: Integer;
begin
  Result := True;
  AError := '';
  LocaleDir := IncludeTrailingPathDelimiter(ADirectory) + 'locales';
  if not DirectoryExists(LocaleDir) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(LocaleDir) + '*.json', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory) <> 0 then Continue;
      FileName := IncludeTrailingPathDelimiter(LocaleDir) + SR.Name;
      if not ReadTextFileSafe(FileName, Text) then
      begin
        AError := 'cannot read ' + FileName;
        Exit(False);
      end;
      try
        Data := GetJSON(Text);
        try
          if not (Data is TJSONObject) then
          begin
            AError := FileName + ': locale must be a JSON object';
            Exit(False);
          end;
          Obj := TJSONObject(Data);
          Lang := ChangeFileExt(SR.Name, '');
          Locale := TPluginLocale.Create(Lang);
          try
            for i := 0 to Obj.Count - 1 do
              Locale.Values.Values[Obj.Names[i]] := Obj.Items[i].AsString;
          except
            Locale.Free;
            raise;
          end;
          APlugin.Locales.Add(Locale);
        finally
          Data.Free;
        end;
      except
        on E: Exception do
        begin
          AError := FileName + ': ' + E.Message;
          Exit(False);
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

end.
