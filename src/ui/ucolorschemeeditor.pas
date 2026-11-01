unit ucolorschemeeditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, TypInfo,
  tyControls.Controller, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.PropertyGrid, tyControls.ValueListEditor, tyControls.Button, tyControls.TyLabel,
  ucolorscheme, utranslation;

type
  { The palette is a record so the editor can write it back atomically.
    The property grid needs published TColor properties, hence this adapter. }
  TPaletteObject = class(TPersistent)
  private
    FBackground, FText, FSelectionBG, FSelectionText: TColor;
    FCurrentLine, FGutterBG, FGutterText: TColor;
    FComment, FStringLit, FNumberLit, FKeyword: TColor;
    FFunctionName, FTypeName, FOperatorColor, FPreprocessor: TColor;
    FLink, FRulerBG, FRulerFont: TColor;
  published
    property Background: TColor read FBackground write FBackground;
    property Text: TColor read FText write FText;
    property SelectionBackground: TColor read FSelectionBG write FSelectionBG;
    property SelectionText: TColor read FSelectionText write FSelectionText;
    property CurrentLine: TColor read FCurrentLine write FCurrentLine;
    property GutterBackground: TColor read FGutterBG write FGutterBG;
    property GutterText: TColor read FGutterText write FGutterText;
    property Comment: TColor read FComment write FComment;
    property StringLiteral: TColor read FStringLit write FStringLit;
    property Number: TColor read FNumberLit write FNumberLit;
    property Keyword: TColor read FKeyword write FKeyword;
    property FunctionName: TColor read FFunctionName write FFunctionName;
    property TypeName: TColor read FTypeName write FTypeName;
    property OperatorColor: TColor read FOperatorColor write FOperatorColor;
    property Preprocessor: TColor read FPreprocessor write FPreprocessor;
    property Link: TColor read FLink write FLink;
    property RulerBackground: TColor read FRulerBG write FRulerBG;
    property RulerText: TColor read FRulerFont write FRulerFont;
  public
    procedure Load(const P: TEditorPalette);
    procedure SaveTo(out P: TEditorPalette);
  end;

  TColorSchemeEditorForm = class(TTyForm)
  private
    FPalette: TEditorPalette;
    FPaletteObject: TPaletteObject;
    FSurface: TTyFormSurface;
    FTitle: TTyTitleBar;
    FGrid: TTyPropertyGrid;
    procedure BuildUI;
    procedure DoOK(Sender: TObject);
    procedure DoCancel(Sender: TObject);
    procedure PropertyRow(Sender: TObject; AInstance: TPersistent;
      APropInfo: PPropInfo; ARow: TTyValueRow);
  public
    constructor Create(AOwner: TComponent; const APalette: TEditorPalette); reintroduce;
    destructor Destroy; override;
    property Palette: TEditorPalette read FPalette;
    function Execute: Boolean;
  end;

implementation

procedure TPaletteObject.Load(const P: TEditorPalette);
begin
  FBackground := P.Background;
  FText := P.Text;
  FSelectionBG := P.SelectionBG;
  FSelectionText := P.SelectionText;
  FCurrentLine := P.CurrentLine;
  FGutterBG := P.GutterBG;
  FGutterText := P.GutterText;
  FComment := P.Comment;
  FStringLit := P.StringLit;
  FNumberLit := P.NumberLit;
  FKeyword := P.Keyword;
  FFunctionName := P.FunctionName;
  FTypeName := P.TypeName;
  FOperatorColor := P.OperatorColor;
  FPreprocessor := P.Preprocessor;
  FLink := P.Link;
  FRulerBG := P.RulerBG;
  FRulerFont := P.RulerFont;
end;

procedure TPaletteObject.SaveTo(out P: TEditorPalette);
begin
  P.Background := FBackground;
  P.Text := FText;
  P.SelectionBG := FSelectionBG;
  P.SelectionText := FSelectionText;
  P.CurrentLine := FCurrentLine;
  P.GutterBG := FGutterBG;
  P.GutterText := FGutterText;
  P.Comment := FComment;
  P.StringLit := FStringLit;
  P.NumberLit := FNumberLit;
  P.Keyword := FKeyword;
  P.FunctionName := FFunctionName;
  P.TypeName := FTypeName;
  P.OperatorColor := FOperatorColor;
  P.Preprocessor := FPreprocessor;
  P.Link := FLink;
  P.RulerBG := FRulerBG;
  P.RulerFont := FRulerFont;
end;

constructor TColorSchemeEditorForm.Create(AOwner: TComponent;
  const APalette: TEditorPalette);
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  FPalette := APalette;
  FPaletteObject := TPaletteObject.Create;
  FPaletteObject.Load(FPalette);
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  SetBounds(0, 0, 520, 560);
  Caption := Tr('Color Scheme Editor');
  Controller := TyDefaultController;
  BuildUI;
  ApplyChromeTheme(TyDefaultController);
end;

destructor TColorSchemeEditorForm.Destroy;
begin
  FPaletteObject.Free;
  inherited;
end;

procedure TColorSchemeEditorForm.BuildUI;
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
  FTitle.Caption := Tr('Color Scheme Editor');
  FTitle.ShowIcon := True;
  FTitle.TitleAlignment := taCenter;

  L := TTyLabel.Create(Self);
  L.Parent := FSurface;
  L.SetBounds(16, 44, 488, 24);
  L.Caption := Tr('Select a color row; the grid uses the themed color editor.');

  FGrid := TTyPropertyGrid.Create(Self);
  FGrid.Parent := FSurface;
  FGrid.SetBounds(16, 72, 488, 400);
  FGrid.OnGetPropertyRow := @PropertyRow;
  FGrid.SelectedObject := FPaletteObject;

  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(300, 486, 100, 32);
  B.Caption := Tr('OK'); B.OnClick := @DoOK;
  B := TTyButton.Create(Self);
  B.Parent := FSurface; B.SetBounds(408, 486, 96, 32);
  B.Caption := Tr('Cancel'); B.OnClick := @DoCancel;
end;

procedure TColorSchemeEditorForm.PropertyRow(Sender: TObject;
  AInstance: TPersistent; APropInfo: PPropInfo; ARow: TTyValueRow);
begin
  if APropInfo = nil then Exit;
  case APropInfo^.Name of
    'Background': ARow.DisplayKey := Tr('Background');
    'Text': ARow.DisplayKey := Tr('Text');
    'SelectionBackground': ARow.DisplayKey := Tr('Selection background');
    'SelectionText': ARow.DisplayKey := Tr('Selection text');
    'CurrentLine': ARow.DisplayKey := Tr('Current line');
    'GutterBackground': ARow.DisplayKey := Tr('Gutter background');
    'GutterText': ARow.DisplayKey := Tr('Gutter text');
    'Comment': ARow.DisplayKey := Tr('Comment');
    'StringLiteral': ARow.DisplayKey := Tr('String');
    'Number': ARow.DisplayKey := Tr('Number');
    'Keyword': ARow.DisplayKey := Tr('Keyword');
    'FunctionName': ARow.DisplayKey := Tr('Function');
    'TypeName': ARow.DisplayKey := Tr('Type');
    'OperatorColor': ARow.DisplayKey := Tr('Operator');
    'Preprocessor': ARow.DisplayKey := Tr('Preprocessor');
    'Link': ARow.DisplayKey := Tr('Link');
    'RulerBackground': ARow.DisplayKey := Tr('Ruler background');
    'RulerText': ARow.DisplayKey := Tr('Ruler text');
  end;
end;

procedure TColorSchemeEditorForm.DoOK(Sender: TObject);
begin
  FPaletteObject.SaveTo(FPalette);
  ModalResult := mrOk;
end;

procedure TColorSchemeEditorForm.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TColorSchemeEditorForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

end.
