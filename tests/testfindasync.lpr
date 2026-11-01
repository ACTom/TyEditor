program testfindasync;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, SysUtils, Classes, FileUtil, ufindfiles;

function RunJob(const AOptions: TFindFileOptions; ACancel: Boolean): Integer;
var
  Job: TFindFileJob;
  FileName, Text, Err: string;
  Line, Col, Count, Files, Scanned: Integer;
  Done, Cancelled: Boolean;
begin
  Result := 0;
  Job := TFindFileJob.Create(AOptions);
  try
    if ACancel then Job.Cancel;
    repeat
      while Job.TakeHit(FileName, Line, Col, Text) do Inc(Result);
      Job.Snapshot(Count, Files, Scanned, Done, Cancelled, Err);
      if not Done then Sleep(10);
    until Done;
    while Job.TakeHit(FileName, Line, Col, Text) do Inc(Result);
    if Err <> '' then
    begin
      WriteLn('job error: ', Err);
      Result := -1;
    end;
  finally
    Job.Free;
  end;
end;

procedure WriteSample(const ADir, AName: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ADir);
  Lines := TStringList.Create;
  try
    Lines.Text := 'needle' + LineEnding;
    Lines.SaveToFile(IncludeTrailingPathDelimiter(ADir) + AName);
  finally
    Lines.Free;
  end;
end;

var
  Opt: TFindFileOptions;
  BaseDir, SubDir, RootDir: string;
  i, N: Integer;
begin
  BaseDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'tyeditor-findasync-' + FormatDateTime('yyyymmddhhnnsszzz', Now);
  RootDir := IncludeTrailingPathDelimiter(BaseDir) + 'root';
  SubDir := IncludeTrailingPathDelimiter(BaseDir) + 'sub';
  if DirectoryExists(BaseDir) then
    DeleteDirectory(BaseDir, True, True);
  ForceDirectories(RootDir);
  ForceDirectories(SubDir);

  try
    for i := 1 to 35 do
    begin
      if i <= 5 then
        WriteSample(SubDir, 'sample' + IntToStr(i) + '.txt')
      else
        WriteSample(RootDir, 'sample' + IntToStr(i) + '.txt');
    end;

    Opt.Directory := BaseDir;
    Opt.Mask := '*.txt';
    Opt.FindText := 'needle';
    Opt.ReplaceText := '';
    Opt.CaseSensitive := False;
    Opt.WholeWord := False;
    Opt.Regex := False;
    Opt.IncludeSubdirs := True;
    Opt.DoReplace := False;
    Opt.ExcludeDirs := '';

    N := RunJob(Opt, False);
    WriteLn('all: ', N);
    if N <> 35 then
    begin
      ExitCode := 1;
      Exit;
    end;

    Opt.ExcludeDirs := 'sub';
    N := RunJob(Opt, False);
    WriteLn('exclude sub: ', N);
    if N <> 30 then
    begin
      ExitCode := 2;
      Exit;
    end;

    Opt.ExcludeDirs := '';
    N := RunJob(Opt, True);
    WriteLn('cancelled: ', N);
    if N < 0 then
    begin
      ExitCode := 3;
      Exit;
    end;

    WriteLn('RESULT ok');
  finally
    if DirectoryExists(BaseDir) then
      DeleteDirectory(BaseDir, True, True);
  end;
end.
