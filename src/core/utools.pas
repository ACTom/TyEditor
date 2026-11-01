unit utools;

{ User-configured external tools.

  External tools are deliberately separate from the plugin system: they have
  their own configuration file, their own manager and their own menu.  A tool
  is a plain executable started without a shell; each argument is one line in
  the configuration and is passed to the process unchanged apart from
  placeholder expansion.  Standard input / standard output carry the text. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, Pipes, FileUtil, LazFileUtils, fpjson, jsonparser, uutils;

type
  TToolInputMode = (timNone, timSelection, timDocument);
  TToolOutputMode = (tomNone, tomShow, tomInsertAtCaret, tomReplaceSelection,
    tomReplaceDocument);
  TToolSaveMode = (tsmNone, tsmCurrent, tsmAll);

  { Editor state handed to a tool run.  All text is UTF-8. }
  TToolContext = record
    FileName: string;
    Lexer: string;
    Encoding: string;
    Eol: string;
    Line: Integer;
    Col: Integer;
    SelectionText: string;
    DocumentText: string;
  end;

  { Shared cancellation flag for the background runner. }
  TToolRunState = class
  public
    Cancelled: Boolean;
  end;

  TExternalTool = class
  private
    FArguments: TStringList;
  public
    Id: string;
    Name: string;
    Command: string;
    WorkingDir: string;
    InputMode: TToolInputMode;
    OutputMode: TToolOutputMode;
    SaveMode: TToolSaveMode;
    TimeoutMs: Integer;
    Enabled: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Assign(ASource: TExternalTool);
    procedure SetArgumentText(const AValue: string);
    function ArgumentText: string;
    function HasPlaceholder(const AName: string): Boolean;
    property Arguments: TStringList read FArguments;
  end;

  TToolStore = class
  private
    FFileName: string;
    FTools: TList;
    FErrors: TStringList;
    function GetTool(AIndex: Integer): TExternalTool;
    function GetCount: Integer;
  public
    constructor Create(const AConfigDir: string);
    destructor Destroy; override;
    procedure Load;
    function Save(out AError: string): Boolean;
    function Add: TExternalTool;
    procedure Remove(ATool: TExternalTool);
    function IndexOf(ATool: TExternalTool): Integer;
    function MoveUp(ATool: TExternalTool): Boolean;
    function MoveDown(ATool: TExternalTool): Boolean;
    function FindById(const AId: string): TExternalTool;
    property Tools: TList read FTools;
    property ToolAt[AIndex: Integer]: TExternalTool read GetTool; default;
    property Count: Integer read GetCount;
    property Errors: TStringList read FErrors;
    property FileName: string read FFileName;
  end;

function NewToolId: string;
function ToolInputModeId(AMode: TToolInputMode): string;
function ToolOutputModeId(AMode: TToolOutputMode): string;
function ToolSaveModeId(AMode: TToolSaveMode): string;
function TryParseToolInputMode(const AValue: string; out AMode: TToolInputMode): Boolean;
function TryParseToolOutputMode(const AValue: string; out AMode: TToolOutputMode): Boolean;
function TryParseToolSaveMode(const AValue: string; out AMode: TToolSaveMode): Boolean;
function ValidateTool(ATool: TExternalTool; out AError: string): Boolean;

function ToolInputText(ATool: TExternalTool; const AContext: TToolContext): string;
function ExpandToolText(const AValue: string; ATool: TExternalTool;
  const AContext: TToolContext; const AInputFile: string): string;

{ Runs ATool synchronously in the calling thread.  The caller is responsible
  for calling this from a worker thread.  AState may be nil. }
function ExecuteTool(ATool: TExternalTool; const AContext: TToolContext;
  AState: TToolRunState; out AOutput, AErrOutput: string;
  out AExitCode: Integer; out AError: string; out ATimedOut: Boolean): Boolean;

implementation

const
  ToolInputModeIds: array[TToolInputMode] of string =
    ('none', 'selection', 'document');
  ToolOutputModeIds: array[TToolOutputMode] of string =
    ('none', 'show', 'insert_at_caret', 'replace_selection', 'replace_document');
  ToolSaveModeIds: array[TToolSaveMode] of string =
    ('none', 'current', 'all');
  DefaultTimeoutMs = 15000;
  MinTimeoutMs = 1000;
  MaxTimeoutMs = 600000;

function NewToolId: string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := 'tool-' + LowerCase(Copy(GUIDToString(Guid), 2, 36));
end;

function ToolInputModeId(AMode: TToolInputMode): string;
begin
  Result := ToolInputModeIds[AMode];
end;

function ToolOutputModeId(AMode: TToolOutputMode): string;
begin
  Result := ToolOutputModeIds[AMode];
end;

function ToolSaveModeId(AMode: TToolSaveMode): string;
begin
  Result := ToolSaveModeIds[AMode];
end;

function TryParseToolInputMode(const AValue: string; out AMode: TToolInputMode): Boolean;
var
  M: TToolInputMode;
begin
  for M := Low(TToolInputMode) to High(TToolInputMode) do
    if SameText(Trim(AValue), ToolInputModeIds[M]) then
    begin
      AMode := M;
      Exit(True);
    end;
  AMode := timNone;
  Result := False;
end;

function TryParseToolOutputMode(const AValue: string; out AMode: TToolOutputMode): Boolean;
var
  M: TToolOutputMode;
begin
  for M := Low(TToolOutputMode) to High(TToolOutputMode) do
    if SameText(Trim(AValue), ToolOutputModeIds[M]) then
    begin
      AMode := M;
      Exit(True);
    end;
  AMode := tomNone;
  Result := False;
end;

function TryParseToolSaveMode(const AValue: string; out AMode: TToolSaveMode): Boolean;
var
  M: TToolSaveMode;
begin
  for M := Low(TToolSaveMode) to High(TToolSaveMode) do
    if SameText(Trim(AValue), ToolSaveModeIds[M]) then
    begin
      AMode := M;
      Exit(True);
    end;
  AMode := tsmNone;
  Result := False;
end;

constructor TExternalTool.Create;
begin
  inherited Create;
  FArguments := TStringList.Create;
  Id := NewToolId;
  Name := '';
  Command := '';
  WorkingDir := '';
  InputMode := timSelection;
  OutputMode := tomReplaceSelection;
  SaveMode := tsmNone;
  TimeoutMs := DefaultTimeoutMs;
  Enabled := True;
end;

destructor TExternalTool.Destroy;
begin
  FArguments.Free;
  inherited;
end;

procedure TExternalTool.Assign(ASource: TExternalTool);
begin
  if ASource = nil then Exit;
  Id := ASource.Id;
  Name := ASource.Name;
  Command := ASource.Command;
  WorkingDir := ASource.WorkingDir;
  InputMode := ASource.InputMode;
  OutputMode := ASource.OutputMode;
  SaveMode := ASource.SaveMode;
  TimeoutMs := ASource.TimeoutMs;
  Enabled := ASource.Enabled;
  FArguments.Assign(ASource.FArguments);
end;

procedure TExternalTool.SetArgumentText(const AValue: string);
begin
  FArguments.Text := AValue;
end;

function TExternalTool.ArgumentText: string;
begin
  Result := FArguments.Text;
end;

function TExternalTool.HasPlaceholder(const AName: string): Boolean;
var
  i: Integer;
begin
  Result := Pos(AName, Command) > 0;
  if Result then Exit;
  Result := Pos(AName, WorkingDir) > 0;
  if Result then Exit;
  for i := 0 to FArguments.Count - 1 do
    if Pos(AName, FArguments[i]) > 0 then
      Exit(True);
end;

function ValidateTool(ATool: TExternalTool; out AError: string): Boolean;
begin
  Result := False;
  AError := '';
  if ATool = nil then
  begin
    AError := 'Tool is missing';
    Exit;
  end;
  if Trim(ATool.Name) = '' then
  begin
    AError := 'Tool name is required';
    Exit;
  end;
  if Trim(ATool.Command) = '' then
  begin
    AError := 'Tool command is required';
    Exit;
  end;
  Result := True;
end;

constructor TToolStore.Create(const AConfigDir: string);
begin
  inherited Create;
  FFileName := IncludeTrailingPathDelimiter(AConfigDir) + 'tools.json';
  FTools := TList.Create;
  FErrors := TStringList.Create;
  FErrors.CaseSensitive := False;
end;

destructor TToolStore.Destroy;
var
  i: Integer;
begin
  for i := 0 to FTools.Count - 1 do
    TExternalTool(FTools[i]).Free;
  FTools.Free;
  FErrors.Free;
  inherited;
end;

function TToolStore.GetTool(AIndex: Integer): TExternalTool;
begin
  if (AIndex >= 0) and (AIndex < FTools.Count) then
    Result := TExternalTool(FTools[AIndex])
  else
    Result := nil;
end;

function TToolStore.GetCount: Integer;
begin
  Result := FTools.Count;
end;

function TToolStore.IndexOf(ATool: TExternalTool): Integer;
begin
  Result := FTools.IndexOf(ATool);
end;

function TToolStore.FindById(const AId: string): TExternalTool;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FTools.Count - 1 do
    if SameText(TExternalTool(FTools[i]).Id, AId) then
      Exit(TExternalTool(FTools[i]));
end;

procedure TToolStore.Load;
var
  Text: string;
  Data: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  Item: TJSONObject;
  Tool: TExternalTool;
  i, j: Integer;
  ArgArr: TJSONArray;
  ModeValue: TToolInputMode;
  OutValue: TToolOutputMode;
  SaveValue: TToolSaveMode;
  Timeout: Integer;
  Id: string;

  procedure AddError(const AMessage: string);
  begin
    FErrors.Add(AMessage);
  end;

  procedure SkipTool(const AMessage: string);
  begin
    AddError(AMessage);
    Tool.Free;
    Tool := nil;
  end;

begin
  for i := 0 to FTools.Count - 1 do
    TExternalTool(FTools[i]).Free;
  FTools.Clear;
  FErrors.Clear;

  if not FileExists(FFileName) then Exit;
  if not ReadTextFileSafe(FFileName, Text) then
  begin
    AddError('Cannot read ' + FFileName);
    Exit;
  end;
  if Trim(Text) = '' then Exit;
  try
    try
      Data := GetJSON(Text);
    except
      on E: Exception do
      begin
        AddError('Cannot parse tools.json: ' + E.Message);
        Exit;
      end;
    end;
    try
      if not (Data is TJSONObject) then
      begin
        AddError('tools.json must contain a JSON object');
        Exit;
      end;
      Obj := TJSONObject(Data);
      if not (Obj.Find('tools') is TJSONArray) then
      begin
        AddError('tools.json has no tools array');
        Exit;
      end;
      Arr := TJSONArray(Obj.Find('tools'));
      for i := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[i] is TJSONObject) then
        begin
          AddError(Format('Tool entry %d is not an object', [i + 1]));
          Continue;
        end;
        Item := TJSONObject(Arr.Items[i]);
        Tool := TExternalTool.Create;
        Tool.Name := Trim(JsonStr(Item, 'name', ''));
        Tool.Command := Trim(JsonStr(Item, 'command', ''));
        Tool.WorkingDir := JsonStr(Item, 'working_dir', '');
        Tool.Enabled := JsonBool(Item, 'enabled', True);

        Id := Trim(JsonStr(Item, 'id', ''));
        if Id <> '' then Tool.Id := Id;

        if (Tool.Name = '') or (Tool.Command = '') then
        begin
          SkipTool(Format('Tool entry %d is missing a name or command', [i + 1]));
          Continue;
        end;

        if not TryParseToolInputMode(JsonStr(Item, 'input', 'none'), ModeValue) then
        begin
          SkipTool(Format('Tool "%s" has an unknown input mode', [Tool.Name]));
          Continue;
        end;
        Tool.InputMode := ModeValue;

        if not TryParseToolOutputMode(JsonStr(Item, 'output', 'none'), OutValue) then
        begin
          SkipTool(Format('Tool "%s" has an unknown output mode', [Tool.Name]));
          Continue;
        end;
        Tool.OutputMode := OutValue;

        if not TryParseToolSaveMode(JsonStr(Item, 'save', 'none'), SaveValue) then
        begin
          SkipTool(Format('Tool "%s" has an unknown save mode', [Tool.Name]));
          Continue;
        end;
        Tool.SaveMode := SaveValue;

        Timeout := JsonInt(Item, 'timeout_ms', DefaultTimeoutMs);
        if Timeout < MinTimeoutMs then Timeout := MinTimeoutMs;
        if Timeout > MaxTimeoutMs then Timeout := MaxTimeoutMs;
        Tool.TimeoutMs := Timeout;

        if Item.Find('args') is TJSONArray then
        begin
          ArgArr := TJSONArray(Item.Find('args'));
          for j := 0 to ArgArr.Count - 1 do
            if ArgArr.Items[j].JSONType = jtString then
              Tool.Arguments.Add(ArgArr.Items[j].AsString);
        end
        else
          Tool.SetArgumentText(JsonStr(Item, 'argument_text', ''));

        { Duplicate ids would make the menu ambiguous; give the later entry a
          fresh id instead of dropping it. }
        for j := 0 to FTools.Count - 1 do
          if SameText(TExternalTool(FTools[j]).Id, Tool.Id) then
          begin
            Tool.Id := NewToolId;
            Break;
          end;

        FTools.Add(Tool);
        Tool := nil;
      end;
    finally
      Data.Free;
    end;
  except
    on E: Exception do
      AddError('Cannot read tools.json: ' + E.Message);
  end;
end;

function TToolStore.Save(out AError: string): Boolean;
var
  Obj, Item: TJSONObject;
  Arr, Args: TJSONArray;
  i, j: Integer;
  Tool: TExternalTool;
  Text: string;
begin
  Result := False;
  AError := '';
  Obj := TJSONObject.Create;
  try
    Obj.Add('schema', 1);
    Arr := TJSONArray.Create;
    Obj.Add('tools', Arr);
    for i := 0 to FTools.Count - 1 do
    begin
      Tool := TExternalTool(FTools[i]);
      Item := TJSONObject.Create;
      Item.Add('id', Tool.Id);
      Item.Add('name', Tool.Name);
      Item.Add('command', Tool.Command);
      Args := TJSONArray.Create;
      for j := 0 to Tool.FArguments.Count - 1 do
        Args.Add(Tool.FArguments[j]);
      Item.Add('args', Args);
      Item.Add('working_dir', Tool.WorkingDir);
      Item.Add('input', ToolInputModeId(Tool.InputMode));
      Item.Add('output', ToolOutputModeId(Tool.OutputMode));
      Item.Add('save', ToolSaveModeId(Tool.SaveMode));
      Item.Add('timeout_ms', Tool.TimeoutMs);
      Item.Add('enabled', Tool.Enabled);
      Arr.Add(Item);
    end;
    Text := Obj.FormatJSON;
  finally
    Obj.Free;
  end;
  try
    AtomicWriteString(FFileName, Text);
    Result := True;
  except
    on E: Exception do
      AError := E.Message;
  end;
end;

function TToolStore.Add: TExternalTool;
begin
  Result := TExternalTool.Create;
  Result.Name := 'New Tool';
  FTools.Add(Result);
end;

procedure TToolStore.Remove(ATool: TExternalTool);
begin
  if ATool = nil then Exit;
  FTools.Remove(ATool);
  ATool.Free;
end;

function TToolStore.MoveUp(ATool: TExternalTool): Boolean;
var
  Index: Integer;
begin
  Index := FTools.IndexOf(ATool);
  Result := Index > 0;
  if Result then
  begin
    FTools.Exchange(Index, Index - 1);
  end;
end;

function TToolStore.MoveDown(ATool: TExternalTool): Boolean;
var
  Index: Integer;
begin
  Index := FTools.IndexOf(ATool);
  Result := (Index >= 0) and (Index < FTools.Count - 1);
  if Result then
    FTools.Exchange(Index, Index + 1);
end;

function ToolInputText(ATool: TExternalTool; const AContext: TToolContext): string;
begin
  if ATool = nil then
    Exit('');
  case ATool.InputMode of
    timSelection: Result := AContext.SelectionText;
    timDocument: Result := AContext.DocumentText;
  else
    Result := '';
  end;
end;

function ExpandToolText(const AValue: string; ATool: TExternalTool;
  const AContext: TToolContext; const AInputFile: string): string;
var
  FileName, Dir: string;
begin
  Result := AValue;
  Result := StringReplace(Result, '${file}', AContext.FileName, [rfReplaceAll]);
  FileName := ExtractFileName(AContext.FileName);
  Result := StringReplace(Result, '${filename}', FileName, [rfReplaceAll]);
  Dir := ExtractFileDir(AContext.FileName);
  Result := StringReplace(Result, '${dir}', Dir, [rfReplaceAll]);
  Result := StringReplace(Result, '${line}', IntToStr(AContext.Line), [rfReplaceAll]);
  Result := StringReplace(Result, '${col}', IntToStr(AContext.Col), [rfReplaceAll]);
  Result := StringReplace(Result, '${lexer}', AContext.Lexer, [rfReplaceAll]);
  Result := StringReplace(Result, '${encoding}', AContext.Encoding, [rfReplaceAll]);
  Result := StringReplace(Result, '${eol}', AContext.Eol, [rfReplaceAll]);
  Result := StringReplace(Result, '${inputfile}', AInputFile, [rfReplaceAll]);
  if ATool <> nil then
    Result := StringReplace(Result, '${/}', PathDelim, [rfReplaceAll]);
end;

function ReadAvailable(AStream: TInputPipeStream): string;
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

function TempInputFileName: string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tyeditor-tool-' +
    IntToStr(GetProcessID) + '-' + Copy(GUIDToString(Guid), 2, 36) + '.txt';
end;

type
  { Writes stdin from a separate thread so a tool that produces output before
    consuming all input cannot deadlock the runner. }
  TToolStdinWriter = class(TThread)
  private
    FProcess: TProcess;
    FData: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AProcess: TProcess; const AData: string);
  end;

constructor TToolStdinWriter.Create(AProcess: TProcess; const AData: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FProcess := AProcess;
  FData := AData;
end;

procedure TToolStdinWriter.Execute;
begin
  try
    try
      if Length(FData) > 0 then
        FProcess.Input.WriteBuffer(FData[1], Length(FData));
    except
      { The tool may exit without reading stdin, or be terminated on timeout. }
    end;
    try
      FProcess.CloseInput;
    except
      // The pipe may already be closed.
    end;
  finally
    FData := '';
  end;
end;

function ExecuteTool(ATool: TExternalTool; const AContext: TToolContext;
  AState: TToolRunState; out AOutput, AErrOutput: string;
  out AExitCode: Integer; out AError: string; out ATimedOut: Boolean): Boolean;
var
  Proc: TProcess;
  Writer: TToolStdinWriter;
  InputText, OutText, ErrText, Chunk, InputFile, Command, WorkDir: string;
  ArgText: string;
  i: Integer;
  StartTick: QWord;
  NeedInputFile: Boolean;

  function Cancelled: Boolean;
  begin
    Result := (AState <> nil) and AState.Cancelled;
  end;

  function AppendStderr(const AMessage: string): string;
  var
    Tail: string;
  begin
    Result := AMessage;
    Tail := Trim(ErrText);
    if Tail <> '' then
      Result := Result + ': ' + Copy(Tail, 1, 2000);
  end;

begin
  Result := False;
  AOutput := '';
  AErrOutput := '';
  AExitCode := -1;
  AError := '';
  ATimedOut := False;
  InputFile := '';
  Proc := nil;
  Writer := nil;
  if ATool = nil then
  begin
    AError := 'Tool is missing';
    Exit;
  end;
  if Trim(ATool.Command) = '' then
  begin
    AError := 'Tool command is empty';
    Exit;
  end;
  if Cancelled then
  begin
    AError := 'Tool cancelled';
    Exit;
  end;
  if (ATool.InputMode = timSelection) and (AContext.SelectionText = '') then
  begin
    AError := 'No text is selected';
    Exit;
  end;

  InputText := ToolInputText(ATool, AContext);
  NeedInputFile := ATool.HasPlaceholder('${inputfile}');
  if NeedInputFile then
  begin
    InputFile := TempInputFileName;
    try
      AtomicWriteString(InputFile, InputText);
    except
      on E: Exception do
      begin
        InputFile := '';
        AError := 'Cannot create tool input file: ' + E.Message;
        Exit;
      end;
    end;
  end;

  try
    try
      WorkDir := Trim(ExpandToolText(ATool.WorkingDir, ATool, AContext, InputFile));
      if WorkDir = '' then
        WorkDir := ExtractFileDir(AContext.FileName);
      if (WorkDir <> '') and (not DirectoryExists(WorkDir)) then
      begin
        AError := 'Tool working directory not found: ' + WorkDir;
        Exit;
      end;

      Command := Trim(ExpandToolText(ATool.Command, ATool, AContext, InputFile));
      if Command = '' then
      begin
        AError := 'Tool command is empty';
        Exit;
      end;
      if (ExtractFilePath(Command) <> '') and (not FilenameIsAbsolute(Command)) then
      begin
        if WorkDir <> '' then
          Command := IncludeTrailingPathDelimiter(WorkDir) + Command
        else
          Command := ExpandFileName(Command);
      end;

      Proc := TProcess.Create(nil);
      Proc.Executable := Command;
      if WorkDir <> '' then
        Proc.CurrentDirectory := WorkDir;
      for i := 0 to ATool.Arguments.Count - 1 do
      begin
        ArgText := Trim(ATool.Arguments[i]);
        if ArgText = '' then Continue;
        Proc.Parameters.Add(ExpandToolText(ArgText, ATool, AContext, InputFile));
      end;
      Proc.Options := [poUsePipes];
      try
        Proc.Execute;
      except
        on E: Exception do
        begin
          AError := 'Cannot start tool: ' + E.Message;
          Exit;
        end;
      end;

      if (ATool.InputMode <> timNone) and (not NeedInputFile) and (InputText <> '') then
      begin
        Writer := TToolStdinWriter.Create(Proc, InputText);
        Writer.Start;
      end
      else
      begin
        try
          Proc.CloseInput;
        except
          // Closing an already closed pipe is harmless.
        end;
      end;

      OutText := '';
      ErrText := '';
      StartTick := GetTickCount64;
      while Proc.Running do
      begin
        Chunk := ReadAvailable(Proc.Output);
        if Chunk <> '' then OutText := OutText + Chunk;
        Chunk := ReadAvailable(Proc.Stderr);
        if Chunk <> '' then ErrText := ErrText + Chunk;
        if Cancelled then
        begin
          Proc.Terminate(124);
          Break;
        end;
        if GetTickCount64 - StartTick > QWord(ATool.TimeoutMs) then
        begin
          ATimedOut := True;
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

      AOutput := OutText;
      AErrOutput := ErrText;
      if Cancelled then
      begin
        AError := 'Tool cancelled';
        Exit;
      end;
      if ATimedOut then
      begin
        AError := AppendStderr(Format('Tool timed out after %d ms', [ATool.TimeoutMs]));
        Exit;
      end;

      AExitCode := Proc.ExitCode;
      if AExitCode <> 0 then
      begin
        AError := AppendStderr(Format('Tool exited with code %d', [AExitCode]));
        Exit;
      end;
      Result := True;
    finally
      if Writer <> nil then
      begin
        if not Writer.Finished then
        begin
          if Proc.Running then
            Proc.Terminate(124);
          Writer.WaitFor;
        end;
        Writer.Free;
        Writer := nil;
      end;
      Proc.Free;
    end;
  finally
    if (InputFile <> '') and FileExists(InputFile) then
      DeleteFile(InputFile);
  end;
end;

end.
