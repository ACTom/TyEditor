program testkeys;
{$mode objfpc}{$H+}

uses
  Interfaces, SysUtils, Classes, Menus, LCLProc,
  ucommands, usettings, ukeybindings;

var
  Failures: Integer = 0;

procedure Check(ACond: Boolean; const AMessage: string);
begin
  if not ACond then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure AddCommand(AParent: TMenuItem; AOwner: TComponent;
  ACommand: TMenuCmd; AShortCut: TShortCut);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(AOwner);
  Item.Name := ShortcutCommandID(ACommand);
  Item.Tag := Ord(ACommand);
  Item.ShortCut := AShortCut;
  AParent.Add(Item);
end;

var
  Owner: TComponent;
  Root, Sub: TMenuItem;
  Settings: TAppSettings;
  Manager: TShortcutManager;
  NewItem: TMenuItem;
  Cmd: TMenuCmd;
begin
  Owner := TComponent.Create(nil);
  Settings := TAppSettings.Create;
  Manager := TShortcutManager.Create(Settings);
  try
    Root := TMenuItem.Create(Owner);
    Sub := TMenuItem.Create(Owner);
    Root.Add(Sub);
    AddCommand(Sub, Owner, mcNew, ShortCut(Ord('N'), [ssCtrl]));
    AddCommand(Sub, Owner, mcOpen, ShortCut(Ord('O'), [ssCtrl]));

    Manager.CaptureDefaults(Root);
    Check(Manager.DefaultShortcut(mcNew) = ShortCut(Ord('N'), [ssCtrl]),
      'default New shortcut captured');
    Check(Manager.DefaultShortcut(mcOpen) = ShortCut(Ord('O'), [ssCtrl]),
      'default Open shortcut captured');

    Settings.Shortcuts.Values[ShortcutCommandID(mcNew)] :=
      ShortCutToText(ShortCut(Ord('M'), [ssCtrl, ssShift]));
    Check(Manager.CurrentShortcut(mcNew) = ShortCut(Ord('M'), [ssCtrl, ssShift]),
      'saved override read back');
    Check(Manager.Conflict(mcOpen, ShortCut(Ord('M'), [ssCtrl, ssShift])) = mcNew,
      'conflict detected');

    Manager.SetShortcut(mcOpen, ShortCut(Ord('M'), [ssCtrl, ssShift]));
    Check(Manager.Conflict(mcNew, ShortCut(Ord('M'), [ssCtrl, ssShift])) = mcOpen,
      'second conflict detected');
    Manager.SetShortcut(mcOpen, ShortCut(Ord('O'), [ssCtrl]));
    Check(not Manager.HasOverride(mcOpen), 'setting default removes override');

    Manager.Apply(Root);
    NewItem := Sub.Items[0];
    Check(NewItem.ShortCut = ShortCut(Ord('M'), [ssCtrl, ssShift]),
      'apply writes override to menu item');

    Manager.ResetShortcut(mcNew);
    Manager.Apply(Root);
    Check(NewItem.ShortCut = ShortCut(Ord('N'), [ssCtrl]),
      'reset restores default');

    Manager.SetShortcut(mcNew, 0);
    Check(Manager.CurrentShortcut(mcNew) = 0,
      'empty override clears shortcut');
    Manager.ResetAll;
    Check(Settings.Shortcuts.Count = 0, 'reset all clears overrides');

    Cmd := mcNone;
    Check(Manager.Conflict(mcNew, 0) = Cmd, 'empty shortcut never conflicts');
  finally
    Manager.Free;
    Settings.Free;
    Owner.Free;
  end;

  if Failures = 0 then
    WriteLn('RESULT ok')
  else
    WriteLn('RESULT failures=', Failures);
  if Failures <> 0 then
    Halt(1);
end.
