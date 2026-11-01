unit uwinproc;

{$mode objfpc}{$H+}

interface

function WindowsProcessAlive(APid: Integer): Boolean;

implementation

{$IFDEF WINDOWS}
uses Windows;

function WindowsProcessAlive(APid: Integer): Boolean;
var
  H: THandle;
  Code: DWORD;
begin
  if APid <= 0 then Exit(False);
  H := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, APid);
  if H = 0 then Exit(False);
  try
    Result := GetExitCodeProcess(H, Code) and (Code = STILL_ACTIVE);
  finally
    CloseHandle(H);
  end;
end;
{$ELSE}
function WindowsProcessAlive(APid: Integer): Boolean;
begin
  Result := True;
end;
{$ENDIF}

end.
