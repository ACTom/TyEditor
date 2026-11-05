unit uplatform;

{$mode objfpc}{$H+}

interface

uses
  Forms, Controls;

procedure SetNativeTopMost(AForm: TCustomForm; AValue: Boolean);

{ Wayland has no client-side always-on-top request. Worse, LCL clears and
  restores fsStayOnTop around every modal dialog (Application.ModalStarted /
  Application.ModalFinished), and the Qt widgetset implements that with
  setWindowFlags, which destroys and recreates the native xdg_toplevel. The
  compositor then re-places the new window (KWin centers it), so the window
  visibly disappears and comes back somewhere else. Treat always-on-top as
  unsupported there instead of moving the window around. }
function AlwaysOnTopSupported: Boolean;

{ Applies "always on top" to AForm, using fsStayOnTop only where it is safe and
  supported. On Wayland this clears the style and does nothing else. }
procedure ApplyFormStayOnTop(AForm: TCustomForm; AValue: Boolean);

implementation

{$IFDEF WINDOWS}
uses
  Windows;
{$ELSE}
  {$IFDEF LCLQt6}
uses
  qtint;
  {$ELSE}
    {$IFDEF LCLQt5}
uses
  qtint;
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

{$IFDEF WINDOWS}
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

function AlwaysOnTopSupported: Boolean;
begin
  {$IF DEFINED(LCLQt6) OR DEFINED(LCLQt5)}
  Result := not IsWayland;
  {$ELSE}
  Result := True;
  {$ENDIF}
end;

procedure ApplyFormStayOnTop(AForm: TCustomForm; AValue: Boolean);
var
  UseTopMost: Boolean;
begin
  if AForm = nil then Exit;
  UseTopMost := AValue and AlwaysOnTopSupported;
  if UseTopMost then
  begin
    if AForm.FormStyle <> fsStayOnTop then
      AForm.FormStyle := fsStayOnTop;
  end
  else if AForm.FormStyle = fsStayOnTop then
    AForm.FormStyle := fsNormal;
  SetNativeTopMost(AForm, UseTopMost);
end;

end.
