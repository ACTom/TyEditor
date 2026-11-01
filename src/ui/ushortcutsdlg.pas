unit ushortcutsdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Menus, LCLType,
  tyControls.Controller, tyControls.Form, tyControls.Panel, tyControls.ListView,
  tyControls.TyLabel, tyControls.Edit, tyControls.Button, tyControls.Dialogs,
  ucommands, usettings, ukeybindings, utranslation;

type
  TShortcutItem = record
    Command: TMenuCmd;
    Caption: string;
    MenuItem: TMenuItem;
  end;

  TShortcutsForm = class(TTyForm)
  private
    FSettings: TAppSettings;
    FManager: TShortcutManager;
    FMainMenu: TMainMenu;
    FExtraMenu: TMenuItem;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FList: TTyListView;
    FFilter: TTyEdit;
    FShortcutEdit: TTyEdit;
    FHint: TTyLabel;
    FReset, FResetAll, FOK, FCancel: TTyButton;
    FItems: array of TShortcutItem;
    FSeen: TStringList;
    FOriginal: TStringList;
    procedure AddMenuItems(AItem: TMenuItem);
    procedure BuildUI;
    procedure RefreshList;
    procedure UpdateSelection;
    procedure ApplyMenus;
    procedure DoSelect(Sender: TObject);
    procedure DoFilter(Sender: TObject);
    procedure SelectCommand(ACommand: TMenuCmd);
    function ShortcutAllowed(AKey: Word; AShift: TShiftState): Boolean;
    procedure DoShortcutKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DoReset(Sender: TObject);
    procedure DoResetAll(Sender: TObject);
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure DoClose(Sender: TObject; var CloseAction: TCloseAction);
    function SelectedCommand: TMenuCmd;
    function CommandCaption(ACommand: TMenuCmd): string;
    procedure RestoreOriginal;
  public
    constructor Create(AOwner: TComponent; ASettings: TAppSettings;
      AManager: TShortcutManager; AMainMenu: TMainMenu; AExtraMenu: TMenuItem);
    destructor Destroy; override;
    function Execute: Boolean;
  end;

implementation

uses
  Dialogs;

constructor TShortcutsForm.Create(AOwner: TComponent; ASettings: TAppSettings;
  AManager: TShortcutManager; AMainMenu: TMainMenu; AExtraMenu: TMenuItem);
var
  i: Integer;
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FSettings := ASettings;
  FManager := AManager;
  FMainMenu := AMainMenu;
  FExtraMenu := AExtraMenu;
  FSeen := TStringList.Create;
  FSeen.Sorted := True;
  FSeen.Duplicates := dupIgnore;
  FOriginal := TStringList.Create;
  FOriginal.Assign(FSettings.Shortcuts);
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  SetBounds(0, 0, 720, 560);
  Caption := Tr('Keyboard Shortcuts');
  Controller := TyDefaultController;

  if FMainMenu <> nil then
    for i := 0 to FMainMenu.Items.Count - 1 do
      AddMenuItems(FMainMenu.Items[i]);
  if FExtraMenu <> nil then
    AddMenuItems(FExtraMenu);

  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  OnClose := @DoClose;
  RefreshList;
  if FList.Items.Count > 0 then
  begin
    FList.ItemIndex := 0;
    UpdateSelection;
  end;
end;

destructor TShortcutsForm.Destroy;
begin
  FSeen.Free;
  FOriginal.Free;
  inherited;
end;

procedure TShortcutsForm.AddMenuItems(AItem: TMenuItem);
var
  Cmd: TMenuCmd;
  CaptionText: string;
  i: Integer;
begin
  if AItem = nil then Exit;
  Cmd := TMenuCmd(AItem.Tag);
  if (AItem.Name <> '') and (Copy(AItem.Name, 1, 4) = 'cmd_') and
     (Cmd <> mcNone) then
  begin
    {$IFDEF LCLCocoa}
    { These live in the native application menu and are not synchronised by
      Cocoa when a user changes a menu shortcut. }
    if (Cmd = mcPreferences) or (Cmd = mcKeyboardShortcuts) then
    begin
      for i := 0 to AItem.Count - 1 do
        AddMenuItems(AItem.Items[i]);
      Exit;
    end;
    {$ENDIF}
    if FSeen.IndexOf(IntToStr(Ord(Cmd))) < 0 then
    begin
      FSeen.Add(IntToStr(Ord(Cmd)));
      CaptionText := StringReplace(AItem.Caption, '&', '', [rfReplaceAll]);
      i := Length(FItems);
      SetLength(FItems, i + 1);
      FItems[i].Command := Cmd;
      FItems[i].Caption := CaptionText;
      FItems[i].MenuItem := AItem;
    end;
  end;
  for i := 0 to AItem.Count - 1 do
    AddMenuItems(AItem.Items[i]);
end;

procedure TShortcutsForm.BuildUI;
begin
  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Keyboard Shortcuts');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FFilter := TTyEdit.Create(Self);
  FFilter.Parent := FSurface;
  FFilter.SetBounds(16, 48, 500, 30);
  FFilter.TextHint := Tr('Filter commands...');
  FFilter.OnChange := @DoFilter;

  FList := TTyListView.Create(Self);
  FList.Parent := FSurface;
  FList.SetBounds(16, 84, 500, 416);
  FList.ShowColumnHeaders := True;
  FList.RowSelect := True;
  FList.ReadOnly := True;
  FList.Columns.Add;
  FList.Columns[0].Text := Tr('Command');
  FList.Columns[0].Width := 330;
  FList.Columns.Add;
  FList.Columns[1].Text := Tr('Shortcut');
  FList.Columns[1].Width := 160;
  FList.OnClick := @DoSelect;

  FHint := TTyLabel.Create(Self);
  FHint.Parent := FSurface;
  FHint.SetBounds(532, 50, 172, 72);
  FHint.Caption := Tr('Select a command, then press the new key combination. Use Ctrl, Alt or Command with a key, or F1-F24 alone.');
  FHint.WordWrap := True;

  FShortcutEdit := TTyEdit.Create(Self);
  FShortcutEdit.Parent := FSurface;
  FShortcutEdit.SetBounds(532, 128, 172, 32);
  FShortcutEdit.ReadOnly := True;
  FShortcutEdit.OnKeyDown := @DoShortcutKey;

  FReset := TTyButton.Create(Self);
  FReset.Parent := FSurface;
  FReset.SetBounds(532, 174, 172, 32);
  FReset.Caption := Tr('Reset Selected');
  FReset.OnClick := @DoReset;

  FResetAll := TTyButton.Create(Self);
  FResetAll.Parent := FSurface;
  FResetAll.SetBounds(532, 214, 172, 32);
  FResetAll.Caption := Tr('Reset All');
  FResetAll.OnClick := @DoResetAll;

  FOK := TTyButton.Create(Self);
  FOK.Parent := FSurface;
  FOK.SetBounds(512, 515, 90, 32);
  FOK.Caption := Tr('OK');
  FOK.OnClick := @DoOK;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(612, 515, 92, 32);
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TShortcutsForm.RefreshList;
var
  i: Integer;
  It: TTyListItem;
  S, FilterText: string;
begin
  FList.Items.Clear;
  FilterText := '';
  if FFilter <> nil then
    FilterText := LowerCase(Trim(FFilter.Text));
  for i := 0 to High(FItems) do
  begin
    S := ShortcutDisplay(FManager.CurrentShortcut(FItems[i].Command));
    if (FilterText <> '') and
       (Pos(FilterText, LowerCase(FItems[i].Caption)) = 0) and
       (Pos(FilterText, LowerCase(S)) = 0) then
      Continue;
    It := FList.Items.Add;
    It.Data := TObject(PtrInt(Ord(FItems[i].Command)));
    It.Caption := FItems[i].Caption;
    if S = '' then
      S := Tr('(none)');
    It.SubItems.Add(S);
  end;
end;

procedure TShortcutsForm.SelectCommand(ACommand: TMenuCmd);
var
  i: Integer;
begin
  for i := 0 to FList.Items.Count - 1 do
    if TMenuCmd(PtrInt(FList.Items[i].Data)) = ACommand then
    begin
      FList.ItemIndex := i;
      Exit;
    end;
end;

function TShortcutsForm.SelectedCommand: TMenuCmd;
begin
  if (FList.ItemIndex < 0) or (FList.ItemIndex >= FList.Items.Count) then
    Result := mcNone
  else
    Result := TMenuCmd(PtrInt(FList.Items[FList.ItemIndex].Data));
end;

function TShortcutsForm.CommandCaption(ACommand: TMenuCmd): string;
var
  i: Integer;
begin
  for i := 0 to High(FItems) do
    if FItems[i].Command = ACommand then
      Exit(FItems[i].Caption);
  Result := '';
end;

procedure TShortcutsForm.UpdateSelection;
var
  Cmd: TMenuCmd;
  S: string;
begin
  Cmd := SelectedCommand;
  if Cmd = mcNone then
  begin
    FShortcutEdit.Text := '';
    Exit;
  end;
  S := ShortcutDisplay(FManager.CurrentShortcut(Cmd));
  if S = '' then
    S := Tr('(none)');
  FShortcutEdit.Text := S;
end;

procedure TShortcutsForm.ApplyMenus;
var
  i: Integer;
begin
  if FMainMenu <> nil then
    for i := 0 to FMainMenu.Items.Count - 1 do
      FManager.Apply(FMainMenu.Items[i]);
  FManager.Apply(FExtraMenu);
end;

procedure TShortcutsForm.DoSelect(Sender: TObject);
begin
  UpdateSelection;
  if FShortcutEdit.CanFocus then
    FShortcutEdit.SetFocus;
end;

procedure TShortcutsForm.DoFilter(Sender: TObject);
begin
  RefreshList;
  if FList.Items.Count > 0 then
    FList.ItemIndex := 0;
  UpdateSelection;
end;

function TShortcutsForm.ShortcutAllowed(AKey: Word; AShift: TShiftState): Boolean;
begin
  if AKey in [VK_TAB, VK_RETURN, VK_ESCAPE, VK_SPACE, VK_BACK, VK_DELETE] then
    Exit(False);
  if (AKey >= VK_F1) and (AKey <= VK_F24) then
    Exit(True);
  Result := (AShift * [ssCtrl, ssAlt, ssMeta]) <> [];
end;

procedure TShortcutsForm.DoShortcutKey(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Cmd, Conflict: TMenuCmd;
  NewShortcut: TShortCut;
  Mods: TShiftState;
  S: string;
begin
  Cmd := SelectedCommand;
  if Cmd = mcNone then Exit;

  if Key in [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN] then
  begin
    Key := 0;
    Exit;
  end;

  if Key = VK_ESCAPE then
  begin
    Key := 0;
    Exit;
  end;

  if (Key = VK_BACK) or (Key = VK_DELETE) then
    NewShortcut := 0
  else
  begin
    Mods := Shift * [ssShift, ssCtrl, ssAlt, ssMeta];
    if not ShortcutAllowed(Key, Mods) then
    begin
      Key := 0;
      Exit;
    end;
    NewShortcut := ShortCut(Key, Mods);
  end;

  Conflict := FManager.Conflict(Cmd, NewShortcut);
  if Conflict <> mcNone then
  begin
    {$IFDEF LCLCocoa}
    if (Conflict = mcPreferences) or (Conflict = mcKeyboardShortcuts) then
    begin
      ShowMessage(Tr('This shortcut is reserved by the application menu.'));
      Key := 0;
      Exit;
    end;
    {$ENDIF}
    if TyMessageDlg(Format(Tr('Shortcut already used by "%s". Replace it?'),
      [CommandCaption(Conflict)]), mtConfirmation, [mbYes, mbNo]) <> mrYes then
    begin
      Key := 0;
      Exit;
    end;
    FManager.SetShortcut(Conflict, 0);
  end;

  FManager.SetShortcut(Cmd, NewShortcut);
  ApplyMenus;
  RefreshList;
  SelectCommand(Cmd);
  S := ShortcutDisplay(NewShortcut);
  if S = '' then
    S := Tr('(none)');
  FShortcutEdit.Text := S;
  Key := 0;
end;

procedure TShortcutsForm.DoReset(Sender: TObject);
var
  Cmd: TMenuCmd;
begin
  Cmd := SelectedCommand;
  if Cmd = mcNone then Exit;
  FManager.ResetShortcut(Cmd);
  ApplyMenus;
  RefreshList;
  SelectCommand(Cmd);
  UpdateSelection;
end;

procedure TShortcutsForm.DoResetAll(Sender: TObject);
begin
  FManager.ResetAll;
  ApplyMenus;
  RefreshList;
  if FList.Items.Count > 0 then
    FList.ItemIndex := 0;
  UpdateSelection;
end;

procedure TShortcutsForm.RestoreOriginal;
begin
  FSettings.Shortcuts.Assign(FOriginal);
  ApplyMenus;
end;

procedure TShortcutsForm.DoOK(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TShortcutsForm.DoCancel(Sender: TObject);
begin
  RestoreOriginal;
  ModalResult := mrCancel;
end;

procedure TShortcutsForm.DoClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if ModalResult <> mrOk then
    RestoreOriginal;
  CloseAction := caHide;
end;

function TShortcutsForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.
