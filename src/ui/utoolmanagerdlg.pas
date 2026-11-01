unit utoolmanagerdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.CheckListBox, tyControls.Memo,
  tyControls.TyLabel, tyControls.Button, tyControls.Dialogs,
  utools, utooleditdlg, utranslation;

type
  TToolManagerForm = class(TTyForm)
  private
    FStore: TToolStore;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FList: TTyCheckListBox;
    FDetails: TTyMemo;
    FNew, FEdit, FDelete, FUp, FDown, FClose: TTyButton;
    FRefreshing: Boolean;
    procedure BuildUI;
    procedure RefreshList;
    procedure ListChanged(Sender: TObject);
    procedure CheckChanged(Sender: TObject);
    procedure DoNew(Sender: TObject);
    procedure DoEdit(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoMoveUp(Sender: TObject);
    procedure DoMoveDown(Sender: TObject);
    procedure DoCloseClick(Sender: TObject);
    function SelectedTool: TExternalTool;
    procedure SaveStore;
  public
    constructor Create(AOwner: TComponent; AStore: TToolStore);
    function Execute: Boolean;
  end;

implementation

function InputModeTitle(AMode: TToolInputMode): string;
begin
  case AMode of
    timSelection: Result := Tr('Selection');
    timDocument: Result := Tr('Document');
  else
    Result := Tr('None');
  end;
end;

function OutputModeTitle(AMode: TToolOutputMode): string;
begin
  case AMode of
    tomShow: Result := Tr('Show in a window');
    tomInsertAtCaret: Result := Tr('Insert at caret');
    tomReplaceSelection: Result := Tr('Replace selection');
    tomReplaceDocument: Result := Tr('Replace document');
  else
    Result := Tr('Ignore');
  end;
end;

function SaveModeTitle(AMode: TToolSaveMode): string;
begin
  case AMode of
    tsmCurrent: Result := Tr('Current file');
    tsmAll: Result := Tr('All files');
  else
    Result := Tr('Never');
  end;
end;

constructor TToolManagerForm.Create(AOwner: TComponent; AStore: TToolStore);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FStore := AStore;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Caption := Tr('Manage Tools');
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  RefreshList;
end;

procedure TToolManagerForm.BuildUI;
begin
  SetBounds(0, 0, 760, 540);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Manage Tools');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FList := TTyCheckListBox.Create(Self);
  FList.Parent := FSurface;
  FList.SetBounds(16, 52, 390, 380);
  FList.OnChange := @ListChanged;
  FList.OnClickCheck := @CheckChanged;

  FDetails := TTyMemo.Create(Self);
  FDetails.Parent := FSurface;
  FDetails.SetBounds(420, 52, 324, 380);
  FDetails.ReadOnly := True;
  FDetails.ScrollBars := ssAutoVertical;
  FDetails.WordWrap := True;

  FNew := TTyButton.Create(Self);
  FNew.Parent := FSurface;
  FNew.SetBounds(16, 448, 90, 32);
  FNew.Caption := Tr('New...');
  FNew.OnClick := @DoNew;

  FEdit := TTyButton.Create(Self);
  FEdit.Parent := FSurface;
  FEdit.SetBounds(114, 448, 90, 32);
  FEdit.Caption := Tr('Edit...');
  FEdit.OnClick := @DoEdit;

  FDelete := TTyButton.Create(Self);
  FDelete.Parent := FSurface;
  FDelete.SetBounds(212, 448, 90, 32);
  FDelete.Caption := Tr('Delete');
  FDelete.OnClick := @DoDelete;

  FUp := TTyButton.Create(Self);
  FUp.Parent := FSurface;
  FUp.SetBounds(310, 448, 80, 32);
  FUp.Caption := Tr('Move Up');
  FUp.OnClick := @DoMoveUp;

  FDown := TTyButton.Create(Self);
  FDown.Parent := FSurface;
  FDown.SetBounds(398, 448, 80, 32);
  FDown.Caption := Tr('Move Down');
  FDown.OnClick := @DoMoveDown;

  FClose := TTyButton.Create(Self);
  FClose.Parent := FSurface;
  FClose.SetBounds(644, 448, 100, 32);
  FClose.Caption := Tr('Close');
  FClose.OnClick := @DoCloseClick;
end;

function TToolManagerForm.SelectedTool: TExternalTool;
var
  Index: Integer;
begin
  Result := nil;
  Index := FList.ItemIndex;
  if (Index >= 0) and (Index < FStore.Count) then
    Result := FStore[Index];
end;

procedure TToolManagerForm.RefreshList;
var
  i: Integer;
  Tool: TExternalTool;
  OldIndex: Integer;
  LineText: string;
begin
  FRefreshing := True;
  try
    OldIndex := FList.ItemIndex;
    FList.Items.BeginUpdate;
    try
      FList.Items.Clear;
      for i := 0 to FStore.Count - 1 do
      begin
        Tool := FStore[i];
        if Tool.Enabled then
          LineText := Tool.Name
        else
          LineText := Tool.Name + '  (' + Tr('disabled') + ')';
        FList.Items.Add(LineText);
        FList.Checked[i] := Tool.Enabled;
      end;
    finally
      FList.Items.EndUpdate;
    end;
    if FList.Items.Count = 0 then
    begin
      FList.Items.Add(Tr('No tools configured'));
      FList.ItemEnabled[0] := False;
    end;
    if (OldIndex >= 0) and (OldIndex < FList.Items.Count) then
      FList.ItemIndex := OldIndex
    else if FList.Items.Count > 0 then
      FList.ItemIndex := 0;
  finally
    FRefreshing := False;
  end;
  ListChanged(nil);
end;

procedure TToolManagerForm.ListChanged(Sender: TObject);
var
  Tool: TExternalTool;
  InfoText: string;
  i: Integer;
begin
  Tool := SelectedTool;
  if Tool = nil then
  begin
    FDetails.Text := '';
    Exit;
  end;
  InfoText := Tool.Name + LineEnding + LineEnding;
  InfoText := InfoText + Tr('Command:') + ' ' + Tool.Command + LineEnding;
  if Tool.Arguments.Count > 0 then
  begin
    InfoText := InfoText + Tr('Arguments:') + LineEnding;
    for i := 0 to Tool.Arguments.Count - 1 do
      InfoText := InfoText + '  ' + Tool.Arguments[i] + LineEnding;
  end;
  if Tool.WorkingDir <> '' then
    InfoText := InfoText + Tr('Working folder:') + ' ' + Tool.WorkingDir + LineEnding;
  InfoText := InfoText + Tr('Input:') + ' ' + InputModeTitle(Tool.InputMode) + LineEnding;
  InfoText := InfoText + Tr('Output:') + ' ' + OutputModeTitle(Tool.OutputMode) + LineEnding;
  InfoText := InfoText + Tr('Save before:') + ' ' + SaveModeTitle(Tool.SaveMode) + LineEnding;
  InfoText := InfoText + Tr('Timeout (sec):') + ' ' + IntToStr(Tool.TimeoutMs div 1000) + LineEnding;
  InfoText := InfoText + LineEnding + Tr('Configuration file:') + LineEnding +
    FStore.FileName;
  FDetails.Text := InfoText;
end;

procedure TToolManagerForm.CheckChanged(Sender: TObject);
var
  Tool: TExternalTool;
  Index: Integer;
begin
  if FRefreshing then Exit;
  Index := FList.ItemIndex;
  if (Index < 0) or (Index >= FStore.Count) then Exit;
  Tool := FStore[Index];
  Tool.Enabled := FList.Checked[Index];
  SaveStore;
  RefreshList;
end;

procedure TToolManagerForm.SaveStore;
var
  ErrorText: string;
begin
  if not FStore.Save(ErrorText) then
    TyMessageDlg(Format(Tr('Unable to save tools: %s'), [ErrorText]),
      mtError, [mbOK]);
end;

procedure TToolManagerForm.DoNew(Sender: TObject);
var
  Tool: TExternalTool;
  Dialog: TToolEditForm;
  ErrorText: string;
begin
  Tool := FStore.Add;
  Dialog := TToolEditForm.Create(Self, Tool);
  try
    if not Dialog.Execute then
    begin
      FStore.Remove(Tool);
      Exit;
    end;
  finally
    Dialog.Free;
  end;
  if not FStore.Save(ErrorText) then
  begin
    TyMessageDlg(Format(Tr('Unable to save tools: %s'), [ErrorText]),
      mtError, [mbOK]);
    Exit;
  end;
  RefreshList;
  FList.ItemIndex := FStore.Count - 1;
  ListChanged(nil);
end;

procedure TToolManagerForm.DoEdit(Sender: TObject);
var
  Tool: TExternalTool;
  Dialog: TToolEditForm;
begin
  Tool := SelectedTool;
  if Tool = nil then Exit;
  Dialog := TToolEditForm.Create(Self, Tool);
  try
    if not Dialog.Execute then Exit;
  finally
    Dialog.Free;
  end;
  SaveStore;
  RefreshList;
end;

procedure TToolManagerForm.DoDelete(Sender: TObject);
var
  Tool: TExternalTool;
begin
  Tool := SelectedTool;
  if Tool = nil then Exit;
  if TyMessageDlg(Format(Tr('Remove tool "%s"?'), [Tool.Name]),
    mtConfirmation, [mbYes, mbNo]) <> mrYes then Exit;
  FStore.Remove(Tool);
  SaveStore;
  RefreshList;
end;

procedure TToolManagerForm.DoMoveUp(Sender: TObject);
var
  Tool: TExternalTool;
begin
  Tool := SelectedTool;
  if Tool = nil then Exit;
  if FStore.MoveUp(Tool) then
  begin
    SaveStore;
    RefreshList;
    FList.ItemIndex := FStore.IndexOf(Tool);
    ListChanged(nil);
  end;
end;

procedure TToolManagerForm.DoMoveDown(Sender: TObject);
var
  Tool: TExternalTool;
begin
  Tool := SelectedTool;
  if Tool = nil then Exit;
  if FStore.MoveDown(Tool) then
  begin
    SaveStore;
    RefreshList;
    FList.ItemIndex := FStore.IndexOf(Tool);
    ListChanged(nil);
  end;
end;

procedure TToolManagerForm.DoCloseClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

function TToolManagerForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.
