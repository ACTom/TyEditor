unit ukeybindings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Menus, LCLType, LCLProc, TypInfo, ucommands, usettings;

type
  TCommandDefault = record
    Command: TMenuCmd;
    ShortCut: TShortCut;
  end;

  { Shared shortcut registry.  Command menu items carry a stable "cmd_<enum>"
    name and their tag holds the TMenuCmd value.  Defaults are captured from
    the freshly built menus, before saved overrides are applied. }
  TShortcutManager = class
  private
    FSettings: TAppSettings;
    FDefaults: array of TCommandDefault;
    procedure CaptureItem(AItem: TMenuItem);
    procedure ApplyItem(AItem: TMenuItem);
    function FindDefaultIndex(ACommand: TMenuCmd): Integer;
  public
    constructor Create(ASettings: TAppSettings);
    procedure CaptureDefaults(AMenu: TMenuItem);
    procedure Apply(AMenu: TMenuItem);
    function CommandID(ACommand: TMenuCmd): string;
    function DefaultShortcut(ACommand: TMenuCmd): TShortCut;
    function CurrentShortcut(ACommand: TMenuCmd): TShortCut;
    function HasOverride(ACommand: TMenuCmd): Boolean;
    function Conflict(ACommand: TMenuCmd; AShortCut: TShortCut): TMenuCmd;
    procedure SetShortcut(ACommand: TMenuCmd; AShortCut: TShortCut);
    procedure ResetShortcut(ACommand: TMenuCmd);
    procedure ResetAll;
    property Settings: TAppSettings read FSettings;
  end;

function ShortcutCommandID(ACommand: TMenuCmd): string;
function ShortcutDisplay(AShortCut: TShortCut): string;

implementation

const
  NoShortcutValue = 'none';

function ShortcutCommandID(ACommand: TMenuCmd): string;
begin
  Result := 'cmd_' + GetEnumName(TypeInfo(TMenuCmd), Ord(ACommand));
end;

function ShortcutDisplay(AShortCut: TShortCut): string;
begin
  if AShortCut = 0 then
    Result := ''
  else
    Result := ShortCutToText(AShortCut);
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

function TShortcutManager.FindDefaultIndex(ACommand: TMenuCmd): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FDefaults) do
    if FDefaults[i].Command = ACommand then
      Exit(i);
  Result := -1;
end;

procedure TShortcutManager.CaptureItem(AItem: TMenuItem);
var
  i, N: Integer;
begin
  if (AItem.Name <> '') and (Copy(AItem.Name, 1, 4) = 'cmd_') and
     (AItem.Tag <> Ord(mcNone)) then
  begin
    if FindDefaultIndex(TMenuCmd(AItem.Tag)) < 0 then
    begin
      N := Length(FDefaults);
      SetLength(FDefaults, N + 1);
      FDefaults[N].Command := TMenuCmd(AItem.Tag);
      FDefaults[N].ShortCut := AItem.ShortCut;
    end;
  end;
  for i := 0 to AItem.Count - 1 do
    CaptureItem(AItem.Items[i]);
end;

procedure TShortcutManager.CaptureDefaults(AMenu: TMenuItem);
var
  i: Integer;
begin
  if AMenu = nil then Exit;
  CaptureItem(AMenu);
  { The passed node itself may be a command item. }
  if (AMenu.Name <> '') and (Copy(AMenu.Name, 1, 4) = 'cmd_') and
     (AMenu.Tag <> Ord(mcNone)) and (FindDefaultIndex(TMenuCmd(AMenu.Tag)) < 0) then
  begin
    i := Length(FDefaults);
    SetLength(FDefaults, i + 1);
    FDefaults[i].Command := TMenuCmd(AMenu.Tag);
    FDefaults[i].ShortCut := AMenu.ShortCut;
  end;
end;

procedure TShortcutManager.ApplyItem(AItem: TMenuItem);
var
  i: Integer;
begin
  if (AItem.Name <> '') and (Copy(AItem.Name, 1, 4) = 'cmd_') and
     (AItem.Tag <> Ord(mcNone)) then
    AItem.ShortCut := CurrentShortcut(TMenuCmd(AItem.Tag));
  for i := 0 to AItem.Count - 1 do
    ApplyItem(AItem.Items[i]);
end;

procedure TShortcutManager.Apply(AMenu: TMenuItem);
var
  i: Integer;
begin
  if AMenu = nil then Exit;
  ApplyItem(AMenu);
  for i := 0 to AMenu.Count - 1 do
    ApplyItem(AMenu.Items[i]);
end;

function TShortcutManager.DefaultShortcut(ACommand: TMenuCmd): TShortCut;
var
  i: Integer;
begin
  i := FindDefaultIndex(ACommand);
  if i >= 0 then
    Result := FDefaults[i].ShortCut
  else
    Result := 0;
end;

function TShortcutManager.CurrentShortcut(ACommand: TMenuCmd): TShortCut;
var
  ID: string;
  i: Integer;
begin
  ID := CommandID(ACommand);
  i := FSettings.Shortcuts.IndexOfName(ID);
  if i >= 0 then
  begin
    if FSettings.Shortcuts.ValueFromIndex[i] = NoShortcutValue then
      Result := 0
    else
      Result := TextToShortCut(FSettings.Shortcuts.ValueFromIndex[i]);
  end
  else
    Result := DefaultShortcut(ACommand);
end;

function TShortcutManager.HasOverride(ACommand: TMenuCmd): Boolean;
begin
  Result := FSettings.Shortcuts.IndexOfName(CommandID(ACommand)) >= 0;
end;

function TShortcutManager.Conflict(ACommand: TMenuCmd;
  AShortCut: TShortCut): TMenuCmd;
var
  i: Integer;
begin
  Result := mcNone;
  if AShortCut = 0 then Exit;
  for i := 0 to High(FDefaults) do
  begin
    if FDefaults[i].Command = ACommand then Continue;
    if CurrentShortcut(FDefaults[i].Command) = AShortCut then
      Exit(FDefaults[i].Command);
  end;
end;

procedure TShortcutManager.SetShortcut(ACommand: TMenuCmd;
  AShortCut: TShortCut);
var
  ID: string;
  Index: Integer;
begin
  ID := CommandID(ACommand);
  if AShortCut = DefaultShortcut(ACommand) then
  begin
    Index := FSettings.Shortcuts.IndexOfName(ID);
    if Index >= 0 then
      FSettings.Shortcuts.Delete(Index);
  end
  else if AShortCut = 0 then
    FSettings.Shortcuts.Values[ID] := NoShortcutValue
  else
    FSettings.Shortcuts.Values[ID] := ShortCutToText(AShortCut);
end;

procedure TShortcutManager.ResetShortcut(ACommand: TMenuCmd);
var
  Index: Integer;
begin
  Index := FSettings.Shortcuts.IndexOfName(CommandID(ACommand));
  if Index >= 0 then
    FSettings.Shortcuts.Delete(Index);
end;

procedure TShortcutManager.ResetAll;
begin
  FSettings.Shortcuts.Clear;
end;

end.
