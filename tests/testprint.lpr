program testprint;
{$mode objfpc}{$H+}

uses
  Interfaces, SysUtils, Classes, Graphics, uprint;

var
  Failures: Integer = 0;
  Lines: TStringList;
  Options: TPrintOptions;
  Bmp: TBitmap;
  Layout: TPrintLayout;
  I: Integer;

procedure Check(ACond: Boolean; const AMessage: string);
begin
  if not ACond then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', AMessage);
  end;
end;

begin
  Lines := TStringList.Create;
  Bmp := TBitmap.Create;
  try
    for I := 1 to 120 do
      Lines.Add(Format('Line %d: ', [I]) + StringOfChar('x', 140));
    Options.LineNumbers := True;
    Options.WrapLines := True;
    Options.Header := True;
    Options.Footer := True;
    Options.SelectionOnly := False;
    Options.SyntaxHighlighting := False;
    Options.MarginLeft := 15;
    Options.MarginTop := 15;
    Options.MarginRight := 15;
    Options.MarginBottom := 15;
    Options.FontName := 'Courier New';
    Options.FontSize := 10;
    Options.TabSize := 4;

    Bmp.SetSize(8, 8);
    Layout := TPrintLayout.Create(Lines, Options, Bmp.Canvas, 0, Lines.Count - 1,
      794, 1123);
    try
      Check(Layout.PageCount > 1, 'long document paginates');
      Check(Layout.PageWidth = 794, 'page width preserved');
      for I := 0 to Layout.PageCount - 1 do
        Layout.DrawPage(Bmp.Canvas, I, 0, 0, 1, 1, I + 1, Layout.PageCount,
          'Test document');
    finally
      Layout.Free;
    end;
  finally
    Bmp.Free;
    Lines.Free;
  end;

  if Failures = 0 then
    WriteLn('RESULT ok')
  else
    WriteLn('RESULT failures=', Failures);
  if Failures <> 0 then
    Halt(1);
end.
