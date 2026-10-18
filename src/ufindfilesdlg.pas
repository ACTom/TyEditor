unit ufindfilesdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  tyControls.Form, tyControls.Edit, tyControls.Button, tyControls.CheckBox,
  tyControls.TyLabel, tyControls.Dialogs, tyControls.Dialogs.SelectPath, tyControls.Controller,
  utranslation,
  ufindfiles;

type
  TFindInFilesForm = class(TTyForm)
  private
    FOnResult: TFindFileResultEvent;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FDirEdit: TTyEdit;
    FMaskEdit: TTyEdit;
    FExcludeEdit: TTyEdit;
    FFindEdit: TTyEdit;
    FReplaceEdit: TTyEdit;
    FCase: TTyCheckBox;
    FWords: TTyCheckBox;
    FRegex: TTyCheckBox;
    FSubdirs: TTyCheckBox;
    FStatus: TTyLabel;
    FProgress: TTyLabel;
    FBtnBrowse: TTyButton;
    FBtnFind: TTyButton;
    FBtnReplace: TTyButton;
    FBtnClose: TTyButton;
    FBtnStop: TTyButton;
    FJob: TFindFileJob;
    FTimer: TTimer;
    FReplaceMode: Boolean;
    procedure BuildUI;
    procedure DoBrowse(Sender: TObject);
    procedure DoFind(Sender: TObject);
    procedure DoReplace(Sender: TObject);
    procedure DoClose(Sender: TObject);
    procedure DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure DoTimer(Sender: TObject);
    procedure DoStop(Sender: TObject);
    procedure StopJob;
    procedure StartJob(AReplace: Boolean);
    procedure SetRunning(AValue: Boolean);
    procedure DoResult(const AFileName: string; ALine, ACol: Integer;
      const AText: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyDefaults(ACase, AWords, ARegex: Boolean);
    procedure ShowDialog(const ADir, AFindText, AReplaceText: string;
      AReplace: Boolean);
    property OnResult: TFindFileResultEvent read FOnResult write FOnResult;
  end;

implementation

constructor TFindInFilesForm.Create(AOwner: TComponent);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  BorderIcons := [biSystemMenu];
  Position := poDesigned;
  SetBounds(260, 160, 700, 380);
  Caption := Tr('Find in Files');
  Controller := TyDefaultController;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.Enabled := False;
  FTimer.OnTimer := @DoTimer;
  OnClose := @DoFormClose;
end;

procedure TFindInFilesForm.BuildUI;
var
  L: TTyLabel;
begin
  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Find in Files');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FStatus := TTyLabel.Create(Self);
  FStatus.Parent := FSurface;
  FStatus.SetBounds(16, 292, 660, 24);
  FStatus.Caption := '';

  FProgress := TTyLabel.Create(Self);
  FProgress.Parent := FSurface;
  FProgress.SetBounds(16, 318, 660, 24);
  FProgress.Caption := '';

  L := TTyLabel.Create(Self);
  L.Parent := FSurface;
  L.SetBounds(16, 44, 90, 30);
  L.Caption := Tr('Folder:');

  FDirEdit := TTyEdit.Create(Self);
  FDirEdit.Parent := FSurface;
  FDirEdit.SetBounds(110, 44, 470, 30);

  FBtnBrowse := TTyButton.Create(Self);
  FBtnBrowse.Parent := FSurface;
  FBtnBrowse.SetBounds(590, 44, 90, 30);
  FBtnBrowse.Caption := Tr('Browse...');
  FBtnBrowse.OnClick := @DoBrowse;

  L := TTyLabel.Create(Self);
  L.Parent := FSurface;
  L.SetBounds(16, 80, 90, 30);
  L.Caption := Tr('Mask:');

  FMaskEdit := TTyEdit.Create(Self);
  FMaskEdit.Parent := FSurface;
  FMaskEdit.SetBounds(110, 80, 570, 30);
  FMaskEdit.Text := '*.*';

  L := TTyLabel.Create(Self);
  L.Parent := FSurface;
  L.SetBounds(16, 116, 90, 30);
  L.Caption := Tr('Find:');

  FFindEdit := TTyEdit.Create(Self);
  FFindEdit.Parent := FSurface;
  FFindEdit.SetBounds(110, 116, 570, 30);

  L := TTyLabel.Create(Self);
  L.Parent := FSurface;
  L.SetBounds(16, 152, 90, 30);
  L.Caption := Tr('Replace:');

  FReplaceEdit := TTyEdit.Create(Self);
  FReplaceEdit.Parent := FSurface;
  FReplaceEdit.SetBounds(110, 152, 570, 30);

  FCase := TTyCheckBox.Create(Self);
  FCase.Parent := FSurface;
  FCase.SetBounds(110, 188, 110, 24);
  FCase.Caption := Tr('Match case');

  FWords := TTyCheckBox.Create(Self);
  FWords.Parent := FSurface;
  FWords.SetBounds(230, 188, 120, 24);
  FWords.Caption := Tr('Whole word');

  FRegex := TTyCheckBox.Create(Self);
  FRegex.Parent := FSurface;
  FRegex.SetBounds(350, 188, 120, 24);
  FRegex.Caption := Tr('Regular expr.');

  FSubdirs := TTyCheckBox.Create(Self);
  FSubdirs.Parent := FSurface;
  FSubdirs.SetBounds(480, 188, 140, 24);
  FSubdirs.Caption := Tr('Include subdirs');
  FSubdirs.Checked := True;

  L := TTyLabel.Create(Self);
  L.Parent := FSurface;
  L.SetBounds(16, 216, 90, 30);
  L.Caption := Tr('Exclude dirs:');

  FExcludeEdit := TTyEdit.Create(Self);
  FExcludeEdit.Parent := FSurface;
  FExcludeEdit.SetBounds(110, 212, 570, 30);

  FBtnFind := TTyButton.Create(Self);
  FBtnFind.Parent := FSurface;
  FBtnFind.SetBounds(110, 252, 120, 30);
  FBtnFind.Caption := Tr('Find All');
  FBtnFind.OnClick := @DoFind;

  FBtnReplace := TTyButton.Create(Self);
  FBtnReplace.Parent := FSurface;
  FBtnReplace.SetBounds(240, 252, 120, 30);
  FBtnReplace.Caption := Tr('Replace All');
  FBtnReplace.OnClick := @DoReplace;

  FBtnClose := TTyButton.Create(Self);
  FBtnClose.Parent := FSurface;
  FBtnStop := TTyButton.Create(Self);
  FBtnStop.Parent := FSurface;
  FBtnStop.SetBounds(370, 252, 100, 30);
  FBtnStop.Caption := Tr('Stop');
  FBtnStop.OnClick := @DoStop;
  FBtnStop.Enabled := False;

  FBtnClose.SetBounds(480, 252, 100, 30);
  FBtnClose.Caption := Tr('Close');
  FBtnClose.OnClick := @DoClose;
end;

procedure TFindInFilesForm.ApplyDefaults(ACase, AWords, ARegex: Boolean);
begin
  FCase.Checked := ACase;
  FWords.Checked := AWords;
  FRegex.Checked := ARegex;
end;

procedure TFindInFilesForm.ShowDialog(const ADir, AFindText, AReplaceText: string;
  AReplace: Boolean);
begin
  FDirEdit.Text := ADir;
  FFindEdit.Text := AFindText;
  FReplaceEdit.Text := AReplaceText;
  if not Visible then Show;
  BringToFront;
  if AReplace then
  begin
    FReplaceEdit.SetFocus;
    FReplaceEdit.SelectAll;
  end
  else
  begin
    FFindEdit.SetFocus;
    FFindEdit.SelectAll;
  end;
end;

procedure TFindInFilesForm.DoBrowse(Sender: TObject);
var
  D: string;
begin
  D := FDirEdit.Text;
  if TySelectDirectory(Tr('Choose a folder'), '', D) then
    FDirEdit.Text := D;
end;


procedure TFindInFilesForm.StopJob;
begin
  FTimer.Enabled := False;
  if FJob <> nil then
  begin
    FJob.Cancel;
    FJob.WaitFor;
    FreeAndNil(FJob);
  end;
  SetRunning(False);
end;

procedure TFindInFilesForm.SetRunning(AValue: Boolean);
begin
  FBtnFind.Enabled := not AValue;
  FBtnReplace.Enabled := not AValue;
  FExcludeEdit.Enabled := not AValue;
  FBtnStop.Enabled := AValue;
end;

procedure TFindInFilesForm.DoTimer(Sender: TObject);
var
  FileName, AText, Err: string;
  Line, Col, Count, Files, Scanned: Integer;
  Done, Cancelled: Boolean;
begin
  if FJob = nil then Exit;
  while FJob.TakeHit(FileName, Line, Col, AText) do
    DoResult(FileName, Line, Col, AText);
  FJob.Snapshot(Count, Files, Scanned, Done, Cancelled, Err);
  FProgress.Caption := Format(Tr('%d file(s) scanned, %d match(es).'),
    [Scanned, Count]);
  if Done then
  begin
    FTimer.Enabled := False;
    if Err <> '' then
      FStatus.Caption := Err
    else if Cancelled then
      FStatus.Caption := Format(Tr('Stopped: %d match(es) in %d file(s).'),
        [Count, Files])
    else if FReplaceMode then
      FStatus.Caption := Format(Tr('Replaced %d occurrence(s) in %d file(s).'),
        [Count, Files])
    else
      FStatus.Caption := Format(Tr('%d match(es) in %d file(s).'), [Count, Files]);
    FreeAndNil(FJob);
    SetRunning(False);
  end;
end;

procedure TFindInFilesForm.DoStop(Sender: TObject);
begin
  if FJob <> nil then
    FJob.Cancel;
end;

procedure TFindInFilesForm.StartJob(AReplace: Boolean);
var
  Opt: TFindFileOptions;
begin
  if FJob <> nil then Exit;
  Opt.Directory := FDirEdit.Text;
  Opt.Mask := FMaskEdit.Text;
  Opt.FindText := FFindEdit.Text;
  Opt.ReplaceText := FReplaceEdit.Text;
  Opt.CaseSensitive := FCase.Checked;
  Opt.WholeWord := FWords.Checked;
  Opt.Regex := FRegex.Checked;
  Opt.IncludeSubdirs := FSubdirs.Checked;
  Opt.DoReplace := AReplace;
  Opt.ExcludeDirs := FExcludeEdit.Text;
  FReplaceMode := AReplace;
  FStatus.Caption := Tr('Searching...');
  if AReplace then
    FStatus.Caption := Tr('Replacing...');
  FProgress.Caption := '';
  SetRunning(True);
  FTimer.Enabled := True;
  try
    FJob := TFindFileJob.Create(Opt);
  except
    on E: Exception do
    begin
      FTimer.Enabled := False;
      SetRunning(False);
      FStatus.Caption := E.Message;
    end;
  end;
end;

procedure TFindInFilesForm.DoFind(Sender: TObject);
begin
  StartJob(False);
end;


procedure TFindInFilesForm.DoReplace(Sender: TObject);
begin
  if FJob <> nil then
  begin
    FStatus.Caption := Tr('Stop the running search first.');
    Exit;
  end;
  if TyMessageDlg(Tr('Replace in all matched files? This cannot be undone.'),
    mtConfirmation, [mbYes, mbNo]) <> mrYes then Exit;
  StartJob(True);
end;
procedure TFindInFilesForm.DoResult(const AFileName: string; ALine, ACol: Integer;
  const AText: string);
begin
  if Assigned(FOnResult) then
    FOnResult(AFileName, ALine, ACol, AText);
end;

procedure TFindInFilesForm.DoClose(Sender: TObject);
begin
  StopJob;
  Hide;
end;

procedure TFindInFilesForm.DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  StopJob;
  CloseAction := caHide;
end;

destructor TFindInFilesForm.Destroy;
begin
  StopJob;
  inherited;
end;

end.
