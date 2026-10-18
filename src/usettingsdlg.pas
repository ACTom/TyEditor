unit usettingsdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.ListBox,
  tyControls.TyLabel, tyControls.Edit, tyControls.CheckBox, tyControls.Button,
  tyControls.ComboBox, tyControls.SpinEdit, tyControls.FontComboBox,
  tyControls.Dialogs.Font, tyControls.Dialogs.SelectPath,
  usettings, uencoding, utranslation, ucolorscheme;

type
  TSettingsForm = class(TTyForm)
  private
    FSettings: TAppSettings;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FCategory: TTyListBox;
    FPageHost: TTyPanel;
    FPages: array[0..3] of TTyPanel;
    FThemeNames: TStringList;
    FLangIDs: TStringList;
    FEncodingChoices: TEncodingChoiceArray;

    FLangCombo, FThemeCombo, FEncodingCombo, FEolCombo, FColorSchemeCombo,
    FNumberMode: TTyComboBox;
    FFontCombo: TTyFontComboBox;
    FBackupDirEdit: TTyEdit;
    FBackupKeep: TTySpinEdit;
    FBtnFont: TTyButton;
    FBtnBackup: TTyButton;
    FFontSize, FTabSize, FSnapshot, FRecentMax: TTySpinEdit;
    FTabSpaces, FWordWrap, FWhitespace, FNumbers, FCurLine, FIndentGuides, FFolding,
    FRuler, FBookmarkMargin, FMinimap, FMicromap,
    FTrimTrailing, FForceFinal, FFindCase, FFindWords, FFindRegex,
    FFindWrap, FRestore, FDarkMode, FSingleInstance, FAutoIndent, FAutoPair, FSmoothScroll,
    FCaretBlink: TTyCheckBox;
    FOK, FCancel: TTyButton;

    procedure BuildUI;
    procedure BuildGeneralPage;
    procedure BuildEditorPage;
    procedure BuildFilesPage;
    procedure BuildSearchPage;
    procedure CategoryChanged(Sender: TObject);
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    function AddLabel(AParent: TWinControl; AX, AY, AW: Integer;
      const ACaption: string): TTyLabel;
    function AddCheck(AParent: TWinControl; AX, AY, AW: Integer;
      const ACaption: string; AChecked: Boolean): TTyCheckBox;
    procedure DoFontDialog(Sender: TObject);
    procedure DoBackupBrowse(Sender: TObject);
    function AddSpin(AParent: TWinControl; AX, AY, AW, AValue, AMin, AMax: Integer): TTySpinEdit;
    function AddCombo(AParent: TWinControl; AX, AY, AW: Integer): TTyComboBox;
  public
    constructor Create(AOwner: TComponent; ASettings: TAppSettings);
    destructor Destroy; override;
    function Execute: Boolean;
  end;

implementation

uses
  Dialogs;

constructor TSettingsForm.Create(AOwner: TComponent; ASettings: TAppSettings);
var
  S: string;
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FSettings := ASettings;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  SetBounds(0, 0, 780, 570);
  Caption := Tr('Preferences');
  FLangIDs := AvailableLanguages;
  FThemeNames := TStringList.Create;
  for S in TyBuiltinThemeNames do
    FThemeNames.Add(S);
  FEncodingChoices := EncodingChoices;
  Controller := TyDefaultController;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  OnClose := nil;
end;

destructor TSettingsForm.Destroy;
begin
  FLangIDs.Free;
  FThemeNames.Free;
  inherited;
end;

function TSettingsForm.AddLabel(AParent: TWinControl; AX, AY, AW: Integer;
  const ACaption: string): TTyLabel;
begin
  Result := TTyLabel.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(AX, AY, AW, 24);
  Result.Caption := ACaption;
end;

function TSettingsForm.AddCheck(AParent: TWinControl; AX, AY, AW: Integer;
  const ACaption: string; AChecked: Boolean): TTyCheckBox;
begin
  Result := TTyCheckBox.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(AX, AY, AW, 24);
  Result.Caption := ACaption;
  Result.Checked := AChecked;
end;

function TSettingsForm.AddSpin(AParent: TWinControl; AX, AY, AW, AValue, AMin, AMax: Integer): TTySpinEdit;
begin
  Result := TTySpinEdit.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(AX, AY, AW, 30);
  Result.MinValue := AMin;
  Result.MaxValue := AMax;
  Result.Value := AValue;
end;

function TSettingsForm.AddCombo(AParent: TWinControl; AX, AY, AW: Integer): TTyComboBox;
begin
  Result := TTyComboBox.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(AX, AY, AW, 30);
end;

procedure TSettingsForm.BuildUI;
var
  i: Integer;
begin
  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Preferences');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FCategory := TTyListBox.Create(Self);
  FCategory.Parent := FSurface;
  FCategory.SetBounds(16, 50, 170, 455);
  FCategory.Items.Add(Tr('General'));
  FCategory.Items.Add(Tr('Editor'));
  FCategory.Items.Add(Tr('Files'));
  FCategory.Items.Add(Tr('Search'));
  FCategory.ItemIndex := 0;
  FCategory.OnClick := @CategoryChanged;

  FPageHost := TTyPanel.Create(Self);
  FPageHost.Parent := FSurface;
  FPageHost.SetBounds(200, 50, 560, 455);

  for i := 0 to High(FPages) do
  begin
    FPages[i] := TTyPanel.Create(Self);
    FPages[i].Parent := FPageHost;
    FPages[i].Align := alClient;
    FPages[i].Visible := False;
  end;

  BuildGeneralPage;
  BuildEditorPage;
  BuildFilesPage;
  BuildSearchPage;
  FPages[0].Visible := True;

  FOK := TTyButton.Create(Self);
  FOK.Parent := FSurface;
  FOK.SetBounds(560, 515, 90, 32);
  FOK.Caption := Tr('OK');
  FOK.OnClick := @DoOK;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(660, 515, 100, 32);
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TSettingsForm.BuildGeneralPage;
var
  P: TTyPanel;
  i, Idx: Integer;
  D: TStringList;
begin
  P := FPages[0];
  AddLabel(P, 16, 16, 130, Tr('UI language:'));
  FLangCombo := AddCombo(P, 160, 12, 230);
  D := TStringList.Create;
  try
    for i := 0 to FLangIDs.Count - 1 do
      D.Add(LanguageDisplayName(FLangIDs[i]));
    FLangCombo.Items.Assign(D);
  finally
    D.Free;
  end;
  Idx := FLangIDs.IndexOf(FSettings.Language);
  if Idx < 0 then Idx := 0;
  FLangCombo.ItemIndex := Idx;

  AddLabel(P, 16, 56, 130, Tr('Interface theme:'));
  FThemeCombo := AddCombo(P, 160, 52, 230);
  for i := 0 to FThemeNames.Count - 1 do
    FThemeCombo.Items.Add(FThemeNames[i]);
  Idx := FThemeNames.IndexOf(FSettings.Theme);
  if Idx < 0 then Idx := 0;
  FThemeCombo.ItemIndex := Idx;

  FRestore := AddCheck(P, 16, 100, 300, Tr('Restore session on startup'), FSettings.RestoreSession);
  FDarkMode := AddCheck(P, 16, 132, 300, Tr('Dark mode'), FSettings.DarkMode);
  FSingleInstance := AddCheck(P, 16, 164, 300, Tr('Single instance'), FSettings.SingleInstance);
  AddLabel(P, 16, 204, 160, Tr('Auto save session (seconds):'));
  FSnapshot := AddSpin(P, 190, 200, 90, FSettings.AutoSnapshotSec, 5, 3600);

  AddLabel(P, 16, 244, 160, Tr('Backup folder:'));
  FBackupDirEdit := TTyEdit.Create(Self);
  FBackupDirEdit.Parent := P;
  FBackupDirEdit.SetBounds(190, 240, 280, 30);
  FBackupDirEdit.Text := FSettings.BackupDir;
  FBtnBackup := TTyButton.Create(Self);
  FBtnBackup.Parent := P;
  FBtnBackup.SetBounds(480, 240, 70, 30);
  FBtnBackup.Caption := Tr('Browse...');
  FBtnBackup.OnClick := @DoBackupBrowse;
  AddLabel(P, 16, 284, 160, Tr('Keep backups:'));
  FBackupKeep := AddSpin(P, 190, 280, 90, FSettings.BackupKeep, 1, 1000);

end;

procedure TSettingsForm.BuildEditorPage;
const
  NumberStyleIDs: array[0..4] of string =
    ('all', 'each5', 'each10', 'relative', 'none');
var
  P: TTyPanel;
  Names: TStringList;
  i: Integer;
begin
  P := FPages[1];
  AddLabel(P, 16, 16, 90, Tr('Font family:'));
  FFontCombo := TTyFontComboBox.Create(Self);
  FFontCombo.Parent := P;
  FFontCombo.SetBounds(110, 12, 190, 30);
  FFontCombo.FixedPitchOnly := False;
  FFontCombo.SelectedFont := FSettings.FontName;
  FBtnFont := TTyButton.Create(Self);
  FBtnFont.Parent := P;
  FBtnFont.SetBounds(310, 12, 80, 30);
  FBtnFont.Caption := Tr('Font...');
  FBtnFont.OnClick := @DoFontDialog;
  AddLabel(P, 400, 16, 70, Tr('Font size:'));
  FFontSize := AddSpin(P, 470, 12, 80, FSettings.FontSize, 6, 48);

  AddLabel(P, 16, 56, 80, Tr('Tab size:'));
  FTabSize := AddSpin(P, 110, 52, 80, FSettings.TabSize, 1, 32);
  FTabSpaces := AddCheck(P, 210, 56, 180, Tr('Use spaces for tabs'), FSettings.TabSpaces);

  FWordWrap := AddCheck(P, 16, 100, 160, Tr('Word wrap'), FSettings.WordWrap);
  FWhitespace := AddCheck(P, 190, 100, 180, Tr('Show whitespace'), FSettings.ShowWhitespace);
  FNumbers := AddCheck(P, 16, 132, 160, Tr('Line numbers'), FSettings.ShowNumbers);
  FCurLine := AddCheck(P, 190, 132, 180, Tr('Highlight current line'), FSettings.ShowCurLine);
  FIndentGuides := AddCheck(P, 16, 164, 160, Tr('Indent guides'), FSettings.ShowIndentGuides);
  FFolding := AddCheck(P, 190, 164, 160, Tr('Folding margin'), FSettings.ShowFolding);
  FRuler := AddCheck(P, 370, 164, 160, Tr('Ruler'), FSettings.ShowRuler);
  FBookmarkMargin := AddCheck(P, 16, 196, 180, Tr('Bookmark margin'), FSettings.ShowBookmarkMargin);
  FMinimap := AddCheck(P, 190, 196, 160, Tr('Minimap'), FSettings.ShowMinimap);
  FMicromap := AddCheck(P, 16, 228, 160, Tr('Micromap'), FSettings.ShowMicromap);
  FAutoIndent := AddCheck(P, 16, 260, 160, Tr('Auto indent'), FSettings.AutoIndent);
  FAutoPair := AddCheck(P, 190, 260, 180, Tr('Auto close brackets'), FSettings.AutoPair);
  FSmoothScroll := AddCheck(P, 16, 292, 160, Tr('Smooth scrolling'), FSettings.SmoothScroll);
  FCaretBlink := AddCheck(P, 190, 292, 160, Tr('Caret blinking'), FSettings.CaretBlink);
  AddLabel(P, 16, 332, 180, Tr('Line number mode:'));
  FNumberMode := AddCombo(P, 200, 328, 220);
  FNumberMode.Items.Add(Tr('All lines'));
  FNumberMode.Items.Add(Tr('Every 5th line'));
  FNumberMode.Items.Add(Tr('Every 10th line'));
  FNumberMode.Items.Add(Tr('Relative line numbers'));
  FNumberMode.Items.Add(Tr('Marks only (dots)'));
  FNumberMode.ItemIndex := 0;
  for i := 0 to High(NumberStyleIDs) do
    if SameText(FSettings.NumbersStyle, NumberStyleIDs[i]) then
    begin
      FNumberMode.ItemIndex := i;
      Break;
    end;

  AddLabel(P, 16, 364, 180, Tr('Editor color scheme:'));
  FColorSchemeCombo := AddCombo(P, 200, 360, 220);
  Names := ColorSchemeNames;
  try
    FColorSchemeCombo.Items.Assign(Names);
  finally
    Names.Free;
  end;
  FColorSchemeCombo.ItemIndex := FColorSchemeCombo.Items.IndexOf(FSettings.ColorScheme);
  if FColorSchemeCombo.ItemIndex < 0 then FColorSchemeCombo.ItemIndex := 0;
end;

procedure TSettingsForm.BuildFilesPage;
var
  P: TTyPanel;
  i, Idx: Integer;
begin
  P := FPages[2];
  AddLabel(P, 16, 16, 130, Tr('Default encoding:'));
  FEncodingCombo := AddCombo(P, 160, 12, 260);
  for i := 0 to High(FEncodingChoices) do
    FEncodingCombo.Items.Add(FEncodingChoices[i].Display);
  Idx := 0;
  for i := 0 to High(FEncodingChoices) do
    if SameText(FEncodingChoices[i].Name, FSettings.DefaultEncoding) then
    begin
      Idx := i;
      Break;
    end;
  FEncodingCombo.ItemIndex := Idx;

  AddLabel(P, 16, 56, 130, Tr('Default line ending:'));
  FEolCombo := AddCombo(P, 160, 52, 160);
  FEolCombo.Items.Add('CRLF');
  FEolCombo.Items.Add('LF');
  FEolCombo.Items.Add('CR');
  if SameText(FSettings.DefaultEol, 'CRLF') then FEolCombo.ItemIndex := 0
  else if SameText(FSettings.DefaultEol, 'CR') then FEolCombo.ItemIndex := 2
  else FEolCombo.ItemIndex := 1;

  FTrimTrailing := AddCheck(P, 16, 100, 300, Tr('Trim trailing spaces on save'), FSettings.TrimTrailingSpaces);
  FForceFinal := AddCheck(P, 16, 132, 300, Tr('Ensure final newline on save'), FSettings.ForceFinalEol);

  AddLabel(P, 16, 172, 180, Tr('Recent files (maximum):'));
  FRecentMax := AddSpin(P, 210, 168, 90, FSettings.RecentMax, 1, 100);
  // automatic session saves are controlled by the interval on the General page
end;

procedure TSettingsForm.BuildSearchPage;
var
  P: TTyPanel;
begin
  P := FPages[3];
  AddLabel(P, 16, 16, 300, Tr('Default search options:'));
  FFindCase := AddCheck(P, 16, 50, 220, Tr('Match case'), FSettings.FindCase);
  FFindWords := AddCheck(P, 16, 82, 220, Tr('Whole word'), FSettings.FindWords);
  FFindRegex := AddCheck(P, 16, 114, 220, Tr('Regular expression'), FSettings.FindRegex);
  FFindWrap := AddCheck(P, 16, 146, 220, Tr('Wrap around'), FSettings.FindWrap);
end;

procedure TSettingsForm.CategoryChanged(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to High(FPages) do
    FPages[i].Visible := i = FCategory.ItemIndex;
end;

procedure TSettingsForm.DoBackupBrowse(Sender: TObject);
var
  D: string;
begin
  D := FBackupDirEdit.Text;
  if TySelectDirectory(Tr('Choose backup folder'), '', D) then
    FBackupDirEdit.Text := D;
end;

procedure TSettingsForm.DoFontDialog(Sender: TObject);
var
  F: TFont;
begin
  F := TFont.Create;
  try
    F.Name := FFontCombo.SelectedFont;
    F.Size := FFontSize.Value;
    if TyFontDialog(F) then
    begin
      FFontCombo.SelectedFont := F.Name;
      FFontSize.Value := F.Size;
    end;
  finally
    F.Free;
  end;
end;

procedure TSettingsForm.DoOK(Sender: TObject);
begin
  if FThemeCombo.ItemIndex >= 0 then
    FSettings.Theme := FThemeNames[FThemeCombo.ItemIndex];
  if FLangCombo.ItemIndex >= 0 then
    FSettings.Language := FLangIDs[FLangCombo.ItemIndex];
  FSettings.FontName := FFontCombo.SelectedFont;
  FSettings.FontSize := FFontSize.Value;
  FSettings.TabSize := FTabSize.Value;
  FSettings.TabSpaces := FTabSpaces.Checked;
  FSettings.WordWrap := FWordWrap.Checked;
  FSettings.ShowWhitespace := FWhitespace.Checked;
  FSettings.ShowNumbers := FNumbers.Checked;
  case FNumberMode.ItemIndex of
    1: FSettings.NumbersStyle := 'each5';
    2: FSettings.NumbersStyle := 'each10';
    3: FSettings.NumbersStyle := 'relative';
    4: FSettings.NumbersStyle := 'none';
  else
    FSettings.NumbersStyle := 'all';
  end;
  FSettings.ShowCurLine := FCurLine.Checked;
  FSettings.ShowIndentGuides := FIndentGuides.Checked;
  FSettings.AutoIndent := FAutoIndent.Checked;
  FSettings.AutoPair := FAutoPair.Checked;
  FSettings.SmoothScroll := FSmoothScroll.Checked;
  FSettings.CaretBlink := FCaretBlink.Checked;
  if FColorSchemeCombo.ItemIndex >= 0 then
    FSettings.ColorScheme := FColorSchemeCombo.Items[FColorSchemeCombo.ItemIndex];
  FSettings.ShowFolding := FFolding.Checked;
  FSettings.ShowRuler := FRuler.Checked;
  FSettings.ShowBookmarkMargin := FBookmarkMargin.Checked;
  FSettings.ShowMinimap := FMinimap.Checked;
  FSettings.ShowMicromap := FMicromap.Checked;
  FSettings.TrimTrailingSpaces := FTrimTrailing.Checked;
  FSettings.ForceFinalEol := FForceFinal.Checked;
  FSettings.RecentMax := FRecentMax.Value;
  if FEncodingCombo.ItemIndex >= 0 then
    FSettings.DefaultEncoding := FEncodingChoices[FEncodingCombo.ItemIndex].Name;
  if FEolCombo.ItemIndex >= 0 then
    FSettings.DefaultEol := FEolCombo.Items[FEolCombo.ItemIndex];
  FSettings.FindCase := FFindCase.Checked;
  FSettings.FindWords := FFindWords.Checked;
  FSettings.FindRegex := FFindRegex.Checked;
  FSettings.FindWrap := FFindWrap.Checked;
  FSettings.RestoreSession := FRestore.Checked;
  FSettings.DarkMode := FDarkMode.Checked;
  FSettings.AutoSnapshotSec := FSnapshot.Value;
  FSettings.BackupDir := FBackupDirEdit.Text;
  FSettings.SingleInstance := FSingleInstance.Checked;
  FSettings.BackupKeep := FBackupKeep.Value;
  FSettings.Save;
  ModalResult := mrOk;
end;

procedure TSettingsForm.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TSettingsForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.
