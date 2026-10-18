unit uplatform;

{$mode objfpc}{$H+}

interface

uses
  Forms;

procedure SetNativeTopMost(AForm: TCustomForm; AValue: Boolean);

implementation

{$IFDEF WINDOWS}
uses
  Windows;

procedure SetNativeTopMost(AForm: TCustomForm; AValue: Boolean);
var
  H: HWND;
begin
  if (AForm = nil) or (not AForm.HandleAllocated) then Exit;
  H := AForm.Handle;
  if AValue then
    SetWindowPos(H, HWND_TOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE)
  else
    SetWindowPos(H, HWND_NOTOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;
{$ELSE}
procedure SetNativeTopMost(AForm: TCustomForm; AValue: Boolean);
begin
end;
{$ENDIF}

end.
