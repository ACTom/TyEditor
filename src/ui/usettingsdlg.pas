unit usettingsdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.AdvancedListBox, tyControls.ScrollBox,
  tyControls.TyLabel, tyControls.Edit, tyControls.CheckBox, tyControls.Button,
  tyControls.ComboBox, tyControls.SpinEdit, tyControls.FontComboBox,
  tyControls.Dialogs.Font, tyControls.Dialogs.SelectPath,
  usettings, uencoding, utranslation, ucolorscheme, uutils;

type
  TSettingsForm = class(TTyForm)
  private
    FSettings: TAppSettings;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FCategory: TTyAdvancedListBox;
    FPageHost: TTyPanel;
    FPages: array[0..4] of TTyScrollBox;
    FThemeNames: TStringList;
    FLangIDs: TStringList;
    FEncodingChoices: TEncodingChoiceArray;

    FLangCombo, FThemeCombo, FEncodingCombo, FEolCombo, FColorSchemeCombo,
    FNumberMode: TTyComboBox;
    FFontCombo, FPrintFontCombo: TTyFontComboBox;
    FBackupDirEdit: TTyEdit;
    FDefaultBackupDir: string;
    FBackupKeep: TTySpinEdit;
    FBtnFont, FBtnBackup, FBtnBackupDefault: TTyButton;
    FFontSize, FTabSize, FSnapshot, FRecentMax, FPrintFontSize: TTySpinEdit;
    FMarginLeft, FMarginTop, FMarginRight, FMarginBottom: TTySpinEdit;
    FTabSpaces, FWordWrap, FWhitespace, FNumbers, FCurLine, FIndentGuides, FFolding,
    FRuler, FBookmarkMargin, FMinimap, FMicromap,
    FTrimTrailing, FForceFinal, FRestore, FDarkMode, FSingleInstance, FAlwaysOnTop,
    FLigatures, FAutoIndent, FAutoPair, FSmoothScroll,
    FCaretBlink, FPrintSelectionOnly, FPrintSyntaxHighlighting, FPrintLineNumbers,
    FPrintWrapLines, FPrintHeader, FPrintFooter: TTyCheckBox;
    FOK, FCancel, FDefaults: TTyButton;

    procedure BuildUI;
    procedure BuildGeneralPage;
    procedure BuildAppearancePage;
    procedure BuildEditorPage;
    procedure BuildFilesPage;
    procedure BuildPrintingPage;
    procedure CategoryChanged(Sender: TObject);
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    function AddLabel(AParent: TWinControl; AX, AY, AW: Integer;
      const ACaption: string): TTyLabel;
    function AddCheck(AParent: TWinControl; AX, AY, AW: Integer;
      const ACaption: string; AChecked: Boolean): TTyCheckBox;
    function AddSpin(AParent: TWinControl; AX, AY, AW, AValue, AMin, AMax: Integer): TTySpinEdit;
    function AddCombo(AParent: TWinControl; AX, AY, AW: Integer): TTyComboBox;
    procedure DoFontDialog(Sender: TObject);
    procedure DoBackupBrowse(Sender: TObject);
    procedure DoBackupDefault(Sender: TObject);
    procedure DoRestoreDefaults(Sender: TObject);
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
  BorderIcons := [biSystemMenu, biMaximize];
  Position := poScreenCenter;
  SetBounds(0, 0, 900, 660);
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 560;
  Resizable := True;
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

  FCategory := TTyAdvancedListBox.Create(Self);
  FCategory.Parent := FSurface;
  FCategory.SetBounds(16, 50, 210, 545);
  FCategory.Anchors := [akLeft, akTop, akBottom];
  FCategory.AddItem(Tr('General'), Tr('Language and startup'), -1);
  FCategory.AddItem(Tr('Appearance'), Tr('Font and colors'), -1);
  FCategory.AddItem(Tr('Editor'), Tr('Tabs and display'), -1);
  FCategory.AddItem(Tr('Files'), Tr('Encoding and backups'), -1);
  FCategory.AddItem(Tr('Printing'), Tr('Font, colors and margins'), -1);
  FCategory.ItemIndex := 0;
  FCategory.OnClick := @CategoryChanged;
  FCategory.OnChange := @CategoryChanged;

  FPageHost := TTyPanel.Create(Self);
  FPageHost.Parent := FSurface;
  FPageHost.SetBounds(238, 50, 646, 545);
  FPageHost.Anchors := [akLeft, akTop, akRight, akBottom];

  for i := 0 to High(FPages) do
  begin
    FPages[i] := TTyScrollBox.Create(Self);
    FPages[i].Parent := FPageHost;
    FPages[i].Align := alClient;
    FPages[i].Visible := False;
  end;

  BuildGeneralPage;
  BuildAppearancePage;
  BuildEditorPage;
  BuildFilesPage;
  BuildPrintingPage;
  FPages[0].Visible := True;

  FDefaults := TTyButton.Create(Self);
  FDefaults.Parent := FSurface;
  FDefaults.SetBounds(16, 608, 140, 32);
  FDefaults.Anchors := [akLeft, akBottom];
  FDefaults.Caption := Tr('Restore Defaults');
  FDefaults.OnClick := @DoRestoreDefaults;

  FOK := TTyButton.Create(Self);
  FOK.Parent := FSurface;
  FOK.SetBounds(684, 608, 90, 32);
  FOK.Anchors := [akRight, akBottom];
  FOK.Caption := Tr('OK');
  FOK.OnClick := @DoOK;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(784, 608, 100, 32);
  FCancel.Anchors := [akRight, akBottom];
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TSettingsForm.BuildGeneralPage;
var
  P: TTyScrollBox;
  i, Idx: Integer;
  D: TStringList;
begin
  P := FPages[0];
  AddLabel(P, 16, 16, 180, Tr('UI language:'));
  FLangCombo := AddCombo(P, 220, 12, 260);
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

  AddLabel(P, 16, 56, 180, Tr('Interface theme:'));
  FThemeCombo := AddCombo(P, 220, 52, 260);
  for i := 0 to FThemeNames.Count - 1 do
    FThemeCombo.Items.Add(FThemeNames[i]);
  Idx := FThemeNames.IndexOf(FSettings.Theme);
  if Idx < 0 then Idx := 0;
  FThemeCombo.ItemIndex := Idx;

  FDarkMode := AddCheck(P, 16, 100, 420, Tr('Dark mode'), FSettings.DarkMode);
  FRestore := AddCheck(P, 16, 132, 420, Tr('Restore session on startup'), FSettings.RestoreSession);
  FSingleInstance := AddCheck(P, 16, 164, 420, Tr('Single instance'), FSettings.SingleInstance);
  FAlwaysOnTop := AddCheck(P, 16, 196, 420, Tr('Always on top'), FSettings.AlwaysOnTop);

  AddLabel(P, 16, 240, 200, Tr('Recent files (maximum):'));
  FRecentMax := AddSpin(P, 220, 236, 100, FSettings.RecentMax, 1, 100);
end;

procedure TSettingsForm.BuildAppearancePage;
var
  P: TTyScrollBox;
  Names: TStringList;
begin
  P := FPages[1];
  AddLabel(P, 16, 16, 100, Tr('Font family:'));
  FFontCombo := TTyFontComboBox.Create(Self);
  FFontCombo.Parent := P;
  FFontCombo.SetBounds(130, 12, 240, 30);
  FFontCombo.FixedPitchOnly := False;
  FFontCombo.SelectedFont := FSettings.FontName;
  FBtnFont := TTyButton.Create(Self);
  FBtnFont.Parent := P;
  FBtnFont.SetBounds(380, 12, 80, 30);
  FBtnFont.Caption := Tr('Font...');
  FBtnFont.OnClick := @DoFontDialog;
  AddLabel(P, 16, 56, 100, Tr('Font size:'));
  FFontSize := AddSpin(P, 130, 52, 80, FSettings.FontSize, 6, 48);
  FLigatures := AddCheck(P, 230, 56, 300, Tr('Enable font ligatures'), FSettings.FontLigatures);

  AddLabel(P, 16, 104, 200, Tr('Editor color scheme:'));
  FColorSchemeCombo := AddCombo(P, 220, 100, 260);
  Names := ColorSchemeNames;
  try
    FColorSchemeCombo.Items.Assign(Names);
  finally
    Names.Free;
  end;
  FColorSchemeCombo.ItemIndex := FColorSchemeCombo.Items.IndexOf(FSettings.ColorScheme);
  if FColorSchemeCombo.ItemIndex < 0 then FColorSchemeCombo.ItemIndex := 0;
end;

procedure TSettingsForm.BuildEditorPage;
const
  NumberStyleIDs: array[0..4] of string =
    ('all', 'each5', 'each10', 'relative', 'none');
var
  P: TTyScrollBox;
  i: Integer;
begin
  P := FPages[2];
  AddLabel(P, 16, 16, 80, Tr('Tab size:'));
  FTabSize := AddSpin(P, 110, 12, 80, FSettings.TabSize, 1, 32);
  FTabSpaces := AddCheck(P, 210, 16, 220, Tr('Use spaces for tabs'), FSettings.TabSpaces);

  FWordWrap := AddCheck(P, 16, 60, 180, Tr('Word wrap'), FSettings.WordWrap);
  FWhitespace := AddCheck(P, 220, 60, 180, Tr('Show whitespace'), FSettings.ShowWhitespace);
  FNumbers := AddCheck(P, 16, 92, 180, Tr('Line numbers'), FSettings.ShowNumbers);
  FCurLine := AddCheck(P, 220, 92, 180, Tr('Highlight current line'), FSettings.ShowCurLine);
  FIndentGuides := AddCheck(P, 16, 124, 180, Tr('Indent guides'), FSettings.ShowIndentGuides);
  FFolding := AddCheck(P, 220, 124, 180, Tr('Folding margin'), FSettings.ShowFolding);
  FRuler := AddCheck(P, 420, 124, 160, Tr('Ruler'), FSettings.ShowRuler);
  FBookmarkMargin := AddCheck(P, 16, 156, 180, Tr('Bookmark margin'), FSettings.ShowBookmarkMargin);
  FMinimap := AddCheck(P, 220, 156, 160, Tr('Minimap'), FSettings.ShowMinimap);
  FMicromap := AddCheck(P, 16, 188, 160, Tr('Micromap'), FSettings.ShowMicromap);
  FAutoIndent := AddCheck(P, 16, 220, 160, Tr('Auto indent'), FSettings.AutoIndent);
  FAutoPair := AddCheck(P, 220, 220, 180, Tr('Auto close brackets'), FSettings.AutoPair);
  FSmoothScroll := AddCheck(P, 16, 252, 160, Tr('Smooth scrolling'), FSettings.SmoothScroll);
  FCaretBlink := AddCheck(P, 220, 252, 160, Tr('Caret blinking'), FSettings.CaretBlink);
  AddLabel(P, 16, 296, 180, Tr('Line number mode:'));
  FNumberMode := AddCombo(P, 220, 292, 260);
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
end;

procedure TSettingsForm.BuildFilesPage;
var
  P: TTyScrollBox;
  i, Idx: Integer;
begin
  P := FPages[3];
  AddLabel(P, 16, 16, 180, Tr('Default encoding:'));
  FEncodingCombo := AddCombo(P, 220, 12, 280);
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

  AddLabel(P, 16, 56, 180, Tr('Default line ending:'));
  FEolCombo := AddCombo(P, 220, 52, 160);
  FEolCombo.Items.Add('CRLF');
  FEolCombo.Items.Add('LF');
  FEolCombo.Items.Add('CR');
  if SameText(FSettings.DefaultEol, 'CRLF') then FEolCombo.ItemIndex := 0
  else if SameText(FSettings.DefaultEol, 'CR') then FEolCombo.ItemIndex := 2
  else FEolCombo.ItemIndex := 1;

  FTrimTrailing := AddCheck(P, 16, 100, 420, Tr('Trim trailing spaces on save'), FSettings.TrimTrailingSpaces);
  FForceFinal := AddCheck(P, 16, 132, 420, Tr('Ensure final newline on save'), FSettings.ForceFinalEol);

  AddLabel(P, 16, 176, 200, Tr('Backup folder:'));
  FBackupDirEdit := TTyEdit.Create(Self);
  FBackupDirEdit.Parent := P;
  FBackupDirEdit.SetBounds(220, 172, 250, 30);
  FDefaultBackupDir := DefaultBackupDir;
  if Trim(FSettings.BackupDir) = '' then
    FBackupDirEdit.Text := FDefaultBackupDir
  else
    FBackupDirEdit.Text := FSettings.BackupDir;
  FBtnBackup := TTyButton.Create(Self);
  FBtnBackup.Parent := P;
  FBtnBackup.SetBounds(476, 172, 80, 30);
  FBtnBackup.Caption := Tr('Browse...');
  FBtnBackup.OnClick := @DoBackupBrowse;
  FBtnBackupDefault := TTyButton.Create(Self);
  FBtnBackupDefault.Parent := P;
  FBtnBackupDefault.SetBounds(562, 172, 80, 30);
  FBtnBackupDefault.Caption := Tr('Default');
  FBtnBackupDefault.OnClick := @DoBackupDefault;
  AddLabel(P, 16, 216, 200, Tr('Keep backups:'));
  FBackupKeep := AddSpin(P, 220, 212, 100, FSettings.BackupKeep, 1, 1000);

  AddLabel(P, 16, 260, 200, Tr('Auto save session (seconds):'));
  FSnapshot := AddSpin(P, 220, 256, 100, FSettings.AutoSnapshotSec, 5, 3600);
end;

procedure TSettingsForm.BuildPrintingPage;
var
  P: TTyScrollBox;
begin
  P := FPages[4];
  AddLabel(P, 16, 16, 100, Tr('Font family:'));
  FPrintFontCombo := TTyFontComboBox.Create(Self);
  FPrintFontCombo.Parent := P;
  FPrintFontCombo.SetBounds(130, 12, 240, 30);
  FPrintFontCombo.FixedPitchOnly := False;
  FPrintFontCombo.SelectedFont := FSettings.PrintFontName;
  AddLabel(P, 16, 56, 100, Tr('Font size:'));
  FPrintFontSize := AddSpin(P, 130, 52, 80, FSettings.PrintFontSize, 6, 48);

  FPrintLineNumbers := AddCheck(P, 16, 100, 300, Tr('Line numbers'), FSettings.PrintLineNumbers);
  FPrintWrapLines := AddCheck(P, 16, 132, 300, Tr('Wrap long lines'), FSettings.PrintWrapLines);
  FPrintHeader := AddCheck(P, 16, 164, 300, Tr('Print header'), FSettings.PrintHeader);
  FPrintFooter := AddCheck(P, 16, 196, 300, Tr('Print footer'), FSettings.PrintFooter);
  FPrintSelectionOnly := AddCheck(P, 16, 228, 420, Tr('Print selection only'),
    FSettings.PrintSelectionOnly);
  FPrintSyntaxHighlighting := AddCheck(P, 16, 260, 420,
    Tr('Syntax highlighting'), FSettings.PrintSyntaxHighlighting);

  AddLabel(P, 16, 308, 200, Tr('Left margin (mm):'));
  FMarginLeft := AddSpin(P, 220, 304, 100, FSettings.PrintMarginLeft, 0, 50);
  AddLabel(P, 16, 344, 200, Tr('Top margin (mm):'));
  FMarginTop := AddSpin(P, 220, 340, 100, FSettings.PrintMarginTop, 0, 50);
  AddLabel(P, 16, 380, 200, Tr('Right margin (mm):'));
  FMarginRight := AddSpin(P, 220, 376, 100, FSettings.PrintMarginRight, 0, 50);
  AddLabel(P, 16, 416, 200, Tr('Bottom margin (mm):'));
  FMarginBottom := AddSpin(P, 220, 412, 100, FSettings.PrintMarginBottom, 0, 50);
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

procedure TSettingsForm.DoBackupDefault(Sender: TObject);
begin
  FBackupDirEdit.Text := FDefaultBackupDir;
end;

procedure TSettingsForm.DoRestoreDefaults(Sender: TObject);
var
  D: TAppSettings;
  Index: Integer;
begin
  D := TAppSettings.Create;
  try
    Index := FLangIDs.IndexOf(D.Language);
    if Index < 0 then Index := 0;
    FLangCombo.ItemIndex := Index;
    Index := FThemeNames.IndexOf(D.Theme);
    if Index < 0 then Index := 0;
    FThemeCombo.ItemIndex := Index;
    FDarkMode.Checked := D.DarkMode;
    FRestore.Checked := D.RestoreSession;
    FSingleInstance.Checked := D.SingleInstance;
    FAlwaysOnTop.Checked := D.AlwaysOnTop;
    FRecentMax.Value := D.RecentMax;

    FFontCombo.SelectedFont := D.FontName;
    FFontSize.Value := D.FontSize;
    FLigatures.Checked := D.FontLigatures;
    Index := FColorSchemeCombo.Items.IndexOf(D.ColorScheme);
    if Index >= 0 then FColorSchemeCombo.ItemIndex := Index;

    FTabSize.Value := D.TabSize;
    FTabSpaces.Checked := D.TabSpaces;
    FWordWrap.Checked := D.WordWrap;
    FWhitespace.Checked := D.ShowWhitespace;
    FNumbers.Checked := D.ShowNumbers;
    FCurLine.Checked := D.ShowCurLine;
    FIndentGuides.Checked := D.ShowIndentGuides;
    FFolding.Checked := D.ShowFolding;
    FRuler.Checked := D.ShowRuler;
    FBookmarkMargin.Checked := D.ShowBookmarkMargin;
    FMinimap.Checked := D.ShowMinimap;
    FMicromap.Checked := D.ShowMicromap;
    FAutoIndent.Checked := D.AutoIndent;
    FAutoPair.Checked := D.AutoPair;
    FSmoothScroll.Checked := D.SmoothScroll;
    FCaretBlink.Checked := D.CaretBlink;
    FNumberMode.ItemIndex := 0;

    FEncodingCombo.ItemIndex := 0;
    for Index := 0 to High(FEncodingChoices) do
      if SameText(FEncodingChoices[Index].Name, D.DefaultEncoding) then
      begin
        FEncodingCombo.ItemIndex := Index;
        Break;
      end;
    if SameText(D.DefaultEol, 'CRLF') then FEolCombo.ItemIndex := 0
    else if SameText(D.DefaultEol, 'CR') then FEolCombo.ItemIndex := 2
    else FEolCombo.ItemIndex := 1;
    FTrimTrailing.Checked := D.TrimTrailingSpaces;
    FForceFinal.Checked := D.ForceFinalEol;
    FBackupDirEdit.Text := FDefaultBackupDir;
    FBackupKeep.Value := D.BackupKeep;
    FSnapshot.Value := D.AutoSnapshotSec;

    FPrintFontCombo.SelectedFont := D.PrintFontName;
    FPrintFontSize.Value := D.PrintFontSize;
    FPrintLineNumbers.Checked := D.PrintLineNumbers;
    FPrintWrapLines.Checked := D.PrintWrapLines;
    FPrintHeader.Checked := D.PrintHeader;
    FPrintFooter.Checked := D.PrintFooter;
    FPrintSelectionOnly.Checked := D.PrintSelectionOnly;
    FPrintSyntaxHighlighting.Checked := D.PrintSyntaxHighlighting;
    FMarginLeft.Value := D.PrintMarginLeft;
    FMarginTop.Value := D.PrintMarginTop;
    FMarginRight.Value := D.PrintMarginRight;
    FMarginBottom.Value := D.PrintMarginBottom;
  finally
    D.Free;
  end;
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
  FSettings.FontLigatures := FLigatures.Checked;
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
  FSettings.RestoreSession := FRestore.Checked;
  FSettings.DarkMode := FDarkMode.Checked;
  FSettings.AlwaysOnTop := FAlwaysOnTop.Checked;
  FSettings.AutoSnapshotSec := FSnapshot.Value;
  if (Trim(FBackupDirEdit.Text) = '') or
     SameText(IncludeTrailingPathDelimiter(Trim(FBackupDirEdit.Text)),
       IncludeTrailingPathDelimiter(FDefaultBackupDir)) then
    FSettings.BackupDir := ''
  else
    FSettings.BackupDir := Trim(FBackupDirEdit.Text);
  FSettings.SingleInstance := FSingleInstance.Checked;
  FSettings.BackupKeep := FBackupKeep.Value;

  FSettings.PrintFontName := FPrintFontCombo.SelectedFont;
  FSettings.PrintFontSize := FPrintFontSize.Value;
  FSettings.PrintSelectionOnly := FPrintSelectionOnly.Checked;
  FSettings.PrintSyntaxHighlighting := FPrintSyntaxHighlighting.Checked;
  FSettings.PrintLineNumbers := FPrintLineNumbers.Checked;
  FSettings.PrintWrapLines := FPrintWrapLines.Checked;
  FSettings.PrintHeader := FPrintHeader.Checked;
  FSettings.PrintFooter := FPrintFooter.Checked;
  FSettings.PrintMarginLeft := FMarginLeft.Value;
  FSettings.PrintMarginTop := FMarginTop.Value;
  FSettings.PrintMarginRight := FMarginRight.Value;
  FSettings.PrintMarginBottom := FMarginBottom.Value;

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
