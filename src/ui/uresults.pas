unit uresults;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Dialogs, fpjson, jsonparser,
  tyControls.Panel, tyControls.ListBox,
  utranslation, uutils;

type
  TSearchHit = class
  public
    FileName: string;
    Line, Col: Integer;
    Text: string;
    constructor Create(const AFileName: string; ALine, ACol: Integer;
      const AText: string);
  end;

  TResultsOpenEvent = procedure(AHit: TSearchHit) of object;

  { Owns the bottom results panel, hit objects and result export. }
  TResultsView = class(TComponent)
  private
    FPanel: TTyPanel;
    FList: TTyListBox;
    FOnOpen: TResultsOpenEvent;
    procedure ListDblClick(Sender: TObject);
    function GetVisible: Boolean;
    procedure SetVisible(AValue: Boolean);
    function GetCount: Integer;
  public
    constructor Create(AOwner: TComponent; AParent: TWinControl);
    destructor Destroy; override;
    procedure Add(const AFileName: string; ALine, ACol: Integer;
      const AText: string);
    procedure Clear;
    procedure SelectLast;
    procedure ExportResults(const ADefaultDir: string);
    property Visible: Boolean read GetVisible write SetVisible;
    property Count: Integer read GetCount;
    property OnOpen: TResultsOpenEvent read FOnOpen write FOnOpen;
  end;

implementation

constructor TSearchHit.Create(const AFileName: string; ALine, ACol: Integer;
  const AText: string);
begin
  inherited Create;
  FileName := AFileName;
  Line := ALine;
  Col := ACol;
  Text := AText;
end;

constructor TResultsView.Create(AOwner: TComponent; AParent: TWinControl);
begin
  inherited Create(AOwner);
  FPanel := TTyPanel.Create(Self);
  FPanel.Name := 'ResultsPanel';
  FPanel.Parent := AParent;
  FPanel.Align := alClient;
  FPanel.Visible := False;

  FList := TTyListBox.Create(Self);
  FList.Name := 'ResultsList';
  FList.Parent := FPanel;
  FList.Align := alClient;
  FList.OnDblClick := @ListDblClick;
end;

destructor TResultsView.Destroy;
begin
  Clear;
  inherited;
end;

function TResultsView.GetVisible: Boolean;
begin
  Result := FPanel.Visible;
end;

procedure TResultsView.SetVisible(AValue: Boolean);
begin
  FPanel.Visible := AValue;
end;

function TResultsView.GetCount: Integer;
begin
  Result := FList.Items.Count;
end;

procedure TResultsView.Add(const AFileName: string; ALine, ACol: Integer;
  const AText: string);
var
  Hit: TSearchHit;
begin
  Hit := TSearchHit.Create(AFileName, ALine, ACol, AText);
  FList.Items.AddObject(Format('%s:%d:%d: %s',
    [AFileName, ALine, ACol, AText]), Hit);
end;

procedure TResultsView.Clear;
var
  i: Integer;
begin
  for i := 0 to FList.Items.Count - 1 do
    if FList.Items.Objects[i] <> nil then
      FList.Items.Objects[i].Free;
  FList.Items.Clear;
end;

procedure TResultsView.SelectLast;
begin
  if FList.Items.Count > 0 then
    FList.ItemIndex := FList.Items.Count - 1;
end;

procedure TResultsView.ListDblClick(Sender: TObject);
begin
  if (FList.ItemIndex < 0) or not (FList.Items.Objects[FList.ItemIndex] is TSearchHit) then
    Exit;
  if Assigned(FOnOpen) then
    FOnOpen(TSearchHit(FList.Items.Objects[FList.ItemIndex]));
end;

procedure TResultsView.ExportResults(const ADefaultDir: string);
var
  Dlg: TSaveDialog;
  Lines: TStringList;
  Root, Obj: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
  Hit: TSearchHit;
  Path, Ext: string;
begin
  if FList.Items.Count = 0 then Exit;
  Dlg := TSaveDialog.Create(Owner);
  try
    Dlg.InitialDir := ADefaultDir;
    Dlg.FileName := 'tyeditor-search-results.txt';
    Dlg.Filter := Tr('Text files') + '|*.txt|' + Tr('JSON files') + '|*.json';
    if not Dlg.Execute then Exit;
    Path := Dlg.FileName;
  finally
    Dlg.Free;
  end;
  Ext := LowerCase(ExtractFileExt(Path));
  try
    if Ext = '.json' then
    begin
      Root := TJSONObject.Create;
      try
        Arr := TJSONArray.Create;
        for i := 0 to FList.Items.Count - 1 do
        begin
          if not (FList.Items.Objects[i] is TSearchHit) then Continue;
          Hit := TSearchHit(FList.Items.Objects[i]);
          Obj := TJSONObject.Create;
          Obj.Add('file', Hit.FileName);
          Obj.Add('line', Hit.Line);
          Obj.Add('column', Hit.Col);
          Obj.Add('text', Hit.Text);
          Arr.Add(Obj);
        end;
        Root.Add('results', Arr);
        AtomicWriteString(Path, Root.FormatJSON);
      finally
        Root.Free;
      end;
    end
    else
    begin
      Lines := TStringList.Create;
      try
        for i := 0 to FList.Items.Count - 1 do
          if FList.Items.Objects[i] is TSearchHit then
          begin
            Hit := TSearchHit(FList.Items.Objects[i]);
            Lines.Add(Format('%s:%d:%d: %s', [Hit.FileName, Hit.Line, Hit.Col, Hit.Text]));
          end;
        AtomicWriteString(Path, Lines.Text);
      finally
        Lines.Free;
      end;
    end;
  except
    on E: Exception do
      MessageDlg(Format(Tr('Cannot export results: %s'), [E.Message]),
        mtError, [mbOK], 0);
  end;
end;

end.
