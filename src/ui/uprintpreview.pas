unit uprintpreview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls, Printers,
  tyControls.Controller, tyControls.Form, tyControls.Panel, tyControls.TyLabel, tyControls.Button,
  uprint, uprintsetupdlg, usettings, utranslation;

type
  TPrintPreviewForm = class(TTyForm)
  private
    FSettings: TAppSettings;
    FLines: TStringList;
    FFirstLine, FLastLine: Integer;
    FLayout: TPrintLayout;
    FTitle: string;
    FCurrent: Integer;
    FZoom: Integer;
    FBitmap: TBitmap;
    FImage: TImage;
    FScroll: TScrollBox;
    FBar: TTyPanel;
    FPageLabel: TTyLabel;
    FBtnPrev, FBtnNext, FBtnZoomOut, FBtnZoomIn, FBtnFit, FBtnPageSetup,
      FBtnPrint, FBtnClose: TTyButton;
    FOnPrint: TNotifyEvent;
    procedure BuildUI;
    procedure RebuildLayout;
    procedure RenderPage;
    procedure DoPrev(Sender: TObject);
    procedure DoNext(Sender: TObject);
    procedure DoZoomOut(Sender: TObject);
    procedure DoZoomIn(Sender: TObject);
    procedure DoFitWidth(Sender: TObject);
    procedure DoPageSetup(Sender: TObject);
    procedure DoPrint(Sender: TObject);
    procedure DoClose(Sender: TObject);
    procedure UpdateControls;
  public
    constructor Create(AOwner: TComponent; ASource: TStrings;
      AFirstLine, ALastLine: Integer; ASettings: TAppSettings;
      const ATitle: string; AOnPrint: TNotifyEvent);
    destructor Destroy; override;
    property Layout: TPrintLayout read FLayout;
    property PreviewTitle: string read FTitle;
  end;

implementation

constructor TPrintPreviewForm.Create(AOwner: TComponent; ASource: TStrings;
  AFirstLine, ALastLine: Integer; ASettings: TAppSettings;
  const ATitle: string; AOnPrint: TNotifyEvent);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  if (Application.MainForm <> nil) and
     (Application.MainForm.FormStyle = fsStayOnTop) then
    FormStyle := fsStayOnTop;
  FSettings := ASettings;
  FTitle := ATitle;
  FOnPrint := AOnPrint;
  FFirstLine := AFirstLine;
  FLastLine := ALastLine;
  FLines := TStringList.Create;
  FLines.Assign(ASource);
  FCurrent := 0;
  FZoom := 80;
  BorderIcons := [biSystemMenu, biMaximize];
  Position := poScreenCenter;
  SetBounds(0, 0, 900, 760);
  Caption := Tr('Print Preview') + ' - ' + ATitle;
  Controller := TyDefaultController;
  FBitmap := TBitmap.Create;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
  RebuildLayout;
  OnShow := @DoFitWidth;
end;

destructor TPrintPreviewForm.Destroy;
begin
  FBitmap.Free;
  FLayout.Free;
  FLines.Free;
  inherited;
end;

procedure TPrintPreviewForm.BuildUI;
begin
  FBar := TTyPanel.Create(Self);
  FBar.Parent := Self;
  FBar.Align := alBottom;
  FBar.Height := 52;

  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FScroll.Color := clGray;

  FImage := TImage.Create(Self);
  FImage.Parent := FScroll;
  FImage.Stretch := True;
  FImage.Proportional := True;

  FPageLabel := TTyLabel.Create(Self);
  FPageLabel.Parent := FBar;
  FPageLabel.SetBounds(10, 14, 170, 24);

  FBtnPrev := TTyButton.Create(Self);
  FBtnPrev.Parent := FBar;
  FBtnPrev.SetBounds(188, 10, 80, 32);
  FBtnPrev.Caption := Tr('< Previous');
  FBtnPrev.OnClick := @DoPrev;

  FBtnNext := TTyButton.Create(Self);
  FBtnNext.Parent := FBar;
  FBtnNext.SetBounds(274, 10, 80, 32);
  FBtnNext.Caption := Tr('Next >');
  FBtnNext.OnClick := @DoNext;

  FBtnZoomOut := TTyButton.Create(Self);
  FBtnZoomOut.Parent := FBar;
  FBtnZoomOut.SetBounds(362, 10, 36, 32);
  FBtnZoomOut.Caption := '-';
  FBtnZoomOut.OnClick := @DoZoomOut;

  FBtnZoomIn := TTyButton.Create(Self);
  FBtnZoomIn.Parent := FBar;
  FBtnZoomIn.SetBounds(404, 10, 36, 32);
  FBtnZoomIn.Caption := '+';
  FBtnZoomIn.OnClick := @DoZoomIn;

  FBtnFit := TTyButton.Create(Self);
  FBtnFit.Parent := FBar;
  FBtnFit.SetBounds(448, 10, 92, 32);
  FBtnFit.Caption := Tr('Fit Width');
  FBtnFit.OnClick := @DoFitWidth;

  FBtnPageSetup := TTyButton.Create(Self);
  FBtnPageSetup.Parent := FBar;
  FBtnPageSetup.SetBounds(548, 10, 100, 32);
  FBtnPageSetup.Caption := Tr('Page Setup');
  FBtnPageSetup.OnClick := @DoPageSetup;

  FBtnPrint := TTyButton.Create(Self);
  FBtnPrint.Parent := FBar;
  FBtnPrint.SetBounds(656, 10, 100, 32);
  FBtnPrint.Caption := Tr('Print...');
  FBtnPrint.OnClick := @DoPrint;

  FBtnClose := TTyButton.Create(Self);
  FBtnClose.Parent := FBar;
  FBtnClose.SetBounds(764, 10, 90, 32);
  FBtnClose.Caption := Tr('Close');
  FBtnClose.OnClick := @DoClose;
end;

procedure TPrintPreviewForm.RebuildLayout;
var
  NewLayout: TPrintLayout;
  Options: TPrintOptions;
begin
  Options := PrintOptionsFromSettings(FSettings);
  NewLayout := MakePrintLayout(FLines, Options, FFirstLine, FLastLine);
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
  FImage.Left := 16;
  FImage.Top := 16;
end;

procedure TPrintPreviewForm.UpdateControls;
begin
  if FLayout = nil then Exit;
  FPageLabel.Caption := Format(Tr('Page %d of %d') + '  %d%%',
    [FCurrent + 1, FLayout.PageCount, FZoom]);
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

procedure TPrintPreviewForm.DoPageSetup(Sender: TObject);
var
  Dlg: TPrintSetupForm;
begin
  Dlg := TPrintSetupForm.Create(Self, FSettings);
  try
    if Dlg.Execute then
      RebuildLayout;
  finally
    Dlg.Free;
  end;
end;

procedure TPrintPreviewForm.DoPrint(Sender: TObject);
begin
  if (not FBtnPrint.Enabled) or (not Assigned(FOnPrint)) then Exit;
  FOnPrint(Self);
end;

procedure TPrintPreviewForm.DoClose(Sender: TObject);
begin
  Close;
end;

end.
