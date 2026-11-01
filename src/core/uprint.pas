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
    SyntaxHighlighting: Boolean;
    MarginLeft: Integer;
    MarginTop: Integer;
    MarginRight: Integer;
    MarginBottom: Integer;
    FontName: string;
    FontSize: Integer;
    TabSize: Integer;
  end;

  TPrintStyle = record
    Start: Integer; // 0-based position in the source line, UTF-16 units
    Len: Integer;
    Color: TColor;
    FontStyles: TFontStyles;
  end;
  TPrintStyles = array of TPrintStyle;
  TPrintLineStyles = array of TPrintStyles;

  TPrintLine = record
    Text: UnicodeString;
    SourceLine: Integer;
    Styles: TPrintStyles;
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
    procedure InitLayout(ASource: TStrings; const AOptions: TPrintOptions;
      ACanvas: TCanvas; AFirstLine, ALastLine, APageWidth, APageHeight: Integer;
      const ALineStyles: TPrintLineStyles);
    procedure AddLine(const AText: UnicodeString; ASourceLine: Integer;
      const AStyles: TPrintStyles);
    procedure BuildLines(ASource: TStrings; AFirstLine, ALastLine: Integer;
      ACanvas: TCanvas; const ALineStyles: TPrintLineStyles);
    procedure ExpandTabs(const AText: UnicodeString; const AStyles: TPrintStyles;
      out AExpanded: UnicodeString; out AExpandedStyles: TPrintStyles);
    function ExpandPageText(const AText: string; APage, APageCount: Integer): string;
    procedure DrawStyledText(ACanvas: TCanvas; AX, AY: Integer;
      const AText: UnicodeString; const AStyles: TPrintStyles);
  public
    constructor Create(ASource: TStrings; const AOptions: TPrintOptions;
      ACanvas: TCanvas; AFirstLine, ALastLine, APageWidth, APageHeight: Integer); overload;
    constructor Create(ASource: TStrings; const AOptions: TPrintOptions;
      ACanvas: TCanvas; AFirstLine, ALastLine, APageWidth, APageHeight: Integer;
      const ALineStyles: TPrintLineStyles); overload;
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
function SlicePrintStyles(const AStyles: TPrintStyles; AStart, ALen: Integer): TPrintStyles;
procedure GetPrintPageGeometry(out ALogicalWidth, ALogicalHeight: Integer;
  out AScaleX, AScaleY: Double);
function MakePrintLayout(ASource: TStrings; const AOptions: TPrintOptions;
  AFirstLine, ALastLine: Integer): TPrintLayout; overload;
function MakePrintLayout(ASource: TStrings; const AOptions: TPrintOptions;
  AFirstLine, ALastLine: Integer; const ALineStyles: TPrintLineStyles): TPrintLayout; overload;
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
  Result.SyntaxHighlighting := ASettings.PrintSyntaxHighlighting;
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

function SlicePrintStyles(const AStyles: TPrintStyles; AStart, ALen: Integer): TPrintStyles;
var
  I, S, E, N: Integer;
begin
  SetLength(Result, 0);
  if ALen <= 0 then Exit;
  for I := 0 to High(AStyles) do
  begin
    S := AStyles[I].Start;
    E := S + AStyles[I].Len;
    if S < AStart then S := AStart;
    if E > AStart + ALen then E := AStart + ALen;
    if E <= S then Continue;
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N].Start := S - AStart;
    Result[N].Len := E - S;
    Result[N].Color := AStyles[I].Color;
    Result[N].FontStyles := AStyles[I].FontStyles;
  end;
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
begin
  inherited Create;
  InitLayout(ASource, AOptions, ACanvas, AFirstLine, ALastLine,
    APageWidth, APageHeight, nil);
end;

constructor TPrintLayout.Create(ASource: TStrings;
  const AOptions: TPrintOptions; ACanvas: TCanvas;
  AFirstLine, ALastLine, APageWidth, APageHeight: Integer;
  const ALineStyles: TPrintLineStyles);
begin
  inherited Create;
  InitLayout(ASource, AOptions, ACanvas, AFirstLine, ALastLine,
    APageWidth, APageHeight, ALineStyles);
end;

procedure TPrintLayout.InitLayout(ASource: TStrings;
  const AOptions: TPrintOptions; ACanvas: TCanvas;
  AFirstLine, ALastLine, APageWidth, APageHeight: Integer;
  const ALineStyles: TPrintLineStyles);
var
  S: string;
  LinesPerPage: Integer;
  Pages, I, N: Integer;
begin
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

  BuildLines(ASource, AFirstLine, ALastLine, ACanvas, ALineStyles);

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

procedure TPrintLayout.ExpandTabs(const AText: UnicodeString;
  const AStyles: TPrintStyles; out AExpanded: UnicodeString;
  out AExpandedStyles: TPrintStyles);

  procedure AppendStyle(AStart, ALen: Integer; AColor: TColor;
    AFontStyles: TFontStyles);
  var
    N: Integer;
  begin
    if ALen <= 0 then Exit;
    N := Length(AExpandedStyles);
    if (N > 0) and
       (AExpandedStyles[N - 1].Start + AExpandedStyles[N - 1].Len = AStart) and
       (AExpandedStyles[N - 1].Color = AColor) and
       (AExpandedStyles[N - 1].FontStyles = AFontStyles) then
      Inc(AExpandedStyles[N - 1].Len, ALen)
    else
    begin
      SetLength(AExpandedStyles, N + 1);
      AExpandedStyles[N].Start := AStart;
      AExpandedStyles[N].Len := ALen;
      AExpandedStyles[N].Color := AColor;
      AExpandedStyles[N].FontStyles := AFontStyles;
    end;
  end;

  function StyleAt(APos: Integer; out AColor: TColor;
    out AFontStyles: TFontStyles): Boolean;
  var
    J: Integer;
  begin
    Result := False;
    AColor := clBlack;
    AFontStyles := [];
    for J := 0 to High(AStyles) do
      if (APos >= AStyles[J].Start) and
         (APos < AStyles[J].Start + AStyles[J].Len) then
      begin
        AColor := AStyles[J].Color;
        AFontStyles := AStyles[J].FontStyles;
        Exit(True);
      end;
  end;

var
  I, N, Col: Integer;
  Ch: WideChar;
  AColor: TColor;
  AFontStyles: TFontStyles;
begin
  AExpanded := '';
  AExpandedStyles := nil;
  Col := 0;
  for I := 1 to Length(AText) do
  begin
    StyleAt(I - 1, AColor, AFontStyles);
    Ch := AText[I];
    if Ch = #9 then
    begin
      N := FOptions.TabSize - (Col mod FOptions.TabSize);
      if N <= 0 then N := FOptions.TabSize;
      AExpanded := AExpanded + StringOfChar(' ', N);
      AppendStyle(Col, N, AColor, AFontStyles);
      Inc(Col, N);
    end
    else
    begin
      AExpanded := AExpanded + Ch;
      AppendStyle(Col, 1, AColor, AFontStyles);
      Inc(Col);
    end;
  end;
end;

procedure TPrintLayout.AddLine(const AText: UnicodeString;
  ASourceLine: Integer; const AStyles: TPrintStyles);
var
  N: Integer;
begin
  N := Length(FLines);
  SetLength(FLines, N + 1);
  FLines[N].Text := AText;
  FLines[N].SourceLine := ASourceLine;
  FLines[N].Styles := AStyles;
end;

procedure TPrintLayout.BuildLines(ASource: TStrings;
  AFirstLine, ALastLine: Integer; ACanvas: TCanvas;
  const ALineStyles: TPrintLineStyles);
var
  I, MaxChars, BreakPos, P, L: Integer;
  Raw, S, Part: UnicodeString;
  AStyles, PartStyles: TPrintStyles;
begin
  ACanvas.Font.Assign(FFont);
  MaxChars := FContentWidth div FCharWidth;
  if MaxChars < 4 then MaxChars := 4;
  if AFirstLine < 0 then AFirstLine := 0;
  if ALastLine >= ASource.Count then ALastLine := ASource.Count - 1;
  for I := AFirstLine to ALastLine do
  begin
    Raw := UTF8Decode(ASource[I]);
    if FOptions.SyntaxHighlighting and (I < Length(ALineStyles)) then
      ExpandTabs(Raw, ALineStyles[I], S, AStyles)
    else
      ExpandTabs(Raw, nil, S, AStyles);
    if (not FOptions.WrapLines) or (Length(S) <= MaxChars) then
    begin
      AddLine(S, I, AStyles);
      Continue;
    end;
    while Length(S) > MaxChars do
    begin
      BreakPos := MaxChars;
      P := LastDelimiter(' ', Copy(S, 1, MaxChars + 1));
      if P > 1 then
        BreakPos := P;
      Part := Copy(S, 1, BreakPos);
      L := Length(TrimRight(Part));
      if L <= 0 then
        Part := ''
      else
        Part := Copy(Part, 1, L);
      PartStyles := SlicePrintStyles(AStyles, 0, Length(Part));
      AddLine(Part, I, PartStyles);
      Delete(S, 1, BreakPos);
      AStyles := SlicePrintStyles(AStyles, BreakPos, Length(S));
      while (S <> '') and (S[1] = ' ') do
      begin
        Delete(S, 1, 1);
        AStyles := SlicePrintStyles(AStyles, 1, Length(S));
      end;
    end;
    AddLine(S, I, AStyles);
  end;
  if Length(FLines) = 0 then
    AddLine('', AFirstLine, nil);
end;

function TPrintLayout.ExpandPageText(const AText: string;
  APage, APageCount: Integer): string;
begin
  Result := StringReplace(AText, '%p', IntToStr(APage), [rfReplaceAll]);
  Result := StringReplace(Result, '%n', IntToStr(APageCount), [rfReplaceAll]);
end;

function PrintTextColor(AColor: TColor): TColor;
var
  C: LongInt;
  R, G, B, Lum: Integer;
begin
  if AColor = clNone then
    Exit(clBlack);
  C := ColorToRGB(AColor);
  R := C and $FF;
  G := (C shr 8) and $FF;
  B := (C shr 16) and $FF;
  { Keep light syntax colors readable on the white print page. }
  Lum := (R * 299 + G * 587 + B * 114) div 1000;
  if Lum > 205 then
  begin
    R := R * 65 div 100;
    G := G * 65 div 100;
    B := B * 65 div 100;
  end;
  Result := RGBToColor(R, G, B);
end;

procedure TPrintLayout.DrawStyledText(ACanvas: TCanvas; AX, AY: Integer;
  const AText: UnicodeString; const AStyles: TPrintStyles);
var
  I, P, S, E, X: Integer;

  procedure DrawPart(const APart: UnicodeString; AColor: TColor;
    AFontStyles: TFontStyles);
  var
    Txt: string;
  begin
    if APart = '' then Exit;
    ACanvas.Font.Color := AColor;
    ACanvas.Font.Style := AFontStyles;
    Txt := UTF8Encode(APart);
    ACanvas.TextOut(X, AY, Txt);
    Inc(X, ACanvas.TextWidth(Txt));
  end;

begin
  X := AX;
  if Length(AStyles) = 0 then
  begin
    DrawPart(AText, clBlack, []);
    Exit;
  end;
  P := 0;
  for I := 0 to High(AStyles) do
  begin
    S := AStyles[I].Start;
    if S < 0 then S := 0;
    if S > Length(AText) then S := Length(AText);
    E := S + AStyles[I].Len;
    if E > Length(AText) then E := Length(AText);
    if E <= P then Continue;
    if S < P then S := P;
    if S > P then
      DrawPart(Copy(AText, P + 1, S - P), clBlack, []);
    if E > S then
      DrawPart(Copy(AText, S + 1, E - S),
        PrintTextColor(AStyles[I].Color), AStyles[I].FontStyles);
    P := E;
  end;
  if P < Length(AText) then
    DrawPart(Copy(AText, P + 1, Length(AText) - P), clBlack, []);
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
  ACanvas.Font.Color := clBlack;
  ACanvas.Font.Style := [];
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
      ACanvas.Font.Color := clBlack;
      ACanvas.Font.Style := [];
      Num := IntToStr(FLines[I].SourceLine + 1);
      LX := AOffsetX + Round((FLeft + FNumberWidth - 6) * AScaleX);
      ACanvas.TextOut(LX - ACanvas.TextWidth(Num), Y, Num);
    end;
    DrawStyledText(ACanvas, X, Y, FLines[I].Text, FLines[I].Styles);
  end;

  if FOptions.Footer then
  begin
    ACanvas.Font.Color := clBlack;
    ACanvas.Font.Style := [];
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

function MakePrintLayout(ASource: TStrings; const AOptions: TPrintOptions;
  AFirstLine, ALastLine: Integer; const ALineStyles: TPrintLineStyles): TPrintLayout;
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
      AFirstLine, ALastLine, PW, PH, ALineStyles);
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
