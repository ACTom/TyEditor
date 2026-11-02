unit ukeybindings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Menus, LCLType, LCLProc, TypInfo, ucommands, usettings;

type
  TCommandSource = (csBuiltin, csPlugin, csTool);

  TCommandDefault = record
    ID: string;
    Caption: string;
    Group: string;
    Source: TCommandSource;
    ShortCut: TShortCut;
  end;

  TShortcutConflict = record
    ID: string;
    Caption: string;
    Group: string;
    Source: TCommandSource;
  end;

  TShortcutConflictArray = array of TShortcutConflict;

  { Menu items carrying this class participate in the shortcut registry.
    CommandID is the stable identity; Tag remains available for the normal
    menu dispatch and must not be used to identify shortcuts. }
  TCommandMenuItem = class(TMenuItem)
  public
    CommandID: string;
    CommandGroup: string;
    CommandSource: TCommandSource;
    DefaultShortCut: TShortCut;
  end;

  { Shared shortcut registry.  Built-in command IDs keep the historical
    "cmd_<enum>" form so existing settings remain valid.  Plugins and
    external tools use namespaced string IDs. }
  TShortcutManager = class
  private
    FSettings: TAppSettings;
    FDefaults: array of TCommandDefault;
    procedure CaptureItem(AItem: TMenuItem; const AGroup: string);
    procedure ApplyItem(AItem: TMenuItem);
    function FindEntryIndex(const AID: string): Integer;
    function ConflictArrayHasID(const AItems: TShortcutConflictArray;
      const AID: string): Boolean;
    procedure AddConflict(var AItems: TShortcutConflictArray;
      AIndex: Integer);
  public
    constructor Create(ASettings: TAppSettings);
    procedure RegisterCommand(const AID, ACaption, AGroup: string;
      ASource: TCommandSource; ADefault: TShortCut);
    procedure UnregisterSource(ASource: TCommandSource);
    procedure CaptureDefaults(AMenu: TMenuItem; const AGroup: string = '');
    procedure Apply(AMenu: TMenuItem);
    function CommandID(ACommand: TMenuCmd): string;
    function DefaultShortcut(const AID: string): TShortCut; overload;
    function DefaultShortcut(ACommand: TMenuCmd): TShortCut; overload;
    function CurrentShortcut(const AID: string): TShortCut; overload;
    function CurrentShortcut(ACommand: TMenuCmd): TShortCut; overload;
    function HasOverride(const AID: string): Boolean; overload;
    function HasOverride(ACommand: TMenuCmd): Boolean; overload;
    function Conflicts(const AID: string;
      AShortCut: TShortCut): TShortcutConflictArray;
    function ValidateConflicts: TShortcutConflictArray;
    function Conflict(ACommand: TMenuCmd; AShortCut: TShortCut): TMenuCmd;
    procedure SetShortcut(const AID: string; AShortCut: TShortCut); overload;
    procedure SetShortcut(ACommand: TMenuCmd; AShortCut: TShortCut); overload;
    procedure ResetShortcut(const AID: string); overload;
    procedure ResetShortcut(ACommand: TMenuCmd); overload;
    procedure ResetAll;
    property Settings: TAppSettings read FSettings;
  end;

function ShortcutCommandID(ACommand: TMenuCmd): string;
function PluginShortcutID(const APluginID, ACommandID: string): string;
function ToolShortcutID(const AToolID: string): string;
function ShortcutDisplay(AShortCut: TShortCut): string;

implementation

const
  NoShortcutValue = 'none';

function ShortcutCommandID(ACommand: TMenuCmd): string;
begin
  Result := 'cmd_' + GetEnumName(TypeInfo(TMenuCmd), Ord(ACommand));
end;

function PluginShortcutID(const APluginID, ACommandID: string): string;
begin
  Result := 'plugin:' + APluginID + ':' + ACommandID;
end;

function ToolShortcutID(const AToolID: string): string;
begin
  Result := 'tool:' + AToolID;
end;

function ShortcutDisplay(AShortCut: TShortCut): string;
begin
  if AShortCut = 0 then
    Result := ''
  else
    Result := ShortCutToText(AShortCut);
end;

function MenuCaptionText(const ACaption: string): string;
begin
  Result := StringReplace(ACaption, '&', '', [rfReplaceAll]);
end;

constructor TShortcutManager.Create(ASettings: TAppSettings);
begin
  inherited Create;
  FSettings := ASettings;
end;

function TShortcutManager.CommandID(ACommand: TMenuCmd): string;
begin
  Result := ShortcutCommandID(ACommand);
end;

function TShortcutManager.FindEntryIndex(const AID: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FDefaults) do
    if FDefaults[i].ID = AID then
      Exit(i);
  Result := -1;
end;

function TShortcutManager.ConflictArrayHasID(
  const AItems: TShortcutConflictArray; const AID: string): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(AItems) do
    if AItems[i].ID = AID then
      Exit(True);
  Result := False;
end;

procedure TShortcutManager.AddConflict(var AItems: TShortcutConflictArray;
  AIndex: Integer);
var
  N: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FDefaults)) then Exit;
  if ConflictArrayHasID(AItems, FDefaults[AIndex].ID) then Exit;
  N := Length(AItems);
  SetLength(AItems, N + 1);
  AItems[N].ID := FDefaults[AIndex].ID;
  AItems[N].Caption := FDefaults[AIndex].Caption;
  AItems[N].Group := FDefaults[AIndex].Group;
  AItems[N].Source := FDefaults[AIndex].Source;
end;

procedure TShortcutManager.RegisterCommand(const AID, ACaption, AGroup: string;
  ASource: TCommandSource; ADefault: TShortCut);
var
  i: Integer;
begin
  if AID = '' then Exit;
  i := FindEntryIndex(AID);
  if i < 0 then
  begin
    i := Length(FDefaults);
    SetLength(FDefaults, i + 1);
    FDefaults[i].ID := AID;
    FDefaults[i].ShortCut := ADefault;
  end;
  { Metadata can change when a plugin is reloaded or a language changes.
    The original default must never be overwritten by a current ShortCut. }
  FDefaults[i].Caption := ACaption;
  FDefaults[i].Group := AGroup;
  FDefaults[i].Source := ASource;
end;

procedure TShortcutManager.UnregisterSource(ASource: TCommandSource);
var
  i, N: Integer;
begin
  N := 0;
  for i := 0 to High(FDefaults) do
    if FDefaults[i].Source <> ASource then
    begin
      if N <> i then
        FDefaults[N] := FDefaults[i];
      Inc(N);
    end;
  if N <> Length(FDefaults) then
    SetLength(FDefaults, N);
end;

procedure TShortcutManager.CaptureItem(AItem: TMenuItem;
  const AGroup: string);
var
  CmdItem: TCommandMenuItem;
  GroupName: string;
  i: Integer;
begin
  if AItem = nil then Exit;
  if AItem is TCommandMenuItem then
  begin
    CmdItem := TCommandMenuItem(AItem);
    if CmdItem.CommandID <> '' then
    begin
      GroupName := CmdItem.CommandGroup;
      if GroupName = '' then
        GroupName := AGroup;
      RegisterCommand(CmdItem.CommandID, MenuCaptionText(CmdItem.Caption),
        GroupName, CmdItem.CommandSource, CmdItem.DefaultShortCut);
    end;
  end;
  for i := 0 to AItem.Count - 1 do
    CaptureItem(AItem.Items[i], AGroup);
end;

procedure TShortcutManager.CaptureDefaults(AMenu: TMenuItem;
  const AGroup: string);
begin
  if AMenu = nil then Exit;
  CaptureItem(AMenu, AGroup);
end;

procedure TShortcutManager.ApplyItem(AItem: TMenuItem);
var
  CmdItem: TCommandMenuItem;
  i: Integer;
begin
  if AItem = nil then Exit;
  if AItem is TCommandMenuItem then
  begin
    CmdItem := TCommandMenuItem(AItem);
    if CmdItem.CommandID <> '' then
      CmdItem.ShortCut := CurrentShortcut(CmdItem.CommandID);
  end;
  for i := 0 to AItem.Count - 1 do
    ApplyItem(AItem.Items[i]);
end;

procedure TShortcutManager.Apply(AMenu: TMenuItem);
begin
  if AMenu = nil then Exit;
  ApplyItem(AMenu);
end;

function TShortcutManager.DefaultShortcut(const AID: string): TShortCut;
var
  i: Integer;
begin
  i := FindEntryIndex(AID);
  if i >= 0 then
    Result := FDefaults[i].ShortCut
  else
    Result := 0;
end;

function TShortcutManager.DefaultShortcut(ACommand: TMenuCmd): TShortCut;
begin
  Result := DefaultShortcut(ShortcutCommandID(ACommand));
end;

function TShortcutManager.CurrentShortcut(const AID: string): TShortCut;
var
  i: Integer;
begin
  i := FSettings.Shortcuts.IndexOfName(AID);
  if i >= 0 then
  begin
    if FSettings.Shortcuts.ValueFromIndex[i] = NoShortcutValue then
      Result := 0
    else
      Result := TextToShortCut(FSettings.Shortcuts.ValueFromIndex[i]);
  end
  else
    Result := DefaultShortcut(AID);
end;

function TShortcutManager.CurrentShortcut(ACommand: TMenuCmd): TShortCut;
begin
  Result := CurrentShortcut(ShortcutCommandID(ACommand));
end;

function TShortcutManager.HasOverride(const AID: string): Boolean;
begin
  Result := FSettings.Shortcuts.IndexOfName(AID) >= 0;
end;

function TShortcutManager.HasOverride(ACommand: TMenuCmd): Boolean;
begin
  Result := HasOverride(ShortcutCommandID(ACommand));
end;

function TShortcutManager.Conflicts(const AID: string;
  AShortCut: TShortCut): TShortcutConflictArray;
var
  i: Integer;
begin
  Result := nil;
  if AShortCut = 0 then Exit;
  for i := 0 to High(FDefaults) do
  begin
    if FDefaults[i].ID = AID then Continue;
    if CurrentShortcut(FDefaults[i].ID) = AShortCut then
      AddConflict(Result, i);
  end;
end;

function TShortcutManager.ValidateConflicts: TShortcutConflictArray;
var
  i, j: Integer;
begin
  Result := nil;
  for i := 0 to High(FDefaults) do
  begin
    if CurrentShortcut(FDefaults[i].ID) = 0 then Continue;
    for j := i + 1 to High(FDefaults) do
      if CurrentShortcut(FDefaults[j].ID) = CurrentShortcut(FDefaults[i].ID) then
      begin
        AddConflict(Result, i);
        AddConflict(Result, j);
      end;
  end;
end;

function TShortcutManager.Conflict(ACommand: TMenuCmd;
  AShortCut: TShortCut): TMenuCmd;
var
  Items: TShortcutConflictArray;
  i: Integer;
  NamePart: string;
  Value: Integer;
begin
  Result := mcNone;
  Items := Conflicts(ShortcutCommandID(ACommand), AShortCut);
  for i := 0 to High(Items) do
    if Items[i].Source = csBuiltin then
    begin
      NamePart := Copy(Items[i].ID, 5, MaxInt);
      Value := GetEnumValue(TypeInfo(TMenuCmd), NamePart);
      if Value >= 0 then
        Exit(TMenuCmd(Value));
    end;
end;

procedure TShortcutManager.SetShortcut(const AID: string;
  AShortCut: TShortCut);
var
  Index: Integer;
begin
  if AID = '' then Exit;
  if AShortCut = DefaultShortcut(AID) then
  begin
    Index := FSettings.Shortcuts.IndexOfName(AID);
    if Index >= 0 then
      FSettings.Shortcuts.Delete(Index);
  end
  else if AShortCut = 0 then
    FSettings.Shortcuts.Values[AID] := NoShortcutValue
  else
    FSettings.Shortcuts.Values[AID] := ShortCutToText(AShortCut);
end;

procedure TShortcutManager.SetShortcut(ACommand: TMenuCmd;
  AShortCut: TShortCut);
begin
  SetShortcut(ShortcutCommandID(ACommand), AShortCut);
end;

procedure TShortcutManager.ResetShortcut(const AID: string);
var
  Index: Integer;
begin
  Index := FSettings.Shortcuts.IndexOfName(AID);
  if Index >= 0 then
    FSettings.Shortcuts.Delete(Index);
end;

procedure TShortcutManager.ResetShortcut(ACommand: TMenuCmd);
begin
  ResetShortcut(ShortcutCommandID(ACommand));
end;

procedure TShortcutManager.ResetAll;
begin
  FSettings.Shortcuts.Clear;
end;

end.
