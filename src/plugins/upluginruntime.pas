unit upluginruntime;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, Pipes, fpjson, jsonparser, FileUtil, LazFileUtils, uutils,
  uPSComponent, uPSRuntime, upluginapi;

type
  TPluginRuntime = class
  public
    function Execute(APlugin: TPluginInfo; ARequest: TJSONObject;
      out AResponse: TJSONObject; out AError: string): Boolean; virtual; abstract;
  end;

  TProcessPluginRuntime = class(TPluginRuntime)
  private
    function ExpandArg(const AArg, APluginDir: string): string;
    function ReadAvailable(AStream: TInputPipeStream): string;
  public
    function Execute(APlugin: TPluginInfo; ARequest: TJSONObject;
      out AResponse: TJSONObject; out AError: string): Boolean; override;
  end;

  TPascalScriptPluginRuntime = class(TPluginRuntime)
  public
    function Execute(APlugin: TPluginInfo; ARequest: TJSONObject;
      out AResponse: TJSONObject; out AError: string): Boolean; override;
  end;

function CreatePluginRuntime(APlugin: TPluginInfo; out AError: string): TPluginRuntime;
procedure ResetPluginCancellation;
procedure CancelPluginExecution;

implementation

var
  PluginExecutionCancelled: Boolean = False;

procedure ResetPluginCancellation;
begin
  PluginExecutionCancelled := False;
end;

procedure CancelPluginExecution;
begin
  PluginExecutionCancelled := True;
end;

function TPluginRuntimeFactoryError(const AType: string): string;
begin
  Result := 'Unsupported plugin runtime: ' + AType;
end;

function CreatePluginRuntime(APlugin: TPluginInfo; out AError: string): TPluginRuntime;
begin
  Result := nil;
  AError := '';
  if APlugin = nil then
  begin
    AError := 'Plugin is missing';
    Exit;
  end;
  if SameText(APlugin.RuntimeType, 'process') then
    Result := TProcessPluginRuntime.Create
  else if SameText(APlugin.RuntimeType, 'pascalscript') then
    Result := TPascalScriptPluginRuntime.Create
  else
    AError := TPluginRuntimeFactoryError(APlugin.RuntimeType);
end;

function TProcessPluginRuntime.ExpandArg(const AArg, APluginDir: string): string;
begin
  Result := StringReplace(AArg, '${pluginDir}', APluginDir, [rfReplaceAll]);
  Result := StringReplace(Result, '${/}', PathDelim, [rfReplaceAll]);
  Result := StringReplace(Result, '${platform}', CurrentPlatformID, [rfReplaceAll]);
end;

function TProcessPluginRuntime.ReadAvailable(AStream: TInputPipeStream): string;
var
  Buffer: string;
  N: LongInt;
begin
  Result := '';
  if AStream = nil then Exit;
  SetLength(Buffer, 65536);
  while AStream.NumBytesAvailable > 0 do
  begin
    N := AStream.Read(Buffer[1], Length(Buffer));
    if N <= 0 then Break;
    Result := Result + Copy(Buffer, 1, N);
  end;
end;

function TProcessPluginRuntime.Execute(APlugin: TPluginInfo;
  ARequest: TJSONObject; out AResponse: TJSONObject; out AError: string): Boolean;
var
  Proc: TProcess;
  RequestText, OutText, ErrText, Chunk, CommandPath: string;
  i: Integer;
  StartTick: QWord;
  TimedOut: Boolean;
  Data: TJSONData;
begin
  Result := False;
  AResponse := nil;
  AError := '';
  if (APlugin = nil) or (ARequest = nil) then
  begin
    AError := 'Plugin request is missing';
    Exit;
  end;
  if APlugin.CommandLine.Count = 0 then
  begin
    AError := 'Plugin command is empty';
    Exit;
  end;

  CommandPath := ExpandArg(APlugin.CommandLine[0], APlugin.Directory);
  if ExtractFilePath(CommandPath) <> '' then
  begin
    if not FilenameIsAbsolute(CommandPath) then
      CommandPath := IncludeTrailingPathDelimiter(APlugin.Directory) + CommandPath;
    if not FileExists(CommandPath) then
    begin
      AError := 'Plugin command not found: ' + CommandPath;
      Exit;
    end;
  end;

  RequestText := ARequest.AsJSON + LineEnding;
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := CommandPath;
    Proc.CurrentDirectory := APlugin.Directory;
    for i := 1 to APlugin.CommandLine.Count - 1 do
      Proc.Parameters.Add(ExpandArg(APlugin.CommandLine[i], APlugin.Directory));
    Proc.Options := [poUsePipes];
    try
      Proc.Execute;
    except
      on E: Exception do
      begin
        AError := 'Cannot start plugin: ' + E.Message;
        Exit;
      end;
    end;

    try
      Proc.Input.WriteBuffer(RequestText[1], Length(RequestText));
      Proc.CloseInput;
    except
      on E: Exception do
      begin
        AError := 'Cannot send plugin request: ' + E.Message;
        Proc.Terminate(124);
        Exit;
      end;
    end;

    OutText := '';
    ErrText := '';
    TimedOut := False;
    StartTick := GetTickCount64;
    while Proc.Running do
    begin
      Chunk := ReadAvailable(Proc.Output);
      if Chunk <> '' then OutText := OutText + Chunk;
      Chunk := ReadAvailable(Proc.Stderr);
      if Chunk <> '' then ErrText := ErrText + Chunk;
      if PluginExecutionCancelled then
      begin
        Proc.Terminate(124);
        Break;
      end;
      if GetTickCount64 - StartTick > QWord(APlugin.TimeoutMs) then
      begin
        TimedOut := True;
        Proc.Terminate(124);
        Break;
      end;
      Sleep(10);
    end;
    Proc.WaitOnExit;
    Chunk := ReadAvailable(Proc.Output);
    if Chunk <> '' then OutText := OutText + Chunk;
    Chunk := ReadAvailable(Proc.Stderr);
    if Chunk <> '' then ErrText := ErrText + Chunk;

    if PluginExecutionCancelled then
    begin
      AError := 'Plugin cancelled';
      Exit;
    end;
    if TimedOut then
    begin
      AError := Format('Plugin timed out after %d ms', [APlugin.TimeoutMs]);
      Exit;
    end;
    if Trim(OutText) = '' then
    begin
      AError := 'Plugin produced no response';
      if Trim(ErrText) <> '' then
        AError := AError + ': ' + Copy(Trim(ErrText), 1, 4000);
      Exit;
    end;
    try
      Data := GetJSON(OutText);
    except
      on E: Exception do
      begin
        AError := 'Invalid plugin response: ' + E.Message;
        if Trim(ErrText) <> '' then
          AError := AError + ': ' + Copy(Trim(ErrText), 1, 4000);
        Exit;
      end;
    end;
    if not (Data is TJSONObject) then
    begin
      Data.Free;
      AError := 'Plugin response must be a JSON object';
      Exit;
    end;
    AResponse := TJSONObject(Data);
    Result := True;
  finally
    Proc.Free;
  end;
end;

type
  TScriptContext = class
  public
    Plugin: TPluginInfo;
    Request: TJSONObject;
    Actions: TJSONArray;
    Messages: TStringList;
    constructor Create(APlugin: TPluginInfo; ARequest: TJSONObject);
    destructor Destroy; override;
    function ContextObject: TJSONObject;
    function OptionValue(const AName: string): string;
    procedure AddAction(const AKind, AText: string);
    procedure AddMessage(const AText: string);
  end;

var
  CurrentScriptContext: TScriptContext = nil;
  ScriptRegisterError: string = '';

constructor TScriptContext.Create(APlugin: TPluginInfo; ARequest: TJSONObject);
begin
  inherited Create;
  Plugin := APlugin;
  Request := ARequest;
  Actions := TJSONArray.Create;
  Messages := TStringList.Create;
  Messages.CaseSensitive := True;
end;

destructor TScriptContext.Destroy;
begin
  Messages.Free;
  Actions.Free;
  inherited;
end;

function TScriptContext.ContextObject: TJSONObject;
begin
  Result := nil;
  if (Request <> nil) and (Request.Find('context') is TJSONObject) then
    Result := TJSONObject(Request.Find('context'));
end;

function TScriptContext.OptionValue(const AName: string): string;
var
  Options: TJSONObject;
begin
  Result := '';
  if (Request = nil) or (not (Request.Find('options') is TJSONObject)) then Exit;
  Options := TJSONObject(Request.Find('options'));
  Result := Options.Get(AName, '');
end;

procedure TScriptContext.AddAction(const AKind, AText: string);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.Add('type', AKind);
  Obj.Add('text', AText);
  Actions.Add(Obj);
end;

procedure TScriptContext.AddMessage(const AText: string);
begin
  Messages.Add(AText);
end;

function PSGetText: string;
var
  Ctx: TJSONObject;
begin
  Result := '';
  if CurrentScriptContext = nil then Exit;
  Ctx := CurrentScriptContext.ContextObject;
  if Ctx <> nil then Result := Ctx.Get('text', '');
end;

function PSGetSelection: string;
var
  Ctx, Sel: TJSONObject;
begin
  Result := '';
  if CurrentScriptContext = nil then Exit;
  Ctx := CurrentScriptContext.ContextObject;
  if (Ctx <> nil) and (Ctx.Find('selection') is TJSONObject) then
  begin
    Sel := TJSONObject(Ctx.Find('selection'));
    Result := Sel.Get('text', '');
  end;
end;

function PSGetOption(AName: string): string;
begin
  if CurrentScriptContext = nil then Exit('');
  Result := CurrentScriptContext.OptionValue(AName);
end;

function PSGetLocale: string;
var
  Ctx: TJSONObject;
begin
  Result := '';
  if CurrentScriptContext = nil then Exit;
  Ctx := CurrentScriptContext.ContextObject;
  if Ctx <> nil then Result := Ctx.Get('locale', '');
end;

function PSGetFileName: string;
var
  Ctx: TJSONObject;
begin
  Result := '';
  if CurrentScriptContext = nil then Exit;
  Ctx := CurrentScriptContext.ContextObject;
  if Ctx <> nil then Result := Ctx.Get('file', '');
end;

procedure PSReplaceSelection(AValue: string);
begin
  if CurrentScriptContext <> nil then
    CurrentScriptContext.AddAction('replace_selection', AValue);
end;

procedure PSReplaceDocument(AValue: string);
begin
  if CurrentScriptContext <> nil then
    CurrentScriptContext.AddAction('replace_document', AValue);
end;

procedure PSInsertText(AValue: string);
begin
  if CurrentScriptContext <> nil then
    CurrentScriptContext.AddAction('insert_text', AValue);
end;

procedure PSSetCaret(ALine, ACol: Integer);
var
  Obj: TJSONObject;
begin
  if CurrentScriptContext = nil then Exit;
  Obj := TJSONObject.Create;
  Obj.Add('type', 'set_caret');
  Obj.Add('line', ALine);
  Obj.Add('col', ACol);
  CurrentScriptContext.Actions.Add(Obj);
end;

procedure PSMessage(AValue: string);
begin
  if CurrentScriptContext <> nil then
    CurrentScriptContext.AddMessage(AValue);
end;

procedure PSLog(AValue: string);
var
  Obj: TJSONObject;
begin
  if CurrentScriptContext = nil then Exit;
  Obj := TJSONObject.Create;
  Obj.Add('type', 'log');
  Obj.Add('text', AValue);
  CurrentScriptContext.Actions.Add(Obj);
end;


type
  TScriptHook = class
  public
    procedure Compile(Sender: TPSScript);
    procedure Line(Sender: TObject);
  end;

procedure RegisterScriptFunctions(Script: TPSScript); forward;

procedure TScriptHook.Compile(Sender: TPSScript);
begin
  RegisterScriptFunctions(Sender);
end;

procedure TScriptHook.Line(Sender: TObject);
begin
  if PluginExecutionCancelled then
    TPSScript(Sender).Stop;
end;

procedure AddScriptFunction(Script: TPSScript; Ptr: Pointer;
  const Decl: string);
begin
  if not Script.AddFunction(Ptr, Decl) then
    ScriptRegisterError := 'Cannot register ' + Decl;
end;

procedure RegisterScriptFunctions(Script: TPSScript);
begin
  AddScriptFunction(Script, @PSGetText, 'function GetText: string;');
  AddScriptFunction(Script, @PSGetSelection, 'function GetSelection: string;');
  AddScriptFunction(Script, @PSGetOption, 'function GetOption(Name: string): string;');
  AddScriptFunction(Script, @PSGetLocale, 'function GetLocale: string;');
  AddScriptFunction(Script, @PSGetFileName, 'function GetFileName: string;');
  AddScriptFunction(Script, @PSReplaceSelection, 'procedure ReplaceSelection(Value: string);');
  AddScriptFunction(Script, @PSReplaceDocument, 'procedure ReplaceDocument(Value: string);');
  AddScriptFunction(Script, @PSInsertText, 'procedure InsertText(Value: string);');
  AddScriptFunction(Script, @PSSetCaret, 'procedure SetCaret(Line, Col: Integer);');
  AddScriptFunction(Script, @PSMessage, 'procedure Message(Value: string);');
  AddScriptFunction(Script, @PSLog, 'procedure Log(Value: string);');
end;

function TPascalScriptPluginRuntime.Execute(APlugin: TPluginInfo;
  ARequest: TJSONObject; out AResponse: TJSONObject; out AError: string): Boolean;
var
  Script: TPSScript;
  Hook: TScriptHook;
  ScriptFile, SourceText, Msg: string;
  i: Integer;
  Ctx: TScriptContext;
  ResponseObj: TJSONObject;
begin
  Result := False;
  AResponse := nil;
  AError := '';
  if (APlugin = nil) or (ARequest = nil) then
  begin
    AError := 'Plugin request is missing';
    Exit;
  end;
  if APlugin.EntryPoint = '' then
  begin
    AError := 'PascalScript entry point is missing';
    Exit;
  end;
  ScriptFile := APlugin.EntryPoint;
  if not FilenameIsAbsolute(ScriptFile) then
    ScriptFile := IncludeTrailingPathDelimiter(APlugin.Directory) + ScriptFile;
  if not FileExists(ScriptFile) then
  begin
    AError := 'Script not found: ' + ScriptFile;
    Exit;
  end;
  if not ReadTextFileSafe(ScriptFile, SourceText) then
  begin
    AError := 'Cannot read script: ' + ScriptFile;
    Exit;
  end;

  Ctx := TScriptContext.Create(APlugin, ARequest);
  CurrentScriptContext := Ctx;
  Script := TPSScript.Create(nil);
  Hook := TScriptHook.Create;
  try
    try
      Script.Script.Text := SourceText;
      Script.MainFileName := ScriptFile;
      ScriptRegisterError := '';
      Script.OnCompile := @Hook.Compile;
      Script.OnLine := @Hook.Line;
      if not Script.Compile then
      begin
        Msg := '';
        for i := 0 to Script.CompilerMessageCount - 1 do
        begin
          if Msg <> '' then Msg := Msg + LineEnding;
          Msg := Msg + Script.CompilerErrorToStr(i);
        end;
        if Msg = '' then Msg := 'PascalScript compilation failed';
        AError := Msg;
        Exit;
      end;
      if ScriptRegisterError <> '' then
      begin
        AError := ScriptRegisterError;
        Exit;
      end;
      if not Script.Execute then
      begin
        if PluginExecutionCancelled then
          AError := 'Plugin cancelled'
        else
        begin
          AError := Script.ExecErrorToString;
          if AError = '' then AError := 'PascalScript execution failed';
        end;
        Exit;
      end;
      ResponseObj := TJSONObject.Create;
      ResponseObj.Add('api', PluginApiVersion);
      ResponseObj.Add('ok', True);
      ResponseObj.Add('actions', Ctx.Actions);
      Ctx.Actions := nil;
      if Ctx.Messages.Count > 0 then
        ResponseObj.Add('message', Trim(Ctx.Messages.Text));
      AResponse := ResponseObj;
      Result := True;
    except
      on E: Exception do
        AError := 'PascalScript error: ' + E.Message;
    end;
  finally
    CurrentScriptContext := nil;
    Hook.Free;
    Script.Free;
    Ctx.Free;
  end;
end;

end.
