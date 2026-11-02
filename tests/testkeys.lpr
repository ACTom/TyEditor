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

function AddCommand(AParent: TMenuItem; AOwner: TComponent;
  const AID, ACaption, AGroup: string; ASource: TCommandSource;
  ADefault: TShortCut): TCommandMenuItem;
begin
  Result := TCommandMenuItem.Create(AOwner);
  Result.Caption := ACaption;
  Result.CommandID := AID;
  Result.CommandGroup := AGroup;
  Result.CommandSource := ASource;
  Result.DefaultShortCut := ADefault;
  if ADefault <> 0 then
    Result.ShortCut := ADefault;
  AParent.Add(Result);
end;

function HasConflict(const AItems: TShortcutConflictArray;
  const AID: string): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(AItems) do
    if AItems[i].ID = AID then
      Exit(True);
  Result := False;
end;

var
  Owner: TComponent;
  Root, Sub: TMenuItem;
  NewItem, OpenItem, PluginItem, ToolItem: TCommandMenuItem;
  Settings: TAppSettings;
  Manager: TShortcutManager;
  Conflicts: TShortcutConflictArray;
  NewID, OpenID, PluginID, ToolID: string;
  NewKey, OpenKey, PluginKey, ToolKey: TShortCut;
begin
  Owner := TComponent.Create(nil);
  Settings := TAppSettings.Create;
  Manager := TShortcutManager.Create(Settings);
  try
    NewID := ShortcutCommandID(mcNew);
    OpenID := ShortcutCommandID(mcOpen);
    PluginID := PluginShortcutID('sample.texttools', 'upper');
    ToolID := ToolShortcutID('tool-1234');
    NewKey := ShortCut(Ord('N'), [ssCtrl]);
    OpenKey := ShortCut(Ord('O'), [ssCtrl]);
    PluginKey := ShortCut(Ord('U'), [ssCtrl, ssAlt]);
    ToolKey := ShortCut(Ord('1'), [ssCtrl, ssAlt]);

    Check(NewID = 'cmd_mcNew', 'built-in id is backward compatible');
    Check(PluginID = 'plugin:sample.texttools:upper', 'plugin id namespace');
    Check(ToolID = 'tool:tool-1234', 'tool id namespace');

    Root := TMenuItem.Create(Owner);
    Sub := TMenuItem.Create(Owner);
    Root.Add(Sub);
    NewItem := AddCommand(Sub, Owner, NewID, '&New', '', csBuiltin, NewKey);
    OpenItem := AddCommand(Sub, Owner, OpenID, '&Open', '', csBuiltin, OpenKey);
    PluginItem := AddCommand(Sub, Owner, PluginID, 'Upper', 'Plugins — Demo',
      csPlugin, 0);
    ToolItem := AddCommand(Sub, Owner, ToolID, 'Format', 'Tools — Demo',
      csTool, 0);

    Manager.CaptureDefaults(Root, 'File');
    Check(Manager.DefaultShortcut(NewID) = NewKey, 'default New captured');
    Check(Manager.DefaultShortcut(OpenID) = OpenKey, 'default Open captured');
    Check(Manager.DefaultShortcut(PluginID) = 0, 'plugin has no default');
    Check(Manager.DefaultShortcut(ToolID) = 0, 'tool has no default');

    Settings.Shortcuts.Values[NewID] :=
      ShortCutToText(ShortCut(Ord('M'), [ssCtrl, ssShift]));
    Check(Manager.CurrentShortcut(NewID) = ShortCut(Ord('M'), [ssCtrl, ssShift]),
      'saved override read back');
    Check(not Manager.HasOverride(OpenID), 'Open has no override');

    Manager.SetShortcut(PluginID, PluginKey);
    Manager.SetShortcut(ToolID, ToolKey);
    Check(Manager.CurrentShortcut(PluginID) = PluginKey,
      'plugin override read back');
    Check(Manager.CurrentShortcut(ToolID) = ToolKey,
      'tool override read back');

    Conflicts := Manager.Conflicts(OpenID, PluginKey);
    Check(Length(Conflicts) = 1, 'plugin conflict count');
    Check(HasConflict(Conflicts, PluginID), 'plugin conflict listed');
    Check(Conflicts[0].Group = 'Plugins — Demo', 'plugin group kept');

    Manager.SetShortcut(NewID, OpenKey);
    Manager.SetShortcut(PluginID, OpenKey);
    Manager.SetShortcut(ToolID, OpenKey);
    Conflicts := Manager.Conflicts(NewID, OpenKey);
    Check(Length(Conflicts) = 3, 'all conflicts returned for New');
    Check(HasConflict(Conflicts, OpenID), 'Open conflict listed');
    Check(HasConflict(Conflicts, PluginID), 'plugin conflict listed too');
    Check(HasConflict(Conflicts, ToolID), 'tool conflict listed too');

    Conflicts := Manager.ValidateConflicts;
    Check(Length(Conflicts) = 4, 'all duplicate menu commands reported');

    Manager.SetShortcut(NewID, NewKey);
    Manager.SetShortcut(OpenID, OpenKey);
    Manager.SetShortcut(PluginID, PluginKey);
    Manager.SetShortcut(ToolID, ToolKey);
    Manager.Apply(Root);
    Check(NewItem.ShortCut = NewKey, 'apply restores built-in default');
    Check(OpenItem.ShortCut = OpenKey, 'apply keeps built-in default');
    Check(PluginItem.ShortCut = PluginKey, 'apply writes plugin override');
    Check(ToolItem.ShortCut = ToolKey, 'apply writes tool override');
    Check(NewItem.DefaultShortCut = NewKey, 'default is not overwritten');

    Manager.UnregisterSource(csPlugin);
    Conflicts := Manager.Conflicts(NewID, PluginKey);
    Check(Length(Conflicts) = 0, 'unregistered plugin no longer conflicts');
    Check(Manager.HasOverride(PluginID), 'plugin setting is retained');
    Manager.RegisterCommand(PluginID, 'Upper', 'Plugins — Demo', csPlugin, 0);
    Check(Manager.CurrentShortcut(PluginID) = PluginKey,
      'plugin setting restored after re-register');

    Manager.SetShortcut(NewID, 0);
    Check(Manager.CurrentShortcut(NewID) = 0,
      'empty override clears shortcut');
    Check(Settings.Shortcuts.Values[NewID] = 'none',
      'empty override stored as none');

    Manager.ResetShortcut(NewID);
    Check(Manager.CurrentShortcut(NewID) = NewKey,
      'reset restores default');

    Manager.ResetAll;
    Check(Settings.Shortcuts.Count = 0, 'reset all clears overrides');

    Check(Manager.Conflict(mcNew, 0) = mcNone,
      'empty shortcut never conflicts');

    Manager.SetShortcut(NewID, PluginKey);
    Check(Manager.Conflict(mcNew, PluginKey) = mcNone,
      'plugin-only conflict does not masquerade as a built-in command');
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
