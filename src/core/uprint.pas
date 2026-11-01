unit uprint;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Printers, usettings, utranslation;

const
  PrintLogicalDPI = 96;
  PrintMmPerInch = 25.4;

type
  TPrintOptions = record
    LineNumbers: Boolean;
    WrapLines: Boolean;
    Header: Boolean;
    Footer: Boolean;
    SelectionOnly: Boolean;
    MarginLeft: Integer;
    MarginTop: Integer;
    MarginRight: Integer;
    MarginBottom: Integer;
    FontName: string;
    FontSize: Integer;
    TabSize: Integer;
  end;

  TPrintLine = record
    Text: string;
    SourceLine: Integer;
  end;

  TPrintPage = record
    FirstLine: Integer;
    LastLine: Integer;
  end;

  TPrintLayout = class
  private
    FOptions: TPrintOptions;
    FLines: array of TPrintLine;
    FPages: array of TPrintPage;
    FFont: TFont;
    FPageWidth: Integer;
    FPageHeight: Integer;
    FLeft: Integer;
    FTop: Integer;
    FRight: Integer;
    FBottom: Integer;
    FContentTop: Integer;
    FContentHeight: Integer;
    FContentWidth: Integer;
    FLineHeight: Integer;
    FCharWidth: Integer;
    FNumberWidth: Integer;
    FPageCount: Integer;
    procedure AddLine(const AText: string; ASourceLine: Integer);
    procedure BuildLines(ASource: TStrings; AFirstLine, ALastLine: Integer;
      ACanvas: TCanvas);
    function ExpandTabs(const AText: string): string;
    function ExpandPageText(const AText: string; APage, APageCount: Integer): string;
  public
    constructor Create(ASource: TStrings; const AOptions: TPrintOptions;
      ACanvas: TCanvas; AFirstLine, ALastLine, APageWidth, APageHeight: Integer);
    destructor Destroy; override;
    procedure DrawPage(ACanvas: TCanvas; APageIndex: Integer;
      AOffsetX, AOffsetY: Integer; AScaleX, AScaleY: Double;
      APageNumber, APageCount: Integer; const ATitle: string);
    property PageCount: Integer read FPageCount;
    property PageWidth: Integer read FPageWidth;
    property PageHeight: Integer read FPageHeight;
  end;

function MmToPrintPx(AMm: Integer): Integer;
function PrintOptionsFromSettings(ASettings: TAppSettings): TPrintOptions;
procedure GetPrintPageGeometry(out ALogicalWidth, ALogicalHeight: Integer;
  out AScaleX, AScaleY: Double);
function MakePrintLayout(ASource: TStrings; const AOptions: TPrintOptions;
  AFirstLine, ALastLine: Integer): TPrintLayout;
procedure DrawPrintPreviewPage(ALayout: TPrintLayout; APageIndex: Integer;
  ABitmap: TBitmap; APageNumber, APageCount: Integer; const ATitle: string);

implementation

function MmToPrintPx(AMm: Integer): Integer;
begin
  Result := Round(AMm * PrintLogicalDPI / PrintMmPerInch);
end;

function PrintOptionsFromSettings(ASettings: TAppSettings): TPrintOptions;
begin
  Result.LineNumbers := ASettings.PrintLineNumbers;
  Result.WrapLines := ASettings.PrintWrapLines;
  Result.Header := ASettings.PrintHeader;
  Result.Footer := ASettings.PrintFooter;
  Result.SelectionOnly := ASettings.PrintSelectionOnly;
  Result.MarginLeft := ASettings.PrintMarginLeft;
  Result.MarginTop := ASettings.PrintMarginTop;
  Result.MarginRight := ASettings.PrintMarginRight;
  Result.MarginBottom := ASettings.PrintMarginBottom;
  Result.FontName := ASettings.PrintFontName;
  Result.FontSize := ASettings.PrintFontSize;
  if Result.FontName = '' then Result.FontName := 'Courier New';
  if Result.FontSize < 6 then Result.FontSize := 10;
  Result.TabSize := ASettings.TabSize;
  if Result.TabSize < 1 then Result.TabSize := 4;
end;

procedure GetPrintPageGeometry(out ALogicalWidth, ALogicalHeight: Integer;
  out AScaleX, AScaleY: Double);
var
  DPIx, DPIy, PW, PH: Integer;
begin
  { A4 at 96 dpi is the fallback when no printer is available. }
  ALogicalWidth := Round(210 * PrintLogicalDPI / PrintMmPerInch);
  ALogicalHeight := Round(297 * PrintLogicalDPI / PrintMmPerInch);
  AScaleX := 1;
  AScaleY := 1;
  try
    if Printer = nil then Exit;
    DPIx := Printer.XDPI;
    DPIy := Printer.YDPI;
    if (DPIx <= 0) or (DPIy <= 0) then Exit;
    PW := Printer.PaperSize.Width;
    PH := Printer.PaperSize.Height;
    if (PW <= 0) or (PH <= 0) then Exit;
    ALogicalWidth := Round(PW * PrintLogicalDPI / DPIx);
    ALogicalHeight := Round(PH * PrintLogicalDPI / DPIy);
    AScaleX := DPIx / PrintLogicalDPI;
    AScaleY := DPIy / PrintLogicalDPI;
  except
    { keep the A4 fallback }
  end;
end;

constructor TPrintLayout.Create(ASource: TStrings;
  const AOptions: TPrintOptions; ACanvas: TCanvas;
  AFirstLine, ALastLine, APageWidth, APageHeight: Integer);
var
  S: string;
  LinesPerPage: Integer;
  Pages, I, N: Integer;
begin
  inherited Create;
  FOptions := AOptions;
  FPageWidth := APageWidth;
  FPageHeight := APageHeight;
  FFont := TFont.Create;
  FFont.Assign(ACanvas.Font);
  if FOptions.FontName <> '' then
    FFont.Name := FOptions.FontName;
  FFont.Size := FOptions.FontSize;
  FFont.PixelsPerInch := PrintLogicalDPI;

  FLeft := MmToPrintPx(FOptions.MarginLeft);
  FTop := MmToPrintPx(FOptions.MarginTop);
  FRight := MmToPrintPx(FOptions.MarginRight);
  FBottom := MmToPrintPx(FOptions.MarginBottom);

  ACanvas.Font.Assign(FFont);
  FLineHeight := ACanvas.TextHeight('Mg') + 2;
  if FLineHeight < 2 then FLineHeight := 16;
  FCharWidth := ACanvas.TextWidth('M');
  if FCharWidth < 1 then FCharWidth := 8;

  FContentTop := FTop;
  if FOptions.Header then
    Inc(FContentTop, FLineHeight + 6);

  FContentHeight := FPageHeight - FBottom - FContentTop;
  if FOptions.Footer then
    Dec(FContentHeight, FLineHeight + 6);
  if FContentHeight < FLineHeight then
    FContentHeight := FLineHeight;

  FNumberWidth := 0;
  if FOptions.LineNumbers then
  begin
    S := IntToStr(ALastLine + 1);
    if Length(S) < 3 then S := StringOfChar('0', 3 - Length(S)) + S;
    FNumberWidth := ACanvas.TextWidth(S) + 10;
  end;

  FContentWidth := FPageWidth - FLeft - FRight - FNumberWidth;
  if FContentWidth < FCharWidth * 4 then
    FContentWidth := FCharWidth * 4;

  BuildLines(ASource, AFirstLine, ALastLine, ACanvas);

  LinesPerPage := FContentHeight div FLineHeight;
  if LinesPerPage < 1 then LinesPerPage := 1;
  Pages := (Length(FLines) + LinesPerPage - 1) div LinesPerPage;
  if Pages < 1 then Pages := 1;
  SetLength(FPages, Pages);
  for I := 0 to Pages - 1 do
  begin
    FPages[I].FirstLine := I * LinesPerPage;
    N := FPages[I].FirstLine + LinesPerPage - 1;
    if N >= Length(FLines) then N := High(FLines);
    FPages[I].LastLine := N;
  end;
  FPageCount := Pages;
end;

destructor TPrintLayout.Destroy;
begin
  FFont.Free;
  inherited;
end;

function TPrintLayout.ExpandTabs(const AText: string): string;
var
  I, Col: Integer;
begin
  Result := '';
  Col := 0;
  for I := 1 to Length(AText) do
  begin
    if AText[I] = #9 then
    begin
      repeat
        Result := Result + ' ';
        Inc(Col);
      until (Col mod FOptions.TabSize) = 0;
    end
    else
    begin
      Result := Result + AText[I];
      Inc(Col);
    end;
  end;
end;

procedure TPrintLayout.AddLine(const AText: string; ASourceLine: Integer);
var
  N: Integer;
begin
  N := Length(FLines);
  SetLength(FLines, N + 1);
  FLines[N].Text := AText;
  FLines[N].SourceLine := ASourceLine;
end;

procedure TPrintLayout.BuildLines(ASource: TStrings;
  AFirstLine, ALastLine: Integer; ACanvas: TCanvas);
var
  I, MaxChars, BreakPos, P: Integer;
  S, Part: string;
begin
  ACanvas.Font.Assign(FFont);
  MaxChars := FContentWidth div FCharWidth;
  if MaxChars < 4 then MaxChars := 4;
  if AFirstLine < 0 then AFirstLine := 0;
  if ALastLine >= ASource.Count then ALastLine := ASource.Count - 1;
  for I := AFirstLine to ALastLine do
  begin
    S := ExpandTabs(ASource[I]);
    if (not FOptions.WrapLines) or (Length(S) <= MaxChars) then
    begin
      AddLine(S, I);
      Continue;
    end;
    while Length(S) > MaxChars do
    begin
      BreakPos := MaxChars;
      P := LastDelimiter(' ', Copy(S, 1, MaxChars + 1));
      if P > 1 then
        BreakPos := P;
      Part := Copy(S, 1, BreakPos);
      AddLine(TrimRight(Part), I);
      Delete(S, 1, BreakPos);
      while (S <> '') and (S[1] = ' ') do
        Delete(S, 1, 1);
    end;
    AddLine(S, I);
  end;
  if Length(FLines) = 0 then
    AddLine('', AFirstLine);
end;

function TPrintLayout.ExpandPageText(const AText: string;
  APage, APageCount: Integer): string;
begin
  Result := StringReplace(AText, '%p', IntToStr(APage), [rfReplaceAll]);
  Result := StringReplace(Result, '%n', IntToStr(APageCount), [rfReplaceAll]);
end;

procedure TPrintLayout.DrawPage(ACanvas: TCanvas; APageIndex: Integer;
  AOffsetX, AOffsetY: Integer; AScaleX, AScaleY: Double;
  APageNumber, APageCount: Integer; const ATitle: string);
var
  I, X, Y, LX, LY: Integer;
  S, Num: string;
  Page: TPrintPage;
begin
  if (APageIndex < 0) or (APageIndex >= Length(FPages)) then Exit;
  Page := FPages[APageIndex];

  ACanvas.Font.Assign(FFont);
  if AScaleY <> 1 then
    ACanvas.Font.Height := Round(FFont.Height * AScaleY);
  ACanvas.Brush.Color := clWhite;
  ACanvas.FillRect(Rect(
    AOffsetX,
    AOffsetY,
    AOffsetX + Round(FPageWidth * AScaleX),
    AOffsetY + Round(FPageHeight * AScaleY)));

  if FOptions.Header then
  begin
    S := ExpandPageText(ATitle, APageNumber, APageCount);
    ACanvas.TextOut(AOffsetX + Round(FLeft * AScaleX),
      AOffsetY + Round(FTop * AScaleY), S);
  end;

  for I := Page.FirstLine to Page.LastLine do
  begin
    Y := AOffsetY + Round((FContentTop + (I - Page.FirstLine) * FLineHeight) * AScaleY);
    X := AOffsetX + Round((FLeft + FNumberWidth) * AScaleX);
    if FOptions.LineNumbers then
    begin
      Num := IntToStr(FLines[I].SourceLine + 1);
      LX := AOffsetX + Round((FLeft + FNumberWidth - 6) * AScaleX);
      ACanvas.TextOut(LX - ACanvas.TextWidth(Num), Y, Num);
    end;
    ACanvas.TextOut(X, Y, FLines[I].Text);
  end;

  if FOptions.Footer then
  begin
    S := ExpandPageText(Tr('Page %p of %n'), APageNumber, APageCount);
    Y := AOffsetY + Round((FPageHeight - FBottom - FLineHeight) * AScaleY);
    LX := AOffsetX + Round((FPageWidth - ACanvas.TextWidth(S)) / 2);
    ACanvas.TextOut(LX, Y, S);
  end;
end;

function MakePrintLayout(ASource: TStrings; const AOptions: TPrintOptions;
  AFirstLine, ALastLine: Integer): TPrintLayout;
var
  PW, PH: Integer;
  ScaleX, ScaleY: Double;
  Bmp: TBitmap;
begin
  GetPrintPageGeometry(PW, PH, ScaleX, ScaleY);
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(8, 8);
    Result := TPrintLayout.Create(ASource, AOptions, Bmp.Canvas,
      AFirstLine, ALastLine, PW, PH);
  finally
    Bmp.Free;
  end;
end;

procedure DrawPrintPreviewPage(ALayout: TPrintLayout; APageIndex: Integer;
  ABitmap: TBitmap; APageNumber, APageCount: Integer; const ATitle: string);
begin
  ABitmap.SetSize(ALayout.PageWidth, ALayout.PageHeight);
  ABitmap.Canvas.Brush.Color := clWhite;
  ABitmap.Canvas.FillRect(0, 0, ABitmap.Width, ABitmap.Height);
  ALayout.DrawPage(ABitmap.Canvas, APageIndex, 0, 0, 1, 1,
    APageNumber, APageCount, ATitle);
end;

end.
