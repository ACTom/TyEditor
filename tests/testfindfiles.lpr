program testfindfiles;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, SysUtils, ufindfiles;
type
  THit = class
    Count: Integer;
    procedure Found(const AFileName: string; ALine, ACol: Integer; const AText: string);
  end;
procedure THit.Found(const AFileName: string; ALine, ACol: Integer; const AText: string);
begin
  Inc(Count);
end;
var
  Opt: TFindFileOptions;
  Job: TFindFileJob;
  N, Files, Scanned: Integer;
  Err, FileName, AText: string;
  Line, Col: Integer;
  Done, Cancelled: Boolean;
  H: THit;
begin
  Opt.Directory := ParamStr(1);
  Opt.Mask := ParamStr(2);
  Opt.FindText := ParamStr(3);
  if ParamCount >= 4 then
  begin
    Opt.ReplaceText := ParamStr(4);
    Opt.DoReplace := True;
  end
  else
    Opt.ReplaceText := '';
  Opt.CaseSensitive := False;
  Opt.WholeWord := False;
  Opt.Regex := False;
  Opt.IncludeSubdirs := True;
  Opt.ExcludeDirs := '';
  H := THit.Create;
  Job := TFindFileJob.Create(Opt);
  try
    repeat
      while Job.TakeHit(FileName, Line, Col, AText) do
        H.Found(FileName, Line, Col, AText);
      Job.Snapshot(N, Files, Scanned, Done, Cancelled, Err);
      if not Done then
        Sleep(10);
    until Done;
    while Job.TakeHit(FileName, Line, Col, AText) do
      H.Found(FileName, Line, Col, AText);
    if (Err <> '') or Cancelled then
      WriteLn('ERROR ', Err)
    else
      WriteLn(Format('RESULT %d matches in %d files', [N, Files]));
  finally
    Job.Free;
    H.Free;
  end;
end.
