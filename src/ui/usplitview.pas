unit usplitview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Controls, Forms, Graphics, ExtCtrls,
  tyControls.Panel, tyControls.TyLabel,
  ATSynEdit, ATSynEdit_Adapter_EControl, ATSynEdit_Globals, ATStrings, ATStringProc,
  ec_SyntAnal, ueditortab, usettings, ucolorscheme, utranslation;

type
  { Read-only document map shown next to the editor pages.

    The main form only decides which TEditorTab is active.  This component owns
    the panel, divider, preview editor, syntax adapter, source change listener
    and all content/style synchronization.  It never writes to the source tab.
    Edits are mirrored line-by-line from TATStrings.OnChangeEx2, so the preview
    does not rebuild the whole document or reset its syntax client per keystroke. }
  TSplitView = class(TComponent)
  private
    FHost: TWinControl;
    FSettings: TAppSettings;
    FHostOnResize: TNotifyEvent;
    FPanel: TTyPanel;
    FBar: TTyPanel;
    FLabel: TTyLabel;
    FEditor: TATSynEdit;
    FAdapter: TATAdapterEControl;
    FVisible: Boolean;
    FStyleTabId: string;
    FStyleDirty: Boolean;
    FContentDirty: Boolean;
    FDragging: Boolean;
    FStartX: Integer;
    FStartWidth: Integer;
    FCurrentTab: TEditorTab;
    FSourceTab: TEditorTab;
    FSourceStrings: TATStrings;
    FPendingKind: TATLineChangeKind;
    FPendingLine: SizeInt;
    FPendingCount: SizeInt;
    FPending: Boolean;
    FQueued: Boolean;
    FForceFull: Boolean;
    FSyncing: Boolean;

    procedure PositionBar;
    procedure HostResized(Sender: TObject);
    procedure PanelResized(Sender: TObject);
    procedure BarMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BarMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure BarMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SourceChanged(Sender: TObject; AChange: TATLineChangeKind;
      ALine, ACount: SizeInt);
    procedure SyncQueued(Data: PtrInt);
    procedure ApplySourceChange;
    procedure AttachSource(ATab: TEditorTab);
    procedure DetachSource;
    procedure CopyEditorViewOptions(ASource, ADest: TATSynEdit);
    procedure EnsureLexer(ATab: TEditorTab);
    procedure SetPreviewText(const AText: string);
    procedure ClearPreview;
    function GetWidth: Integer;
    procedure SetWidth(AValue: Integer);
    function MaxWidth: Integer;
  public
    constructor Create(AOwner: TComponent; AHost: TWinControl;
      ASettings: TAppSettings);
    destructor Destroy; override;
    procedure Toggle(ATab: TEditorTab);
    procedure Refresh(ATab: TEditorTab; AForce: Boolean = False);
    procedure Schedule(ATab: TEditorTab);
    procedure DetachTab(ATab: TEditorTab);
    procedure ApplyTheme(const APalette: TEditorPalette);
    procedure InvalidateStyle;
    property Visible: Boolean read FVisible;
    property Width: Integer read GetWidth write SetWidth;
  end;

implementation

constructor TSplitView.Create(AOwner: TComponent; AHost: TWinControl;
  ASettings: TAppSettings);
begin
  inherited Create(AOwner);
  FHost := AHost;
  FSettings := ASettings;
  FHostOnResize := FHost.OnResize;
  FHost.OnResize := @HostResized;

  FPanel := TTyPanel.Create(Self);
  FPanel.Name := 'SplitPanel';
  FPanel.Parent := FHost;
  FPanel.Align := alRight;
  FPanel.Width := 420;
  FPanel.Visible := False;
  FPanel.OnResize := @PanelResized;

  FBar := TTyPanel.Create(Self);
  FBar.Name := 'SplitBar';
  FBar.Parent := FHost;
  FBar.Align := alNone;
  FBar.Width := 8;
  FBar.Cursor := crHSplit;
  FBar.Visible := False;
  FBar.OnMouseDown := @BarMouseDown;
  FBar.OnMouseMove := @BarMouseMove;
  FBar.OnMouseUp := @BarMouseUp;

  FLabel := TTyLabel.Create(Self);
  FLabel.Parent := FPanel;
  FLabel.Align := alTop;
  FLabel.Height := 24;
  FLabel.Caption := Tr('Document map (read-only)');

  FEditor := TATSynEdit.Create(Self);
  FEditor.Name := 'Preview';
  FEditor.Parent := FPanel;
  FEditor.Align := alClient;
  FEditor.ModeReadOnly := True;
  FEditor.OptCaretVirtual := False;
  FEditor.OptCaretManyAllowed := False;
  FEditor.OptScrollbarsNew := True;
  FEditor.OptMinimapVisible := False;
  FEditor.OptMicromapVisible := False;
  FEditor.OptBorderVisible := False;
  FEditor.OptBorderFocusedActive := False;
  FEditor.OptUnprintedEof := False;

  FAdapter := TATAdapterEControl.Create(Self);
  FAdapter.AddEditor(FEditor);

  FVisible := False;
  FStyleDirty := True;
  FContentDirty := True;
end;

destructor TSplitView.Destroy;
begin
  DetachSource;
  if (FHost <> nil) and (FHost.OnResize = @HostResized) then
    FHost.OnResize := FHostOnResize;
  if FAdapter <> nil then
    FAdapter.AddEditor(nil);
  if FEditor <> nil then
    FEditor.AdapterForHilite := nil;
  inherited;
end;

procedure TSplitView.PositionBar;
begin
  if (FBar = nil) or (FPanel = nil) or (not FVisible) then Exit;
  FBar.Top := FPanel.Top;
  FBar.Height := FPanel.Height;
  FBar.Left := FPanel.Left - FBar.Width;
  FBar.BringToFront;
end;

procedure TSplitView.HostResized(Sender: TObject);
begin
  if Assigned(FHostOnResize) then
    FHostOnResize(Sender);
  if (FPanel <> nil) and FVisible and (FPanel.Width > MaxWidth) then
    FPanel.Width := MaxWidth;
  PositionBar;
end;

procedure TSplitView.PanelResized(Sender: TObject);
begin
  PositionBar;
end;

function TSplitView.MaxWidth: Integer;
begin
  Result := FHost.ClientWidth - 300;
  if Result < 200 then
    Result := Max(120, FHost.ClientWidth div 2);
end;

function TSplitView.GetWidth: Integer;
begin
  if FPanel = nil then
    Result := 0
  else
    Result := FPanel.Width;
end;

procedure TSplitView.SetWidth(AValue: Integer);
begin
  if FPanel = nil then Exit;
  if MaxWidth < 120 then Exit;
  if MaxWidth >= 200 then
    AValue := EnsureRange(AValue, 200, MaxWidth)
  else
    AValue := MaxWidth;
  FPanel.Width := AValue;
  PositionBar;
end;

procedure TSplitView.BarMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  FDragging := True;
  FStartX := Mouse.CursorPos.X;
  FStartWidth := FPanel.Width;
end;

procedure TSplitView.BarMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if not FDragging then Exit;
  SetWidth(FStartWidth - (Mouse.CursorPos.X - FStartX));
end;

procedure TSplitView.BarMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    FDragging := False;
end;

procedure TSplitView.CopyEditorViewOptions(ASource, ADest: TATSynEdit);
var
  i: Integer;
begin
  if (ASource = nil) or (ADest = nil) then Exit;

  { Shared mapping: every new global view setting is handled once in
    ueditortab.ApplyEditorViewOptions. }
  ApplyEditorViewOptions(ADest, FSettings);

  { Per-tab overrides that are not global settings. }
  ADest.OptScaleFont := ASource.OptScaleFont;
  ADest.OptTabSize := ASource.OptTabSize;
  ADest.OptTabSpaces := ASource.OptTabSpaces;
  ADest.OptAutoIndent := ASource.OptAutoIndent;
  ADest.OptNumbersShowCarets := ASource.OptNumbersShowCarets;
  ADest.OptNumbersAutosize := ASource.OptNumbersAutosize;
  ADest.OptNumbersAlignment := ASource.OptNumbersAlignment;
  ADest.OptNumbersIndentPercents := ASource.OptNumbersIndentPercents;
  ADest.OptGutterShowFoldAlways := ASource.OptGutterShowFoldAlways;
  ADest.OptGutterWidthNumbers := ASource.OptGutterWidthNumbers;
  ADest.OptGutterWidthBookmarks := ASource.OptGutterWidthBookmarks;
  ADest.OptGutterWidthFolding := ASource.OptGutterWidthFolding;
  ADest.OptGutterVisible := ASource.OptGutterVisible;
  for i := 0 to Min(ASource.Gutter.Count, ADest.Gutter.Count) - 1 do
  begin
    ADest.Gutter[i].Visible := ASource.Gutter[i].Visible;
    ADest.Gutter[i].Size := ASource.Gutter[i].Size;
  end;

  { Document-map deltas. }
  ADest.OptWrapMode := TATEditorWrapMode.ModeOn;
  ADest.OptUnprintedEof := False;
  ADest.OptMinimapVisible := False;
  ADest.OptMicromapVisible := False;
  ADest.OptBorderVisible := False;
  ADest.OptBorderFocusedActive := False;
  ADest.OptCaretVirtual := False;
  ADest.OptCaretManyAllowed := False;
end;
procedure TSplitView.EnsureLexer(ATab: TEditorTab);
var
  NewLexer: TecSyntAnalyzer;
begin
  NewLexer := nil;
  if (ATab <> nil) and (ATab.Adapter <> nil) then
    NewLexer := ATab.Adapter.Lexer;

  if FAdapter.Lexer = NewLexer then Exit;

  { SetLexer stops and recreates the EControl client.  Never do this when the
    analyzer did not actually change: it is expensive and causes the visible
    flicker/revert cycle. }
  FAdapter.Lexer := NewLexer;
  { Folding visibility and language indentation can change with the lexer. }
  FStyleDirty := True;
  if NewLexer <> nil then
    FEditor.DoEventChange(0);
end;

procedure TSplitView.SetPreviewText(const AText: string);
var
  ScrollTop: Integer;
begin
  ScrollTop := FEditor.LineTop;
  FEditor.ModeReadOnly := False;
  try
    FEditor.Text := AText;
  finally
    FEditor.ModeReadOnly := True;
  end;
  FEditor.LineTop := ScrollTop;
end;

procedure TSplitView.ClearPreview;
begin
  DetachSource;
  if FAdapter.Lexer <> nil then
    FAdapter.Lexer := nil;
  if FEditor.Text <> '' then
    SetPreviewText('');
  FStyleTabId := '';
  FStyleDirty := True;
  FContentDirty := False;
  FCurrentTab := nil;
end;

procedure TSplitView.Toggle(ATab: TEditorTab);
begin
  FVisible := not FVisible;
  FPanel.Visible := FVisible;
  FBar.Visible := FVisible;
  if FVisible then
  begin
    InvalidateStyle;
    FContentDirty := True;
    Refresh(ATab, True);
    PositionBar;
  end
  else
    DetachSource;
end;

procedure TSplitView.Refresh(ATab: TEditorTab; AForce: Boolean);
var
  TabChanged: Boolean;
begin
  if ATab = nil then
  begin
    FCurrentTab := nil;
    if FVisible then
      ClearPreview;
    Exit;
  end;
  { Track the active tab even while hidden, so DetachTab can drop the adapter
    before that tab is destroyed. }
  FCurrentTab := ATab;
  if not FVisible then Exit;
  AttachSource(ATab);

  TabChanged := FStyleTabId <> ATab.SessionId;
  if AForce then
  begin
    FContentDirty := True;
    FStyleDirty := True;
  end;
  if TabChanged then
    FContentDirty := True;

  EnsureLexer(ATab);

  if FStyleDirty or TabChanged then
  begin
    CopyEditorViewOptions(ATab.Editor, FEditor);
    FStyleTabId := ATab.SessionId;
    FStyleDirty := False;
  end;

  if FContentDirty then
  begin
    SetPreviewText(ATab.Editor.Text);
    FContentDirty := False;
    FPending := False;
    FForceFull := False;
    FQueued := False;
  end;

  FEditor.Invalidate;
  PositionBar;
end;

procedure TSplitView.Schedule(ATab: TEditorTab);
begin
  if ATab <> nil then
    FCurrentTab := ATab;
  if not FVisible then Exit;
  if (FSourceTab <> FCurrentTab) or (FSourceStrings = nil) then
    Exit;
  if FQueued then Exit;
  FQueued := True;
  Application.QueueAsyncCall(@SyncQueued, 0);
end;

procedure TSplitView.SourceChanged(Sender: TObject; AChange: TATLineChangeKind;
  ALine, ACount: SizeInt);
begin
  if FSyncing or (not FVisible) or (Sender <> FSourceStrings) then Exit;
  if FPending then
    // More than one edit before the queued sync: do one full copy rather than
    // apply a stale single-line hint.
    FForceFull := True
  else
  begin
    FPendingKind := AChange;
    FPendingLine := ALine;
    FPendingCount := ACount;
    FPending := True;
  end;
  if not FQueued then
  begin
    FQueued := True;
    Application.QueueAsyncCall(@SyncQueued, 0);
  end;
end;

procedure TSplitView.SyncQueued(Data: PtrInt);
begin
  if not FQueued then Exit;
  FQueued := False;
  if (not FVisible) or (FCurrentTab = nil) then Exit;
  if (FSourceTab <> FCurrentTab) or (FSourceStrings = nil) then
  begin
    Refresh(FCurrentTab, True);
    Exit;
  end;
  if (not FPending) or FForceFull then
    Refresh(FCurrentTab, True)
  else
    ApplySourceChange;
end;

procedure TSplitView.ApplySourceChange;
var
  Src, Dst: TATStrings;
  Lines: TStringList;
  Ends: array of TATLineEnds;
  i, N, Line: SizeInt;
begin
  if (FSourceTab = nil) or (FSourceStrings = nil) then Exit;
  Src := FSourceStrings;
  Dst := FEditor.Strings;
  Line := FPendingLine;
  N := FPendingCount;
  if N < 1 then
    N := 1;
  FPending := False;

  if (FPendingKind = TATLineChangeKind.DeletedAll) or (Line < 0) then
  begin
    SetPreviewText(FSourceTab.Editor.Text);
    Exit;
  end;

  FSyncing := True;
  FEditor.ModeReadOnly := False;
  try
    case FPendingKind of
      TATLineChangeKind.Edited:
        if (Line + N <= Src.Count) and (Line + N <= Dst.Count) then
          for i := 0 to N - 1 do
          begin
            Dst.Lines[Line + i] := Src.Lines[Line + i];
            Dst.LinesEnds[Line + i] := Src.LinesEnds[Line + i];
          end
        else
          SetPreviewText(FSourceTab.Editor.Text);

      TATLineChangeKind.Added:
        if (Line <= Src.Count) and (Line + N <= Src.Count) then
        begin
          Lines := TStringList.Create;
          try
            SetLength(Ends, N);
            for i := 0 to N - 1 do
            begin
              Lines.Add(UTF8Encode(Src.Lines[Line + i]));
              Ends[i] := Src.LinesEnds[Line + i];
            end;
            Dst.LineBlockInsertEnds(Line, Lines, Ends);
          finally
            Lines.Free;
          end;
        end
        else
          SetPreviewText(FSourceTab.Editor.Text);

      TATLineChangeKind.Deleted:
        if (Line < Dst.Count) and (Line + N <= Dst.Count) then
          Dst.LineBlockDelete(Line, Line + N - 1)
        else
          SetPreviewText(FSourceTab.Editor.Text);
    end;
  finally
    FEditor.ModeReadOnly := True;
    FSyncing := False;
  end;
  FForceFull := False;
  { A line edit must rebuild the wrap map; otherwise the tail of the changed
    line can remain clipped in the cached wrap bitmap until a resize. }
  FEditor.UpdateWrapInfo(True, True);
  FEditor.Invalidate;
end;

procedure TSplitView.AttachSource(ATab: TEditorTab);
begin
  if (ATab = nil) or (ATab.Editor = nil) then
  begin
    DetachSource;
    Exit;
  end;
  if FSourceStrings = ATab.Editor.Strings then
  begin
    FSourceTab := ATab;
    Exit;
  end;
  DetachSource;
  FSourceTab := ATab;
  FSourceStrings := ATab.Editor.Strings;
  FSourceStrings.OnChangeEx2 := @SourceChanged;
end;

procedure TSplitView.DetachSource;
begin
  if FSourceStrings <> nil then
    FSourceStrings.OnChangeEx2 := nil;
  FSourceStrings := nil;
  FSourceTab := nil;
  FPending := False;
  FForceFull := False;
  FQueued := False;
end;

procedure TSplitView.DetachTab(ATab: TEditorTab);
begin
  if ATab = nil then Exit;
  if FStyleTabId = ATab.SessionId then
    FStyleTabId := '';
  FContentDirty := True;
  { Only the active tab can leave the preview pointing at a destroyed adapter.
    A non-active tab may share the same analyzer; clearing it there would make
    the map lose highlighting without any PageChanged notification. }
  if FSourceTab = ATab then
    DetachSource;
  if FCurrentTab = ATab then
  begin
    FCurrentTab := nil;
    if (FAdapter <> nil) and (ATab.Adapter <> nil) and
      (FAdapter.Lexer = ATab.Adapter.Lexer) then
      FAdapter.Lexer := nil;
  end;
end;

procedure TSplitView.ApplyTheme(const APalette: TEditorPalette);
begin
  if FEditor = nil then Exit;
  ApplyPalette(FEditor, APalette);
end;

procedure TSplitView.InvalidateStyle;
begin
  FStyleDirty := True;
end;

end.
