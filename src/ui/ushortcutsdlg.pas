unit ushortcutsdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Menus, LCLType,
  ATSynEdit_Keymap,
  tyControls.Controller, tyControls.Form, tyControls.Panel, tyControls.ListView,
  tyControls.TyLabel, tyControls.Edit, tyControls.Button, tyControls.Dialogs,
  ucommands, usettings, ukeybindings, ueditorkeymap, utranslation;

type
  TShortcutItem = record
    CommandID: string;
    Caption: string;
    Group: string;
  end;

  TShortcutsForm = class(TTyForm)
  private
    FSettings: TAppSettings;
    FManager: TShortcutManager;
    FMainMenu: TMainMenu;
    FExtraMenu: TMenuItem;
    FEditorKeymap: TATKeymap;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FList: TTyListView;
    FFilter: TTyEdit;
    FShortcutEdit: TTyEdit;
    FHint: TTyLabel;
    FConflictHint: TTyLabel;
    FReset, FResetAll, FOK, FCancel: TTyButton;
    FItems: array of TShortcutItem;
    FSeen: TStringList;
    FOriginal: TStringList;
    FGroupMap: TStringList;
    FGroupCollapsed: TStringList;
    FConflictIDs: TStringList;
    procedure AddMenuItems(AItem: TMenuItem; const AGroup: string);
    procedure BuildUI;
    procedure RefreshList;
    procedure RefreshConflicts;
    procedure UpdateSelection;
    procedure ApplyMenus;
    procedure DoSelect(Sender: TObject);
    procedure DoFilter(Sender: TObject);
    procedure SelectCommand(const ACommandID: string);
    function ShortcutAllowed(AKey: Word; AShift: TShiftState): Boolean;
    procedure DoShortcutKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DoReset(Sender: TObject);
    procedure DoResetAll(Sender: TObject);
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure DoClose(Sender: TObject; var CloseAction: TCloseAction);
    function SelectedCommand: string;
    procedure RestoreOriginal;
    function EnsureGroup(const AName: string): Integer;
    function ConflictCaption(const AConflict: TShortcutConflict): string;
  public
    constructor Create(AOwner: TComponent; ASettings: TAppSettings;
      AManager: TShortcutManager; AMainMenu: TMainMenu; AExtraMenu: TMenuItem;
      AEditorKeymap: TATKeymap);
    destructor Destroy; override;
    function Execute: Boolean;
  end;

implementation

uses
  Dialogs;

function MenuGroupText(const ACaption: string): string;
begin
  Result := StringReplace(ACaption, '&', '', [rfReplaceAll]);
end;

constructor TShortcutsForm.Create(AOwner: TComponent; ASettings: TAppSettings;
  AManager: TShortcutManager; AMainMenu: TMainMenu; AExtraMenu: TMenuItem;
  AEditorKeymap: TATKeymap);
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
  FEditorKeymap := AEditorKeymap;
  FSeen := TStringList.Create;
  FSeen.Sorted := True;
  FSeen.Duplicates := dupIgnore;
  FOriginal := TStringList.Create;
  FOriginal.Assign(FSettings.Shortcuts);
  FGroupMap := TStringList.Create;
  FGroupCollapsed := TStringList.Create;
  FConflictIDs := TStringList.Create;
  FConflictIDs.Sorted := True;
  FConflictIDs.Duplicates := dupIgnore;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  SetBounds(0, 0, 720, 560);
  Caption := Tr('Keyboard Shortcuts');
  Controller := TyDefaultController;

  if FMainMenu <> nil then
    for i := 0 to FMainMenu.Items.Count - 1 do
      AddMenuItems(FMainMenu.Items[i], MenuGroupText(FMainMenu.Items[i].Caption));
  if FExtraMenu <> nil then
    AddMenuItems(FExtraMenu, 'Application');

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
  FGroupMap.Free;
  FGroupCollapsed.Free;
  FConflictIDs.Free;
  inherited;
end;

procedure TShortcutsForm.AddMenuItems(AItem: TMenuItem;
  const AGroup: string);
var
  CmdItem: TCommandMenuItem;
  ID, CaptionText, GroupName: string;
  i: Integer;
begin
  if AItem = nil then Exit;
  if AItem is TCommandMenuItem then
  begin
    CmdItem := TCommandMenuItem(AItem);
    ID := CmdItem.CommandID;
    if ID <> '' then
    begin
      {$IFDEF LCLCocoa}
      { These live in the native application menu and are not synchronised by
        Cocoa when a user changes a menu shortcut. }
      if (ID = ShortcutCommandID(mcPreferences)) or
         (ID = ShortcutCommandID(mcKeyboardShortcuts)) then
      begin
        for i := 0 to AItem.Count - 1 do
          AddMenuItems(AItem.Items[i], AGroup);
        Exit;
      end;
      {$ENDIF}
      if FSeen.IndexOf(ID) < 0 then
      begin
        FSeen.Add(ID);
        GroupName := CmdItem.CommandGroup;
        if GroupName = '' then
          GroupName := AGroup;
        if GroupName = '' then
          GroupName := Tr('Other');
        CaptionText := StringReplace(AItem.Caption, '&', '', [rfReplaceAll]);
        i := Length(FItems);
        SetLength(FItems, i + 1);
        FItems[i].CommandID := ID;
        FItems[i].Caption := CaptionText;
        FItems[i].Group := GroupName;
      end;
    end;
  end;
  for i := 0 to AItem.Count - 1 do
    AddMenuItems(AItem.Items[i], AGroup);
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

  FConflictHint := TTyLabel.Create(Self);
  FConflictHint.Parent := FSurface;
  FConflictHint.SetBounds(16, 84, 500, 20);
  FConflictHint.Caption := '';

  FList := TTyListView.Create(Self);
  FList.Parent := FSurface;
  FList.SetBounds(16, 108, 500, 392);
  FList.ShowColumnHeaders := True;
  FList.RowSelect := True;
  FList.ReadOnly := True;
  FList.GroupView := True;
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

function TShortcutsForm.EnsureGroup(const AName: string): Integer;
var
  Index: Integer;
  G: TTyListGroup;
begin
  Index := FGroupMap.IndexOf(AName);
  if Index >= 0 then
    Exit(PtrInt(FGroupMap.Objects[Index]));
  G := FList.Groups.Add;
  G.Caption := AName;
  G.Collapsed := FGroupCollapsed.Values[AName] = '1';
  Index := FList.Groups.Count - 1;
  FGroupMap.AddObject(AName, TObject(PtrInt(Index)));
  Result := Index;
end;

procedure TShortcutsForm.RefreshConflicts;
var
  Conflicts: TShortcutConflictArray;
  i: Integer;
begin
  FConflictIDs.Clear;
  Conflicts := FManager.ValidateConflicts;
  for i := 0 to High(Conflicts) do
    FConflictIDs.Add(Conflicts[i].ID);
  if FConflictIDs.Count > 0 then
    FConflictHint.Caption := Format(Tr('%d shortcut conflicts'),
      [FConflictIDs.Count])
  else
    FConflictHint.Caption := '';
end;

procedure TShortcutsForm.RefreshList;
var
  i, GroupIndex: Integer;
  It: TTyListItem;
  S, FilterText, GroupText: string;
begin
  for i := 0 to FList.Groups.Count - 1 do
    if FList.Groups[i].Collapsed then
      FGroupCollapsed.Values[FList.Groups[i].Caption] := '1'
    else
      FGroupCollapsed.Values[FList.Groups[i].Caption] := '0';
  FList.Items.Clear;
  FList.Groups.Clear;
  FGroupMap.Clear;
  RefreshConflicts;

  FilterText := '';
  if FFilter <> nil then
    FilterText := LowerCase(Trim(FFilter.Text));
  for i := 0 to High(FItems) do
  begin
    S := ShortcutDisplay(FManager.CurrentShortcut(FItems[i].CommandID));
    GroupText := FItems[i].Group;
    if (FilterText <> '') and
       (Pos(FilterText, LowerCase(FItems[i].Caption)) = 0) and
       (Pos(FilterText, LowerCase(GroupText)) = 0) and
       (Pos(FilterText, LowerCase(S)) = 0) then
      Continue;
    GroupIndex := EnsureGroup(GroupText);
    It := FList.Items.Add;
    It.Data := TObject(PtrInt(i));
    It.GroupIndex := GroupIndex;
    It.Caption := FItems[i].Caption;
    if S = '' then
      S := Tr('(none)')
    else if FConflictIDs.IndexOf(FItems[i].CommandID) >= 0 then
      S := '⚠ ' + S;
    It.SubItems.Add(S);
  end;
end;

procedure TShortcutsForm.UpdateSelection;
var
  Cmd: string;
  S: string;
begin
  Cmd := SelectedCommand;
  if Cmd = '' then
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
  { Platform-reserved combinations. }
  if (AKey = VK_DELETE) and (ssCtrl in AShift) and (ssAlt in AShift) then
    Exit(False);
  if (AKey = VK_F4) and (ssAlt in AShift) then
    Exit(False);
  if (AKey = VK_ESCAPE) and (ssCtrl in AShift) and (ssShift in AShift) then
    Exit(False);
  if (AKey >= VK_F1) and (AKey <= VK_F24) then
    Exit(True);
  Result := (AShift * [ssCtrl, ssAlt, ssMeta]) <> [];
end;

function TShortcutsForm.ConflictCaption(
  const AConflict: TShortcutConflict): string;
begin
  if AConflict.Group <> '' then
    Result := AConflict.Group + ' — ' + AConflict.Caption
  else
    Result := AConflict.Caption;
end;

procedure TShortcutsForm.DoShortcutKey(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Cmd: string;
  NewShortcut: TShortCut;
  Mods: TShiftState;
  S, Msg: string;
  Conflicts: TShortcutConflictArray;
  Lines: TStringList;
  i: Integer;
  EditorName: string;
begin
  Cmd := SelectedCommand;
  if Cmd = '' then Exit;

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

  Conflicts := FManager.Conflicts(Cmd, NewShortcut);
  if Length(Conflicts) > 0 then
  begin
    {$IFDEF LCLCocoa}
    for i := 0 to High(Conflicts) do
      if (Conflicts[i].ID = ShortcutCommandID(mcPreferences)) or
         (Conflicts[i].ID = ShortcutCommandID(mcKeyboardShortcuts)) then
      begin
        ShowMessage(Tr('This shortcut is reserved by the application menu.'));
        Key := 0;
        Exit;
      end;
    {$ENDIF}
    Lines := TStringList.Create;
    try
      for i := 0 to High(Conflicts) do
        Lines.Add(ConflictCaption(Conflicts[i]));
      Msg := Tr('Shortcut already used by:') + sLineBreak +
        Lines.Text + sLineBreak + Tr('Replace all conflicting shortcuts?');
      if TyMessageDlg(Msg, mtConfirmation, [mbYes, mbNo]) <> mrYes then
      begin
        Key := 0;
        Exit;
      end;
      for i := 0 to High(Conflicts) do
        FManager.SetShortcut(Conflicts[i].ID, 0);
    finally
      Lines.Free;
    end;
  end;

  if NewShortcut <> 0 then
  begin
    EditorName := EditorKeyConflictName(FEditorKeymap, NewShortcut);
    if EditorName <> '' then
      if TyMessageDlg(Format(Tr('This key is used by the editor action "%s". The menu shortcut will override it. Continue?'),
        [EditorName]), mtConfirmation, [mbYes, mbNo]) <> mrYes then
      begin
        Key := 0;
        Exit;
      end;
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
  Cmd: string;
begin
  Cmd := SelectedCommand;
  if Cmd = '' then Exit;
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

function TShortcutsForm.SelectedCommand: string;
begin
  if (FList.ItemIndex < 0) or (FList.ItemIndex >= FList.Items.Count) then
    Result := ''
  else
    Result := FItems[PtrInt(FList.Items[FList.ItemIndex].Data)].CommandID;
end;

procedure TShortcutsForm.SelectCommand(const ACommandID: string);
var
  i: Integer;
begin
  for i := 0 to FList.Items.Count - 1 do
    if FItems[PtrInt(FList.Items[i].Data)].CommandID = ACommandID then
    begin
      FList.ItemIndex := i;
      Exit;
    end;
end;

end.
