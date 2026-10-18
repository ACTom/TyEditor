program testfindasync;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, SysUtils, ufindfiles;

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
    if Err <> '' then WriteLn('job error: ', Err);
  finally
    Job.Free;
  end;
end;

var
  Opt: TFindFileOptions;
  N: Integer;
begin
  Opt.Directory := '/tmp/tysearch';
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
  if N <> 35 then Halt(1);
  Opt.ExcludeDirs := 'sub';
  N := RunJob(Opt, False);
  WriteLn('exclude sub: ', N);
  if N <> 30 then Halt(2);
  Opt.ExcludeDirs := '';
  N := RunJob(Opt, True);
  WriteLn('cancelled: ', N);
  WriteLn('RESULT ok');
end.
