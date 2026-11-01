unit utooleditdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.Memo, tyControls.Edit, tyControls.ComboBox,
  tyControls.SpinEdit, tyControls.CheckBox, tyControls.TyLabel, tyControls.Button,
  tyControls.Dialogs, tyControls.Dialogs.SelectPath,
  utools, utranslation;

type
  TToolEditForm = class(TTyForm)
  private
    FOriginal: TExternalTool;
    FTool: TExternalTool;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FNameEdit, FCommandEdit, FDirEdit: TTyEdit;
    FArgs: TTyMemo;
    FInputCombo, FOutputCombo, FSaveCombo: TTyComboBox;
    FTimeout: TTySpinEdit;
    FEnabled: TTyCheckBox;
    FBrowseCommand, FBrowseDir, FOK, FCancel: TTyButton;
    procedure BuildUI;
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure DoBrowseCommand(Sender: TObject);
    procedure DoBrowseDir(Sender: TObject);
    function AddLabel(AX, AY, AW: Integer; const ACaption: string): TTyLabel;
  public
    constructor Create(AOwner: TComponent; ATool: TExternalTool);
    destructor Destroy; override;
    function Execute: Boolean;
  end;

implementation

constructor TToolEditForm.Create(AOwner: TComponent; ATool: TExternalTool);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FOriginal := ATool;
  FTool := TExternalTool.Create;
  if ATool <> nil then
    FTool.Assign(ATool);
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Caption := Tr('Edit Tool');
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
end;

destructor TToolEditForm.Destroy;
begin
  FTool.Free;
  inherited;
end;

function TToolEditForm.AddLabel(AX, AY, AW: Integer;
  const ACaption: string): TTyLabel;
begin
  Result := TTyLabel.Create(Self);
  Result.Parent := FSurface;
  Result.SetBounds(AX, AY, AW, 24);
  Result.Caption := ACaption;
end;

procedure TToolEditForm.BuildUI;
var
  PlaceholderHint: TTyLabel;
begin
  SetBounds(0, 0, 700, 600);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Edit Tool');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  AddLabel(16, 56, 100, Tr('Name:'));
  FNameEdit := TTyEdit.Create(Self);
  FNameEdit.Parent := FSurface;
  FNameEdit.SetBounds(130, 52, 540, 30);
  FNameEdit.Text := FTool.Name;

  AddLabel(16, 96, 100, Tr('Command:'));
  FCommandEdit := TTyEdit.Create(Self);
  FCommandEdit.Parent := FSurface;
  FCommandEdit.SetBounds(130, 92, 450, 30);
  FCommandEdit.Text := FTool.Command;
  FCommandEdit.TextHint := Tr('Executable name or path');

  FBrowseCommand := TTyButton.Create(Self);
  FBrowseCommand.Parent := FSurface;
  FBrowseCommand.SetBounds(500, 92, 80, 30);
  FBrowseCommand.Caption := Tr('Browse...');
  FBrowseCommand.OnClick := @DoBrowseCommand;

  AddLabel(16, 136, 110, Tr('Working folder:'));
  FDirEdit := TTyEdit.Create(Self);
  FDirEdit.Parent := FSurface;
  FDirEdit.SetBounds(130, 132, 450, 30);
  FDirEdit.Text := FTool.WorkingDir;
  FDirEdit.TextHint := Tr('Empty uses the file folder');

  FBrowseDir := TTyButton.Create(Self);
  FBrowseDir.Parent := FSurface;
  FBrowseDir.SetBounds(500, 132, 80, 30);
  FBrowseDir.Caption := Tr('Browse...');
  FBrowseDir.OnClick := @DoBrowseDir;

  AddLabel(16, 176, 110, Tr('Arguments:'));
  FArgs := TTyMemo.Create(Self);
  FArgs.Parent := FSurface;
  FArgs.SetBounds(130, 172, 540, 120);
  FArgs.ScrollBars := ssAutoVertical;
  FArgs.WordWrap := False;
  FArgs.Text := FTool.ArgumentText;

  PlaceholderHint := AddLabel(16, 300, 660,
    Tr('Placeholders: ${file} ${filename} ${dir} ${line} ${col} ${lexer} ${encoding} ${eol} ${inputfile}'));
  PlaceholderHint.WordWrap := True;
  PlaceholderHint.Height := 40;

  AddLabel(16, 344, 110, Tr('Input:'));
  FInputCombo := TTyComboBox.Create(Self);
  FInputCombo.Parent := FSurface;
  FInputCombo.SetBounds(130, 340, 200, 30);
  FInputCombo.Items.Add(Tr('None'));
  FInputCombo.Items.Add(Tr('Selection'));
  FInputCombo.Items.Add(Tr('Document'));
  FInputCombo.ItemIndex := Ord(FTool.InputMode);

  AddLabel(360, 344, 90, Tr('Save before:'));
  FSaveCombo := TTyComboBox.Create(Self);
  FSaveCombo.Parent := FSurface;
  FSaveCombo.SetBounds(460, 340, 210, 30);
  FSaveCombo.Items.Add(Tr('Never'));
  FSaveCombo.Items.Add(Tr('Current file'));
  FSaveCombo.Items.Add(Tr('All files'));
  FSaveCombo.ItemIndex := Ord(FTool.SaveMode);

  AddLabel(16, 384, 110, Tr('Output:'));
  FOutputCombo := TTyComboBox.Create(Self);
  FOutputCombo.Parent := FSurface;
  FOutputCombo.SetBounds(130, 380, 540, 30);
  FOutputCombo.Items.Add(Tr('Ignore'));
  FOutputCombo.Items.Add(Tr('Show in a window'));
  FOutputCombo.Items.Add(Tr('Insert at caret'));
  FOutputCombo.Items.Add(Tr('Replace selection'));
  FOutputCombo.Items.Add(Tr('Replace document'));
  FOutputCombo.ItemIndex := Ord(FTool.OutputMode);

  AddLabel(16, 424, 110, Tr('Timeout (sec):'));
  FTimeout := TTySpinEdit.Create(Self);
  FTimeout.Parent := FSurface;
  FTimeout.SetBounds(130, 420, 90, 30);
  FTimeout.MinValue := 1;
  FTimeout.MaxValue := 600;
  FTimeout.Value := FTool.TimeoutMs div 1000;

  FEnabled := TTyCheckBox.Create(Self);
  FEnabled.Parent := FSurface;
  FEnabled.SetBounds(260, 424, 220, 24);
  FEnabled.Caption := Tr('Enabled');
  FEnabled.Checked := FTool.Enabled;

  FOK := TTyButton.Create(Self);
  FOK.Parent := FSurface;
  FOK.SetBounds(470, 520, 90, 32);
  FOK.Caption := Tr('OK');
  FOK.OnClick := @DoOK;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(570, 520, 100, 32);
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TToolEditForm.DoBrowseCommand(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := Tr('Choose executable');
    Dialog.Filter := 'All files (*.*)|*.*';
    Dialog.Options := [ofFileMustExist];
    if FCommandEdit.Text <> '' then
      Dialog.FileName := FCommandEdit.Text;
    if Dialog.Execute then
      FCommandEdit.Text := Dialog.FileName;
  finally
    Dialog.Free;
  end;
end;

procedure TToolEditForm.DoBrowseDir(Sender: TObject);
var
  Dir: string;
begin
  Dir := FDirEdit.Text;
  if TySelectDirectory(Tr('Choose working folder'), '', Dir) then
    FDirEdit.Text := Dir;
end;

procedure TToolEditForm.DoOK(Sender: TObject);
var
  ErrorText: string;
begin
  FTool.Name := Trim(FNameEdit.Text);
  FTool.Command := Trim(FCommandEdit.Text);
  FTool.WorkingDir := Trim(FDirEdit.Text);
  FTool.SetArgumentText(FArgs.Text);
  FTool.InputMode := TToolInputMode(FInputCombo.ItemIndex);
  FTool.OutputMode := TToolOutputMode(FOutputCombo.ItemIndex);
  FTool.SaveMode := TToolSaveMode(FSaveCombo.ItemIndex);
  FTool.TimeoutMs := FTimeout.Value * 1000;
  FTool.Enabled := FEnabled.Checked;

  if not ValidateTool(FTool, ErrorText) then
  begin
    if Trim(FTool.Name) = '' then
      ErrorText := Tr('Tool name is required.')
    else if Trim(FTool.Command) = '' then
      ErrorText := Tr('Tool command is required.');
    TyMessageDlg(ErrorText, mtError, [mbOK]);
    Exit;
  end;

  if FOriginal <> nil then
    FOriginal.Assign(FTool);
  ModalResult := mrOk;
end;

procedure TToolEditForm.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TToolEditForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.
