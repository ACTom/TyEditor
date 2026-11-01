unit upluginruntime;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, Pipes, base64, fpjson, jsonparser, FileUtil,
  LazFileUtils, LazUTF8, uutils, uPSComponent, uPSRuntime, upluginapi;

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
    FailureMessage: string;
    constructor Create(APlugin: TPluginInfo; ARequest: TJSONObject);
    destructor Destroy; override;
    function ContextObject: TJSONObject;
    function OptionValue(const AName: string): string;
    procedure AddAction(const AKind, AText: string);
    procedure AddMessage(const AText: string);
    procedure SetFailure(const AMessage: string);
  end;

var
  CurrentScriptContext: TScriptContext = nil;
  ScriptRegisterError: string = '';
  ScriptLastError: string = '';

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

procedure TScriptContext.SetFailure(const AMessage: string);
begin
  FailureMessage := AMessage;
end;

function PSGetCommand: string;
begin
  Result := '';
  if (CurrentScriptContext <> nil) and (CurrentScriptContext.Request <> nil) then
    Result := CurrentScriptContext.Request.Get('command', '');
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

function PSLastError: string;
begin
  Result := ScriptLastError;
end;

procedure PSFail(AValue: string);
begin
  if CurrentScriptContext <> nil then
    CurrentScriptContext.SetFailure(AValue);
end;

procedure PSFailKey(AKey, AFallback: string);
begin
  if CurrentScriptContext = nil then Exit;
  if CurrentScriptContext.Plugin <> nil then
    CurrentScriptContext.SetFailure(
      CurrentScriptContext.Plugin.Translate(AKey, AFallback))
  else
    CurrentScriptContext.SetFailure(AFallback);
end;

function PSBase64Encode(AValue: string): string;
begin
  ScriptLastError := '';
  try
    Result := EncodeStringBase64(AValue);
  except
    on E: Exception do
    begin
      Result := '';
      ScriptLastError := E.Message;
    end;
  end;
end;

function ValidBase64Text(const AValue: string): Boolean;
var
  i, PadCount: Integer;
  C: Char;
begin
  if AValue = '' then Exit(True);
  if Length(AValue) mod 4 <> 0 then Exit(False);
  PadCount := 0;
  for i := 1 to Length(AValue) do
  begin
    C := AValue[i];
    if C = '=' then
      Inc(PadCount)
    else if PadCount > 0 then
      Exit(False)
    else if not (C in ['A'..'Z', 'a'..'z', '0'..'9', '+', '/']) then
      Exit(False);
  end;
  Result := PadCount <= 2;
end;

function PSBase64Decode(AValue: string): string;
begin
  ScriptLastError := '';
  if not ValidBase64Text(AValue) then
  begin
    Result := '';
    ScriptLastError := 'Invalid Base64 input';
    Exit;
  end;
  try
    Result := DecodeStringBase64(AValue, True);
  except
    on E: Exception do
    begin
      Result := '';
      ScriptLastError := 'Invalid Base64 input';
    end;
  end;
end;

function PSShiftLetters(AValue: string; AShift: Integer): string;
var
  i, Base, Offset: Integer;
  C: Char;
begin
  Result := AValue;
  AShift := AShift mod 26;
  if AShift < 0 then Inc(AShift, 26);
  for i := 1 to Length(Result) do
  begin
    C := Result[i];
    if (C >= 'a') and (C <= 'z') then
    begin
      Base := Ord('a');
      Offset := (Ord(C) - Base + AShift) mod 26;
      Result[i] := Chr(Base + Offset);
    end
    else if (C >= 'A') and (C <= 'Z') then
    begin
      Base := Ord('A');
      Offset := (Ord(C) - Base + AShift) mod 26;
      Result[i] := Chr(Base + Offset);
    end;
  end;
end;

function PSUpperText(AValue: string): string;
begin
  Result := UTF8UpperCase(AValue);
end;

function PSLowerText(AValue: string): string;
begin
  Result := UTF8LowerCase(AValue);
end;

function PSTitleText(AValue: string): string;
var
  i: Integer;
  C: Char;
  InWord: Boolean;
begin
  Result := AValue;
  InWord := False;
  for i := 1 to Length(Result) do
  begin
    C := Result[i];
    if (C >= 'a') and (C <= 'z') then
    begin
      if not InWord then
        Result[i] := Chr(Ord(C) - 32);
      InWord := True;
    end
    else if (C >= 'A') and (C <= 'Z') then
    begin
      if InWord then
        Result[i] := Chr(Ord(C) + 32);
      InWord := True;
    end
    else if Ord(C) >= 128 then
      InWord := True
    else
      InWord := False;
  end;
end;

function PSTrimTrailingSpaces(AValue: string): string;
var
  i, StartPos, EndPos, NextPos: Integer;
  Ending: string;
begin
  Result := '';
  StartPos := 1;
  i := 1;
  while i <= Length(AValue) do
  begin
    if (AValue[i] = #10) or (AValue[i] = #13) then
    begin
      EndPos := i - 1;
      while (EndPos >= StartPos) and (AValue[EndPos] in [' ', #9]) do
        Dec(EndPos);
      Result := Result + Copy(AValue, StartPos, EndPos - StartPos + 1);
      Ending := AValue[i];
      NextPos := i + 1;
      if (AValue[i] = #13) and (NextPos <= Length(AValue)) and
         (AValue[NextPos] = #10) then
      begin
        Ending := #13#10;
        Inc(NextPos);
      end;
      Result := Result + Ending;
      StartPos := NextPos;
      i := NextPos;
    end
    else
      Inc(i);
  end;
  if StartPos <= Length(AValue) then
  begin
    EndPos := Length(AValue);
    while (EndPos >= StartPos) and (AValue[EndPos] in [' ', #9]) do
      Dec(EndPos);
    Result := Result + Copy(AValue, StartPos, EndPos - StartPos + 1);
  end;
end;

function JSONLineIndent(ALevel, AIndent: Integer): string;
begin
  if (ALevel <= 0) or (AIndent <= 0) then
    Result := ''
  else
    Result := StringOfChar(' ', ALevel * AIndent);
end;

function JSONValueText(Data: TJSONData; AIndent, ALevel: Integer;
  ASortKeys: Boolean): string;
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  Names: TStringList;
  Name, FloatText: string;
  Number: TJSONNumber;
  FloatValue: TJSONFloat;
  FS: TFormatSettings;
  i: Integer;
begin
  if Data = nil then Exit('null');
  case Data.JSONType of
    jtObject:
      begin
        Obj := TJSONObject(Data);
        if Obj.Count = 0 then Exit('{}');
        Names := TStringList.Create;
        try
          Names.CaseSensitive := True;
          for i := 0 to Obj.Count - 1 do
            Names.Add(Obj.Names[i]);
          if ASortKeys then
            Names.Sort;
          Result := '{';
          for i := 0 to Names.Count - 1 do
          begin
            Name := Names[i];
            if i > 0 then
              Result := Result + ',';
            if AIndent > 0 then
              Result := Result + #10 + JSONLineIndent(ALevel + 1, AIndent);
            Result := Result + '"' + StringToJSONString(Name) + '":';
            if AIndent > 0 then
              Result := Result + ' ';
            Result := Result + JSONValueText(Obj.Find(Name), AIndent,
              ALevel + 1, ASortKeys);
          end;
          if AIndent > 0 then
            Result := Result + #10 + JSONLineIndent(ALevel, AIndent);
          Result := Result + '}';
        finally
          Names.Free;
        end;
      end;
    jtArray:
      begin
        Arr := TJSONArray(Data);
        if Arr.Count = 0 then Exit('[]');
        Result := '[';
        for i := 0 to Arr.Count - 1 do
        begin
          if i > 0 then
            Result := Result + ',';
          if AIndent > 0 then
            Result := Result + #10 + JSONLineIndent(ALevel + 1, AIndent);
          Result := Result + JSONValueText(Arr.Items[i], AIndent,
            ALevel + 1, ASortKeys);
        end;
        if AIndent > 0 then
          Result := Result + #10 + JSONLineIndent(ALevel, AIndent);
        Result := Result + ']';
      end;
    jtString:
      Result := '"' + StringToJSONString(Data.AsString) + '"';
    jtNumber:
      begin
        Number := TJSONNumber(Data);
        if Number.NumberType = ntFloat then
        begin
          FloatValue := Number.AsFloat;
          FS := DefaultFormatSettings;
          FS.DecimalSeparator := '.';
          FloatText := FloatToStr(FloatValue, FS);
          if (Pos('.', FloatText) = 0) and (Pos('E', FloatText) = 0) and
             (Pos('e', FloatText) = 0) then
            FloatText := FloatText + '.0';
          Result := FloatText;
        end
        else
          Result := Number.AsString;
      end;
    jtBoolean:
      if Data.AsBoolean then
        Result := 'true'
      else
        Result := 'false';
    jtNull:
      Result := 'null';
  else
    Result := 'null';
  end;
end;

function PSFormatJSON(AValue: string; AIndent: Integer;
  ASortKeys: Boolean): string;
var
  Data: TJSONData;
begin
  ScriptLastError := '';
  try
    Data := GetJSON(AValue);
  except
    ScriptLastError := 'Invalid JSON';
    Result := '';
    Exit;
  end;
  try
    if AIndent < 0 then AIndent := 0;
    Result := JSONValueText(Data, AIndent, 0, ASortKeys);
  finally
    Data.Free;
  end;
end;

function PSMinifyJSON(AValue: string): string;
begin
  Result := PSFormatJSON(AValue, 0, False);
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
  AddScriptFunction(Script, @PSGetCommand, 'function GetCommand: string;');
  AddScriptFunction(Script, @PSReplaceSelection, 'procedure ReplaceSelection(Value: string);');
  AddScriptFunction(Script, @PSReplaceDocument, 'procedure ReplaceDocument(Value: string);');
  AddScriptFunction(Script, @PSInsertText, 'procedure InsertText(Value: string);');
  AddScriptFunction(Script, @PSSetCaret, 'procedure SetCaret(Line, Col: Integer);');
  AddScriptFunction(Script, @PSMessage, 'procedure Message(Value: string);');
  AddScriptFunction(Script, @PSLog, 'procedure Log(Value: string);');
  AddScriptFunction(Script, @PSBase64Encode, 'function Base64Encode(Text: string): string;');
  AddScriptFunction(Script, @PSBase64Decode, 'function Base64Decode(Text: string): string;');
  AddScriptFunction(Script, @PSShiftLetters, 'function ShiftLetters(Text: string; Shift: Integer): string;');
  AddScriptFunction(Script, @PSUpperText, 'function UpperText(Text: string): string;');
  AddScriptFunction(Script, @PSLowerText, 'function LowerText(Text: string): string;');
  AddScriptFunction(Script, @PSTitleText, 'function TitleText(Text: string): string;');
  AddScriptFunction(Script, @PSTrimTrailingSpaces, 'function TrimTrailingSpaces(Text: string): string;');
  AddScriptFunction(Script, @PSFormatJSON, 'function FormatJSON(Text: string; Indent: Integer; SortKeys: Boolean): string;');
  AddScriptFunction(Script, @PSMinifyJSON, 'function MinifyJSON(Text: string): string;');
  AddScriptFunction(Script, @PSLastError, 'function LastError: string;');
  AddScriptFunction(Script, @PSFail, 'procedure Fail(Message: string);');
  AddScriptFunction(Script, @PSFailKey, 'procedure FailKey(Key, Fallback: string);');
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
  ScriptLastError := '';
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
      if Ctx.FailureMessage <> '' then
      begin
        ResponseObj.Add('ok', False);
        ResponseObj.Add('message', Ctx.FailureMessage);
      end
      else
      begin
        ResponseObj.Add('ok', True);
        ResponseObj.Add('actions', Ctx.Actions);
        Ctx.Actions := nil;
        if Ctx.Messages.Count > 0 then
          ResponseObj.Add('message', Trim(Ctx.Messages.Text));
      end;
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
