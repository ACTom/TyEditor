unit ustatus;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls,
  tyControls.StatusBar,
  ATSynEdit, ATSynEdit_Carets,
  ueditortab, uencoding, utranslation;

type
  { Owns the bottom status bar and its eight panels. }
  TStatusView = class(TComponent)
  private
    FBar: TTyStatusBar;
    function GetHeight: Integer;
  public
    constructor Create(AOwner: TComponent; AParent: TWinControl;
      AOnMouseDown: TMouseEvent);
    procedure Update(ATab: TEditorTab);
    procedure SetText(AIndex: Integer; const AText: string);
    function PanelAtPos(X, Y: Integer): Integer;
    property Height: Integer read GetHeight;
  end;

implementation

constructor TStatusView.Create(AOwner: TComponent; AParent: TWinControl;
  AOnMouseDown: TMouseEvent);
var
  P: TTyStatusPanel;
begin
  inherited Create(AOwner);
  FBar := TTyStatusBar.Create(Self);
  FBar.Name := 'Status';
  FBar.Parent := AParent;
  FBar.Align := alBottom;
  FBar.Height := 30;
  FBar.OnMouseDown := AOnMouseDown;

  P := FBar.Panels.Add; P.Text := 'Ln 1, Col 1'; P.Width := 160;
  P := FBar.Panels.Add; P.Text := Tr('Sel 0'); P.Width := 90;
  P := FBar.Panels.Add; P.Text := Format(Tr('Lines %d'), [1]); P.Width := 110;
  P := FBar.Panels.Add; P.Text := 'UTF-8'; P.Width := 160;
  P := FBar.Panels.Add; P.Text := 'LF'; P.Width := 70;
  P := FBar.Panels.Add; P.Text := Tr('Plain text'); P.Width := 140;
  P := FBar.Panels.Add; P.Text := Tr('INS'); P.Width := 60;
  P := FBar.Panels.Add; P.Text := ''; P.Width := 0;
end;

function TStatusView.GetHeight: Integer;
begin
  Result := FBar.Height;
end;

procedure TStatusView.SetText(AIndex: Integer; const AText: string);
begin
  if (AIndex >= 0) and (AIndex < FBar.Panels.Count) then
    FBar.Panels[AIndex].Text := AText;
end;

function TStatusView.PanelAtPos(X, Y: Integer): Integer;
begin
  Result := FBar.PanelAtPos(X, Y);
end;

procedure TStatusView.Update(ATab: TEditorTab);
var
  Ed: TATSynEdit;
  C: TATCaretItem;
  X1, Y1, X2, Y2: Integer;
  Sel: Boolean;
  SelText, LexName: string;
begin
  if ATab = nil then Exit;
  Ed := ATab.Editor;
  if Ed.Carets.Count = 0 then Exit;
  C := Ed.Carets[0];
  X1 := C.PosX; Y1 := C.PosY; X2 := C.EndX; Y2 := C.EndY;
  C.GetRange(X1, Y1, X2, Y2, Sel);
  if Sel then
  begin
    if Y1 = Y2 then
      SelText := Format(Tr('Sel %d'), [Abs(X2 - X1)])
    else
      SelText := Format(Tr('Sel %dL'), [Abs(Y2 - Y1) + 1]);
  end
  else
    SelText := Tr('Sel 0');
  FBar.Panels[0].Text := Format(Tr('Ln %d, Col %d'), [C.PosY + 1, C.PosX + 1]);
  FBar.Panels[1].Text := SelText;
  FBar.Panels[2].Text := Format(Tr('Lines %d'), [Ed.Strings.Count]);
  FBar.Panels[3].Text := EncodingDisplayName(Ed);
  if (ATab.EolText <> '') and (ATab.EolText <> 'NONE') then
    FBar.Panels[4].Text := ATab.EolText
  else
    FBar.Panels[4].Text := EolName(Ed.Strings.Endings);
  if (ATab.Adapter <> nil) and (ATab.Adapter.Lexer <> nil) then
    LexName := ATab.Adapter.Lexer.LexerName
  else
    LexName := Tr('Plain text');
  FBar.Panels[5].Text := LexName;
  if Ed.ModeOverwrite then
    FBar.Panels[6].Text := Tr('OVR')
  else
    FBar.Panels[6].Text := Tr('INS');
  if ATab.FileName <> '' then
    FBar.Panels[7].Text := ATab.FileName
  else
    FBar.Panels[7].Text := ATab.UntitledName;
end;

end.
