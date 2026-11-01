unit uprintpreview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, Printers,
  tyControls.Controller, tyControls.Form, tyControls.Panel, tyControls.ScrollBox,
  tyControls.TyLabel, tyControls.Button, tyControls.CheckBox, tyControls.SpinEdit,
  tyControls.FontComboBox,
  uprint, usettings, utranslation;

type
  TPrintPreviewForm = class(TTyForm)
  private
    FSettings: TAppSettings;
    FFullLines: TStringList;
    FSelectionLines: TStringList;
    FFullStyles, FSelectionStyles: TPrintLineStyles;
    FSelectionFirstLine: Integer;
    FLayout: TPrintLayout;
    FTitle: string;
    FCurrent: Integer;
    FZoom: Integer;
    FBitmap: TBitmap;
    FSurface: TTyFormSurface;
    FTitleBar: TTyTitleBar;
    FImage: TImage;
    FScroll: TScrollBox;
    FBar: TTyPanel;
    FZoomGroup: TTyPanel;
    FSettingsPanel: TTyPanel;
    FSettingsScroll: TTyScrollBox;
    FSettingsFooter: TTyPanel;
    FPageLabel, FZoomLabel: TTyLabel;
    FPrintFontCombo: TTyFontComboBox;
    FPrintFontSize: TTySpinEdit;
    FLineNumbers, FWrapLines, FHeader, FFooter, FSelectionOnly,
      FPrintSyntax: TTyCheckBox;
    FMarginLeft, FMarginTop, FMarginRight, FMarginBottom: TTySpinEdit;
    FBtnPrev, FBtnNext, FBtnZoomOut, FBtnZoomIn, FBtnFit, FBtnPrint,
      FBtnClose, FBtnDefaults: TTyButton;
    FOnPrint: TNotifyEvent;
    FLoadingOptions: Boolean;
    procedure BuildUI;
    procedure BuildSettingsPanel;
    procedure LoadOptionsFrom(ASettings: TAppSettings);
    procedure ApplyOptionsToSettings;
    procedure OptionsChanged(Sender: TObject);
    procedure RebuildLayout;
    procedure RenderPage;
    procedure DoPrev(Sender: TObject);
    procedure DoNext(Sender: TObject);
    procedure DoZoomOut(Sender: TObject);
    procedure DoZoomIn(Sender: TObject);
    procedure DoFitWidth(Sender: TObject);
    procedure DoScrollResize(Sender: TObject);
    procedure CenterPreview;
    procedure DoPrint(Sender: TObject);
    procedure DoClose(Sender: TObject);
    procedure DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure DoRestoreDefaults(Sender: TObject);
    procedure UpdateControls;
  public
    constructor Create(AOwner: TComponent; ASource, ASelectionSource: TStrings;
      const AFullStyles, ASelectionStyles: TPrintLineStyles;
      ASelectionFirstLine: Integer; ASettings: TAppSettings;
      const ATitle: string; AOnPrint: TNotifyEvent);
    destructor Destroy; override;
    property Layout: TPrintLayout read FLayout;
    property PreviewTitle: string read FTitle;
  end;

implementation

constructor TPrintPreviewForm.Create(AOwner: TComponent; ASource,
  ASelectionSource: TStrings; const AFullStyles,
  ASelectionStyles: TPrintLineStyles; ASelectionFirstLine: Integer;
  ASettings: TAppSettings; const ATitle: string; AOnPrint: TNotifyEvent);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FSettings := ASettings;
  FTitle := ATitle;
  FOnPrint := AOnPrint;
  FFullStyles := AFullStyles;
  FSelectionStyles := ASelectionStyles;
  FSelectionFirstLine := ASelectionFirstLine;
  FFullLines := TStringList.Create;
  FFullLines.Assign(ASource);
  if FFullLines.Count = 0 then FFullLines.Add('');
  FSelectionLines := nil;
  if ASelectionSource <> nil then
  begin
    FSelectionLines := TStringList.Create;
    FSelectionLines.Assign(ASelectionSource);
    if FSelectionLines.Count = 0 then
      FreeAndNil(FSelectionLines);
  end;
  FCurrent := 0;
  FZoom := 80;
  BorderIcons := [biSystemMenu, biMaximize];
  Position := poScreenCenter;
  SetBounds(0, 0, 1100, 780);
  Constraints.MinWidth := 900;
  Constraints.MinHeight := 620;
  Resizable := True;
  Caption := Tr('Print Preview') + ' - ' + ATitle;
  Controller := TyDefaultController;
  FBitmap := TBitmap.Create;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  LoadOptionsFrom(FSettings);
  RebuildLayout;
  OnShow := @DoFitWidth;
  OnClose := @DoFormClose;
end;

destructor TPrintPreviewForm.Destroy;
begin
  FBitmap.Free;
  FLayout.Free;
  FSelectionLines.Free;
  FFullLines.Free;
  inherited;
end;

procedure TPrintPreviewForm.BuildUI;
begin
  FSurface := TTyFormSurface.Create(Self);
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitleBar := TTyTitleBar.Create(Self);
  FTitleBar.Parent := FSurface;
  FTitleBar.Align := alTop;
  FTitleBar.Caption := Caption;
  FTitleBar.ShowIcon := True;
  FTitleBar.TitleAlignment := taCenter;

  FSettingsPanel := TTyPanel.Create(Self);
  FSettingsPanel.Parent := FSurface;
  FSettingsPanel.Align := alRight;
  FSettingsPanel.Width := 330;
  BuildSettingsPanel;

  FBar := TTyPanel.Create(Self);
  FBar.Parent := FSurface;
  FBar.Align := alBottom;
  FBar.Height := 54;

  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := FSurface;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FScroll.Color := clGray;
  FScroll.OnResize := @DoScrollResize;

  FImage := TImage.Create(Self);
  FImage.Parent := FScroll;
  FImage.Stretch := True;
  FImage.Proportional := True;

  FBtnPrev := TTyButton.Create(Self);
  FBtnPrev.Parent := FBar;
  FBtnPrev.SetBounds(16, 11, 34, 32);
  FBtnPrev.Caption := '‹';
  FBtnPrev.OnClick := @DoPrev;

  FPageLabel := TTyLabel.Create(Self);
  FPageLabel.Parent := FBar;
  FPageLabel.SetBounds(56, 15, 110, 24);
  FPageLabel.Alignment := taCenter;

  FBtnNext := TTyButton.Create(Self);
  FBtnNext.Parent := FBar;
  FBtnNext.SetBounds(172, 11, 34, 32);
  FBtnNext.Caption := '›';
  FBtnNext.OnClick := @DoNext;

  FZoomGroup := TTyPanel.Create(Self);
  FZoomGroup.Parent := FBar;
  FZoomGroup.Align := alRight;
  FZoomGroup.Width := 244;

  FBtnZoomOut := TTyButton.Create(Self);
  FBtnZoomOut.Parent := FZoomGroup;
  FBtnZoomOut.SetBounds(0, 11, 34, 32);
  FBtnZoomOut.Caption := '−';
  FBtnZoomOut.OnClick := @DoZoomOut;

  FZoomLabel := TTyLabel.Create(Self);
  FZoomLabel.Parent := FZoomGroup;
  FZoomLabel.SetBounds(40, 15, 50, 24);
  FZoomLabel.Alignment := taCenter;

  FBtnZoomIn := TTyButton.Create(Self);
  FBtnZoomIn.Parent := FZoomGroup;
  FBtnZoomIn.SetBounds(96, 11, 34, 32);
  FBtnZoomIn.Caption := '+';
  FBtnZoomIn.OnClick := @DoZoomIn;

  FBtnFit := TTyButton.Create(Self);
  FBtnFit.Parent := FZoomGroup;
  FBtnFit.SetBounds(140, 11, 88, 32);
  FBtnFit.Caption := Tr('Fit Width');
  FBtnFit.OnClick := @DoFitWidth;
end;

procedure TPrintPreviewForm.BuildSettingsPanel;
var
  LabelControl: TTyLabel;
  L: TTyLabel;

  function AddOptionLabel(AY: Integer; const ACaption: string): TTyLabel;
  begin
    Result := TTyLabel.Create(Self);
    Result.Parent := FSettingsScroll;
    Result.SetBounds(28, AY, 278, 24);
    Result.Caption := ACaption;
  end;

  function AddOptionCheck(AY: Integer; const ACaption: string;
    AChecked: Boolean): TTyCheckBox;
  begin
    Result := TTyCheckBox.Create(Self);
    Result.Parent := FSettingsScroll;
    Result.SetBounds(28, AY, 278, 24);
    Result.Caption := ACaption;
    Result.Checked := AChecked;
    Result.OnChange := @OptionsChanged;
  end;

  function AddOptionSpin(AY: Integer; AValue, AMin, AMax: Integer): TTySpinEdit;
  begin
    Result := TTySpinEdit.Create(Self);
    Result.Parent := FSettingsScroll;
    Result.SetBounds(182, AY, 100, 30);
    Result.MinValue := AMin;
    Result.MaxValue := AMax;
    Result.Value := AValue;
    Result.OnChange := @OptionsChanged;
  end;

begin
  LabelControl := TTyLabel.Create(Self);
  LabelControl.Parent := FSettingsPanel;
  LabelControl.Align := alTop;
  LabelControl.Height := 42;
  LabelControl.BorderSpacing.Left := 28;
  LabelControl.Caption := Tr('Print settings');
  LabelControl.Font.Style := [fsBold];

  FSettingsFooter := TTyPanel.Create(Self);
  FSettingsFooter.Parent := FSettingsPanel;
  FSettingsFooter.Align := alBottom;
  FSettingsFooter.Height := 62;

  FBtnPrint := TTyButton.Create(Self);
  FBtnPrint.Parent := FSettingsFooter;
  FBtnPrint.SetBounds(28, 15, 150, 32);
  FBtnPrint.Caption := Tr('Print...');
  FBtnPrint.OnClick := @DoPrint;

  FBtnClose := TTyButton.Create(Self);
  FBtnClose.Parent := FSettingsFooter;
  FBtnClose.SetBounds(190, 15, 100, 32);
  FBtnClose.Caption := Tr('Close');
  FBtnClose.OnClick := @DoClose;

  FSettingsScroll := TTyScrollBox.Create(Self);
  FSettingsScroll.Parent := FSettingsPanel;
  FSettingsScroll.Align := alClient;

  L := AddOptionLabel(16, Tr('Font family:'));
  FPrintFontCombo := TTyFontComboBox.Create(Self);
  FPrintFontCombo.Parent := FSettingsScroll;
  FPrintFontCombo.SetBounds(28, 40, 280, 30);
  FPrintFontCombo.FixedPitchOnly := False;
  FPrintFontCombo.OnChange := @OptionsChanged;

  AddOptionLabel(80, Tr('Font size:'));
  FPrintFontSize := AddOptionSpin(104, FSettings.PrintFontSize, 6, 48);
  FPrintFontSize.Left := 28;

  FLineNumbers := AddOptionCheck(148, Tr('Line numbers'), FSettings.PrintLineNumbers);
  FWrapLines := AddOptionCheck(180, Tr('Wrap long lines'), FSettings.PrintWrapLines);
  FHeader := AddOptionCheck(212, Tr('Print header'), FSettings.PrintHeader);
  FFooter := AddOptionCheck(244, Tr('Print footer'), FSettings.PrintFooter);
  FSelectionOnly := AddOptionCheck(276, Tr('Print selection only'),
    FSettings.PrintSelectionOnly);
  FPrintSyntax := AddOptionCheck(308, Tr('Syntax highlighting'),
    FSettings.PrintSyntaxHighlighting);

  AddOptionLabel(352, Tr('Margins (mm):'));
  AddOptionLabel(384, Tr('Left'));
  FMarginLeft := AddOptionSpin(380, FSettings.PrintMarginLeft, 0, 50);
  AddOptionLabel(420, Tr('Top'));
  FMarginTop := AddOptionSpin(416, FSettings.PrintMarginTop, 0, 50);
  AddOptionLabel(456, Tr('Right'));
  FMarginRight := AddOptionSpin(452, FSettings.PrintMarginRight, 0, 50);
  AddOptionLabel(492, Tr('Bottom'));
  FMarginBottom := AddOptionSpin(488, FSettings.PrintMarginBottom, 0, 50);

  FBtnDefaults := TTyButton.Create(Self);
  FBtnDefaults.Parent := FSettingsScroll;
  FBtnDefaults.SetBounds(28, 546, 160, 32);
  FBtnDefaults.Caption := Tr('Restore Defaults');
  FBtnDefaults.OnClick := @DoRestoreDefaults;

end;

procedure TPrintPreviewForm.LoadOptionsFrom(ASettings: TAppSettings);
begin
  FLoadingOptions := True;
  try
    FPrintFontCombo.SelectedFont := ASettings.PrintFontName;
    FPrintFontSize.Value := ASettings.PrintFontSize;
    FLineNumbers.Checked := ASettings.PrintLineNumbers;
    FWrapLines.Checked := ASettings.PrintWrapLines;
    FHeader.Checked := ASettings.PrintHeader;
    FFooter.Checked := ASettings.PrintFooter;
    FMarginLeft.Value := ASettings.PrintMarginLeft;
    FMarginTop.Value := ASettings.PrintMarginTop;
    FMarginRight.Value := ASettings.PrintMarginRight;
    FMarginBottom.Value := ASettings.PrintMarginBottom;
    FSelectionOnly.Enabled := FSelectionLines <> nil;
    FSelectionOnly.Checked := ASettings.PrintSelectionOnly and FSelectionOnly.Enabled;
    FPrintSyntax.Checked := ASettings.PrintSyntaxHighlighting;
  finally
    FLoadingOptions := False;
  end;
end;

procedure TPrintPreviewForm.ApplyOptionsToSettings;
begin
  if FPrintFontCombo.SelectedFont <> '' then
    FSettings.PrintFontName := FPrintFontCombo.SelectedFont;
  FSettings.PrintFontSize := FPrintFontSize.Value;
  FSettings.PrintLineNumbers := FLineNumbers.Checked;
  FSettings.PrintWrapLines := FWrapLines.Checked;
  FSettings.PrintHeader := FHeader.Checked;
  FSettings.PrintFooter := FFooter.Checked;
  FSettings.PrintSyntaxHighlighting := FPrintSyntax.Checked;
  FSettings.PrintMarginLeft := FMarginLeft.Value;
  FSettings.PrintMarginTop := FMarginTop.Value;
  FSettings.PrintMarginRight := FMarginRight.Value;
  FSettings.PrintMarginBottom := FMarginBottom.Value;
  if FSelectionOnly.Enabled then
    FSettings.PrintSelectionOnly := FSelectionOnly.Checked;
end;

procedure TPrintPreviewForm.OptionsChanged(Sender: TObject);
begin
  if FLoadingOptions then Exit;
  ApplyOptionsToSettings;
  RebuildLayout;
end;

procedure TPrintPreviewForm.RebuildLayout;
var
  NewLayout: TPrintLayout;
  Options: TPrintOptions;
  Source: TStringList;
  SourceStyles: TPrintLineStyles;
  FirstLine, LastLine: Integer;
begin
  Options := PrintOptionsFromSettings(FSettings);
  if FSelectionOnly.Checked and (FSelectionLines <> nil) then
  begin
    Source := FSelectionLines;
    SourceStyles := FSelectionStyles;
    FirstLine := FSelectionFirstLine;
    LastLine := FSelectionFirstLine + FSelectionLines.Count - 1;
  end
  else
  begin
    Source := FFullLines;
    SourceStyles := FFullStyles;
    FirstLine := 0;
    LastLine := FFullLines.Count - 1;
  end;
  NewLayout := MakePrintLayout(Source, Options, FirstLine, LastLine, SourceStyles);
  FreeAndNil(FLayout);
  FLayout := NewLayout;
  if FCurrent >= FLayout.PageCount then
    FCurrent := FLayout.PageCount - 1;
  if FCurrent < 0 then
    FCurrent := 0;
  RenderPage;
  UpdateControls;
end;

procedure TPrintPreviewForm.RenderPage;
begin
  if (FLayout = nil) or (FLayout.PageCount = 0) then Exit;
  if FCurrent < 0 then FCurrent := 0;
  if FCurrent >= FLayout.PageCount then FCurrent := FLayout.PageCount - 1;
  DrawPrintPreviewPage(FLayout, FCurrent, FBitmap, FCurrent + 1,
    FLayout.PageCount, FTitle);
  FImage.Picture.Bitmap.Assign(FBitmap);
  FImage.Width := Round(FLayout.PageWidth * FZoom / 100);
  FImage.Height := Round(FLayout.PageHeight * FZoom / 100);
  FImage.Top := 16;
  CenterPreview;
end;

procedure TPrintPreviewForm.UpdateControls;
begin
  if FLayout = nil then Exit;
  FPageLabel.Caption := Format(Tr('Page %d of %d'),
    [FCurrent + 1, FLayout.PageCount]);
  FZoomLabel.Caption := Format('%d%%', [FZoom]);
  FBtnPrev.Enabled := FCurrent > 0;
  FBtnNext.Enabled := FCurrent < FLayout.PageCount - 1;
  FBtnZoomOut.Enabled := FZoom > 25;
  FBtnZoomIn.Enabled := FZoom < 200;
  FBtnPrint.Enabled := (Printer <> nil) and Printer.CanPrint;
  if not FBtnPrint.Enabled then
    FBtnPrint.Caption := Tr('No printer')
  else
    FBtnPrint.Caption := Tr('Print...');
end;

procedure TPrintPreviewForm.DoPrev(Sender: TObject);
begin
  if FCurrent > 0 then
  begin
    Dec(FCurrent);
    RenderPage;
    UpdateControls;
  end;
end;

procedure TPrintPreviewForm.DoNext(Sender: TObject);
begin
  if (FLayout <> nil) and (FCurrent < FLayout.PageCount - 1) then
  begin
    Inc(FCurrent);
    RenderPage;
    UpdateControls;
  end;
end;

procedure TPrintPreviewForm.DoZoomOut(Sender: TObject);
begin
  if FZoom > 25 then
  begin
    Dec(FZoom, 10);
    RenderPage;
    UpdateControls;
  end;
end;

procedure TPrintPreviewForm.DoZoomIn(Sender: TObject);
begin
  if FZoom < 200 then
  begin
    Inc(FZoom, 10);
    RenderPage;
    UpdateControls;
  end;
end;

procedure TPrintPreviewForm.DoFitWidth(Sender: TObject);
var
  Avail: Integer;
begin
  if (FLayout = nil) or (FLayout.PageWidth <= 0) or (FScroll.ClientWidth <= 0) then Exit;
  Avail := FScroll.ClientWidth - 36;
  FZoom := Round(Avail * 100 / FLayout.PageWidth);
  if FZoom < 25 then FZoom := 25;
  if FZoom > 200 then FZoom := 200;
  RenderPage;
  UpdateControls;
end;

procedure TPrintPreviewForm.DoScrollResize(Sender: TObject);
begin
  CenterPreview;
end;

procedure TPrintPreviewForm.CenterPreview;
var
  L: Integer;
begin
  if FImage = nil then Exit;
  L := (FScroll.ClientWidth - FImage.Width) div 2;
  if L < 16 then L := 16;
  FImage.Left := L;
end;

procedure TPrintPreviewForm.DoPrint(Sender: TObject);
begin
  if (not FBtnPrint.Enabled) or (not Assigned(FOnPrint)) then Exit;
  FSettings.Save;
  FOnPrint(Self);
end;

procedure TPrintPreviewForm.DoClose(Sender: TObject);
begin
  Close;
end;

procedure TPrintPreviewForm.DoFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  FSettings.Save;
end;

procedure TPrintPreviewForm.DoRestoreDefaults(Sender: TObject);
var
  D: TAppSettings;
begin
  D := TAppSettings.Create;
  try
    LoadOptionsFrom(D);
    ApplyOptionsToSettings;
    RebuildLayout;
  finally
    D.Free;
  end;
end;

end.
