unit umacromanager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, FileUtil,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.Panel, tyControls.ListBox, tyControls.Button, tyControls.TyLabel,
  tyControls.Dialogs, utranslation;

type
  TMacroManagerForm = class(TTyForm)
  private
    FDir: string;
    FList: TTyListBox;
    FTitle: TTyTitleBar;
    FSurface: TTyFormSurface;
    FSelected: string;
    procedure BuildUI;
    procedure RefreshList;
    procedure DoOpen(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoRename(Sender: TObject);
    procedure DoImport(Sender: TObject);
    procedure DoExport(Sender: TObject);
    procedure DoClose(Sender: TObject);
    function SelectedPath: string;
  public
    constructor Create(AOwner: TComponent; const ADir: string); reintroduce;
    function Execute: string;
  end;

implementation

constructor TMacroManagerForm.Create(AOwner: TComponent; const ADir: string);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FDir := IncludeTrailingPathDelimiter(ADir);
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  SetBounds(0, 0, 520, 420);
  Caption := Tr('Macro Manager');
  Controller := TyDefaultController;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  RefreshList;
end;

procedure TMacroManagerForm.BuildUI;
var
  B: TTyButton;
  L: TTyLabel;
begin
  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Macro Manager');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  FList := TTyListBox.Create(Self);
  FList.Parent := FSurface;
  FList.SetBounds(16, 44, 488, 260);
  FList.OnDblClick := @DoOpen;

  L := TTyLabel.Create(Self);
  L.Parent := FSurface;
  L.SetBounds(16, 310, 488, 24);
  L.Caption := Tr('Macros are stored as JSON files in the macro folder.');

  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(16, 344, 90, 30);
  B.Caption := Tr('Load'); B.OnClick := @DoOpen;
  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(114, 344, 90, 30);
  B.Caption := Tr('Delete'); B.OnClick := @DoDelete;
  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(212, 344, 90, 30);
  B.Caption := Tr('Rename'); B.OnClick := @DoRename;
  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(310, 344, 90, 30);
  B.Caption := Tr('Import'); B.OnClick := @DoImport;
  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(310, 380, 90, 30);
  B.Caption := Tr('Export'); B.OnClick := @DoExport;
  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(408, 344, 90, 30);
  B.Caption := Tr('Close'); B.OnClick := @DoClose;
end;

procedure TMacroManagerForm.RefreshList;
var
  SR: TSearchRec;
  Base: string;
begin
  FList.Items.Clear;
  if FindFirst(FDir + '*.json', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        Base := ChangeFileExt(SR.Name, '');
        FList.Items.AddObject(Base, TObject(PtrInt(0)));
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function TMacroManagerForm.SelectedPath: string;
begin
  Result := '';
  if (FList.ItemIndex >= 0) and (FList.ItemIndex < FList.Items.Count) then
    Result := FDir + FList.Items[FList.ItemIndex] + '.json';
end;

procedure TMacroManagerForm.DoOpen(Sender: TObject);
begin
  FSelected := SelectedPath;
  if FSelected <> '' then
    ModalResult := mrOk;
end;

procedure TMacroManagerForm.DoDelete(Sender: TObject);
var
  P: string;
begin
  P := SelectedPath;
  if (P = '') or (TyMessageDlg(Format(Tr('Delete macro "%s"?'),
    [ExtractFileName(P)]), mtConfirmation, [mbYes, mbNo]) <> mrYes) then Exit;
  if DeleteFile(P) then RefreshList;
end;

procedure TMacroManagerForm.DoRename(Sender: TObject);
var
  P, S, N: string;
begin
  P := SelectedPath;
  if P = '' then Exit;
  S := ChangeFileExt(ExtractFileName(P), '');
  if not InputQuery(Tr('Rename Macro'), Tr('Name:'), S) then Exit;
  S := Trim(S);
  if S = '' then Exit;
  N := FDir + S + '.json';
  if FileExists(N) then
  begin
    TyMessageDlg(Tr('A macro with that name already exists.'), mtError, [mbOK]);
    Exit;
  end;
  if RenameFile(P, N) then RefreshList;
end;

procedure TMacroManagerForm.DoImport(Sender: TObject);
var
  D: TOpenDialog;
  P, Dest: string;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := Tr('JSON files') + '|*.json|' + Tr('All files') + '|*.*';
    if not D.Execute then Exit;
    P := D.FileName;
    Dest := FDir + ExtractFileName(P);
    if FileExists(Dest) and (TyMessageDlg(Tr('Overwrite existing macro?'),
      mtConfirmation, [mbYes, mbNo]) <> mrYes) then Exit;
    if CopyFile(P, Dest) then RefreshList;
  finally
    D.Free;
  end;
end;

procedure TMacroManagerForm.DoExport(Sender: TObject);
var
  D: TSaveDialog;
  P: string;
begin
  P := SelectedPath;
  if P = '' then Exit;
  D := TSaveDialog.Create(Self);
  try
    D.FileName := ExtractFileName(P);
    D.Filter := Tr('JSON files') + '|*.json|' + Tr('All files') + '|*.*';
    if D.Execute then
      CopyFile(P, D.FileName);
  finally
    D.Free;
  end;
end;

procedure TMacroManagerForm.DoClose(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TMacroManagerForm.Execute: string;
begin
  FSelected := '';
  ShowModal;
  Result := FSelected;
end;

end.
