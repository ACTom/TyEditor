unit ueditortab;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  tyControls.TabSheet,
  ATSynEdit, ATSynEdit_Carets, ATSynEdit_Gutter, ATSynEdit_Globals, ATStrings,
  ATSynEdit_Adapter_EControl, ec_SyntAnal,
  usettings, uutils;

type
  TEditorTab = class
  private
    FPage: TTyTabSheet;
    FEditor: TATSynEdit;
    FAdapter: TATAdapterEControl;
    FFileName: string;
    FUntitledName: string;
    FSessionId: string;
    FBackupFile: string;
    FEolText: string;
    FPinned: Boolean;
    FSettings: TAppSettings;
    procedure UpdateGutterVisibility;
    procedure ApplyLanguageIndent;
    procedure CalcBookmarkColor(Sender: TObject; AKind: Integer; var AColor: TColor);
    function GetModified: Boolean;
    function GetBaseTitle: string;
  public
    constructor Create(AOwner: TComponent; APage: TTyTabSheet;
      const ASessionId: string; ASettings: TAppSettings);
    destructor Destroy; override;
    procedure ApplySettings;
    procedure UpdateCaption;
    procedure LoadFromFile(const AFileName: string; const AEncoding: string = '';
      AForceEncoding: Boolean = False);
    procedure SaveToFile(const AFileName: string);
    procedure SetLexer(ALexer: TecSyntAnalyzer);
    procedure GotoLineColumn(ALine, ACol: Integer);
    procedure ClearBackup;
    procedure RefreshEolText;
    property EolText: string read FEolText;
    property Page: TTyTabSheet read FPage;
    property Editor: TATSynEdit read FEditor;
    property Adapter: TATAdapterEControl read FAdapter;
    property FileName: string read FFileName write FFileName;
    property UntitledName: string read FUntitledName write FUntitledName;
    property SessionId: string read FSessionId write FSessionId;
    property BackupFile: string read FBackupFile write FBackupFile;
    property Pinned: Boolean read FPinned write FPinned;
    property BaseTitle: string read GetBaseTitle;
    property Modified: Boolean read GetModified;
  end;

procedure ApplyEditorViewOptions(AEditor: TATSynEdit; const ASettings: TAppSettings);

implementation

uses
  ATStringProc, uencoding;

procedure ApplyEditorViewOptions(AEditor: TATSynEdit; const ASettings: TAppSettings);
begin
  if (AEditor = nil) or (ASettings = nil) then Exit;
  AEditor.Font.Name := ASettings.FontName;
  AEditor.Font.Size := ASettings.FontSize;
  AEditor.OptTabSize := ASettings.TabSize;
  AEditor.OptTabSpaces := ASettings.TabSpaces;
  if ASettings.WordWrap then
    AEditor.OptWrapMode := TATEditorWrapMode.ModeOn
  else
    AEditor.OptWrapMode := TATEditorWrapMode.ModeOff;
  AEditor.OptUnprintedVisible := ASettings.ShowWhitespace;
  AEditor.OptFoldEnabled := ASettings.ShowFolding;
  AEditor.OptGutterShowFoldAlways := False;
  AEditor.OptRulerVisible := ASettings.ShowRuler;
  AEditor.OptBorderVisible := False;
  AEditor.OptBorderFocusedActive := False;
  AEditor.OptShowCurLine := ASettings.ShowCurLine;
  AEditor.OptShowIndentLines := ASettings.ShowIndentGuides;
  case LowerCase(ASettings.NumbersStyle) of
    'each5': AEditor.OptNumbersStyle := TATEditorNumbersStyle.Each5th;
    'each10': AEditor.OptNumbersStyle := TATEditorNumbersStyle.Each10th;
    'relative': AEditor.OptNumbersStyle := TATEditorNumbersStyle.Relative;
    'none': AEditor.OptNumbersStyle := TATEditorNumbersStyle.None;
  else
    AEditor.OptNumbersStyle := TATEditorNumbersStyle.All;
  end;
  AEditor.OptNumbersShowFirst := not SameText(ASettings.NumbersStyle, 'none');
  AEditor.OptCaretVirtual := False;
  AEditor.OptCaretManyAllowed := False;
  AEditor.OptShowFontLigatures := False;
  AEditor.OptScrollSmooth := ASettings.SmoothScroll;
  AEditor.OptCaretBlinkEnabled := ASettings.CaretBlink;
  AEditor.OptScrollbarsNew := True;
  AEditor.OptScrollStyleVert := TATEditorScrollbarStyle.Auto;
  AEditor.OptScrollStyleHorz := TATEditorScrollbarStyle.Auto;
  AEditor.OptMinimapVisible := ASettings.ShowMinimap;
  AEditor.OptMicromapVisible := ASettings.ShowMicromap;
end;

constructor TEditorTab.Create(AOwner: TComponent; APage: TTyTabSheet;
  const ASessionId: string; ASettings: TAppSettings);
begin
  inherited Create;
  FSettings := ASettings;
  FPage := APage;
  FSessionId := ASessionId;
  FUntitledName := APage.Caption;
  FPage.Caption := FUntitledName;

  FEditor := TATSynEdit.Create(AOwner);
  FEditor.Name := 'Editor_' + ASessionId;
  FEditor.Parent := FPage;
  FEditor.Align := alClient;
  FEditor.Carets.ManyAllowed := False;
  FEditor.OptAutoPairForMultiCarets := False;
  FEditor.Strings.Encoding := TATFileEncoding.UTF8;
  FEditor.Strings.SaveSignUtf8 := False;
  if ASettings.DefaultEncoding <> '' then
    FEditor.EncodingName := ASettings.DefaultEncoding;
  if EolFromName(ASettings.DefaultEol) <> TATLineEnds.None then
    FEditor.Strings.Endings := EolFromName(ASettings.DefaultEol)
  else
    FEditor.Strings.Endings := DefaultEol;

  FAdapter := TATAdapterEControl.Create(AOwner);
  FAdapter.AddEditor(FEditor);

  ApplySettings;
end;

destructor TEditorTab.Destroy;
begin
  { The editor is a child of the page and is destroyed with it.  The adapter
    is owned by the main form, so it must be released here or every closed tab
    leaks its EControl client and parse ranges. }
  if FAdapter <> nil then
  begin
    FAdapter.AddEditor(nil);
    FreeAndNil(FAdapter);
  end;
  inherited;
end;

function TEditorTab.GetModified: Boolean;
begin
  Result := (FEditor <> nil) and FEditor.Modified;
end;

function TEditorTab.GetBaseTitle: string;
begin
  if FFileName <> '' then
    Result := ExtractFileName(FFileName)
  else
    Result := FUntitledName;
end;

procedure TEditorTab.UpdateCaption;
var
  S: string;
begin
  if FPage = nil then Exit;
  S := BaseTitle;
  if Pinned then
    S := '[P] ' + S;
  if Modified then
    S := '*' + S;
  if FEditor.ModeReadOnly then
    S := S + ' [RO]';
  if FPage.Caption <> S then
    FPage.Caption := S;
end;

procedure TEditorTab.ApplySettings;
var
  MouseActions: TATEditorMouseActions;
begin
  if FEditor = nil then Exit;
  ApplyEditorViewOptions(FEditor, FSettings);
  FEditor.OptCopyLinesIfNoSel := False;
  FEditor.OptCutLinesIfNoSel := False;
  FEditor.OptMouseRightClickMovesCaret := False;
  FEditor.OptMouse2ClickOpensURL := False;
  FEditor.OptMouse2ClickAction := TATEditorDoubleClickAction.SelectWordChars;
  InitEditorMouseActions(MouseActions, True);
  FEditor.MouseActions := MouseActions;
  FEditor.OptAutoIndent := FSettings.AutoIndent;
  FEditor.OptAutoPairForMultiCarets := FSettings.AutoPair;
  if FSettings.AutoPair then
    FEditor.OptAutoPairChars := '([{'
  else
    FEditor.OptAutoPairChars := '';
  FEditor.OptSavingTrimSpaces := FSettings.TrimTrailingSpaces;
  FEditor.OptSavingForceFinalEol := FSettings.ForceFinalEol;
  FEditor.OnCalcBookmarkColor := @CalcBookmarkColor;
  UpdateGutterVisibility;
  ApplyLanguageIndent;
end;

procedure TEditorTab.CalcBookmarkColor(Sender: TObject; AKind: Integer;
  var AColor: TColor);
begin
  case AKind of
    2: AColor := $004080FF; // green
    3: AColor := $00FF6060; // blue-ish
    4: AColor := $00C060C0; // purple
    5: AColor := $00A0A000; // teal
  else
    AColor := $000000E0; // red
  end;
end;

procedure TEditorTab.ApplyLanguageIndent;
var
  i, P: Integer;
  S, LexName, Rule: string;
  TabSize: Integer;
  Spaces, Auto: Boolean;
begin
  if FSettings = nil then Exit;
  if (FAdapter = nil) or (FAdapter.Lexer = nil) then
  begin
    FEditor.OptTabSize := FSettings.TabSize;
    FEditor.OptTabSpaces := FSettings.TabSpaces;
    FEditor.OptAutoIndent := FSettings.AutoIndent;
    Exit;
  end;
  LexName := FAdapter.Lexer.LexerName;
  for i := 0 to FSettings.LanguageIndent.Count - 1 do
  begin
    Rule := FSettings.LanguageIndent[i];
    P := Pos('|', Rule);
    if P = 0 then Continue;
    S := Copy(Rule, 1, P - 1);
    if not SameText(S, LexName) then Continue;
    S := Copy(Rule, P + 1, MaxInt);
    P := Pos('|', S);
    if P = 0 then Continue;
    TabSize := StrToIntDef(Copy(S, 1, P - 1), FEditor.OptTabSize);
    S := Copy(S, P + 1, MaxInt);
    P := Pos('|', S);
    if P = 0 then Continue;
    Spaces := StrToBoolDef(Copy(S, 1, P - 1), FEditor.OptTabSpaces);
    Auto := StrToBoolDef(Copy(S, P + 1, MaxInt), FEditor.OptAutoIndent);
    FEditor.OptTabSize := TabSize;
    FEditor.OptTabSpaces := Spaces;
    FEditor.OptAutoIndent := Auto;
    Exit;
  end;
  FEditor.OptTabSize := FSettings.TabSize;
  FEditor.OptTabSpaces := FSettings.TabSpaces;
  FEditor.OptAutoIndent := FSettings.AutoIndent;
end;

procedure TEditorTab.UpdateGutterVisibility;
var
  N: Integer;
begin
  if FEditor = nil then Exit;
  N := FEditor.Gutter.FindIndexByTag(ATEditorOptions.GutterTagNumbers);
  if N >= 0 then
    FEditor.Gutter[N].Visible := FSettings.ShowNumbers;
  N := FEditor.Gutter.FindIndexByTag(ATEditorOptions.GutterTagBookmarks);
  if N >= 0 then
    FEditor.Gutter[N].Visible := FSettings.ShowBookmarkMargin;
  N := FEditor.Gutter.FindIndexByTag(ATEditorOptions.GutterTagLineStates);
  if N >= 0 then
    FEditor.Gutter[N].Visible := False;
  N := FEditor.Gutter.FindIndexByTag(ATEditorOptions.GutterTagFolding);
  if N >= 0 then
    FEditor.Gutter[N].Visible := FSettings.ShowFolding and (FAdapter <> nil) and
      (FAdapter.Lexer <> nil);
  N := FEditor.Gutter.FindIndexByTag(ATEditorOptions.GutterTagSeparator);
  if N >= 0 then
    FEditor.Gutter[N].Visible := False;
end;

procedure TEditorTab.LoadFromFile(const AFileName: string;
  const AEncoding: string; AForceEncoding: Boolean);
var
  OldDetect: Boolean;
begin
  if AEncoding <> '' then
  begin
    OldDetect := FEditor.Strings.EncodingDetect;
    try
      FEditor.Strings.EncodingDetect := False;
      FEditor.EncodingName := AEncoding;
      FEditor.LoadFromFile(AFileName, []);
      if AForceEncoding then
        FEditor.EncodingName := AEncoding;
    finally
      FEditor.Strings.EncodingDetect := OldDetect;
    end;
  end
  else
    FEditor.LoadFromFile(AFileName, []);
  FFileName := AFileName;
  FEditor.Modified := False;
  RefreshEolText;
  UpdateCaption;
end;

procedure TEditorTab.SaveToFile(const AFileName: string);
var
  TmpName, BakName: string;
  Probe: TFileStream;
begin
  if FileExists(AFileName) then
  begin
    try
      Probe := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyNone);
      Probe.Free;
    except
      raise Exception.Create('Permission denied: ' + AFileName);
    end;
  end;
  TmpName := AFileName + '.tyeditor.tmp';
  BakName := AFileName + '.tyeditor.bak';
  try
    FEditor.Strings.SaveToFile(TmpName);
    {$IFDEF WINDOWS}
    if FileExists(AFileName) then
    begin
      DeleteFile(BakName);
      if not RenameFile(AFileName, BakName) then
        raise Exception.Create('Cannot replace ' + AFileName);
      if not RenameFile(TmpName, AFileName) then
      begin
        RenameFile(BakName, AFileName);
        raise Exception.Create('Cannot replace ' + AFileName);
      end;
      DeleteFile(BakName);
    end
    else if not RenameFile(TmpName, AFileName) then
      raise Exception.Create('Cannot replace ' + AFileName);
    {$ELSE}
    if not RenameFile(TmpName, AFileName) then
      raise Exception.Create('Cannot replace ' + AFileName);
    {$ENDIF}
  except
    DeleteFile(TmpName);
    raise;
  end;
  FFileName := AFileName;
  FEditor.Modified := False;
  RefreshEolText;
  ClearBackup;
  UpdateCaption;
end;

procedure TEditorTab.SetLexer(ALexer: TecSyntAnalyzer);
begin
  if FAdapter <> nil then
  begin
    FAdapter.Lexer := ALexer;
    UpdateGutterVisibility;
    ApplyLanguageIndent;
    FEditor.DoEventChange(0);
  end;
end;

procedure TEditorTab.GotoLineColumn(ALine, ACol: Integer);
begin
  if ALine < 0 then ALine := 0;
  if ACol < 0 then ACol := 0;
  FEditor.DoGotoPos(Point(ACol, ALine), Point(-1, -1), 5, 5,
    True, TATEditorActionIfFolded.Unfold);
  FEditor.SetFocus;
end;

procedure TEditorTab.RefreshEolText;
begin
  FEolText := EolDisplayName(FEditor);
end;

procedure TEditorTab.ClearBackup;
begin
  if (FBackupFile <> '') and FileExists(FBackupFile) then
    DeleteFile(FBackupFile);
  FBackupFile := '';
end;

end.
