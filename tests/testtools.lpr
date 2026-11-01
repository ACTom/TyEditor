program testtools;
{$mode objfpc}{$H+}

{ Automated tests for the external-tools core.  The test executable doubles as
  the tool under test: --echo, --catfile, --fail and --sleep implement small
  deterministic commands, so no external program is required. }

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, DateUtils, FileUtil, utools, uutils;

function Check(ACond: Boolean; const AMessage: string): Boolean;
begin
  Result := ACond;
  if not Result then
    WriteLn('FAIL: ', AMessage);
end;

procedure CopyStream(AInput, AOutput: TStream);
var
  Buffer: array[0..8191] of Byte;
  N: LongInt;
begin
  while True do
  begin
    N := AInput.Read(Buffer, SizeOf(Buffer));
    if N <= 0 then Break;
    AOutput.WriteBuffer(Buffer, N);
  end;
end;

procedure WriteStdErr(const AText: string);
var
  Stream: THandleStream;
  Data: RawByteString;
begin
  Data := AText;
  Stream := THandleStream.Create(StdErrorHandle);
  try
    if Data <> '' then
      Stream.WriteBuffer(Data[1], Length(Data));
  finally
    Stream.Free;
  end;
end;

procedure HandleSelfMode;
var
  InStream, OutStream: THandleStream;
  Text: string;
begin
  if ParamStr(1) = '--echo' then
  begin
    InStream := THandleStream.Create(StdInputHandle);
    OutStream := THandleStream.Create(StdOutputHandle);
    try
      CopyStream(InStream, OutStream);
    finally
      OutStream.Free;
      InStream.Free;
    end;
    Halt(0);
  end;

  if ParamStr(1) = '--catfile' then
  begin
    if not ReadTextFileSafe(ParamStr(2), Text) then
    begin
      WriteStdErr('cannot read ' + ParamStr(2));
      Halt(4);
    end;
    OutStream := THandleStream.Create(StdOutputHandle);
    try
      if Text <> '' then
        OutStream.WriteBuffer(Text[1], Length(Text));
    finally
      OutStream.Free;
    end;
    Halt(0);
  end;

  if ParamStr(1) = '--fail' then
  begin
    WriteStdErr('boom');
    Halt(3);
  end;

  if ParamStr(1) = '--sleep' then
  begin
    Sleep(StrToIntDef(ParamStr(2), 1000));
    Halt(0);
  end;
end;

type
  TCancelThread = class(TThread)
  private
    FState: TToolRunState;
  protected
    procedure Execute; override;
  public
    constructor Create(AState: TToolRunState);
  end;

constructor TCancelThread.Create(AState: TToolRunState);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FState := AState;
end;

procedure TCancelThread.Execute;
begin
  Sleep(300);
  FState.Cancelled := True;
end;

function SelfExe: string;
begin
  Result := ExpandFileName(ParamStr(0));
end;

function NewContext(const AText: string): TToolContext;
begin
  Result.FileName := '';
  Result.Lexer := '';
  Result.Encoding := '';
  Result.Eol := '';
  Result.Line := 1;
  Result.Col := 1;
  Result.SelectionText := '';
  Result.DocumentText := AText;
end;

var
  Tool: TExternalTool;
  Store: TToolStore;
  Context: TToolContext;
  State: TToolRunState;
  CancelThread: TCancelThread;
  Output, ErrOutput, ErrorText, ConfigDir, Expected, Written, InputFile: string;
  ExitCode: Integer;
  TimedOut, Saved: Boolean;
  StartTick: QWord;
begin
  HandleSelfMode;

  Tool := TExternalTool.Create;
  try
    { Placeholder expansion. }
    Context := NewContext('');
    Context.FileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
      'placeholder-file.txt';
    InputFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
      'placeholder-input.txt';
    Context.Line := 12;
    Context.Col := 5;
    Context.Lexer := 'C++';
    Context.Encoding := 'UTF-8';
    Context.Eol := 'LF';
    Expected := Context.FileName + '|' + ExtractFileName(Context.FileName) + '|' +
      ExtractFileDir(Context.FileName) + '|12|5|C++|UTF-8|LF|' + InputFile;
    Written := ExpandToolText(
      '${file}|${filename}|${dir}|${line}|${col}|${lexer}|${encoding}|${eol}|${inputfile}',
      Tool, Context, InputFile);
    if not Check(Written = Expected, 'placeholder expansion: ' + Written) then Halt(1);
  finally
    Tool.Free;
  end;

  ConfigDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'tyeditor-tools-test-' + IntToStr(GetProcessID);
  if DirectoryExists(ConfigDir) then
    DeleteDirectory(ConfigDir, False, True);
  ForceDirectories(ConfigDir);

  { Configuration round trip. }
  Store := TToolStore.Create(ConfigDir);
  try
    Tool := Store.Add;
    Tool.Name := 'Echo Test';
    Tool.Command := SelfExe;
    Tool.Arguments.Add('--echo');
    Tool.InputMode := timDocument;
    Tool.OutputMode := tomReplaceDocument;
    Tool.SaveMode := tsmCurrent;
    Tool.TimeoutMs := 4321;
    Tool.Enabled := False;
    Saved := Store.Save(ErrorText);
    if not Check(Saved, 'save tools: ' + ErrorText) then Halt(2);
  finally
    Store.Free;
  end;

  Store := TToolStore.Create(ConfigDir);
  try
    Store.Load;
    if not Check(Store.Count = 1, 'tool count after load') then Halt(3);
    if not Check(Store.Errors.Count = 0, 'load errors: ' + Store.Errors.Text) then Halt(4);
    Tool := Store[0];
    if not Check(Tool.Name = 'Echo Test', 'tool name after load') then Halt(5);
    if not Check(Tool.Arguments.Count = 1, 'argument count after load') then Halt(6);
    if not Check(Tool.Arguments[0] = '--echo', 'argument after load') then Halt(7);
    if not Check(Tool.InputMode = timDocument, 'input mode after load') then Halt(8);
    if not Check(Tool.OutputMode = tomReplaceDocument, 'output mode after load') then Halt(9);
    if not Check(Tool.SaveMode = tsmCurrent, 'save mode after load') then Halt(10);
    if not Check(Tool.TimeoutMs = 4321, 'timeout after load') then Halt(11);
    if not Check(not Tool.Enabled, 'enabled state after load') then Halt(12);

    { stdin to stdout. }
    Context := NewContext('hello world' + LineEnding);
    State := TToolRunState.Create;
    try
      Tool.InputMode := timDocument;
      Tool.TimeoutMs := 5000;
      if not ExecuteTool(Tool, Context, State, Output, ErrOutput, ExitCode,
        ErrorText, TimedOut) then
      begin
        WriteLn('echo tool error: ', ErrorText);
        Halt(13);
      end;
      if not Check(Output = Context.DocumentText, 'echo output: ' + Output) then Halt(14);
      if not Check(ExitCode = 0, 'echo exit code') then Halt(15);
    finally
      State.Free;
    end;

    { A large stdin payload must not deadlock against stdout. }
    Context := NewContext(StringOfChar('x', 200000));
    State := TToolRunState.Create;
    try
      Tool.InputMode := timDocument;
      Tool.TimeoutMs := 10000;
      if not Check(ExecuteTool(Tool, Context, State, Output, ErrOutput, ExitCode,
        ErrorText, TimedOut), 'large input: ' + ErrorText) then Halt(34);
      if not Check(Length(Output) = 200000, 'large output length: ' + IntToStr(Length(Output))) then Halt(35);
    finally
      State.Free;
    end;

    { A selection tool must refuse to run without a selection. }
    Context := NewContext('document');
    Context.SelectionText := '';
    State := TToolRunState.Create;
    try
      Tool.InputMode := timSelection;
      if not Check(not ExecuteTool(Tool, Context, State, Output, ErrOutput, ExitCode,
        ErrorText, TimedOut), 'empty selection accepted') then Halt(16);
      if not Check(Pos('no text is selected', LowerCase(ErrorText)) > 0,
        'selection error: ' + ErrorText) then Halt(17);
    finally
      State.Free;
    end;

    { Non-zero exit code and stderr are reported. }
    Tool.Arguments.Clear;
    Tool.Arguments.Add('--fail');
    Tool.InputMode := timNone;
    Context := NewContext('');
    State := TToolRunState.Create;
    try
      if not Check(not ExecuteTool(Tool, Context, State, Output, ErrOutput, ExitCode,
        ErrorText, TimedOut), 'failing tool succeeded') then Halt(18);
      if not Check(ExitCode = 3, 'failed exit code: ' + IntToStr(ExitCode)) then Halt(19);
      if not Check(Pos('code 3', ErrorText) > 0, 'exit error text: ' + ErrorText) then Halt(20);
      if not Check(Pos('boom', ErrOutput) > 0, 'stderr not captured: ' + ErrOutput) then Halt(21);
    finally
      State.Free;
    end;

    { Timeout. }
    Tool.Arguments.Clear;
    Tool.Arguments.Add('--sleep');
    Tool.Arguments.Add('2000');
    Tool.TimeoutMs := 500;
    Context := NewContext('');
    State := TToolRunState.Create;
    try
      StartTick := GetTickCount64;
      if not Check(not ExecuteTool(Tool, Context, State, Output, ErrOutput, ExitCode,
        ErrorText, TimedOut), 'slow tool succeeded') then Halt(22);
      if not Check(TimedOut, 'timeout flag missing') then Halt(23);
      if not Check(Pos('timed out', LowerCase(ErrorText)) > 0,
        'timeout error: ' + ErrorText) then Halt(24);
      if not Check(GetTickCount64 - StartTick >= 400, 'timeout too fast') then Halt(25);
    finally
      State.Free;
    end;

    { Cancellation. }
    Tool.TimeoutMs := 10000;
    State := TToolRunState.Create;
    CancelThread := TCancelThread.Create(State);
    try
      StartTick := GetTickCount64;
      CancelThread.Start;
      if not Check(not ExecuteTool(Tool, Context, State, Output, ErrOutput, ExitCode,
        ErrorText, TimedOut), 'cancelled tool succeeded') then Halt(26);
      if not Check(Pos('cancelled', LowerCase(ErrorText)) > 0,
        'cancel error: ' + ErrorText) then Halt(27);
      if not Check(GetTickCount64 - StartTick < 1600, 'cancellation too slow') then Halt(28);
    finally
      if not CancelThread.Finished then CancelThread.WaitFor;
      CancelThread.Free;
      State.Free;
    end;

    { The inputfile placeholder is materialised as a temporary file. }
    Tool.Arguments.Clear;
    Tool.Arguments.Add('--catfile');
    Tool.Arguments.Add('${inputfile}');
    Tool.InputMode := timDocument;
    Tool.TimeoutMs := 5000;
    Context := NewContext('file payload');
    State := TToolRunState.Create;
    try
      if not Check(ExecuteTool(Tool, Context, State, Output, ErrOutput, ExitCode,
        ErrorText, TimedOut), 'inputfile tool: ' + ErrorText) then Halt(29);
      if not Check(Output = 'file payload', 'inputfile output: ' + Output) then Halt(30);
    finally
      State.Free;
    end;

    { Unknown or incomplete entries are skipped and reported. }
    AtomicWriteString(Store.FileName,
      '{"schema":1,"tools":[' +
      '{"name":"Good","command":"echo","input":"none","output":"none"},' +
      '{"name":"Broken"}]}');
    Store.Load;
    if not Check(Store.Count = 1, 'invalid entries not skipped') then Halt(31);
    if not Check(Store.Errors.Count = 1, 'invalid entry not reported') then Halt(32);
    if not Check(Store[0].Name = 'Good', 'valid entry lost') then Halt(33);
  finally
    Store.Free;
    DeleteDirectory(ConfigDir, False, True);
  end;

  WriteLn('RESULT ok');
end.
