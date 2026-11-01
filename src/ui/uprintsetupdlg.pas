unit uprintsetupdlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  tyControls.Controller, tyControls.Form, tyControls.Panel,
  tyControls.TyLabel, tyControls.CheckBox, tyControls.Button,
  tyControls.SpinEdit, usettings, utranslation;

type
  TPrintSetupForm = class(TTyForm)
  private
    FSettings: TAppSettings;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FMarginLeft, FMarginTop, FMarginRight, FMarginBottom: TTySpinEdit;
    FLineNumbers, FWrapLines, FHeader, FFooter: TTyCheckBox;
    FOK, FCancel, FDefaults: TTyButton;
    procedure BuildUI;
    procedure LoadValues;
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure DoDefaults(Sender: TObject);
    function AddLabel(AX, AY: Integer; const ACaption: string): TTyLabel;
  public
    constructor Create(AOwner: TComponent; ASettings: TAppSettings);
    function Execute: Boolean;
  end;

implementation

constructor TPrintSetupForm.Create(AOwner: TComponent; ASettings: TAppSettings);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FSettings := ASettings;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  SetBounds(0, 0, 500, 390);
  Caption := Tr('Page Setup');
  Controller := TyDefaultController;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  LoadValues;
end;

function TPrintSetupForm.AddLabel(AX, AY: Integer;
  const ACaption: string): TTyLabel;
begin
  Result := TTyLabel.Create(Self);
  Result.Parent := FSurface;
  Result.SetBounds(AX, AY, 150, 24);
  Result.Caption := ACaption;
end;

procedure TPrintSetupForm.BuildUI;
begin
  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitle := TTyTitleBar.Create(Self);
  FTitle.Parent := FSurface;
  FTitle.Align := alTop;
  FTitle.Caption := Tr('Page Setup');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  AddLabel(24, 52, Tr('Left margin (mm):'));
  FMarginLeft := TTySpinEdit.Create(Self);
  FMarginLeft.Parent := FSurface;
  FMarginLeft.SetBounds(190, 48, 90, 30);
  FMarginLeft.MinValue := 0;
  FMarginLeft.MaxValue := 50;

  AddLabel(24, 88, Tr('Top margin (mm):'));
  FMarginTop := TTySpinEdit.Create(Self);
  FMarginTop.Parent := FSurface;
  FMarginTop.SetBounds(190, 84, 90, 30);
  FMarginTop.MinValue := 0;
  FMarginTop.MaxValue := 50;

  AddLabel(24, 124, Tr('Right margin (mm):'));
  FMarginRight := TTySpinEdit.Create(Self);
  FMarginRight.Parent := FSurface;
  FMarginRight.SetBounds(190, 120, 90, 30);
  FMarginRight.MinValue := 0;
  FMarginRight.MaxValue := 50;

  AddLabel(24, 160, Tr('Bottom margin (mm):'));
  FMarginBottom := TTySpinEdit.Create(Self);
  FMarginBottom.Parent := FSurface;
  FMarginBottom.SetBounds(190, 156, 90, 30);
  FMarginBottom.MinValue := 0;
  FMarginBottom.MaxValue := 50;

  FLineNumbers := TTyCheckBox.Create(Self);
  FLineNumbers.Parent := FSurface;
  FLineNumbers.SetBounds(310, 48, 165, 24);
  FLineNumbers.Caption := Tr('Line numbers');

  FWrapLines := TTyCheckBox.Create(Self);
  FWrapLines.Parent := FSurface;
  FWrapLines.SetBounds(310, 80, 165, 24);
  FWrapLines.Caption := Tr('Wrap long lines');

  FHeader := TTyCheckBox.Create(Self);
  FHeader.Parent := FSurface;
  FHeader.SetBounds(310, 112, 165, 24);
  FHeader.Caption := Tr('Print header');

  FFooter := TTyCheckBox.Create(Self);
  FFooter.Parent := FSurface;
  FFooter.SetBounds(310, 144, 165, 24);
  FFooter.Caption := Tr('Print footer');

  FDefaults := TTyButton.Create(Self);
  FDefaults.Parent := FSurface;
  FDefaults.SetBounds(24, 320, 140, 32);
  FDefaults.Caption := Tr('Restore Defaults');
  FDefaults.OnClick := @DoDefaults;

  FOK := TTyButton.Create(Self);
  FOK.Parent := FSurface;
  FOK.SetBounds(286, 320, 90, 32);
  FOK.Caption := Tr('OK');
  FOK.OnClick := @DoOK;

  FCancel := TTyButton.Create(Self);
  FCancel.Parent := FSurface;
  FCancel.SetBounds(386, 320, 90, 32);
  FCancel.Caption := Tr('Cancel');
  FCancel.OnClick := @DoCancel;
end;

procedure TPrintSetupForm.LoadValues;
begin
  FMarginLeft.Value := FSettings.PrintMarginLeft;
  FMarginTop.Value := FSettings.PrintMarginTop;
  FMarginRight.Value := FSettings.PrintMarginRight;
  FMarginBottom.Value := FSettings.PrintMarginBottom;
  FLineNumbers.Checked := FSettings.PrintLineNumbers;
  FWrapLines.Checked := FSettings.PrintWrapLines;
  FHeader.Checked := FSettings.PrintHeader;
  FFooter.Checked := FSettings.PrintFooter;
end;

procedure TPrintSetupForm.DoDefaults(Sender: TObject);
begin
  FMarginLeft.Value := 15;
  FMarginTop.Value := 15;
  FMarginRight.Value := 15;
  FMarginBottom.Value := 15;
  FLineNumbers.Checked := True;
  FWrapLines.Checked := True;
  FHeader.Checked := False;
  FFooter.Checked := True;
end;

procedure TPrintSetupForm.DoOK(Sender: TObject);
begin
  FSettings.PrintMarginLeft := FMarginLeft.Value;
  FSettings.PrintMarginTop := FMarginTop.Value;
  FSettings.PrintMarginRight := FMarginRight.Value;
  FSettings.PrintMarginBottom := FMarginBottom.Value;
  FSettings.PrintLineNumbers := FLineNumbers.Checked;
  FSettings.PrintWrapLines := FWrapLines.Checked;
  FSettings.PrintHeader := FHeader.Checked;
  FSettings.PrintFooter := FFooter.Checked;
  FSettings.Save;
  ModalResult := mrOk;
end;

procedure TPrintSetupForm.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TPrintSetupForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.
