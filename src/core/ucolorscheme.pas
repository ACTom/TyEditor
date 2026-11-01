unit ucolorscheme;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, fpjson, jsonparser,
  ATSynEdit, ec_SyntAnal, ec_syntax_format, uutils;

type
  TEditorPalette = record
    Background, Text: TColor;
    GutterBG, GutterText, GutterActiveBG, GutterActiveText: TColor;
    RulerBG, RulerFont: TColor;
    CurrentLine, SelectionBG, SelectionText, Caret: TColor;
    Border, Indent, Unprinted, UnprintedBG: TColor;
    BookmarkBG, FoldLine, ChangedBG, AddedBG, SavedBG: TColor;
    Comment, StringLit, NumberLit, Keyword, FunctionName, TypeName: TColor;
    OperatorColor, Preprocessor, Tag, Attribute, Constant, Link: TColor;
  end;

  TColorSchemeDef = record
    Light, Dark: TEditorPalette;
  end;

function ColorSchemeNames: TStringList;
function FindColorScheme(const AName: string): TColorSchemeDef;
function DefaultColorSchemeName: string;
procedure ApplyPalette(AEditor: TATSynEdit; const P: TEditorPalette);
procedure ApplyTokenStyle(AFormat: TecSyntaxFormat; const P: TEditorPalette);
procedure ApplyPaletteToAnalyzer(AAnalyzer: TecSyntAnalyzer; const P: TEditorPalette);
function PaletteToJSON(const P: TEditorPalette): TJSONObject;
function PaletteFromJSON(AObj: TJSONObject; out P: TEditorPalette): Boolean;
function LoadPaletteFile(const AFileName: string; out P: TEditorPalette): Boolean;
procedure SavePaletteFile(const AFileName: string; const P: TEditorPalette);

implementation

function C(R, G, B: Byte): TColor; inline;
begin
  Result := TColor(R or (G shl 8) or (B shl 16));
end;

function MakePalette(ABg, AFg, AComment, AString, ANumber, AKeyword,
  AFunction, AType, AOperator, APreproc, ATag, AAttr, AConst, ALink,
  ASelBG, ASelFG, ACurrent, AGutterBG, AGutterFG, ABorder, AIndent,
  AUnprinted, ABookmark, AFold, AChanged, AAdded, ASaved: TColor): TEditorPalette;
begin
  Result.Background := ABg;
  Result.Text := AFg;
  Result.Comment := AComment;
  Result.StringLit := AString;
  Result.NumberLit := ANumber;
  Result.Keyword := AKeyword;
  Result.FunctionName := AFunction;
  Result.TypeName := AType;
  Result.OperatorColor := AOperator;
  Result.Preprocessor := APreproc;
  Result.Tag := ATag;
  Result.Attribute := AAttr;
  Result.Constant := AConst;
  Result.Link := ALink;
  Result.SelectionBG := ASelBG;
  Result.SelectionText := ASelFG;
  Result.CurrentLine := ACurrent;
  Result.GutterBG := AGutterBG;
  Result.GutterText := AGutterFG;
  Result.GutterActiveBG := ACurrent;
  Result.GutterActiveText := AFg;
  Result.RulerBG := AGutterBG;
  Result.RulerFont := AGutterFG;
  Result.Caret := AFg;
  Result.Border := ABorder;
  Result.Indent := AIndent;
  Result.Unprinted := AUnprinted;
  Result.UnprintedBG := ABg;
  Result.BookmarkBG := ABookmark;
  Result.FoldLine := AFold;
  Result.ChangedBG := AChanged;
  Result.AddedBG := AAdded;
  Result.SavedBG := ASaved;
end;

function ColorSchemeNames: TStringList;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.Add('GitHub');
  Result.Add('One Dark');
  Result.Add('Solarized');
  Result.Add('Monokai');
  Result.Add('Dracula');
  Result.Add('Gruvbox');
  Result.Add('High Contrast');
end;

function DefaultColorSchemeName: string;
begin
  Result := 'GitHub';
end;

function FindColorScheme(const AName: string): TColorSchemeDef;
begin
  if SameText(AName, 'One Dark') then
  begin
    Result.Light := MakePalette(
      C(250,250,250), C(56,58,66), C(160,161,167), C(80,161,79),
      C(152,104,1), C(166,38,164), C(64,120,242), C(193,132,1),
      C(1,132,188), C(166,38,164), C(228,86,73), C(152,104,1),
      C(152,104,1), C(64,120,242), C(229,229,230), C(56,58,66),
      C(240,240,241), C(234,234,235), C(157,157,159), C(219,219,220),
      C(238,238,238), C(205,205,205), C(255,250,205), C(219,219,220),
      C(255,245,200), C(220,245,220), C(215,240,255));
    Result.Dark := MakePalette(
      C(40,44,52), C(171,178,191), C(92,99,112), C(152,195,121),
      C(209,154,102), C(198,120,221), C(97,175,239), C(229,192,123),
      C(86,182,194), C(198,120,221), C(224,108,117), C(209,154,102),
      C(209,154,102), C(97,175,239), C(62,68,81), C(255,255,255),
      C(44,49,60), C(33,37,43), C(127,132,142), C(24,26,31),
      C(50,55,66), C(90,95,105), C(59,46,30), C(60,66,78),
      C(61,56,38), C(40,60,45), C(35,55,70));
  end
  else if SameText(AName, 'Solarized') then
  begin
    Result.Light := MakePalette(
      C(253,246,227), C(101,123,131), C(147,161,161), C(42,161,152),
      C(211,54,130), C(133,153,0), C(38,139,210), C(181,137,0),
      C(101,123,131), C(203,75,22), C(42,161,152), C(181,137,0),
      C(211,54,130), C(38,139,210), C(238,232,213), C(7,54,66),
      C(245,238,220), C(238,232,213), C(147,161,161), C(222,216,198),
      C(238,232,213), C(147,161,161), C(255,242,194), C(222,216,198),
      C(255,245,205), C(225,245,225), C(220,240,250));
    Result.Dark := MakePalette(
      C(0,43,54), C(131,148,150), C(88,110,117), C(42,161,152),
      C(211,54,130), C(133,153,0), C(38,139,210), C(181,137,0),
      C(131,148,150), C(203,75,22), C(42,161,152), C(181,137,0),
      C(211,54,130), C(38,139,210), C(7,54,66), C(253,246,227),
      C(7,54,66), C(7,54,66), C(88,110,117), C(0,43,54),
      C(7,54,66), C(88,110,117), C(60,50,15), C(0,55,70),
      C(60,55,20), C(20,60,50), C(20,50,65));
  end
  else if SameText(AName, 'Monokai') then
  begin
    Result.Light := MakePalette(
      C(248,248,242), C(39,40,34), C(117,113,94), C(80,120,30),
      C(190,120,0), C(166,38,164), C(64,120,242), C(193,132,1),
      C(1,132,188), C(166,38,164), C(228,86,73), C(152,104,1),
      C(190,120,0), C(64,120,242), C(230,230,224), C(39,40,34),
      C(240,240,234), C(238,238,232), C(117,113,94), C(220,220,214),
      C(238,238,232), C(190,190,184), C(255,250,205), C(220,220,214),
      C(255,245,200), C(220,245,220), C(215,240,255));
    Result.Dark := MakePalette(
      C(39,40,34), C(248,248,242), C(117,113,94), C(230,219,116),
      C(174,129,255), C(249,38,114), C(166,226,46), C(102,217,239),
      C(249,38,114), C(249,38,114), C(249,38,114), C(166,226,46),
      C(174,129,255), C(102,217,239), C(73,72,62), C(248,248,242),
      C(45,46,40), C(45,46,40), C(117,113,94), C(73,72,62),
      C(60,62,54), C(117,113,94), C(80,60,20), C(73,72,62),
      C(65,60,35), C(40,65,50), C(35,60,75));
  end
  else if SameText(AName, 'Dracula') then
  begin
    Result.Light := MakePalette(
      C(255,251,235), C(31,31,31), C(140,132,120), C(0,130,80),
      C(160,90,0), C(130,60,160), C(30,90,200), C(160,90,0),
      C(30,110,140), C(130,60,160), C(200,60,70), C(160,90,0),
      C(160,90,0), C(30,90,200), C(232,226,210), C(31,31,31),
      C(245,240,224), C(242,237,221), C(140,132,120), C(220,214,198),
      C(238,233,217), C(190,184,168), C(255,248,205), C(220,214,198),
      C(255,245,200), C(220,245,220), C(215,240,255));
    Result.Dark := MakePalette(
      C(40,42,54), C(248,248,242), C(98,114,164), C(241,250,140),
      C(189,147,249), C(255,121,198), C(139,233,253), C(80,250,123),
      C(255,121,198), C(255,121,198), C(255,121,198), C(80,250,123),
      C(189,147,249), C(139,233,253), C(68,71,90), C(248,248,242),
      C(45,47,60), C(45,47,60), C(98,114,164), C(68,71,90),
      C(60,63,80), C(98,114,164), C(60,50,30), C(68,71,90),
      C(60,55,35), C(35,65,50), C(35,60,75));
  end
  else if SameText(AName, 'Gruvbox') then
  begin
    Result.Light := MakePalette(
      C(251,241,199), C(60,56,54), C(146,131,116), C(121,125,55),
      C(175,58,3), C(143,101,63), C(66,123,88), C(181,118,20),
      C(60,56,54), C(143,101,63), C(121,125,55), C(181,118,20),
      C(175,58,3), C(69,133,136), C(235,219,178), C(60,56,54),
      C(242,229,188), C(235,219,178), C(146,131,116), C(213,196,161),
      C(235,219,178), C(189,174,147), C(242,224,170), C(213,196,161),
      C(255,240,190), C(220,240,210), C(215,240,250));
    Result.Dark := MakePalette(
      C(40,40,40), C(235,219,178), C(146,131,116), C(184,187,38),
      C(211,134,155), C(251,73,52), C(131,165,152), C(250,189,47),
      C(235,219,178), C(211,134,155), C(184,187,38), C(250,189,47),
      C(211,134,155), C(131,165,152), C(80,73,69), C(251,241,199),
      C(50,48,47), C(50,48,47), C(146,131,116), C(80,73,69),
      C(70,65,60), C(146,131,116), C(80,60,30), C(80,73,69),
      C(65,60,35), C(45,65,50), C(40,60,75));
  end
  else if SameText(AName, 'High Contrast') then
  begin
    Result.Light := MakePalette(
      C(255,255,255), C(0,0,0), C(0,96,0), C(0,0,180),
      C(128,0,0), C(128,0,128), C(0,0,255), C(0,96,96),
      C(0,0,0), C(160,0,0), C(0,96,0), C(128,0,128),
      C(128,0,0), C(0,0,200), C(0,0,0), C(255,255,255),
      C(235,235,235), C(240,240,240), C(0,0,0), C(0,0,0),
      C(210,210,210), C(80,80,80), C(255,255,128), C(180,180,180),
      C(255,255,160), C(200,255,200), C(200,230,255));
    Result.Dark := MakePalette(
      C(0,0,0), C(255,255,255), C(128,255,128), C(128,200,255),
      C(255,200,128), C(255,128,255), C(128,200,255), C(128,255,255),
      C(255,255,255), C(255,128,128), C(128,255,128), C(255,128,255),
      C(255,200,128), C(128,200,255), C(255,255,0), C(0,0,0),
      C(30,30,30), C(15,15,15), C(220,220,220), C(80,80,80),
      C(50,50,50), C(160,160,160), C(60,60,0), C(80,80,80),
      C(80,70,0), C(0,70,30), C(0,50,80));
  end
  else
  begin
    Result.Light := MakePalette(
      C(255,255,255), C(31,35,40), C(106,115,125), C(3,47,98),
      C(0,92,197), C(215,58,73), C(111,66,193), C(0,92,197),
      C(36,41,46), C(215,58,73), C(34,134,58), C(111,66,193),
      C(0,92,197), C(9,105,218), C(9,105,218), C(255,255,255),
      C(246,248,250), C(246,248,250), C(87,96,106), C(208,215,222),
      C(234,238,242), C(208,215,222), C(255,251,204), C(208,215,222),
      C(255,248,197), C(218,251,225), C(221,244,255));
    Result.Dark := MakePalette(
      C(13,17,23), C(230,237,243), C(139,148,158), C(165,214,255),
      C(121,192,255), C(255,123,114), C(210,168,255), C(255,166,87),
      C(201,209,217), C(255,123,114), C(126,231,135), C(210,168,255),
      C(121,192,255), C(88,166,255), C(38,79,120), C(255,255,255),
      C(22,27,34), C(22,27,34), C(139,148,158), C(48,54,61),
      C(33,38,45), C(72,79,88), C(59,35,0), C(48,54,61),
      C(61,53,20), C(26,61,40), C(20,50,70));
  end;
end;

procedure ApplyPalette(AEditor: TATSynEdit; const P: TEditorPalette);
begin
  if AEditor = nil then Exit;
  AEditor.Colors.TextBG := P.Background;
  AEditor.Colors.TextFont := P.Text;
  AEditor.Colors.TextDisabledBG := P.Background;
  AEditor.Colors.TextDisabledFont := P.Comment;
  AEditor.Colors.GutterBG := P.GutterBG;
  AEditor.Colors.GutterFont := P.GutterText;
  AEditor.Colors.GutterCaretBG := P.GutterActiveBG;
  AEditor.Colors.GutterCaretFont := P.GutterActiveText;
  AEditor.Colors.RulerBG := P.RulerBG;
  AEditor.Colors.RulerFont := P.RulerFont;
  AEditor.Colors.CurrentLineBG := P.CurrentLine;
  AEditor.Colors.CurrentLineBG2 := P.CurrentLine;
  AEditor.Colors.TextSelBG := P.SelectionBG;
  AEditor.Colors.TextSelFont := P.SelectionText;
  AEditor.Colors.Caret := P.Caret;
  AEditor.Colors.BorderLine := P.Border;
  AEditor.Colors.BorderLineFocused := P.Border;
  AEditor.Colors.IndentVertLines := P.Indent;
  AEditor.Colors.UnprintedFont := P.Unprinted;
  AEditor.Colors.UnprintedBG := P.UnprintedBG;
  AEditor.Colors.BookmarkBG := P.BookmarkBG;
  AEditor.Colors.GutterFoldLine := P.FoldLine;
  AEditor.Colors.GutterFoldLine2 := P.FoldLine;
  AEditor.Colors.GutterFoldBG := P.GutterBG;
  AEditor.Colors.GutterSeparatorBG := P.Border;
  AEditor.Colors.StateChanged := P.ChangedBG;
  AEditor.Colors.StateAdded := P.AddedBG;
  AEditor.Colors.StateSaved := P.SavedBG;
  AEditor.Colors.MarkedLinesBG := P.CurrentLine;
  AEditor.Colors.LockedBG := P.CurrentLine;
  AEditor.Colors.MarginRight := P.Border;
  AEditor.Colors.MarginCaret := P.Caret;
  AEditor.Invalidate;
end;

function IsCommentName(const N: string): Boolean;
begin
  Result := (Pos('comment', N) > 0) or (Pos('doc comment', N) > 0);
end;

function IsStringName(const N: string): Boolean;
begin
  Result := (Pos('string', N) > 0) or (Pos('char', N) > 0) or
    (Pos('quote', N) > 0) or (Pos('heredoc', N) > 0);
end;

function IsNumberName(const N: string): Boolean;
begin
  Result := (Pos('number', N) > 0) or (Pos('numeric', N) > 0) or
    (Pos('integer', N) > 0) or (Pos('float', N) > 0) or
    (Pos('hex', N) > 0) or (Pos('digit', N) > 0);
end;

function TokenColorForName(const P: TEditorPalette; const AName: string;
  AKind: TecTokenKind): TColor;
var
  N: string;
begin
  if AKind = etkComment then Exit(P.Comment);
  if AKind = etkString then Exit(P.StringLit);
  N := LowerCase(AName);
  if IsCommentName(N) then Exit(P.Comment)
  else if IsStringName(N) then Exit(P.StringLit)
  else if IsNumberName(N) then Exit(P.NumberLit)
  else if (Pos('preproc', N) > 0) or (Pos('directive', N) > 0) or
    (Pos('pragma', N) > 0) or (Pos('include', N) > 0) or (Pos('define', N) > 0) then
    Exit(P.Preprocessor)
  else if (Pos('keyword', N) > 0) or (Pos('reserved', N) > 0) then
    Exit(P.Keyword)
  else if (Pos('function', N) > 0) or (Pos('procedure', N) > 0) or
    (Pos('method', N) > 0) or (N = 'proc') or (N = 'func') then
    Exit(P.FunctionName)
  else if (Pos('type', N) > 0) or (Pos('class', N) > 0) or
    (Pos('struct', N) > 0) or (Pos('interface', N) > 0) or
    (Pos('enum', N) > 0) or (Pos('record', N) > 0) then
    Exit(P.TypeName)
  else if (Pos('attrib', N) > 0) or (Pos('property', N) > 0) then
    Exit(P.Attribute)
  else if (Pos('tag', N) > 0) or (Pos('element', N) > 0) or
    (Pos('markup', N) > 0) then
    Exit(P.Tag)
  else if (Pos('constant', N) > 0) or (Pos('boolean', N) > 0) or
    (N = 'true') or (N = 'false') or (N = 'null') or (N = 'nil') then
    Exit(P.Constant)
  else if (Pos('operator', N) > 0) or (Pos('symbol', N) > 0) or
    (Pos('bracket', N) > 0) or (Pos('punct', N) > 0) or
    (Pos('separator', N) > 0) then
    Exit(P.OperatorColor)
  else if (Pos('link', N) > 0) or (Pos('url', N) > 0) then
    Exit(P.Link)
  else
    Result := P.Text;
end;

procedure ApplyTokenStyle(AFormat: TecSyntaxFormat; const P: TEditorPalette);
begin
  if (AFormat = nil) or (AFormat.Font = nil) then Exit;
  AFormat.Font.Color := TokenColorForName(P, AFormat.DisplayName, AFormat.TokenKind);
  // Let the editor background show through; lexer-specific light backgrounds
  // must not leak into a dark scheme.
  AFormat.BgColor := clNone;
end;

procedure ApplyPaletteToAnalyzer(AAnalyzer: TecSyntAnalyzer; const P: TEditorPalette);
var
  i: Integer;
begin
  if AAnalyzer = nil then Exit;
  for i := 0 to AAnalyzer.Formats.Count - 1 do
    ApplyTokenStyle(AAnalyzer.Formats[i], P);
end;


function PaletteToJSON(const P: TEditorPalette): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('background', P.Background);
  Result.Add('text', P.Text);
  Result.Add('gutter_bg', P.GutterBG);
  Result.Add('gutter_text', P.GutterText);
  Result.Add('ruler_bg', P.RulerBG);
  Result.Add('ruler_font', P.RulerFont);
  Result.Add('gutter_active_bg', P.GutterActiveBG);
  Result.Add('gutter_active_text', P.GutterActiveText);
  Result.Add('current_line', P.CurrentLine);
  Result.Add('selection_bg', P.SelectionBG);
  Result.Add('selection_text', P.SelectionText);
  Result.Add('caret', P.Caret);
  Result.Add('border', P.Border);
  Result.Add('indent', P.Indent);
  Result.Add('unprinted', P.Unprinted);
  Result.Add('unprinted_bg', P.UnprintedBG);
  Result.Add('bookmark_bg', P.BookmarkBG);
  Result.Add('fold_line', P.FoldLine);
  Result.Add('changed_bg', P.ChangedBG);
  Result.Add('added_bg', P.AddedBG);
  Result.Add('saved_bg', P.SavedBG);
  Result.Add('comment', P.Comment);
  Result.Add('string', P.StringLit);
  Result.Add('number', P.NumberLit);
  Result.Add('keyword', P.Keyword);
  Result.Add('function', P.FunctionName);
  Result.Add('type', P.TypeName);
  Result.Add('operator', P.OperatorColor);
  Result.Add('preprocessor', P.Preprocessor);
  Result.Add('tag', P.Tag);
  Result.Add('attribute', P.Attribute);
  Result.Add('constant', P.Constant);
  Result.Add('link', P.Link);
end;

function PaletteFromJSON(AObj: TJSONObject; out P: TEditorPalette): Boolean;
  function Col(const AName: string; ADef: TColor): TColor;
  begin
    if AObj.IndexOfName(AName) >= 0 then
      Result := TColor(AObj.Get(AName, Integer(ADef)))
    else
      Result := ADef;
  end;
var
  D: TColorSchemeDef;
begin
  Result := False;
  if AObj = nil then Exit;
  D := FindColorScheme(DefaultColorSchemeName);
  P := D.Light;
  P.Background := Col('background', P.Background);
  P.Text := Col('text', P.Text);
  P.GutterBG := Col('gutter_bg', P.GutterBG);
  P.GutterText := Col('gutter_text', P.GutterText);
  P.RulerBG := Col('ruler_bg', P.RulerBG);
  P.RulerFont := Col('ruler_font', P.RulerFont);
  P.GutterActiveBG := Col('gutter_active_bg', P.GutterActiveBG);
  P.GutterActiveText := Col('gutter_active_text', P.GutterActiveText);
  P.CurrentLine := Col('current_line', P.CurrentLine);
  P.SelectionBG := Col('selection_bg', P.SelectionBG);
  P.SelectionText := Col('selection_text', P.SelectionText);
  P.Caret := Col('caret', P.Caret);
  P.Border := Col('border', P.Border);
  P.Indent := Col('indent', P.Indent);
  P.Unprinted := Col('unprinted', P.Unprinted);
  P.UnprintedBG := Col('unprinted_bg', P.UnprintedBG);
  P.BookmarkBG := Col('bookmark_bg', P.BookmarkBG);
  P.FoldLine := Col('fold_line', P.FoldLine);
  P.ChangedBG := Col('changed_bg', P.ChangedBG);
  P.AddedBG := Col('added_bg', P.AddedBG);
  P.SavedBG := Col('saved_bg', P.SavedBG);
  P.Comment := Col('comment', P.Comment);
  P.StringLit := Col('string', P.StringLit);
  P.NumberLit := Col('number', P.NumberLit);
  P.Keyword := Col('keyword', P.Keyword);
  P.FunctionName := Col('function', P.FunctionName);
  P.TypeName := Col('type', P.TypeName);
  P.OperatorColor := Col('operator', P.OperatorColor);
  P.Preprocessor := Col('preprocessor', P.Preprocessor);
  P.Tag := Col('tag', P.Tag);
  P.Attribute := Col('attribute', P.Attribute);
  P.Constant := Col('constant', P.Constant);
  P.Link := Col('link', P.Link);
  Result := True;
end;

function LoadPaletteFile(const AFileName: string; out P: TEditorPalette): Boolean;
var
  S: string;
  Data: TJSONData;
begin
  Result := False;
  if not ReadTextFileSafe(AFileName, S) then Exit;
  try
    Data := GetJSON(S);
    try
      if Data is TJSONObject then
        Result := PaletteFromJSON(TJSONObject(Data), P);
    finally
      Data.Free;
    end;
  except
    Result := False;
  end;
end;

procedure SavePaletteFile(const AFileName: string; const P: TEditorPalette);
var
  Obj: TJSONObject;
begin
  Obj := PaletteToJSON(P);
  try
    AtomicWriteString(AFileName, Obj.FormatJSON);
  finally
    Obj.Free;
  end;
end;

end.
