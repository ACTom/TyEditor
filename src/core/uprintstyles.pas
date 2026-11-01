unit uprintstyles;

{$mode objfpc}{$H+}

interface

uses
  Classes, Graphics, ATSynEdit, ATSynEdit_LineParts, uprint;

function PrintLineStylesFromEditor(AEditor: TATSynEdit;
  ALine: Integer): TPrintStyles;
function PrintStylesFromEditor(AEditor: TATSynEdit;
  AFirstLine, ALastLine: Integer): TPrintLineStyles;

implementation

function PrintLineStylesFromEditor(AEditor: TATSynEdit;
  ALine: Integer): TPrintStyles;
var
  Parts: TATLineParts;
  ColorAfter: TColor;
  I, N: Integer;
  FontStyles: TFontStyles;
begin
  SetLength(Result, 0);
  if AEditor = nil then Exit;
  if not AEditor.DoCalcLineHiliteEx(ALine, Parts, clWhite, ColorAfter, False) then
    Exit;

  for I := 0 to High(Parts) do
  begin
    if Parts[I].Len <= 0 then Break;
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N].Start := Parts[I].Offset;
    Result[N].Len := Parts[I].Len;
    if Parts[I].ColorFont = clNone then
      Result[N].Color := AEditor.Colors.TextFont
    else
      Result[N].Color := Parts[I].ColorFont;
    FontStyles := [];
    if (Parts[I].FontStyles and afsFontBold) <> 0 then
      Include(FontStyles, fsBold);
    if (Parts[I].FontStyles and afsFontItalic) <> 0 then
      Include(FontStyles, fsItalic);
    if (Parts[I].FontStyles and afsFontCrossed) <> 0 then
      Include(FontStyles, fsStrikeOut);
    Result[N].FontStyles := FontStyles;
  end;
end;

function PrintStylesFromEditor(AEditor: TATSynEdit;
  AFirstLine, ALastLine: Integer): TPrintLineStyles;
var
  I: Integer;
begin
  SetLength(Result, 0);
  if AEditor = nil then Exit;
  if AFirstLine < 0 then AFirstLine := 0;
  if ALastLine >= AEditor.Strings.Count then
    ALastLine := AEditor.Strings.Count - 1;
  if ALastLine < AFirstLine then Exit;
  SetLength(Result, ALastLine - AFirstLine + 1);
  for I := AFirstLine to ALastLine do
    Result[I - AFirstLine] := PrintLineStylesFromEditor(AEditor, I);
end;

end.
