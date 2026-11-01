unit ufind;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, Menus, LCLType,
  tyControls.Form, tyControls.Edit, tyControls.Button, tyControls.CheckBox,
  tyControls.TyLabel, tyControls.ListBox, tyControls.ComboBox, tyControls.Menu, tyControls.Controller,
  utranslation,
  ATSynEdit, ATSynEdit_Finder, ATSynEdit_Carets, ATSynEdit_RegExpr;

type
  TFindForm = class(TTyForm)
  private
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FFindEdit: TTyComboBox;
    FReplaceEdit: TTyEdit;
    FFindLabel: TTyLabel;
    FReplaceLabel: TTyLabel;
    FCase: TTyCheckBox;
    FWords: TTyCheckBox;
    FRegex: TTyCheckBox;
    FWrap: TTyCheckBox;
    FInSel: TTyCheckBox;
    FBtnFind: TTyButton;
    FBtnReplace: TTyButton;
    FBtnReplaceAll: TTyButton;
    FBtnCount: TTyButton;
    FBtnAll: TTyButton;
    FBtnPreview: TTyButton;
    FHistory: TStringList;
    FHistoryRef: TStringList;
    FBtnClose: TTyButton;
    FStatus: TTyLabel;
    FResults: TTyListBox;
    FFilterEdit: TTyEdit;
    FResultCache: TStringList;
    FFinder: TATEditorFinder;
    FEditor: TATSynEdit;
    procedure BuildUI;
    procedure UpdateFinder;
    procedure DoFindNext(Sender: TObject);
    procedure DoReplace(Sender: TObject);
    procedure DoReplaceAll(Sender: TObject);
    procedure DoCount(Sender: TObject);
    procedure DoFindAll(Sender: TObject);
    procedure DoPreview(Sender: TObject);
    procedure RememberFind;
    procedure FindKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DoResultDblClick(Sender: TObject);
    procedure DoFilterResults(Sender: TObject);
    procedure DoClose(Sender: TObject);
    procedure DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure SetEditor(AEditor: TATSynEdit);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowFind(AReplace: Boolean);
    procedure FocusFind;
    procedure ApplyDefaults(ACase, AWords, ARegex, AWrap: Boolean);
    procedure GetOptions(out ACase, AWords, ARegex, AWrap: Boolean);
    procedure SetFindText(const AText: string);
    procedure SetHistory(AHistory: TStringList);
    procedure FindNext;
    procedure FindPrevious;
    property Editor: TATSynEdit read FEditor write SetEditor;
    property Finder: TATEditorFinder read FFinder;
  end;

implementation

constructor TFindForm.Create(AOwner: TComponent);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  BorderIcons := [biSystemMenu];
  Position := poDesigned;
  SetBounds(220, 180, 620, 400);
  Caption := Tr('Find / Replace');
  FHistory := TStringList.Create;
  FResultCache := TStringList.Create;
  FFinder := TATEditorFinder.Create;
  FFinder.OptFromCaret := True;
  FFinder.OptWrapped := True;
  Controller := TyDefaultController;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  OnClose := @DoFormClose;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

destructor TFindForm.Destroy;
begin
  FFinder.Free;
  FHistory.Free;
  FResultCache.Free;
  inherited;
end;

procedure TFindForm.BuildUI;
begin
  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Find / Replace');
  FTitle.ShowIcon := True;
  FTitle.Height := 32;
  FTitle.TitleAlignment := taCenter;

  FFindLabel := TTyLabel.Create(Self);
  FFindLabel.Parent := FSurface;
  FFindLabel.SetBounds(16, 48, 90, 24);
  FFindLabel.Caption := Tr('Find what:');

  FFindEdit := TTyComboBox.Create(Self);
  FFindEdit.Parent := FSurface;
  FFindEdit.Style := csDropDown;
  FFindEdit.ReadOnly := False;
  FFindEdit.SetBounds(110, 44, 360, 30);
  FFindEdit.Text := '';
  FFindEdit.OnKeyDown := @FindKeyDown;

  FReplaceLabel := TTyLabel.Create(Self);
  FReplaceLabel.Parent := FSurface;
  FReplaceLabel.SetBounds(16, 86, 90, 24);
  FReplaceLabel.Caption := Tr('Replace with:');

  FReplaceEdit := TTyEdit.Create(Self);
  FReplaceEdit.Parent := FSurface;
  FReplaceEdit.SetBounds(110, 82, 360, 30);

  FCase := TTyCheckBox.Create(Self);
  FCase.Parent := FSurface;
  FCase.SetBounds(110, 122, 110, 24);
  FCase.Caption := Tr('Match case');

  FWords := TTyCheckBox.Create(Self);
  FWords.Parent := FSurface;
  FWords.SetBounds(230, 122, 120, 24);
  FWords.Caption := Tr('Whole word');

  FRegex := TTyCheckBox.Create(Self);
  FRegex.Parent := FSurface;
  FRegex.SetBounds(360, 122, 120, 24);
  FRegex.Caption := Tr('Regular expr.');

  FWrap := TTyCheckBox.Create(Self);
  FWrap.Parent := FSurface;
  FWrap.SetBounds(110, 150, 120, 24);
  FWrap.Caption := Tr('Wrap around');
  FWrap.Checked := True;

  FInSel := TTyCheckBox.Create(Self);
  FInSel.Parent := FSurface;
  FInSel.SetBounds(230, 150, 120, 24);
  FInSel.Caption := Tr('In selection');

  FBtnFind := TTyButton.Create(Self);
  FBtnFind.Parent := FSurface;
  FBtnFind.SetBounds(484, 44, 116, 30);
  FBtnFind.Caption := Tr('Find Next');
  FBtnFind.OnClick := @DoFindNext;

  FBtnReplace := TTyButton.Create(Self);
  FBtnReplace.Parent := FSurface;
  FBtnReplace.SetBounds(484, 80, 116, 30);
  FBtnReplace.Caption := Tr('Replace');
  FBtnReplace.OnClick := @DoReplace;

  FBtnReplaceAll := TTyButton.Create(Self);
  FBtnReplaceAll.Parent := FSurface;
  FBtnReplaceAll.SetBounds(484, 116, 116, 30);
  FBtnReplaceAll.Caption := Tr('Replace All');
  FBtnReplaceAll.OnClick := @DoReplaceAll;

  FBtnCount := TTyButton.Create(Self);
  FBtnCount.Parent := FSurface;
  FBtnCount.SetBounds(484, 152, 116, 30);
  FBtnCount.Caption := Tr('Count');
  FBtnCount.OnClick := @DoCount;

  FBtnPreview := TTyButton.Create(Self);
  FBtnPreview.Parent := FSurface;
  FBtnPreview.SetBounds(484, 188, 116, 30);
  FBtnPreview.Caption := Tr('Preview');
  FBtnPreview.OnClick := @DoPreview;

  FBtnAll := TTyButton.Create(Self);
  FBtnAll.Parent := FSurface;
  FBtnAll.SetBounds(484, 224, 116, 30);
  FBtnAll.Caption := Tr('Find All');
  FBtnAll.OnClick := @DoFindAll;

  FBtnClose := TTyButton.Create(Self);
  FBtnClose.Parent := FSurface;
  FBtnClose.SetBounds(484, 260, 116, 30);
  FBtnClose.Caption := Tr('Close');
  FBtnClose.OnClick := @DoClose;

  FStatus := TTyLabel.Create(Self);
  FStatus.Parent := FSurface;
  FStatus.SetBounds(16, 188, 450, 24);
  FStatus.Caption := '';

  FResults := TTyListBox.Create(Self);
  FResults.Parent := FSurface;
  FFilterEdit := TTyEdit.Create(Self);
  FFilterEdit.Parent := FSurface;
  FFilterEdit.SetBounds(16, 226, 450, 30);
  FFilterEdit.TextHint := Tr('Filter results');
  FFilterEdit.OnChange := @DoFilterResults;

  FResults.SetBounds(16, 262, 450, 100);
  FResults.OnDblClick := @DoResultDblClick;
end;

procedure TFindForm.SetEditor(AEditor: TATSynEdit);
begin
  FEditor := AEditor;
  FFinder.Editor := AEditor;
end;

procedure TFindForm.UpdateFinder;
begin
  FFinder.Editor := FEditor;
  FFinder.StrFind := FFindEdit.Text;
  FFinder.StrReplace := FReplaceEdit.Text;
  FFinder.OptCase := FCase.Checked;
  FFinder.OptWords := FWords.Checked;
  FFinder.OptRegex := FRegex.Checked;
  FFinder.OptWrapped := FWrap.Checked;
  FFinder.OptInSelection := FInSel.Checked;
end;

procedure TFindForm.DoFindNext(Sender: TObject);
var
  DidChange: Boolean;
begin
  if FEditor = nil then Exit;
  if FFindEdit.Text = '' then
  begin
    FStatus.Caption := Tr('Enter text to find.');
    Exit;
  end;
  RememberFind;
  UpdateFinder;
  try
    if FFinder.DoAction_FindOrReplace(False, False, DidChange, True) then
    begin
      FEditor.DoGotoPos(FFinder.MatchEdPos, FFinder.MatchEdEnd, 5, 5, True,
        TATEditorActionIfFolded.Unfold);
      FStatus.Caption := Format(Tr('Found at line %d, column %d.'),
        [FFinder.MatchEdPos.Y + 1, FFinder.MatchEdPos.X + 1]);
    end
    else
      FStatus.Caption := Tr('Not found.');
  except
    on E: Exception do
      FStatus.Caption := E.Message;
  end;
end;

procedure TFindForm.DoReplace(Sender: TObject);
var
  DidChange: Boolean;
begin
  if FEditor = nil then Exit;
  UpdateFinder;
  if FFindEdit.Text = '' then Exit;
  try
    if FFinder.DoAction_FindOrReplace(True, False, DidChange, True) then
    begin
      FEditor.DoGotoPos(FFinder.MatchEdPosAfterRep, Point(-1, -1), 5, 5, True,
        TATEditorActionIfFolded.Unfold);
      FStatus.Caption := Tr('Replaced one match.');
    end
    else
      FStatus.Caption := Tr('Not found.');
  except
    on E: Exception do
      FStatus.Caption := E.Message;
  end;
end;

procedure TFindForm.DoReplaceAll(Sender: TObject);
var
  N: Integer;
begin
  if FEditor = nil then Exit;
  UpdateFinder;
  if FFindEdit.Text = '' then Exit;
  try
    N := FFinder.DoAction_ReplaceAll;
    FStatus.Caption := Format(Tr('Replaced %d occurrence(s).'), [N]);
  except
    on E: Exception do
      FStatus.Caption := E.Message;
  end;
end;

procedure TFindForm.DoCount(Sender: TObject);
var
  N: Integer;
begin
  if FEditor = nil then Exit;
  UpdateFinder;
  if FFindEdit.Text = '' then Exit;
  try
    N := FFinder.DoAction_CountAll(False);
    FStatus.Caption := Format(Tr('%d occurrence(s).'), [N]);
  except
    on E: Exception do
      FStatus.Caption := E.Message;
  end;
end;

procedure TFindForm.DoFindAll(Sender: TObject);
var
  Results: TATFinderResults;
  i: Integer;
  S, LineText: string;

  function LineAt(AIndex: Integer): string;
  begin
    if (AIndex >= 0) and (AIndex < FEditor.Strings.Count) then
      Result := FEditor.Strings.Lines[AIndex]
    else
      Result := '';
  end;

begin
  if FEditor = nil then Exit;
  UpdateFinder;
  if FFindEdit.Text = '' then Exit;
  FResults.Items.BeginUpdate;
  try
    FResults.Items.Clear;
    FResultCache.Clear;
    Results := TATFinderResults.Create;
    try
      try
        FFinder.DoAction_FindAll(Results, False);
        for i := 0 to Results.Count - 1 do
        begin
          LineText := LineAt(Results[i].PosBegin.Y);
          if Length(LineText) > 120 then
            LineText := Copy(LineText, 1, 120) + '...';
          S := Format('%d:%d: %s', [Results[i].PosBegin.Y + 1,
            Results[i].PosBegin.X + 1, LineText]);
        begin
          FResults.Items.AddObject(S, TObject(PtrInt(Results[i].PosBegin.Y)));
          FResultCache.AddObject(S, TObject(PtrInt(Results[i].PosBegin.Y)));
        end;
        end;
        FStatus.Caption := Format('%d occurrence(s).', [Results.Count]);
      except
        on E: Exception do
          FStatus.Caption := E.Message;
      end;
    finally
      Results.Free;
    end;
  finally
    FResults.Items.EndUpdate;
  end;
end;

procedure TFindForm.DoFilterResults(Sender: TObject);
var
  i: Integer;
  F: string;
begin
  F := LowerCase(Trim(FFilterEdit.Text));
  FResults.Items.BeginUpdate;
  try
    FResults.Items.Clear;
    for i := 0 to FResultCache.Count - 1 do
      if (F = '') or (Pos(F, LowerCase(FResultCache[i])) > 0) then
        FResults.Items.AddObject(FResultCache[i], FResultCache.Objects[i]);
  finally
    FResults.Items.EndUpdate;
  end;
end;

procedure TFindForm.DoResultDblClick(Sender: TObject);
var
  N: Integer;
begin
  if (FEditor = nil) or (FResults.ItemIndex < 0) then Exit;
  N := PtrInt(FResults.Items.Objects[FResults.ItemIndex]);
  if N < 0 then Exit;
  FEditor.DoGotoPos(Point(0, N), Point(-1, -1), 5, 5, True,
    TATEditorActionIfFolded.Unfold);
  FEditor.SetFocus;
end;

procedure TFindForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    Hide;
  end;
end;

procedure TFindForm.FindKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    if ssShift in Shift then FindPrevious else DoFindNext(nil);
  end
  else if Key = VK_ESCAPE then
  begin
    Key := 0;
    Hide;
  end;
end;

procedure TFindForm.RememberFind;
var
  S: string;
begin
  S := FFindEdit.Text;
  if S = '' then Exit;
  if FHistory.IndexOf(S) >= 0 then FHistory.Delete(FHistory.IndexOf(S));
  FHistory.Insert(0, S);
  while FHistory.Count > 20 do FHistory.Delete(FHistory.Count - 1);
  FFindEdit.Items.Assign(FHistory);
  if FHistoryRef <> nil then FHistoryRef.Assign(FHistory);
end;

procedure TFindForm.DoPreview(Sender: TObject);
var
  Re: TRegExpr;
  Line, Replaced: string;
  Y, P: Integer;
begin
  if FEditor = nil then Exit;
  if FFindEdit.Text = '' then Exit;
  UpdateFinder;
  try
    if FRegex.Checked then
    begin
      Re := TRegExpr.Create;
      try
        Re.Expression := FFindEdit.Text;
        Re.ModifierI := not FCase.Checked;
        Y := FFinder.MatchEdPos.Y;
        if (Y < 0) or (Y >= FEditor.Strings.Count) then Y := 0;
        Line := FEditor.Strings.Lines[Y];
        if Re.Exec(Line) then
          Replaced := Re.Replace(Line, FReplaceEdit.Text, True)
        else
          Replaced := Line;
      finally
        Re.Free;
      end;
    end
    else
    begin
      Y := FFinder.MatchEdPos.Y;
      if (Y < 0) or (Y >= FEditor.Strings.Count) then Y := 0;
      Line := FEditor.Strings.Lines[Y];
      Replaced := Line;
      P := Pos(FFindEdit.Text, Line);
      if P > 0 then
        Replaced := Copy(Line, 1, P - 1) + FReplaceEdit.Text +
          Copy(Line, P + Length(FFindEdit.Text), MaxInt);
    end;
    FStatus.Caption := Format(Tr('Preview: %s'), [Replaced]);
  except
    on E: Exception do FStatus.Caption := E.Message;
  end;
end;

procedure TFindForm.SetHistory(AHistory: TStringList);
begin
  if AHistory = nil then Exit;
  FHistoryRef := AHistory;
  FHistory.Assign(AHistory);
  FFindEdit.Items.Assign(FHistory);
end;

procedure TFindForm.DoClose(Sender: TObject);
begin
  Hide;
end;

procedure TFindForm.DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TFindForm.ShowFind(AReplace: Boolean);
begin
  FReplaceEdit.Visible := AReplace;
  FReplaceLabel.Visible := AReplace;
  FBtnReplace.Visible := AReplace;
  FBtnReplaceAll.Visible := AReplace;
  if not Visible then
    Show;
  BringToFront;
  FFindEdit.SetFocus;
  FFindEdit.SelectAll;
end;

procedure TFindForm.FocusFind;
begin
  FFindEdit.SetFocus;
  FFindEdit.SelectAll;
end;

procedure TFindForm.ApplyDefaults(ACase, AWords, ARegex, AWrap: Boolean);
begin
  FCase.Checked := ACase;
  FWords.Checked := AWords;
  FRegex.Checked := ARegex;
  FWrap.Checked := AWrap;
end;

procedure TFindForm.GetOptions(out ACase, AWords, ARegex, AWrap: Boolean);
begin
  ACase := FCase.Checked;
  AWords := FWords.Checked;
  ARegex := FRegex.Checked;
  AWrap := FWrap.Checked;
end;

procedure TFindForm.SetFindText(const AText: string);
begin
  FFindEdit.Text := AText;
end;

procedure TFindForm.FindNext;
begin
  DoFindNext(nil);
end;

procedure TFindForm.FindPrevious;
begin
  if FEditor = nil then Exit;
  FFinder.OptBack := True;
  try
    DoFindNext(nil);
  finally
    FFinder.OptBack := False;
  end;
end;

end.
