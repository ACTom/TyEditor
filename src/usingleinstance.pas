unit usingleinstance;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, uutils, uwinproc
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

function AcquireSingleInstance: Boolean;
procedure ReleaseSingleInstance;
procedure WriteOpenRequest(const AFiles: array of string);
function TakeOpenRequests(out AFiles: TStringList; out AFocus: Boolean): Boolean;

implementation

function InstanceDir: string;
begin
  Result := AppConfigDir + 'instance' + PathDelim;
end;

function LockFile: string;
begin
  Result := InstanceDir + 'lock.txt';
end;

function QueueDir: string;
begin
  Result := InstanceDir + 'queue' + PathDelim;
end;

function ReadLockTime(out ATime: TDateTime): Boolean;
var
  S: TStringList;
  P: Integer;
  Txt: string;
begin
  Result := False;
  ATime := 0;
  if not FileExists(LockFile) then Exit;
  S := TStringList.Create;
  try
    try S.LoadFromFile(LockFile); except Exit; end;
    Txt := S.Text;
    P := Pos(LineEnding, Txt);
    if P > 0 then Txt := Copy(Txt, 1, P - 1);
    ATime := StrToDateTimeDef(Txt, 0);
    Result := ATime > 0;
  finally
    S.Free;
  end;
end;

function ReadLockPid(out APid: Integer): Boolean;
var
  S: TStringList;
begin
  Result := False;
  APid := 0;
  if not FileExists(LockFile) then Exit;
  S := TStringList.Create;
  try
    try S.LoadFromFile(LockFile); except Exit; end;
    if S.Count >= 2 then
      APid := StrToIntDef(Trim(S[1]), 0);
    Result := APid > 0;
  finally
    S.Free;
  end;
end;

function ProcessAlive(APid: Integer): Boolean;
{$IFDEF UNIX}
var
  R: LongInt;
{$ENDIF}
begin
{$IFDEF UNIX}
  if APid <= 0 then Exit(False);
  R := fpKill(APid, 0);
  Result := (R = 0) or (fpGetErrno = ESysEPERM);
{$ELSE}
  Result := WindowsProcessAlive(APid);
{$ENDIF}
end;

function AcquireSingleInstance: Boolean;
var
  S: TStringList;
  T: TDateTime;
  Age: LongInt;
  Pid: Integer;
begin
  EnsureDir(InstanceDir);
  EnsureDir(QueueDir);
  if FileExists(LockFile) then
  begin
    if ReadLockPid(Pid) and ProcessAlive(Pid) then
      Exit(False);
    Age := FileAge(LockFile);
    if (not ReadLockPid(Pid)) and (Age >= 0) and
       (Now - FileDateToDateTime(Age) < 10 / SecsPerDay) then
      Exit(False);
    DeleteFile(LockFile);
  end;
  S := TStringList.Create;
  try
    S.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    S.Add(IntToStr(GetProcessID));
    S.SaveToFile(LockFile);
  finally
    S.Free;
  end;
  Result := True;
end;

procedure ReleaseSingleInstance;
begin
  if FileExists(LockFile) then
    DeleteFile(LockFile);
end;

procedure WriteOpenRequest(const AFiles: array of string);
var
  S: TStringList;
  Name: string;
  i: Integer;
begin
  EnsureDir(QueueDir);
  S := TStringList.Create;
  try
    if Length(AFiles) = 0 then
      S.Add('__focus__')
    else
      for i := 0 to High(AFiles) do
        S.Add(AFiles[i]);
    Name := QueueDir + FormatDateTime('yyyymmdd_hhnnsszzz', Now) + '_' + IntToStr(GetProcessID) + '.req';
    S.SaveToFile(Name);
  finally
    S.Free;
  end;
end;

function TakeOpenRequests(out AFiles: TStringList; out AFocus: Boolean): Boolean;
var
  SR: TSearchRec;
  S: TStringList;
  i: Integer;
begin
  Result := False;
  AFocus := False;
  AFiles := TStringList.Create;
  if not DirectoryExists(QueueDir) then Exit;
  if FindFirst(QueueDir + '*.req', faAnyFile, SR) = 0 then
  begin
    S := TStringList.Create;
    try
      repeat
        if (SR.Attr and faDirectory) <> 0 then Continue;
        S.Clear;
        try
          S.LoadFromFile(QueueDir + SR.Name);
          for i := 0 to S.Count - 1 do
          begin
            if S[i] = '__focus__' then
              AFocus := True
            else if (S[i] <> '') and FileExists(S[i]) then
              AFiles.Add(S[i]);
          end;
        except
        end;
        DeleteFile(QueueDir + SR.Name);
        Result := True;
      until FindNext(SR) <> 0;
    finally
      S.Free;
      FindClose(SR);
    end;
  end;
end;

end.
