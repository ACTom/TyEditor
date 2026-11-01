unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Math, Types, Forms, Controls, Graphics, fpjson, jsonparser,
  Dialogs, Menus, StdCtrls, ExtCtrls, LCLType, LCLIntf, Clipbrd, LCLTranslator,
  tyControls.Controller, tyControls.Types, tyControls.Form, tyControls.BuiltinThemes,
  tyControls.PageControl, tyControls.TabSheet, tyControls.StatusBar,
  tyControls.Menu, tyControls.Panel, tyControls.ListBox, tyControls.TyLabel,
  tyControls.Dialogs,
  ATSynEdit, ATSynEdit_Carets, ATSynEdit_Commands, ATSynEdit_Globals,
  ATSynEdit_Bookmarks, ATSynEdit_Adapter_EControl, ATStringProc, atscrollbar,
  ec_SyntAnal,
  uutils, usettings, uencoding, ulanguage, umacro, ueditortab, usession,
  ufind, ufindfilesdlg, utranslation, usettingsdlg, ucolorscheme,
  umacromanager, ubookmarklist, usingleinstance, ucolorschemeeditor, uplatform,
  usplitview, uresults, ustatus, ucommands, umenubuilder,
  upluginapi, upluginmanager, upluginmanagerdlg, upluginoptionsdlg, upluginrun,
  upluginruntime, utools, utoolmanagerdlg, utoolrun;

type
  TPluginMenuAction = class
  public
    Plugin: TPluginInfo;
    Command: TPluginCommand;
  end;

  TClosedTab = class
  public
    FileName: string;
    Title: string;
    Text: string;
    Encoding: string;
    CaretX, CaretY: Integer;
    Pinned: Boolean;
  end;

  TMainForm = class(TTyForm)
  private
    FSurface: TTyFormSurface;
    FTitleBar: TTyTitleBar;
    FMenuBar: TTyMenuBar;
    FPages: TTyPageControl;
    FBottomHost: TTyPanel;
    FStatusView: TStatusView;
    FResultsView: TResultsView;
    FMainMenu: TMainMenu;
    FRecentMenu, FConvertMenu, FReloadEncMenu, FRecentEncMenu, FEolMenu, FLanguageMenu: TMenuItem;
    FWrapItem, FWhitespaceItem, FNumbersItem, FFoldingItem, FMinimapItem,
    FMicromapItem, FAlwaysOnTopItem, FResultsItem, FThemeDarkItem,
    FRulerItem, FBookmarkMarginItem, FSplitViewItem, FThemeMenu, FColorSchemeMenu,
    FMacroRecordItem: TMenuItem;
    FThemeNames, FColorSchemeNames: TStringList;
    FTabs: TList;
    FSettings: TAppSettings;
    FBackupConfig: TBackupConfig;
    FLanguage: TLanguageManager;
    FMacro: TMacro;
    FFindForm: TFindForm;
    FFindFilesForm: TFindInFilesForm;
    FBookmarkForm: TBookmarkListForm;
    FSplitView: TSplitView;
    FInstanceTimer: TTimer;
    FStatusPopup: TTyPopupMenu;
    FTabPopup: TTyPopupMenu;
    FOpenTabsMenu, FPluginMenu: TMenuItem;
    FPluginManager: TPluginManager;
    FPluginActions: TList;
    FUserPluginNoticeShown: Boolean;
    FToolsMenu: TMenuItem;
    FToolStore: TToolStore;
    FClosedTabs: TList;
    FContextTab: TEditorTab;
    FEncodingChoices: TEncodingChoiceArray;
    FLexerNames: TStringList;
    FSessionTimer: TTimer;
    FUntitledCounter: Integer;
    FClosing: Boolean;
    FDestroying: Boolean;
    FRestoring: Boolean;
    FBookmarkGroup: Integer;
    FStartupDone: Boolean;
    FStartupRestorePending: Boolean;
    FStartupWasUnclean: Boolean;
    FRunningMarker: string;
    FLang: string;

    procedure BuildChrome;
    procedure LoadAppIcon;
    procedure BuildMenu;
    procedure BuildBottomPanel;
    function AddItem(AParent: TMenuItem; const ACaption: string;
      AShortCut: TShortCut; ACommand: TMenuCmd; AChecked: Boolean = False;
      ARadio: Boolean = False): TMenuItem;
    procedure AddSep(AParent: TMenuItem);
    function AddSub(AParent: TMenuItem; const ACaption: string): TMenuItem;
    procedure ClearMenu(AMenu: TMenuItem);
    procedure RebuildRecentMenu;
    procedure RebuildEncodingMenus;
    procedure RebuildRecentEncodingMenu;
    procedure RebuildEolMenu;
    procedure RebuildLanguageMenu;
    procedure RebuildThemeMenu;
    procedure RebuildColorSchemeMenu;
    procedure UpdateColorSchemeChecks;
    procedure ColorSchemeClick(Sender: TObject);
    function CurrentPalette: TEditorPalette;
    procedure UpdateDocumentMenuChecks;
    procedure UpdateThemeChecks;
    procedure ApplyAppTheme;
    procedure ThemeClick(Sender: TObject);
    procedure ToggleRuler;
    procedure ToggleBookmarkMargin;

    function CreateTab(const ATitle: string; const ASessionId: string = ''): TEditorTab;
    function ActiveTab: TEditorTab;
    function TabByPage(APage: TTyCustomTabSheet): TEditorTab;
    function TabByIndex(AIndex: Integer): TEditorTab;
    function FindTabByFile(const AFileName: string): TEditorTab;
    procedure SyncTabOrder;
    procedure SelectTab(ATab: TEditorTab);
    procedure NewUntitled;
    procedure OpenFileDialog;
    procedure OpenFiles(const AFiles: array of string);
    function LoadFileIntoTab(ATab: TEditorTab; const AFileName: string;
      const AForceEncoding: string = ''): Boolean;
    function SaveTab(ATab: TEditorTab; ASaveAs: Boolean): Boolean;
    function SaveAll: Boolean;
    procedure ReloadTab(ATab: TEditorTab);
    function ConfirmCloseTab(ATab: TEditorTab; AAsk: Boolean): Boolean;
    procedure CloseTab(ATab: TEditorTab; AAsk: Boolean; var ACanClose: Boolean;
      ACloseAppIfLast: Boolean = True);
    procedure CloseOthers;
    procedure CloseAll;
    procedure CloseRight;
    procedure ReopenClosedTab;
    procedure PushClosedTab(ATab: TEditorTab);
    procedure BuildTabPopup;
    procedure TabPopupOpening(Sender: TObject);
    procedure PagesMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PagesContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure PagesMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PagesDblClick(Sender: TObject);
    procedure TabPopupClose(Sender: TObject);
    procedure TabPopupCloseOthers(Sender: TObject);
    procedure TabPopupCloseRight(Sender: TObject);
    procedure TabPopupCopyPath(Sender: TObject);
    procedure TabPopupReveal(Sender: TObject);
    procedure TabPopupPin(Sender: TObject);
    procedure TabPopupReopen(Sender: TObject);
    procedure RebuildOpenTabsMenu;
    procedure OpenTabMenuClick(Sender: TObject);
    function BundledPluginDir: string;
    function UserPluginDir: string;
    procedure LoadPlugins;
    procedure RebuildPluginMenu;
    procedure PluginActionClick(Sender: TObject);
    procedure ReloadPluginsClick(Sender: TObject);
    procedure OpenPluginFolderClick(Sender: TObject);
    procedure ShowPluginErrorsClick(Sender: TObject);
    procedure ManagePluginsClick(Sender: TObject);
    procedure InstallPluginClick(Sender: TObject);
    procedure RunPluginAction(AAction: TPluginMenuAction);
    procedure ApplyPluginResponse(ATab: TEditorTab; APlugin: TPluginInfo;
      AResponse: TJSONObject);
    procedure ShowPluginError(const AMessage: string);
    function PluginMessage(APlugin: TPluginInfo; AObject: TJSONObject): string;

    procedure LoadTools;
    procedure RebuildToolsMenu;
    procedure ToolActionClick(Sender: TObject);
    procedure ManageToolsClick(Sender: TObject);
    procedure ReloadToolsClick(Sender: TObject);
    procedure ShowToolErrorsClick(Sender: TObject);
    procedure RunExternalTool(ATool: TExternalTool);
    function BuildToolContext(ATab: TEditorTab): TToolContext;
    procedure ApplyToolOutput(ATab: TEditorTab; ATool: TExternalTool;
      const AOutput, AErrOutput: string);
    procedure ShowToolError(const AMessage: string);

    procedure UpdateStatus;
    procedure UpdateCaption;
    procedure EditorChanged(Sender: TObject);
    procedure EditorCaretChanged(Sender: TObject);
    procedure EditorClicked(Sender: TObject);
    procedure EditorCommand(Sender: TObject; ACommand: Integer;
      AInvoke: TATCommandInvoke; const AText: string; var AHandled: Boolean);
    procedure EditorClickGutter(Sender: TObject; ABand: Integer;
      ALine: Integer; var AHandled: Boolean);
    procedure PageChanged(Sender: TObject);
    procedure PageTabClose(Sender: TObject; AIndex: Integer;
      var AllowClose: Boolean);
    procedure PageReorder(Sender: TObject; AFromIndex, AToIndex: Integer);

    procedure MenuClick(Sender: TObject);
    procedure RecentClick(Sender: TObject);
    procedure EncodingConvertClick(Sender: TObject);
    procedure EncodingReloadClick(Sender: TObject);
    procedure EncodingRecentClick(Sender: TObject);
    procedure EolClick(Sender: TObject);
    procedure LexerClick(Sender: TObject);
    procedure LexerAutoClick(Sender: TObject);
    procedure LexerPlainClick(Sender: TObject);
    procedure StatusMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ShowStatusPopup(AKind: Integer);
    procedure DoDropFiles(Sender: TObject; const FileNames: array of string);

    procedure DoEditorCmd(ACommand: Integer);
    procedure ToggleComment(AAdd: Boolean);
    procedure GoToMatchingBracket;
    procedure ToggleBookmark;
    procedure NextBookmark(ANext: Boolean);
    procedure ClearBookmarks;
    procedure ShowBookmarkList;
    procedure SetBookmarkGroup(Sender: TObject);
    procedure BookmarkJump(AEntry: TBookmarkEntry);
    procedure BookmarkDelete(AEntry: TBookmarkEntry);
    procedure JoinLines;
    procedure SplitLine;
    procedure AddCaret(ADown: Boolean);
    procedure GoToLine;
    procedure ShowFindDlg(AReplace: Boolean);
    procedure ShowFindInFilesDlg(AReplace: Boolean);
    procedure FindNext;
    procedure FindPrevious;

    procedure ToggleWrap;
    procedure ToggleWhitespace;
    procedure ToggleNumbers;
    procedure ToggleFolding;
    procedure ToggleMinimap;
    procedure ToggleMicromap;
    procedure ToggleResults;
    procedure ToggleSplitView;
    procedure TogglePinActive;
    procedure ImportColorScheme;
    procedure EditColorScheme;
    procedure ExportColorScheme;
    procedure InstanceTimerTick(Sender: TObject);
    procedure ToggleTheme;
    procedure ToggleAlwaysOnTop;
    procedure ApplyDialogStayOnTop;
    procedure ApplyTopMostLater(Data: PtrInt);
    procedure ToggleFullScreen;
    procedure ApplySettingsToAll;
    procedure ApplyEditorTheme(AEditor: TATSynEdit);
    procedure ApplyScrollbarTheme(ADark: Boolean);

    procedure MacroRecord;
    procedure MacroPlay;
    procedure MacroPlayN;
    procedure MacroSave;
    procedure MacroLoad;
    procedure ShowMacroManager;
    procedure PlayBoundMacro;
    procedure SaveSettingsNow;
    procedure SaveSessionAndSettings;
    procedure RestoreSession;
    procedure UpdateWindowSettings;
    procedure SessionTimerTick(Sender: TObject);

    procedure FindFileResult(const AFileName: string; ALine, ACol: Integer;
      const AText: string);
    procedure ResultsOpen(AHit: TSearchHit);
    procedure CopyPath;
    procedure ExportResults;
    procedure ShowAbout;
    procedure ShowPreferences;
    procedure CloseAppLater(Data: PtrInt);
    procedure MaybeCloseAfterTabClose(Data: PtrInt);
    procedure DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure DoFormShow(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

constructor TMainForm.Create(AOwner: TComponent);
var
  I: Integer;
  Files: array of string;
begin
  RequireDerivedFormResource := False;
  inherited Create(AOwner);
  FTabs := TList.Create;
  FClosedTabs := TList.Create;
  FPluginActions := TList.Create;
  FPluginManager := TPluginManager.Create(AppConfigDir);
  FToolStore := TToolStore.Create(AppConfigDir);
  FSettings := TAppSettings.Create;
  FSettings.Load;
  FBackupConfig := MakeBackupConfig(FSettings.BackupDir, FSettings.BackupKeep);
  if FSettings.SingleInstance then
  begin
    if not AcquireSingleInstance then
    begin
      SetLength(Files, ParamCount);
      for I := 1 to ParamCount do Files[I - 1] := ParamStr(I);
      WriteOpenRequest(Files);
      Application.Terminate;
      Exit;
    end;
  end;
  FRunningMarker := RunningMarkerFileName;
  FStartupWasUnclean := FileExists(FRunningMarker);
  try
    AtomicWriteString(FRunningMarker, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  except
    // A marker failure must not prevent startup.
  end;
  FLang := EffectiveLanguage(FSettings.Language);
  SetDefaultLang(FLang, GetLanguageDir);
  TranslateUnitResourceStringsEx('', GetLanguageDir, 'tycontrols', 'tyControls.StrConsts');
  LoadTranslation(FLang);
  FLanguage := TLanguageManager.Create;
  FLanguage.LoadLibrary;
  FMacro := TMacro.Create;
  if (FSettings.MacroPath <> '') and FileExists(FSettings.MacroPath) then
    FMacro.LoadFromFile(FSettings.MacroPath);
  FEncodingChoices := EncodingChoices;
  FLexerNames := TStringList.Create;
  FLexerNames.CaseSensitive := False;
  FThemeNames := TStringList.Create;
  FThemeNames.CaseSensitive := False;
  FColorSchemeNames := TStringList.Create;
  FColorSchemeNames.CaseSensitive := False;
  LoadPlugins;
  LoadTools;

  BuildChrome;
  BuildMenu;
  RebuildOpenTabsMenu;
  BuildBottomPanel;
  ApplyAppTheme;

  FFindForm := TFindForm.Create(Self);
  FFindForm.SetHistory(FSettings.FindHistory);
  FFindFilesForm := TFindInFilesForm.Create(Self);
  FFindFilesForm.OnResult := @FindFileResult;
  FFindForm.ApplyDefaults(FSettings.FindCase, FSettings.FindWords, FSettings.FindRegex, FSettings.FindWrap);
  FFindFilesForm.ApplyDefaults(FSettings.FindCase, FSettings.FindWords, FSettings.FindRegex);
  FBookmarkGroup := 1;
  FBookmarkForm := TBookmarkListForm.Create(Self);
  FBookmarkForm.OnJump := @BookmarkJump;
  FBookmarkForm.OnDelete := @BookmarkDelete;
  ApplyDialogStayOnTop;

  FSessionTimer := TTimer.Create(Self);
  FSessionTimer.Interval := FSettings.AutoSnapshotSec * 1000;
  FSessionTimer.OnTimer := @SessionTimerTick;

  { Session restore is deferred until OnShow: a crash-recovery dialog shown
    from the constructor runs before Application.MainForm is assigned and is
    therefore not themed by the main form's controller. }
  FStartupRestorePending := FSettings.RestoreSession;
  if not FStartupRestorePending then
  begin
    NewUntitled;
    SelectTab(ActiveTab);
  end;
  FSessionTimer.Enabled := True;
  OnClose := @DoFormClose;
  OnShow := @DoFormShow;
end;

destructor TMainForm.Destroy;
var
  i: Integer;
  Tab: TEditorTab;
begin
  FDestroying := True;
  if FSessionTimer <> nil then
    FSessionTimer.Enabled := False;
  if FSplitView <> nil then
    FreeAndNil(FSplitView);
  if FFindForm <> nil then FreeAndNil(FFindForm);
  if FFindFilesForm <> nil then FreeAndNil(FFindFilesForm);
  if FBookmarkForm <> nil then FreeAndNil(FBookmarkForm);
  if FTabs <> nil then
  begin
    for i := 0 to FTabs.Count - 1 do
    begin
      Tab := TEditorTab(FTabs[i]);
      if Tab <> nil then
      begin
        if Tab.Adapter <> nil then
          Tab.Adapter.AddEditor(nil);
        Tab.Free;
      end;
    end;
    FreeAndNil(FTabs);
  end;
  if FClosedTabs <> nil then
  begin
    for i := 0 to FClosedTabs.Count - 1 do
      TClosedTab(FClosedTabs[i]).Free;
    FreeAndNil(FClosedTabs);
  end;
  if FPluginManager <> nil then FreeAndNil(FPluginManager);
  if FToolStore <> nil then FreeAndNil(FToolStore);
  if FPluginActions <> nil then
  begin
    for I := 0 to FPluginActions.Count - 1 do
      TPluginMenuAction(FPluginActions[I]).Free;
    FreeAndNil(FPluginActions);
  end;
  if FLanguage <> nil then FreeAndNil(FLanguage);
  if FMacro <> nil then FreeAndNil(FMacro);
  if FSettings <> nil then FreeAndNil(FSettings);
  if FLexerNames <> nil then FreeAndNil(FLexerNames);
  if FThemeNames <> nil then FreeAndNil(FThemeNames);
  if FColorSchemeNames <> nil then FreeAndNil(FColorSchemeNames);
  if FEncodingChoices <> nil then FEncodingChoices := nil;
  inherited;
end;

procedure TMainForm.BuildChrome;
begin
  Caption := 'TyEditor';
  BorderIcons := [biSystemMenu, biMinimize, biMaximize];
  Position := poDesigned;
  SetBounds(FSettings.WindowLeft, FSettings.WindowTop,
    FSettings.WindowWidth, FSettings.WindowHeight);
  if FSettings.WindowMaximized then
    WindowState := wsMaximized;

  TyRegisterBuiltinThemes;
  TyDefaultController.ThemeName := FSettings.Theme;
  if FSettings.Theme = '' then
    TyDefaultController.ThemeName := 'default';
  if FSettings.DarkMode then
    TyDefaultController.Mode := 'dark'
  else
    TyDefaultController.Mode := 'light';
  ApplyChromeTheme(TyDefaultController);
  if FSettings.AlwaysOnTop then
    FormStyle := fsStayOnTop
  else if FormStyle = fsStayOnTop then
    FormStyle := fsNormal;
  SetNativeTopMost(Self, FSettings.AlwaysOnTop);

  FSurface := TTyFormSurface.Create(Self);
  FSurface.Name := 'Surface';
  FSurface.Parent := Self;
  FSurface.Align := alClient;

  FTitleBar := TTyTitleBar.Create(Self);
  FTitleBar.Name := 'TitleBar';
  FTitleBar.Parent := FSurface;
  FTitleBar.Align := alTop;
  FTitleBar.Caption := 'TyEditor';
  FTitleBar.TitleAlignment := taCenter;
  FTitleBar.ShowIcon := True;
  LoadAppIcon;

  FPages := TTyPageControl.Create(Self);
  FPages.Name := 'Pages';
  FPages.Parent := FSurface;
  FPages.Align := alClient;
  FPages.TabsClosable := True;
  FPages.OnChange := @PageChanged;
  FPages.OnTabClose := @PageTabClose;
  FPages.OnReorder := @PageReorder;
  BuildTabPopup;

  FSplitView := TSplitView.Create(Self, FSurface, FSettings);

  FInstanceTimer := TTimer.Create(Self);
  FInstanceTimer.Interval := 500;
  FInstanceTimer.OnTimer := @InstanceTimerTick;
  if FSettings.SingleInstance then
    FInstanceTimer.Enabled := True;
end;

procedure TMainForm.LoadAppIcon;
var
  P: string;
begin
  P := AppIconFileName;
  if (P = '') or (not FileExists(P)) then Exit;
  try
    Application.Icon.LoadFromFile(P);
    Icon.Assign(Application.Icon);
    if FTitleBar <> nil then
    begin
      FTitleBar.Icon.Assign(Application.Icon);
      FTitleBar.HostIconChanged;
    end;
  except
    // a missing or unsupported icon must not prevent startup
  end;
end;

function TMainForm.AddItem(AParent: TMenuItem; const ACaption: string;
  AShortCut: TShortCut; ACommand: TMenuCmd; AChecked: Boolean;
  ARadio: Boolean): TMenuItem;
begin
  Result := TMenuItem.Create(FMainMenu);
  Result.Caption := Tr(ACaption);
  if AShortCut <> 0 then
    Result.ShortCut := AShortCut;
  Result.Tag := Ord(ACommand);
  Result.OnClick := @MenuClick;
  Result.Checked := AChecked;
  Result.RadioItem := ARadio;
  AParent.Add(Result);
end;

procedure TMainForm.AddSep(AParent: TMenuItem);
begin
  AddItem(AParent, '-', 0, mcNone);
end;

function TMainForm.AddSub(AParent: TMenuItem; const ACaption: string): TMenuItem;
begin
  Result := TMenuItem.Create(FMainMenu);
  Result.Caption := Tr(ACaption);
  AParent.Add(Result);
end;

procedure TMainForm.BuildMenu;
var
  B: TMenuBuilder;
begin
  B := TMenuBuilder.Create(Self, @MenuClick, @SetBookmarkGroup);
  try
    B.Build;
    FMainMenu := B.MainMenu;
    FRecentMenu := B.RecentMenu;
    FConvertMenu := B.ConvertMenu;
    FReloadEncMenu := B.ReloadEncMenu;
    FRecentEncMenu := B.RecentEncMenu;
    FEolMenu := B.EolMenu;
    FLanguageMenu := B.LanguageMenu;
    FThemeMenu := B.ThemeMenu;
    FColorSchemeMenu := B.ColorSchemeMenu;
    FOpenTabsMenu := B.OpenTabsMenu;
    FWrapItem := B.WrapItem;
    FWhitespaceItem := B.WhitespaceItem;
    FNumbersItem := B.NumbersItem;
    FFoldingItem := B.FoldingItem;
    FRulerItem := B.RulerItem;
    FBookmarkMarginItem := B.BookmarkMarginItem;
    FSplitViewItem := B.SplitViewItem;
    FMinimapItem := B.MinimapItem;
    FMicromapItem := B.MicromapItem;
    FAlwaysOnTopItem := B.AlwaysOnTopItem;
    FThemeDarkItem := B.ThemeDarkItem;
    FResultsItem := B.ResultsItem;
    FMacroRecordItem := B.MacroRecordItem;
    FPluginMenu := B.PluginMenu;
    FToolsMenu := B.ToolsMenu;
  finally
    B.Free;
  end;

  FMenuBar := TTyMenuBar.Create(Self);
  FMenuBar.Name := 'MenuBar';
  FMenuBar.Parent := FTitleBar;
  FMenuBar.Align := alLeft;
  FMenuBar.AutoSizeWidth := True;
  FMenuBar.Menu := FMainMenu;
  MenuBar := FMenuBar;

  RebuildRecentMenu;
  RebuildEncodingMenus;
  RebuildEolMenu;
  RebuildLanguageMenu;
  RebuildThemeMenu;
  RebuildColorSchemeMenu;
  FAlwaysOnTopItem.Checked := FSettings.AlwaysOnTop;
  FWrapItem.Checked := FSettings.WordWrap;
  FWhitespaceItem.Checked := FSettings.ShowWhitespace;
  FNumbersItem.Checked := FSettings.ShowNumbers;
  FFoldingItem.Checked := FSettings.ShowFolding;
  FMinimapItem.Checked := FSettings.ShowMinimap;
  FMicromapItem.Checked := FSettings.ShowMicromap;
  FThemeDarkItem.Checked := FSettings.DarkMode;
  FRulerItem.Checked := FSettings.ShowRuler;
  FBookmarkMarginItem.Checked := FSettings.ShowBookmarkMargin;
  RebuildPluginMenu;
  RebuildToolsMenu;
end;
procedure TMainForm.BuildBottomPanel;
var
  P: TTyStatusPanel;
begin
  FBottomHost := TTyPanel.Create(Self);
  FBottomHost.Name := 'BottomHost';
  FBottomHost.Parent := FSurface;
  FBottomHost.Align := alBottom;
  FBottomHost.Height := 32;

  FStatusView := TStatusView.Create(Self, FBottomHost, @StatusMouseDown);
  FResultsView := TResultsView.Create(Self, FBottomHost);
  FResultsView.OnOpen := @ResultsOpen;
  FBottomHost.Height := FStatusView.Height + 2;

  FStatusPopup := TTyPopupMenu.Create(Self);
  FStatusPopup.Name := 'StatusPopup';
  FStatusPopup.Controller := TyDefaultController;
end;

procedure TMainForm.ClearMenu(AMenu: TMenuItem);
begin
  while AMenu.Count > 0 do
    AMenu.Items[0].Free;
end;

procedure TMainForm.RebuildRecentMenu;
var
  i: Integer;
  It: TMenuItem;
begin
  if FRecentMenu = nil then Exit;
  ClearMenu(FRecentMenu);
  if FSettings.Recent.Count = 0 then
  begin
    It := TMenuItem.Create(FMainMenu);
    It.Caption := Tr('(empty)');
    It.Enabled := False;
    FRecentMenu.Add(It);
    Exit;
  end;
  for i := 0 to FSettings.Recent.Count - 1 do
  begin
    It := TMenuItem.Create(FMainMenu);
    It.Caption := '&' + IntToStr(i + 1) + ' ' + FSettings.Recent[i];
    It.Tag := i;
    It.OnClick := @RecentClick;
    FRecentMenu.Add(It);
  end;
end;

procedure TMainForm.RebuildEncodingMenus;
var
  C: TEncodingChoice;
  It: TMenuItem;
  i: Integer;
begin
  if (FConvertMenu = nil) or (FReloadEncMenu = nil) or (FRecentEncMenu = nil) then Exit;
  ClearMenu(FConvertMenu);
  ClearMenu(FReloadEncMenu);
  for i := 0 to High(FEncodingChoices) do
  begin
    C := FEncodingChoices[i];
    It := TMenuItem.Create(FMainMenu);
    It.Caption := C.Display;
    It.Tag := i;
    It.RadioItem := True;
    It.OnClick := @EncodingConvertClick;
    FConvertMenu.Add(It);

    It := TMenuItem.Create(FMainMenu);
    It.Caption := C.Display;
    It.Tag := i;
    It.RadioItem := True;
    It.OnClick := @EncodingReloadClick;
    FReloadEncMenu.Add(It);
  end;
  RebuildRecentEncodingMenu;
  UpdateDocumentMenuChecks;
end;

procedure TMainForm.RebuildRecentEncodingMenu;
var
  It: TMenuItem;
  i: Integer;
begin
  if FRecentEncMenu = nil then Exit;
  ClearMenu(FRecentEncMenu);
  for i := 0 to FSettings.EncodingHistory.Count - 1 do
  begin
    It := TMenuItem.Create(FMainMenu);
    It.Caption := FSettings.EncodingHistory[i];
    It.Tag := i;
    It.OnClick := @EncodingRecentClick;
    FRecentEncMenu.Add(It);
  end;
  if FSettings.EncodingHistory.Count = 0 then
  begin
    It := TMenuItem.Create(FMainMenu);
    It.Caption := Tr('(none)');
    It.Enabled := False;
    FRecentEncMenu.Add(It);
  end;
end;

procedure TMainForm.RebuildEolMenu;
var
  It: TMenuItem;
begin
  if FEolMenu = nil then Exit;
  ClearMenu(FEolMenu);
  It := TMenuItem.Create(FMainMenu); It.Caption := Tr('Windows (CRLF)');
  It.Tag := Ord(TATLineEnds.Windows); It.RadioItem := True; It.OnClick := @EolClick; FEolMenu.Add(It);
  It := TMenuItem.Create(FMainMenu); It.Caption := Tr('Unix (LF)');
  It.Tag := Ord(TATLineEnds.Unix); It.RadioItem := True; It.OnClick := @EolClick; FEolMenu.Add(It);
  It := TMenuItem.Create(FMainMenu); It.Caption := Tr('Mac (CR)');
  It.Tag := Ord(TATLineEnds.Mac); It.RadioItem := True; It.OnClick := @EolClick; FEolMenu.Add(It);
  It := TMenuItem.Create(FMainMenu); It.Caption := '-'; It.Tag := -1; FEolMenu.Add(It);
  It := TMenuItem.Create(FMainMenu); It.Caption := Tr('Mixed (detected)');
  It.Tag := -1; It.Enabled := False; FEolMenu.Add(It);
  UpdateDocumentMenuChecks;
end;

procedure TMainForm.RebuildLanguageMenu;
var
  It: TMenuItem;
  i: Integer;
  Names: TStringList;
begin
  if FLanguageMenu = nil then Exit;
  ClearMenu(FLanguageMenu);
  FLexerNames.Clear;

  It := TMenuItem.Create(FMainMenu); It.Caption := Tr('&Auto Detect');
  It.Tag := -1; It.RadioItem := True; It.OnClick := @LexerAutoClick; FLanguageMenu.Add(It);
  It := TMenuItem.Create(FMainMenu); It.Caption := Tr('&Plain Text');
  It.Tag := -2; It.RadioItem := True; It.OnClick := @LexerPlainClick; FLanguageMenu.Add(It);
  It := TMenuItem.Create(FMainMenu); It.Caption := '-'; It.Tag := -1; FLanguageMenu.Add(It);

  if not FLanguage.Loaded then
  begin
    It := TMenuItem.Create(FMainMenu);
    It.Caption := Tr('Syntax library not found');
    It.Tag := -1;
    It.Enabled := False;
    FLanguageMenu.Add(It);
    Exit;
  end;

  Names := FLanguage.LexerNames;
  try
    for i := 0 to Names.Count - 1 do
    begin
      FLexerNames.Add(Names[i]);
      It := TMenuItem.Create(FMainMenu);
      It.Caption := StringReplace(Names[i], '&', '&&', [rfReplaceAll]);
      It.Tag := i; It.RadioItem := True;
      It.OnClick := @LexerClick;
      FLanguageMenu.Add(It);
    end;
  finally
    Names.Free;
  end;
  UpdateDocumentMenuChecks;
end;

procedure TMainForm.RebuildThemeMenu;
var
  Names: TStringArray;
  It: TMenuItem;
  i: Integer;
begin
  if FThemeMenu = nil then Exit;
  ClearMenu(FThemeMenu);
  FThemeNames.Clear;
  Names := TyBuiltinThemeNames;
  for i := 0 to High(Names) do
  begin
    FThemeNames.Add(Names[i]);
    It := TMenuItem.Create(FMainMenu);
    It.Caption := Names[i];
    It.Tag := i;
    It.RadioItem := True;
    It.Checked := SameText(Names[i], FSettings.Theme);
    It.OnClick := @ThemeClick;
    FThemeMenu.Add(It);
  end;
end;

procedure TMainForm.UpdateThemeChecks;
var
  i: Integer;
begin
  if FThemeMenu = nil then Exit;
  for i := 0 to FThemeMenu.Count - 1 do
    if (FThemeMenu.Items[i].Tag >= 0) and (FThemeMenu.Items[i].Tag < FThemeNames.Count) then
      FThemeMenu.Items[i].Checked := SameText(FThemeNames[FThemeMenu.Items[i].Tag], FSettings.Theme);
end;

procedure TMainForm.ApplyAppTheme;
begin
  TyDefaultController.ThemeName := FSettings.Theme;
  if FSettings.Theme = '' then
    TyDefaultController.ThemeName := 'default';
  if FSettings.DarkMode then
    TyDefaultController.Mode := 'dark'
  else
    TyDefaultController.Mode := 'light';
  ApplyChromeTheme(TyDefaultController);
  if FSettings.AlwaysOnTop then
    FormStyle := fsStayOnTop
  else if FormStyle = fsStayOnTop then
    FormStyle := fsNormal;
  SetNativeTopMost(Self, FSettings.AlwaysOnTop);
  if FFindForm <> nil then
  begin
    FFindForm.Controller := TyDefaultController;
    FFindForm.ApplyChromeTheme(TyDefaultController);
  end;
  if FFindFilesForm <> nil then
  begin
    FFindFilesForm.Controller := TyDefaultController;
    FFindFilesForm.ApplyChromeTheme(TyDefaultController);
  end;
  ApplyDialogStayOnTop;
  FLanguage.ApplyPalette(CurrentPalette);
  FThemeDarkItem.Checked := FSettings.DarkMode;
  UpdateThemeChecks;
  UpdateColorSchemeChecks;
  ApplySettingsToAll;
  if FSplitView <> nil then
    FSplitView.ApplyTheme(CurrentPalette);
end;

procedure TMainForm.ThemeClick(Sender: TObject);
var
  i: Integer;
begin
  i := (Sender as TMenuItem).Tag;
  if (i < 0) or (i >= FThemeNames.Count) then Exit;
  FSettings.Theme := FThemeNames[i];
  ApplyAppTheme;
end;

procedure TMainForm.ToggleRuler;
begin
  FSettings.ShowRuler := not FSettings.ShowRuler;
  FRulerItem.Checked := FSettings.ShowRuler;
  ApplySettingsToAll;
end;

procedure TMainForm.ToggleBookmarkMargin;
begin
  FSettings.ShowBookmarkMargin := not FSettings.ShowBookmarkMargin;
  FBookmarkMarginItem.Checked := FSettings.ShowBookmarkMargin;
  ApplySettingsToAll;
end;

procedure TMainForm.RebuildColorSchemeMenu;
var
  Names: TStringList;
  It: TMenuItem;
  i: Integer;
begin
  if FColorSchemeMenu = nil then Exit;
  ClearMenu(FColorSchemeMenu);
  FColorSchemeNames.Clear;
  Names := ColorSchemeNames;
  try
    if (FSettings.CustomColorSchemeFile <> '') and FileExists(FSettings.CustomColorSchemeFile) then
      Names.Add('Custom');
    for i := 0 to Names.Count - 1 do
    begin
      FColorSchemeNames.Add(Names[i]);
      It := TMenuItem.Create(FMainMenu);
      It.Caption := Names[i];
      It.Tag := i;
      It.RadioItem := True;
      It.Checked := SameText(Names[i], FSettings.ColorScheme);
      It.OnClick := @ColorSchemeClick;
      FColorSchemeMenu.Add(It);
    end;
    AddSep(FColorSchemeMenu);
    AddItem(FColorSchemeMenu, 'Edit Color Scheme...', SC(Ord('K'), [ssCtrl, ssAlt]), mcEditScheme);
    AddItem(FColorSchemeMenu, 'Import Color Scheme...', 0, mcImportScheme);
    AddItem(FColorSchemeMenu, 'Export Color Scheme...', 0, mcExportScheme);
  finally
    Names.Free;
  end;
end;

procedure TMainForm.UpdateColorSchemeChecks;
var
  i: Integer;
begin
  if FColorSchemeMenu = nil then Exit;
  for i := 0 to FColorSchemeMenu.Count - 1 do
    if (FColorSchemeMenu.Items[i].Tag >= 0) and
       (FColorSchemeMenu.Items[i].Tag < FColorSchemeNames.Count) then
      FColorSchemeMenu.Items[i].Checked :=
        SameText(FColorSchemeNames[FColorSchemeMenu.Items[i].Tag], FSettings.ColorScheme);
end;

procedure TMainForm.ColorSchemeClick(Sender: TObject);
var
  i: Integer;
begin
  i := (Sender as TMenuItem).Tag;
  if (i < 0) or (i >= FColorSchemeNames.Count) then Exit;
  FSettings.ColorScheme := FColorSchemeNames[i];
  ApplyAppTheme;
end;

function TMainForm.CurrentPalette: TEditorPalette;
var
  S: TColorSchemeDef;
begin
  if (FSettings.CustomColorSchemeFile <> '') and
     FileExists(FSettings.CustomColorSchemeFile) and
     LoadPaletteFile(FSettings.CustomColorSchemeFile, Result) then
    Exit;
  S := FindColorScheme(FSettings.ColorScheme);
  if TyDefaultController.Mode = 'dark' then
    Result := S.Dark
  else
    Result := S.Light;
end;

procedure TMainForm.UpdateDocumentMenuChecks;
var
  Tab: TEditorTab;
  Ed: TATSynEdit;
  i: Integer;
  EncName, LexName: string;
  E: TATLineEnds;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  Ed := Tab.Editor;
  EncName := Ed.EncodingName;
  if FConvertMenu <> nil then
    for i := 0 to FConvertMenu.Count - 1 do
      if (FConvertMenu.Items[i].Tag >= 0) and (FConvertMenu.Items[i].Tag <= High(FEncodingChoices)) then
        FConvertMenu.Items[i].Checked := SameText(FEncodingChoices[FConvertMenu.Items[i].Tag].Name, EncName);
  if FReloadEncMenu <> nil then
    for i := 0 to FReloadEncMenu.Count - 1 do
      if (FReloadEncMenu.Items[i].Tag >= 0) and (FReloadEncMenu.Items[i].Tag <= High(FEncodingChoices)) then
        FReloadEncMenu.Items[i].Checked := SameText(FEncodingChoices[FReloadEncMenu.Items[i].Tag].Name, EncName);
  E := Ed.Strings.Endings;
  if FEolMenu <> nil then
    for i := 0 to FEolMenu.Count - 1 do
      if FEolMenu.Items[i].Tag >= 0 then
        FEolMenu.Items[i].Checked := FEolMenu.Items[i].Tag = Ord(E);
  if FLanguageMenu <> nil then
  begin
    if (Tab.Adapter <> nil) and (Tab.Adapter.Lexer <> nil) then
      LexName := Tab.Adapter.Lexer.LexerName
    else
      LexName := '';
    for i := 0 to FLanguageMenu.Count - 1 do
      if FLanguageMenu.Items[i].Tag = -2 then
        FLanguageMenu.Items[i].Checked := LexName = ''
      else if FLanguageMenu.Items[i].Tag >= 0 then
      begin
        if (FLanguageMenu.Items[i].Tag < FLexerNames.Count) and (LexName <> '') then
          FLanguageMenu.Items[i].Checked := SameText(FLexerNames[FLanguageMenu.Items[i].Tag], LexName)
        else
          FLanguageMenu.Items[i].Checked := False;
      end;
  end;
end;

function TMainForm.CreateTab(const ATitle: string;
  const ASessionId: string): TEditorTab;
var
  Page: TTyTabSheet;
  Id: string;
begin
  if ASessionId = '' then
    Id := NewSessionId
  else
    Id := ASessionId;
  Page := FPages.AddPage(ATitle);
  Result := TEditorTab.Create(Self, Page, Id, FSettings);
  ApplyEditorTheme(Result.Editor);
  Result.Editor.OnChange := @EditorChanged;
  Result.Editor.OnChangeCaretPos := @EditorCaretChanged;
  Result.Editor.OnClick := @EditorClicked;
  Result.Editor.OnCommand := @EditorCommand;
  Result.Editor.OnClickGutter := @EditorClickGutter;
  FTabs.Add(Result);
  FPages.ActivePage := Page;
  Result.Editor.SetFocus;
end;

function TMainForm.ActiveTab: TEditorTab;
begin
  Result := nil;
  if FPages <> nil then
    Result := TabByPage(FPages.ActivePage);
end;

function TMainForm.TabByPage(APage: TTyCustomTabSheet): TEditorTab;
var
  i: Integer;
begin
  Result := nil;
  if (APage = nil) or (FTabs = nil) then Exit;
  for i := 0 to FTabs.Count - 1 do
    if TEditorTab(FTabs[i]).Page = APage then
      Exit(TEditorTab(FTabs[i]));
end;

function TMainForm.TabByIndex(AIndex: Integer): TEditorTab;
begin
  Result := nil;
  if (FPages <> nil) and (AIndex >= 0) and (AIndex < FPages.PageCount) then
    Result := TabByPage(FPages.Pages[AIndex]);
end;

function TMainForm.FindTabByFile(const AFileName: string): TEditorTab;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FTabs.Count - 1 do
    if (TEditorTab(FTabs[i]).FileName <> '') and
       SameFileName(TEditorTab(FTabs[i]).FileName, AFileName) then
      Exit(TEditorTab(FTabs[i]));
end;

procedure TMainForm.SyncTabOrder;
var
  i, j: Integer;
  Tmp: TEditorTab;
begin
  for i := 0 to FTabs.Count - 2 do
    for j := i + 1 to FTabs.Count - 1 do
      if TEditorTab(FTabs[j]).Page.PageIndex < TEditorTab(FTabs[i]).Page.PageIndex then
      begin
        Tmp := TEditorTab(FTabs[i]);
        FTabs[i] := FTabs[j];
        FTabs[j] := Tmp;
      end;
end;

procedure TMainForm.SelectTab(ATab: TEditorTab);
begin
  if (ATab = nil) or (FPages = nil) then Exit;
  { PageChanged refreshes status/caption/find/menu when the active page
    actually changes.  Only fill in state when the page was already active
    (for example right after CreateTab/AddPage). }
  if FPages.ActivePage <> ATab.Page then
    FPages.ActivePage := ATab.Page
  else
  begin
    if FFindForm <> nil then
      FFindForm.Editor := ATab.Editor;
    UpdateCaption;
    UpdateStatus;
    UpdateDocumentMenuChecks;
    RebuildOpenTabsMenu;
  end;
  if ATab.Editor.Visible then
    ATab.Editor.SetFocus;
end;

procedure TMainForm.NewUntitled;
var
  Tab: TEditorTab;
begin
  Inc(FUntitledCounter);
  FRestoring := True;
  try
    Tab := CreateTab(Tr('Untitled') + ' ' + IntToStr(FUntitledCounter));
    Tab.Editor.Text := '';
    Tab.Editor.Modified := False;
    Tab.RefreshEolText;
    Tab.UpdateCaption;
  finally
    FRestoring := False;
  end;
  SelectTab(Tab);
end;

procedure TMainForm.OpenFileDialog;
var
  Dlg: TOpenDialog;
  i: Integer;
  Files: array of string;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.InitialDir := FSettings.LastDir;
    Dlg.Filter := Tr('Text files') + '|*.txt;*.md;*.pas;*.pp;*.c;*.h;*.cpp;*.hpp;*.py;*.js;*.ts;*.json;*.xml;*.html;*.css;*.sh;*.ini;*.log;*.csv|' + Tr('All files') + '|*.*';
    Dlg.Options := [ofAllowMultiSelect, ofFileMustExist, ofEnableSizing];
    if not Dlg.Execute then Exit;
    SetLength(Files, Dlg.Files.Count);
    for i := 0 to Dlg.Files.Count - 1 do
      Files[i] := Dlg.Files[i];
    if Length(Files) > 0 then
    begin
      FSettings.LastDir := ExtractFileDir(Files[0]);
      OpenFiles(Files);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.OpenFiles(const AFiles: array of string);
var
  i: Integer;
  Tab: TEditorTab;
  Existing: TEditorTab;
  Allow: Boolean;
begin
  for i := 0 to High(AFiles) do
  begin
    if not FileExists(AFiles[i]) then
    begin
      TyMessageDlg(Format(Tr('File not found: %s'), [AFiles[i]]), mtError, [mbOK]);
      Continue;
    end;
    Existing := FindTabByFile(AFiles[i]);
    if Existing <> nil then
    begin
      SelectTab(Existing);
      Continue;
    end;
    Tab := CreateTab(ExtractFileName(AFiles[i]));
    if not LoadFileIntoTab(Tab, AFiles[i]) then
    begin
      Allow := True;
      CloseTab(Tab, False, Allow, False);
      if FTabs.Count = 0 then
        NewUntitled;
      Continue;
    end;
    SelectTab(Tab);
  end;
end;

function TMainForm.LoadFileIntoTab(ATab: TEditorTab; const AFileName: string;
  const AForceEncoding: string): Boolean;
var
  Lexer: TecSyntAnalyzer;
  Det: TEncodingDetection;
  EncName: string;
begin
  Result := False;
  if (ATab = nil) or (not FileExists(AFileName)) then Exit;
  try
    EncName := AForceEncoding;
    if EncName = '' then
      EncName := FSettings.EncodingForFile(AFileName);
    if EncName = '' then
    begin
      Det := DetectFileEncoding(AFileName);
      if (Det.Name <> '') and (Det.Confidence >= 60) then
        EncName := Det.Name;
    end;
    ATab.LoadFromFile(AFileName, EncName);
    if ATab.Editor.EncodingName <> '' then
    begin
      FSettings.AddEncoding(ATab.Editor.EncodingName);
      FSettings.SetEncodingForFile(AFileName, ATab.Editor.EncodingName);
      RebuildRecentEncodingMenu;
      UpdateDocumentMenuChecks;
    end;
    ATab.UntitledName := ExtractFileName(AFileName);
    Lexer := FLanguage.FindByFileName(AFileName);
    ATab.SetLexer(Lexer);
    ATab.RefreshEolText;
    ATab.UpdateCaption;
    FSettings.AddRecent(AFileName);
    FSettings.LastDir := ExtractFileDir(AFileName);
    RebuildRecentMenu;
    UpdateStatus;
    if ATab = ActiveTab then
      FSplitView.Refresh(ATab, True);
    Result := True;
  except
    on E: Exception do
      TyMessageDlg(Format(Tr('Cannot open %s:'), [AFileName]) + LineEnding + E.Message,
        mtError, [mbOK]);
  end;
end;

function TMainForm.SaveTab(ATab: TEditorTab; ASaveAs: Boolean): Boolean;
var
  Dlg: TSaveDialog;
  Path: string;
  Lexer: TecSyntAnalyzer;
begin
  Result := False;
  if ATab = nil then Exit;
  Path := ATab.FileName;
  if ASaveAs or (Path = '') then
  begin
    Dlg := TSaveDialog.Create(Self);
    try
      Dlg.InitialDir := FSettings.LastDir;
      Dlg.FileName := ATab.BaseTitle;
      Dlg.Filter := Tr('Text files') + '|*.txt|' + Tr('All files') + '|*.*';
      Dlg.Options := [ofOverwritePrompt, ofEnableSizing];
      if not Dlg.Execute then Exit;
      Path := Dlg.FileName;
    finally
      Dlg.Free;
    end;
  end;
  try
    ATab.SaveToFile(Path);
    ATab.UntitledName := ExtractFileName(Path);
    if ATab.Adapter.Lexer = nil then
    begin
      Lexer := FLanguage.FindByFileName(Path);
      ATab.SetLexer(Lexer);
    end;
    ATab.RefreshEolText;
    ATab.UpdateCaption;
    FSettings.AddRecent(Path);
    FSettings.LastDir := ExtractFileDir(Path);
    RebuildRecentMenu;
    Result := True;
    UpdateCaption;
    UpdateStatus;
  except
    on E: Exception do
      TyMessageDlg(Format(Tr('Cannot save %s:'), [Path]) + LineEnding + E.Message,
        mtError, [mbOK]);
  end;
end;

function TMainForm.SaveAll: Boolean;
var
  i: Integer;
  Tab: TEditorTab;
begin
  Result := True;
  for i := 0 to FTabs.Count - 1 do
  begin
    Tab := TEditorTab(FTabs[i]);
    if Tab.Editor.Modified or (Tab.FileName = '') then
      if not SaveTab(Tab, False) then
      begin
        Result := False;
        Break;
      end;
  end;
end;

procedure TMainForm.ReloadTab(ATab: TEditorTab);
var
  Lexer: TecSyntAnalyzer;
begin
  if (ATab = nil) or (ATab.FileName = '') then Exit;
  if ATab.Editor.Modified then
    if TyMessageDlg(Tr('Discard unsaved changes and reload?'), mtConfirmation,
      [mbYes, mbNo]) <> mrYes then Exit;
  try
    ATab.LoadFromFile(ATab.FileName, ATab.Editor.EncodingName);
    Lexer := FLanguage.FindByFileName(ATab.FileName);
    ATab.SetLexer(Lexer);
    ATab.RefreshEolText;
    ATab.UpdateCaption;
    UpdateStatus;
    if ATab = ActiveTab then
      FSplitView.Refresh(ATab, True);
  except
    on E: Exception do
      TyMessageDlg(Tr('Cannot reload:') + ' ' + E.Message, mtError, [mbOK]);
  end;
end;

function TMainForm.ConfirmCloseTab(ATab: TEditorTab; AAsk: Boolean): Boolean;
var
  R: TModalResult;
begin
  Result := True;
  if (ATab = nil) or (not AAsk) or (not ATab.Editor.Modified) then Exit;
  R := TyMessageDlg(Format(Tr('Save changes to %s?'), [ATab.BaseTitle]),
    mtConfirmation, [mbYes, mbNo, mbCancel]);
  if R = mrCancel then
    Exit(False);
  if (R = mrYes) and (not SaveTab(ATab, False)) then
    Exit(False);
end;

procedure TMainForm.CloseTab(ATab: TEditorTab; AAsk: Boolean;
  var ACanClose: Boolean; ACloseAppIfLast: Boolean);
var
  Index: Integer;
begin
  ACanClose := True;
  if ATab = nil then Exit;
  if ATab.Pinned and AAsk then
  begin
    TyMessageDlg(Tr('This tab is pinned. Unpin it before closing.'), mtInformation, [mbOK]);
    ACanClose := False;
    Exit;
  end;
  if not ConfirmCloseTab(ATab, AAsk) then
  begin
    ACanClose := False;
    Exit;
  end;
  if (not FClosing) and (not ATab.Pinned) then
    PushClosedTab(ATab);
  ATab.ClearBackup;
  FSplitView.DetachTab(ATab);
  FTabs.Remove(ATab);
  Index := ATab.Page.PageIndex;
  // Let the page control destroy the page and its editor together.  Freeing the
  // editor first can leave the page's child list/HWND in an inconsistent state.
  if ATab.Adapter <> nil then
    ATab.Adapter.AddEditor(nil);
  FPages.RemovePage(Index);
  ATab.Free;
  if FPages.PageCount > 0 then
  begin
    SelectTab(ActiveTab);
    FSplitView.Refresh(ActiveTab, True);
  end
  else
  begin
    FSplitView.Refresh(nil, True);
    if ACloseAppIfLast and (not FClosing) then
      Application.QueueAsyncCall(@CloseAppLater, 0);
  end;
end;


procedure TMainForm.PushClosedTab(ATab: TEditorTab);
var
  C: TClosedTab;
begin
  if (ATab = nil) or (FClosedTabs = nil) then Exit;
  C := TClosedTab.Create;
  C.FileName := ATab.FileName;
  C.Title := ATab.BaseTitle;
  C.Encoding := ATab.Editor.EncodingName;
  if ATab.Editor.Modified or (ATab.FileName = '') then
    C.Text := ATab.Editor.Text
  else
    C.Text := '';
  if ATab.Editor.Carets.Count > 0 then
  begin
    C.CaretX := ATab.Editor.Carets[0].PosX;
    C.CaretY := ATab.Editor.Carets[0].PosY;
  end;
  C.Pinned := ATab.Pinned;
  FClosedTabs.Add(C);
  while FClosedTabs.Count > 20 do
  begin
    TClosedTab(FClosedTabs[0]).Free;
    FClosedTabs.Delete(0);
  end;
end;

procedure TMainForm.ReopenClosedTab;
var
  C: TClosedTab;
  Tab: TEditorTab;
begin
  if (FClosedTabs = nil) or (FClosedTabs.Count = 0) then Exit;
  C := TClosedTab(FClosedTabs[FClosedTabs.Count - 1]);
  FClosedTabs.Delete(FClosedTabs.Count - 1);
  try
    Tab := CreateTab(C.Title);
    Tab.FileName := C.FileName;
    Tab.UntitledName := C.Title;
    Tab.Pinned := C.Pinned;
    if C.Text <> '' then
    begin
      Tab.Editor.Text := C.Text;
      Tab.Editor.Modified := True;
    end
    else if (C.FileName <> '') and FileExists(C.FileName) then
      Tab.LoadFromFile(C.FileName, C.Encoding)
    else
      Tab.Editor.Modified := False;
    if C.Encoding <> '' then
      Tab.Editor.EncodingName := C.Encoding;
    if (C.FileName <> '') then
      Tab.SetLexer(FLanguage.FindByFileName(C.FileName));
    Tab.RefreshEolText;
    Tab.UpdateCaption;
    Tab.GotoLineColumn(C.CaretY, C.CaretX);
    SelectTab(Tab);
    RebuildOpenTabsMenu;
  finally
    C.Free;
  end;
end;

procedure TMainForm.CloseRight;
var
  i, Base: Integer;
  Tab: TEditorTab;
  Allow: Boolean;
begin
  if FContextTab = nil then Exit;
  Base := FTabs.IndexOf(FContextTab);
  if Base < 0 then Exit;
  i := FTabs.Count - 1;
  while i > Base do
  begin
    Tab := TEditorTab(FTabs[i]);
    if not Tab.Pinned then
    begin
      Allow := True;
      CloseTab(Tab, True, Allow, False);
      if not Allow then Break;
    end;
    Dec(i);
  end;
  RebuildOpenTabsMenu;
end;

procedure TMainForm.BuildTabPopup;
  function Add(const ACaption: string; AHandler: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    Result.Caption := Tr(ACaption);
    Result.OnClick := AHandler;
    FTabPopup.Items.Add(Result);
  end;
begin
  FTabPopup := TTyPopupMenu.Create(Self);
  FTabPopup.Name := 'TabPopup';
  FTabPopup.Controller := TyDefaultController;
  FTabPopup.OnPopup := @TabPopupOpening;
  Add('Close', @TabPopupClose);
  Add('Close Others', @TabPopupCloseOthers);
  Add('Close Right', @TabPopupCloseRight);
  Add('-', nil);
  Add('Copy File Path', @TabPopupCopyPath);
  Add('Open Containing Folder', @TabPopupReveal);
  Add('-', nil);
  Add('Pin / Unpin Tab', @TabPopupPin);
  Add('Reopen Closed Tab', @TabPopupReopen);
  FPages.OnMouseDown := @PagesMouseDown;
  FPages.OnMouseUp := @PagesMouseUp;
  FPages.OnDblClick := @PagesDblClick;
  FPages.OnContextPopup := @PagesContextPopup;
  FPages.PopupMenu := FTabPopup;
end;

procedure TMainForm.PagesMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbRight then Exit;
  TabPopupOpening(nil);
  FTabPopup.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

procedure TMainForm.PagesContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin
  TabPopupOpening(nil);
  Handled := True;
  FTabPopup.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

procedure TMainForm.PagesMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbRight then Exit;
  TabPopupOpening(nil);
  FTabPopup.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

procedure TMainForm.PagesDblClick(Sender: TObject);
var
  P: TPoint;
  BandHeight: Integer;
begin
  P := FPages.ScreenToClient(Mouse.CursorPos);
  if (P.X < 0) or (P.Y < 0) then Exit;
  if FPages.IndexOfTabAt(P) >= 0 then Exit;
  if FPages.IndexOfPageAt(P) >= 0 then Exit;

  BandHeight := FPages.TabHeight * Max(1, FPages.RowCount);
  if P.Y > BandHeight then Exit;

  NewUntitled;
end;

procedure TMainForm.TabPopupOpening(Sender: TObject);
var
  P: TPoint;
  Idx: Integer;
begin
  P := FPages.ScreenToClient(Mouse.CursorPos);
  Idx := FPages.IndexOfTabAt(P);
  if (Idx >= 0) then
    FContextTab := TabByIndex(Idx)
  else
    FContextTab := ActiveTab;
  if (FContextTab = nil) or (FTabs.Count = 0) then
  begin
    FTabPopup.Items[0].Enabled := False;
    Exit;
  end;
  FTabPopup.Items[0].Enabled := not FContextTab.Pinned;
  FTabPopup.Items[FTabPopup.Items.Count - 1].Caption := Tr('Reopen Closed Tab');
end;

procedure TMainForm.TabPopupClose(Sender: TObject);
var
  Allow: Boolean;
begin
  if FContextTab = nil then Exit;
  Allow := True;
  CloseTab(FContextTab, True, Allow, True);
  RebuildOpenTabsMenu;
end;

procedure TMainForm.TabPopupCloseOthers(Sender: TObject);
begin
  if FContextTab = nil then Exit;
  SelectTab(FContextTab);
  CloseOthers;
  RebuildOpenTabsMenu;
end;

procedure TMainForm.TabPopupCloseRight(Sender: TObject);
begin
  CloseRight;
end;

procedure TMainForm.TabPopupCopyPath(Sender: TObject);
begin
  if (FContextTab <> nil) and (FContextTab.FileName <> '') then
    Clipboard.AsText := FContextTab.FileName;
end;

procedure TMainForm.TabPopupReveal(Sender: TObject);
begin
  if (FContextTab <> nil) and (FContextTab.FileName <> '') then
    OpenURL(ExtractFileDir(FContextTab.FileName));
end;

procedure TMainForm.TabPopupPin(Sender: TObject);
begin
  if FContextTab = nil then Exit;
  FContextTab.Pinned := not FContextTab.Pinned;
  FContextTab.UpdateCaption;
  RebuildOpenTabsMenu;
end;

procedure TMainForm.TabPopupReopen(Sender: TObject);
begin
  ReopenClosedTab;
end;

procedure TMainForm.RebuildOpenTabsMenu;
var
  i: Integer;
  It: TMenuItem;
  Tab: TEditorTab;
begin
  if FOpenTabsMenu = nil then Exit;
  ClearMenu(FOpenTabsMenu);
  for i := 0 to FTabs.Count - 1 do
  begin
    Tab := TEditorTab(FTabs[i]);
    It := TMenuItem.Create(FMainMenu);
    It.Caption := IntToStr(i + 1) + ' ' + Tab.BaseTitle;
    It.Tag := i;
    It.Checked := Tab = ActiveTab;
    It.OnClick := @OpenTabMenuClick;
    FOpenTabsMenu.Add(It);
  end;
end;

procedure TMainForm.OpenTabMenuClick(Sender: TObject);
var
  i: Integer;
begin
  i := (Sender as TMenuItem).Tag;
  if (i >= 0) and (i < FTabs.Count) then
    SelectTab(TEditorTab(FTabs[i]));
end;

function TMainForm.BundledPluginDir: string;
begin
  Result := FindResourcePath('data/plugins');
end;

function TMainForm.UserPluginDir: string;
begin
  Result := IncludeTrailingPathDelimiter(AppConfigDir) + 'plugins';
  EnsureDir(Result);
end;

procedure TMainForm.LoadPlugins;
begin
  if FPluginManager = nil then Exit;
  FPluginManager.Reload(BundledPluginDir, UserPluginDir);
  FPluginManager.SetLocale(FLang);
end;

procedure TMainForm.RebuildPluginMenu;
var
  i, j, Index: Integer;
  Plugin: TPluginInfo;
  Command: TPluginCommand;
  MenuAction: TPluginMenuAction;
  Sub, Item: TMenuItem;
begin
  if FPluginMenu = nil then Exit;
  FPluginMenu.Clear;
  for i := 0 to FPluginActions.Count - 1 do
    TPluginMenuAction(FPluginActions[i]).Free;
  FPluginActions.Clear;

  for i := 0 to FPluginManager.Plugins.Count - 1 do
  begin
    Plugin := TPluginInfo(FPluginManager.Plugins[i]);
    if (not Plugin.Enabled) or (Plugin.Commands.Count = 0) then Continue;
    Sub := TMenuItem.Create(FMainMenu);
    Sub.Caption := Plugin.LocalizedName;
    FPluginMenu.Add(Sub);
    for j := 0 to Plugin.Commands.Count - 1 do
    begin
      Command := TPluginCommand(Plugin.Commands[j]);
      Item := TMenuItem.Create(FMainMenu);
      Item.Caption := Plugin.CommandTitle(Command);
      MenuAction := TPluginMenuAction.Create;
      MenuAction.Plugin := Plugin;
      MenuAction.Command := Command;
      Index := FPluginActions.Add(MenuAction);
      Item.Tag := Index;
      Item.OnClick := @PluginActionClick;
      Sub.Add(Item);
    end;
  end;

  if FPluginActions.Count = 0 then
  begin
    Item := TMenuItem.Create(FMainMenu);
    Item.Caption := Tr('No plugins found');
    Item.Enabled := False;
    FPluginMenu.Add(Item);
  end;

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := '-';
  FPluginMenu.Add(Item);

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := Tr('Manage Plugins...');
  Item.OnClick := @ManagePluginsClick;
  FPluginMenu.Add(Item);

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := Tr('Install Plugin...');
  Item.OnClick := @InstallPluginClick;
  FPluginMenu.Add(Item);

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := Tr('Reload Plugins');
  Item.OnClick := @ReloadPluginsClick;
  FPluginMenu.Add(Item);

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := Tr('Open Plugins Folder');
  Item.OnClick := @OpenPluginFolderClick;
  FPluginMenu.Add(Item);

  if FPluginManager.Errors.Count > 0 then
  begin
    Item := TMenuItem.Create(FMainMenu);
    Item.Caption := Format(Tr('Plugin Errors (%d)...'), [FPluginManager.Errors.Count]);
    Item.OnClick := @ShowPluginErrorsClick;
    FPluginMenu.Add(Item);
  end;
end;

procedure TMainForm.PluginActionClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := (Sender as TMenuItem).Tag;
  if (Index >= 0) and (Index < FPluginActions.Count) then
    RunPluginAction(TPluginMenuAction(FPluginActions[Index]));
end;

procedure TMainForm.ManagePluginsClick(Sender: TObject);
var
  Dialog: TPluginManagerForm;
begin
  Dialog := TPluginManagerForm.Create(Self, FPluginManager);
  try
    Dialog.Execute;
  finally
    Dialog.Free;
  end;
  LoadPlugins;
  RebuildPluginMenu;
end;

procedure TMainForm.InstallPluginClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  ErrorText: string;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'TyEditor plugins (*.typlugin)|*.typlugin|All files (*.*)|*.*';
    Dialog.Options := [ofFileMustExist];
    if not Dialog.Execute then Exit;
    if FPluginManager.InstallPackage(Dialog.FileName, ErrorText) then
    begin
      LoadPlugins;
      RebuildPluginMenu;
      TyMessageDlg(Tr('Plugin package installed.'), mtInformation, [mbOK]);
    end
    else
      TyMessageDlg(Format(Tr('Unable to install plugin: %s'), [ErrorText]),
        mtError, [mbOK]);
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.ReloadPluginsClick(Sender: TObject);
begin
  LoadPlugins;
  RebuildPluginMenu;
  if FPluginManager.Errors.Count > 0 then
    ShowPluginErrorsClick(nil);
end;

procedure TMainForm.OpenPluginFolderClick(Sender: TObject);
begin
  OpenDocument(UserPluginDir);
end;

procedure TMainForm.ShowPluginErrorsClick(Sender: TObject);
var
  ErrorText: string;
  i: Integer;
begin
  ErrorText := '';
  for i := 0 to FPluginManager.Errors.Count - 1 do
  begin
    if ErrorText <> '' then
      ErrorText := ErrorText + LineEnding;
    ErrorText := ErrorText + FPluginManager.Errors[i];
  end;
  if ErrorText = '' then
    ErrorText := Tr('No plugin errors.');
  TyMessageDlg(ErrorText, mtError, [mbOK]);
end;

procedure TMainForm.ShowPluginError(const AMessage: string);
begin
  TyMessageDlg(AMessage, mtError, [mbOK]);
end;

function TMainForm.PluginMessage(APlugin: TPluginInfo;
  AObject: TJSONObject): string;
var
  Key: string;
begin
  Result := '';
  if AObject = nil then Exit;
  Result := AObject.Get('message', '');
  Key := AObject.Get('message_key', '');
  if Key <> '' then
    Result := APlugin.Translate(Key, Result);
end;

procedure TMainForm.RunPluginAction(AAction: TPluginMenuAction);
var
  Tab: TEditorTab;
  Req, Ctx, SelObj, Opts, Resp: TJSONObject;
  Carets: TJSONArray;
  CaretObj: TJSONObject;
  OptionsForm: TPluginOptionsForm;
  Progress: TPluginProgressForm;
  OptionValues: TStringList;
  Err, SelText, DocText, LexName: string;
  Caret: TATCaretItem;
  X1, Y1, X2, Y2, StartOffset, EndOffset, i: Integer;
  HasSelection: Boolean;
begin
  Tab := ActiveTab;
  if (Tab = nil) or (AAction = nil) or (AAction.Plugin = nil) or
     (AAction.Command = nil) then Exit;

  if (not AAction.Plugin.Bundled) and (not FUserPluginNoticeShown) then
  begin
    if TyMessageDlg(Format(Tr('Plugin "%s" is not bundled with TyEditor. Run it only if you trust its source.'),
      [AAction.Plugin.LocalizedName]), mtWarning, [mbYes, mbNo]) <> mrYes then
      Exit;
    FUserPluginNoticeShown := True;
  end;

  SelText := Tab.Editor.TextSelected;
  if (AAction.Command.Scope = 'selection') and (SelText = '') then
  begin
    ShowPluginError(Tr('Select text before running this plugin action.'));
    Exit;
  end;

  OptionValues := nil;
  if AAction.Plugin.Options.Count > 0 then
  begin
    OptionsForm := TPluginOptionsForm.Create(Self, AAction.Plugin);
    try
      if not OptionsForm.Execute(OptionValues) then Exit;
    finally
      OptionsForm.Free;
    end;
  end;

  DocText := Tab.Editor.Text;
  StartOffset := 0;
  EndOffset := 0;
  HasSelection := False;
  if Tab.Editor.Carets.Count > 0 then
  begin
    Caret := Tab.Editor.Carets[0];
    Caret.GetRange(X1, Y1, X2, Y2, HasSelection);
    if HasSelection then
    begin
      StartOffset := Tab.Editor.CaretPosToOffset(Point(X1, Y1));
      EndOffset := Tab.Editor.CaretPosToOffset(Point(X2, Y2));
    end
    else
    begin
      StartOffset := Tab.Editor.CaretPosToOffset(Point(Caret.PosX, Caret.PosY));
      EndOffset := StartOffset;
    end;
  end;

  if Tab.Adapter <> nil then
  begin
    if Tab.Adapter.Lexer <> nil then LexName := Tab.Adapter.Lexer.LexerName
    else LexName := '';
  end
  else
    LexName := '';

  Req := TJSONObject.Create;
  try
    Req.Add('api', PluginApiVersion);
    Req.Add('protocol', 1);
    Req.Add('plugin', AAction.Plugin.Id);
    Req.Add('command', AAction.Command.Id);
    Req.Add('scope', AAction.Command.Scope);

    Opts := TJSONObject.Create;
    if OptionValues <> nil then
      for i := 0 to OptionValues.Count - 1 do
        Opts.Add(OptionValues.Names[i], OptionValues.ValueFromIndex[i]);
    Req.Add('options', Opts);

    Ctx := TJSONObject.Create;
    Ctx.Add('locale', FLang);
    Ctx.Add('file', Tab.FileName);
    Ctx.Add('encoding', Tab.Editor.EncodingName);
    Ctx.Add('eol', Tab.EolText);
    Ctx.Add('lexer', LexName);
    Ctx.Add('modified', Tab.Editor.Modified);
    Ctx.Add('text', DocText);

    SelObj := TJSONObject.Create;
    SelObj.Add('text', SelText);
    SelObj.Add('start', StartOffset);
    SelObj.Add('end', EndOffset);
    SelObj.Add('length', EndOffset - StartOffset);
    if Tab.Editor.Carets.Count > 0 then
    begin
      SelObj.Add('caret_x', Tab.Editor.Carets[0].PosX);
      SelObj.Add('caret_y', Tab.Editor.Carets[0].PosY);
    end;
    Ctx.Add('selection', SelObj);

    Carets := TJSONArray.Create;
    for i := 0 to Tab.Editor.Carets.Count - 1 do
    begin
      CaretObj := TJSONObject.Create;
      CaretObj.Add('offset', Tab.Editor.CaretPosToOffset(
        Point(Tab.Editor.Carets[i].PosX, Tab.Editor.Carets[i].PosY)));
      Carets.Add(CaretObj);
    end;
    Ctx.Add('carets', Carets);
    Req.Add('context', Ctx);

    if not AAction.Plugin.Enabled then
    begin
      ShowPluginError(Tr('This plugin is disabled.'));
      Exit;
    end;

    ResetPluginCancellation;
    Progress := TPluginProgressForm.Create(Self, FPluginManager, AAction.Plugin,
      AAction.Command, Req);
    try
      if not Progress.Run(Resp, Err) then
      begin
        if not Progress.Cancelled then
          ShowPluginError(Err);
      end
      else
        try
          ApplyPluginResponse(Tab, AAction.Plugin, Resp);
        finally
          Resp.Free;
        end;
    finally
      Progress.Free;
    end;
  finally
    Req.Free;
    OptionValues.Free;
  end;
end;

procedure TMainForm.ApplyPluginResponse(ATab: TEditorTab; APlugin: TPluginInfo;
  AResponse: TJSONObject);
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  i: Integer;
  Kind, ActionText, Msg: string;
  Line, Col: Integer;
begin
  if (ATab = nil) or (APlugin = nil) or (AResponse = nil) then Exit;
  if (AResponse.Find('ok') <> nil) and (not AResponse.Get('ok', True)) then
  begin
    Msg := PluginMessage(APlugin, AResponse);
    if Msg <> '' then
      ShowMessage(Msg);
    Exit;
  end;
  if AResponse.Find('actions') is TJSONArray then
  begin
    Arr := TJSONArray(AResponse.Find('actions'));
    for i := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[i] is TJSONObject) then Continue;
      Obj := TJSONObject(Arr.Items[i]);
      Kind := LowerCase(Trim(Obj.Get('type', Obj.Get('kind', ''))));
      ActionText := Obj.Get('text', '');
      if Kind = 'replace_selection' then
        ATab.Editor.TextInsertAtCarets(ActionText, False, False, False)
      else if Kind = 'replace_document' then
      begin
        ATab.Editor.Text := ActionText;
        ATab.Editor.Modified := True;
        ATab.RefreshEolText;
      end
      else if Kind = 'insert_text' then
        ATab.Editor.TextInsertAtCarets(ActionText, False, False, False)
      else if Kind = 'set_caret' then
      begin
        Line := Obj.Get('line', 0);
        Col := Obj.Get('col', 0);
        ATab.GotoLineColumn(Line, Col);
      end
      else if Kind = 'message' then
        ShowMessage(PluginMessage(APlugin, Obj))
      else if Kind = 'log' then
        WriteLn(ActionText);
    end;
  end;
  Msg := PluginMessage(APlugin, AResponse);
  if Msg <> '' then
    ShowMessage(Msg);
  ATab.UpdateCaption;
  UpdateCaption;
  UpdateStatus;
end;

procedure TMainForm.LoadTools;
begin
  if FToolStore = nil then Exit;
  FToolStore.Load;
end;

procedure TMainForm.RebuildToolsMenu;
var
  i, EnabledCount: Integer;
  Tool: TExternalTool;
  Item: TMenuItem;
begin
  if FToolsMenu = nil then Exit;
  FToolsMenu.Clear;
  EnabledCount := 0;
  for i := 0 to FToolStore.Count - 1 do
  begin
    Tool := FToolStore[i];
    if not Tool.Enabled then Continue;
    Item := TMenuItem.Create(FMainMenu);
    Item.Caption := Tool.Name;
    Item.Tag := i;
    Item.OnClick := @ToolActionClick;
    FToolsMenu.Add(Item);
    Inc(EnabledCount);
  end;

  if EnabledCount = 0 then
  begin
    Item := TMenuItem.Create(FMainMenu);
    Item.Caption := Tr('No tools configured');
    Item.Enabled := False;
    FToolsMenu.Add(Item);
  end;

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := '-';
  FToolsMenu.Add(Item);

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := Tr('Manage Tools...');
  Item.OnClick := @ManageToolsClick;
  FToolsMenu.Add(Item);

  Item := TMenuItem.Create(FMainMenu);
  Item.Caption := Tr('Reload Tools');
  Item.OnClick := @ReloadToolsClick;
  FToolsMenu.Add(Item);

  if FToolStore.Errors.Count > 0 then
  begin
    Item := TMenuItem.Create(FMainMenu);
    Item.Caption := Format(Tr('Tool Errors (%d)...'), [FToolStore.Errors.Count]);
    Item.OnClick := @ShowToolErrorsClick;
    FToolsMenu.Add(Item);
  end;
end;

procedure TMainForm.ToolActionClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := (Sender as TMenuItem).Tag;
  if (Index >= 0) and (Index < FToolStore.Count) then
    RunExternalTool(FToolStore[Index]);
end;

procedure TMainForm.ManageToolsClick(Sender: TObject);
var
  Dialog: TToolManagerForm;
begin
  Dialog := TToolManagerForm.Create(Self, FToolStore);
  try
    Dialog.Execute;
  finally
    Dialog.Free;
  end;
  { The manager writes tools.json directly; reload so hand edits and
    validation errors are picked up as well. }
  LoadTools;
  RebuildToolsMenu;
end;

procedure TMainForm.ReloadToolsClick(Sender: TObject);
begin
  LoadTools;
  RebuildToolsMenu;
  if FToolStore.Errors.Count > 0 then
    ShowToolErrorsClick(nil);
end;

procedure TMainForm.ShowToolErrorsClick(Sender: TObject);
var
  ErrorText: string;
  i: Integer;
begin
  ErrorText := '';
  for i := 0 to FToolStore.Errors.Count - 1 do
  begin
    if ErrorText <> '' then
      ErrorText := ErrorText + LineEnding;
    ErrorText := ErrorText + FToolStore.Errors[i];
  end;
  if ErrorText = '' then
    ErrorText := Tr('No tool errors.');
  TyMessageDlg(ErrorText, mtWarning, [mbOK]);
end;

function TMainForm.BuildToolContext(ATab: TEditorTab): TToolContext;
var
  Caret: TATCaretItem;
begin
  Result.FileName := '';
  Result.Lexer := '';
  Result.Encoding := '';
  Result.Eol := '';
  Result.Line := 1;
  Result.Col := 1;
  Result.SelectionText := '';
  Result.DocumentText := '';
  if ATab = nil then Exit;

  Result.FileName := ATab.FileName;
  Result.Encoding := ATab.Editor.EncodingName;
  Result.Eol := ATab.EolText;
  Result.SelectionText := ATab.Editor.TextSelected;
  Result.DocumentText := ATab.Editor.Text;
  if ATab.Adapter <> nil then
  begin
    if ATab.Adapter.Lexer <> nil then
      Result.Lexer := ATab.Adapter.Lexer.LexerName;
  end;
  if ATab.Editor.Carets.Count > 0 then
  begin
    Caret := ATab.Editor.Carets[0];
    Result.Line := Caret.PosY + 1;
    Result.Col := Caret.PosX + 1;
  end;
end;

procedure TMainForm.RunExternalTool(ATool: TExternalTool);
var
  Tab: TEditorTab;
  Context: TToolContext;
  Progress: TToolProgressForm;
  OutputText, ErrorOutput, ErrorText: string;
begin
  if ATool = nil then Exit;
  Tab := ActiveTab;

  if ATool.SaveMode <> tsmNone then
  begin
    if Tab = nil then
    begin
      ShowToolError(Tr('Open a document before running this tool.'));
      Exit;
    end;
    if ATool.SaveMode = tsmCurrent then
    begin
      if not SaveTab(Tab, False) then Exit;
    end
    else if not SaveAll then
      Exit;
  end;

  if (Tab = nil) and ((ATool.InputMode <> timNone) or
    (ATool.OutputMode in [tomInsertAtCaret, tomReplaceSelection, tomReplaceDocument])) then
  begin
    ShowToolError(Tr('Open a document before running this tool.'));
    Exit;
  end;

  Context := BuildToolContext(Tab);
  if (ATool.InputMode = timSelection) and (Context.SelectionText = '') then
  begin
    ShowToolError(Tr('Select text before running this tool.'));
    Exit;
  end;

  Progress := TToolProgressForm.Create(Self, ATool, Context);
  try
    if not Progress.Run(OutputText, ErrorOutput, ErrorText) then
    begin
      if not Progress.Cancelled then
        ShowToolError(ErrorText);
      Exit;
    end;
  finally
    Progress.Free;
  end;

  ApplyToolOutput(Tab, ATool, OutputText, ErrorOutput);
end;

procedure TMainForm.ApplyToolOutput(ATab: TEditorTab; ATool: TExternalTool;
  const AOutput, AErrOutput: string);
var
  Viewer: TToolOutputForm;
  ViewText: string;
begin
  if ATool = nil then Exit;
  case ATool.OutputMode of
    tomShow:
      begin
        ViewText := AOutput;
        if Trim(AErrOutput) <> '' then
        begin
          if ViewText <> '' then
            ViewText := ViewText + LineEnding + LineEnding;
          ViewText := ViewText + Tr('Standard error:') + LineEnding + AErrOutput;
        end;
        if Trim(ViewText) = '' then
          ViewText := Tr('(no output)');
        Viewer := TToolOutputForm.Create(Self, ATool.Name, ViewText);
        try
          Viewer.Execute;
        finally
          Viewer.Free;
        end;
      end;
    tomInsertAtCaret, tomReplaceSelection:
      if (ATab <> nil) and (AOutput <> '') then
      begin
        ATab.Editor.TextInsertAtCarets(AOutput, False, False, False);
        ATab.UpdateCaption;
        UpdateCaption;
        UpdateStatus;
      end;
    tomReplaceDocument:
      if ATab <> nil then
      begin
        ATab.Editor.Text := AOutput;
        ATab.Editor.Modified := True;
        ATab.RefreshEolText;
        ATab.UpdateCaption;
        UpdateCaption;
        UpdateStatus;
      end;
  end;
end;

procedure TMainForm.ShowToolError(const AMessage: string);
begin
  if Trim(AMessage) = '' then
    TyMessageDlg(Tr('The tool failed.'), mtError, [mbOK])
  else
    TyMessageDlg(AMessage, mtError, [mbOK]);
end;

procedure TMainForm.CloseOthers;
var
  i: Integer;
  Tab: TEditorTab;
  Allow: Boolean;
begin
  i := FTabs.Count - 1;
  while i >= 0 do
  begin
    Tab := TEditorTab(FTabs[i]);
    if (Tab <> ActiveTab) and (not Tab.Pinned) then
    begin
      Allow := True;
      CloseTab(Tab, True, Allow);
      if not Allow then Exit;
    end;
    Dec(i);
  end;
end;

procedure TMainForm.CloseAll;
var
  Allow: Boolean;
  i: Integer;
  Tab: TEditorTab;
begin
  i := FTabs.Count - 1;
  while i >= 0 do
  begin
    Tab := TEditorTab(FTabs[i]);
    if not Tab.Pinned then
    begin
      Allow := True;
      CloseTab(Tab, True, Allow, False);
      if not Allow then Exit;
    end;
    Dec(i);
  end;
  if (FPages.PageCount = 0) and (not FClosing) then
    Close;
end;

procedure TMainForm.UpdateCaption;
var
  Tab: TEditorTab;
  S: string;
begin
  Tab := ActiveTab;
  if Tab = nil then
    S := 'TyEditor'
  else
  begin
    S := Tab.BaseTitle;
    if Tab.Editor.Modified then S := '*' + S;
  end;
  Caption := 'TyEditor - ' + S;
  if FTitleBar <> nil then
    FTitleBar.Caption := Caption;
end;

procedure TMainForm.UpdateStatus;
begin
  if FStatusView <> nil then
    FStatusView.Update(ActiveTab);
end;
procedure TMainForm.EditorChanged(Sender: TObject);
begin
  if FDestroying then Exit;
  if (ActiveTab <> nil) and (Sender = ActiveTab.Editor) and (FSplitView <> nil) then
    FSplitView.Schedule(ActiveTab);
  if FRestoring then Exit;
  UpdateStatus;
  UpdateCaption;
end;

procedure TMainForm.EditorCaretChanged(Sender: TObject);
begin
  UpdateStatus;
end;

procedure TMainForm.EditorClicked(Sender: TObject);
begin
  UpdateStatus;
end;

procedure TMainForm.EditorCommand(Sender: TObject; ACommand: Integer;
  AInvoke: TATCommandInvoke; const AText: string; var AHandled: Boolean);
begin
  AHandled := False;
  FMacro.RecordCommand(ACommand, AInvoke, AText);
end;

procedure TMainForm.EditorClickGutter(Sender: TObject; ABand: Integer;
  ALine: Integer; var AHandled: Boolean);
var
  Ed: TATSynEdit;
  N: Integer;
begin
  AHandled := False;
  Ed := Sender as TATSynEdit;
  N := Ed.Gutter.FindIndexByTag(ATEditorOptions.GutterTagBookmarks);
  if (N >= 0) and (ABand = N) then
  begin
    Ed.BookmarkToggleForLine(ALine, 1, '', TATBookmarkAutoDelete.DontDelete, True, 1);
    AHandled := True;
  end;
end;

procedure TMainForm.PageChanged(Sender: TObject);
begin
  if FDestroying then Exit;
  if FSplitView <> nil then
    FSplitView.Refresh(ActiveTab, True);
  if FRestoring then Exit;
  if FFindForm <> nil then
  begin
    if ActiveTab <> nil then
      FFindForm.Editor := ActiveTab.Editor
    else
      FFindForm.Editor := nil;
  end;
  UpdateCaption;
  UpdateStatus;
  UpdateDocumentMenuChecks;
  RebuildOpenTabsMenu;
end;

procedure TMainForm.PageTabClose(Sender: TObject; AIndex: Integer;
  var AllowClose: Boolean);
var
  Tab: TEditorTab;
begin
  AllowClose := False;
  Tab := TabByIndex(AIndex);
  if Tab = nil then Exit;
  if Tab.Pinned then
  begin
    TyMessageDlg(Tr('This tab is pinned. Unpin it before closing.'), mtInformation, [mbOK]);
    Exit;
  end;
  if not ConfirmCloseTab(Tab, True) then Exit;

  if not Tab.Pinned then
    PushClosedTab(Tab);
  Tab.ClearBackup;
  FSplitView.DetachTab(Tab);
  FTabs.Remove(Tab);
  if Tab.Adapter <> nil then
    Tab.Adapter.AddEditor(nil);
  Tab.Free;

  { The tab strip removes the page and its editor AFTER this callback returns.
    Removing it here too is what closed the next tab and left a dangling editor. }
  AllowClose := True;
  if FPages.PageCount = 1 then
    Application.QueueAsyncCall(@MaybeCloseAfterTabClose, 0);
end;

procedure TMainForm.PageReorder(Sender: TObject; AFromIndex, AToIndex: Integer);
begin
  if (AFromIndex >= 0) and (AToIndex >= 0) then
    FTabs.Move(AFromIndex, AToIndex);
  SyncTabOrder;
end;

procedure TMainForm.MenuClick(Sender: TObject);
var
  Cmd: Integer;
  Tab: TEditorTab;
  S: string;
  N: Integer;
  AllowClose: Boolean;
begin
  Cmd := (Sender as TMenuItem).Tag;
  case TMenuCmd(Cmd) of
    mcNew: NewUntitled;
    mcOpen: OpenFileDialog;
    mcSave: if ActiveTab <> nil then SaveTab(ActiveTab, False);
    mcSaveAs: if ActiveTab <> nil then SaveTab(ActiveTab, True);
    mcSaveAll: SaveAll;
    mcReload: if ActiveTab <> nil then ReloadTab(ActiveTab);
    mcClose:
      if ActiveTab <> nil then
      begin
        Tab := ActiveTab;
        AllowClose := True;
        CloseTab(Tab, True, AllowClose);
      end;
    mcCloseOthers: CloseOthers;
    mcCloseAll: CloseAll;
    mcReopen: ReopenClosedTab;
    mcExit: Close;
    mcUndo: DoEditorCmd(cCommand_Undo);
    mcRedo: DoEditorCmd(cCommand_Redo);
    mcCut: DoEditorCmd(cCommand_ClipboardCut);
    mcCopy: DoEditorCmd(cCommand_ClipboardCopy);
    mcPaste: DoEditorCmd(cCommand_ClipboardPaste);
    mcDelete: DoEditorCmd(cCommand_TextDeleteSelection);
    mcSelectAll: DoEditorCmd(cCommand_SelectAll);
    mcDupLine: DoEditorCmd(cCommand_TextDuplicateLine);
    mcDelLine: DoEditorCmd(cCommand_TextDeleteLine);
    mcMoveUp: DoEditorCmd(cCommand_MoveSelectionUp);
    mcMoveDown: DoEditorCmd(cCommand_MoveSelectionDown);
    mcIndent: DoEditorCmd(cCommand_TextIndent);
    mcUnindent: DoEditorCmd(cCommand_TextUnindent);
    mcComment: ToggleComment(True);
    mcUncomment: ToggleComment(False);
    mcMatchBracket: GoToMatchingBracket;
    mcUpper: DoEditorCmd(cCommand_TextCaseUpper);
    mcLower: DoEditorCmd(cCommand_TextCaseLower);
    mcTitle: DoEditorCmd(cCommand_TextCaseTitle);
    mcSortAsc: DoEditorCmd(cCommand_Sort_Asc);
    mcSortDesc: DoEditorCmd(cCommand_Sort_Desc);
    mcSortAscNoCase: DoEditorCmd(cCommand_Sort_AscNoCase);
    mcSortDescNoCase: DoEditorCmd(cCommand_Sort_DescNoCase);
    mcTrimTrailing: DoEditorCmd(cCommand_TextTrimSpacesRight);
    mcRemoveDup: DoEditorCmd(cCommand_DeleteAdjacentDups);
    mcJoinLines: JoinLines;
    mcSplitLine: SplitLine;
    mcAddCaretAbove: AddCaret(False);
    mcAddCaretBelow: AddCaret(True);
    mcFind: ShowFindDlg(False);
    mcReplace: ShowFindDlg(True);
    mcFindNext: FindNext;
    mcFindPrev: FindPrevious;
    mcFindInFiles: ShowFindInFilesDlg(False);
    mcReplaceInFiles: ShowFindInFilesDlg(True);
    mcExportResults: ExportResults;
    mcGotoLine: GoToLine;
    mcToggleBookmark: ToggleBookmark;
    mcNextBookmark: NextBookmark(True);
    mcPrevBookmark: NextBookmark(False);
    mcClearBookmarks: ClearBookmarks;
    mcBookmarkList: ShowBookmarkList;
    mcImportScheme: ImportColorScheme;
    mcEditScheme: EditColorScheme;
    mcExportScheme: ExportColorScheme;
    mcWrap: ToggleWrap;
    mcWhitespace: ToggleWhitespace;
    mcNumbers: ToggleNumbers;
    mcFolding: ToggleFolding;
    mcRuler: ToggleRuler;
    mcBookmarkMargin: ToggleBookmarkMargin;
    mcSplitView: ToggleSplitView;
    mcPinTab: TogglePinActive;
    mcMinimap: ToggleMinimap;
    mcMicromap: ToggleMicromap;
    mcZoomIn:
      begin
        DoEditorCmd(cCommand_ZoomIn);
        FSplitView.InvalidateStyle;
        FSplitView.Refresh(ActiveTab);
      end;
    mcZoomOut:
      begin
        DoEditorCmd(cCommand_ZoomOut);
        FSplitView.InvalidateStyle;
        FSplitView.Refresh(ActiveTab);
      end;
    mcZoomReset:
      begin
        DoEditorCmd(cCommand_ZoomReset);
        FSplitView.InvalidateStyle;
        FSplitView.Refresh(ActiveTab);
      end;
    mcFullScreen: ToggleFullScreen;
    mcAlwaysOnTop: ToggleAlwaysOnTop;
    mcResults: ToggleResults;
    mcThemeDark: ToggleTheme;
    mcMacroRecord: MacroRecord;
    mcMacroPlay: MacroPlay;
    mcMacroPlayN: MacroPlayN;
    mcMacroSave: MacroSave;
    mcMacroLoad: MacroLoad;
    mcMacroManager: ShowMacroManager;
    mcMacroPlayBound: PlayBoundMacro;
    mcManageTools: ManageToolsClick(nil);
    mcReloadTools: ReloadToolsClick(nil);
    mcCopyPath: CopyPath;
    mcAbout: ShowAbout;
    mcPreferences: ShowPreferences;
    mcSaveSettings: SaveSettingsNow;
  end;
end;

procedure TMainForm.RecentClick(Sender: TObject);
var
  i: Integer;
  Files: array of string;
begin
  i := (Sender as TMenuItem).Tag;
  if (i >= 0) and (i < FSettings.Recent.Count) then
  begin
    SetLength(Files, 1);
    Files[0] := FSettings.Recent[i];
    OpenFiles(Files);
  end;
end;

procedure TMainForm.EncodingConvertClick(Sender: TObject);
var
  i: Integer;
  Tab: TEditorTab;
begin
  i := (Sender as TMenuItem).Tag;
  if (i < 0) or (i > High(FEncodingChoices)) then Exit;
  Tab := ActiveTab;
  if Tab = nil then Exit;
  SetEditorEncoding(Tab.Editor, FEncodingChoices[i].Name, True);
  FSettings.AddEncoding(FEncodingChoices[i].Name);
  if Tab.FileName <> '' then
    FSettings.SetEncodingForFile(Tab.FileName, FEncodingChoices[i].Name);
  RebuildRecentEncodingMenu;
  Tab.UpdateCaption;
  UpdateStatus;
  UpdateDocumentMenuChecks;
  if Tab = ActiveTab then
    FSplitView.Refresh(Tab, True);
end;

procedure TMainForm.EncodingReloadClick(Sender: TObject);
var
  i: Integer;
  Tab: TEditorTab;
  Lexer: TecSyntAnalyzer;
begin
  i := (Sender as TMenuItem).Tag;
  if (i < 0) or (i > High(FEncodingChoices)) then Exit;
  Tab := ActiveTab;
  if (Tab = nil) or (Tab.FileName = '') then
  begin
    TyMessageDlg(Tr('Reloading with an encoding requires a saved file.'),
      mtInformation, [mbOK]);
    Exit;
  end;
  if Tab.Editor.Modified then
    if TyMessageDlg(Tr('Discard unsaved changes and reload?'), mtConfirmation,
      [mbYes, mbNo]) <> mrYes then Exit;
  Tab.LoadFromFile(Tab.FileName, FEncodingChoices[i].Name, True);
  FSettings.AddEncoding(FEncodingChoices[i].Name);
  if Tab.FileName <> '' then
    FSettings.SetEncodingForFile(Tab.FileName, FEncodingChoices[i].Name);
  RebuildRecentEncodingMenu;
  Lexer := FLanguage.FindByFileName(Tab.FileName);
  Tab.SetLexer(Lexer);
  Tab.RefreshEolText;
  Tab.UpdateCaption;
  UpdateStatus;
  UpdateDocumentMenuChecks;
  if Tab = ActiveTab then
    FSplitView.Refresh(Tab, True);
end;

procedure TMainForm.EncodingRecentClick(Sender: TObject);
var
  i: Integer;
  Tab: TEditorTab;
  C: TEncodingChoice;
begin
  i := (Sender as TMenuItem).Tag;
  if (i < 0) or (i >= FSettings.EncodingHistory.Count) then Exit;
  Tab := ActiveTab;
  if Tab = nil then Exit;
  C := EncodingChoiceByName(FSettings.EncodingHistory[i]);
  SetEditorEncoding(Tab.Editor, C.Name, True);
  FSettings.AddEncoding(C.Name);
  RebuildRecentEncodingMenu;
  Tab.UpdateCaption;
  UpdateStatus;
  UpdateDocumentMenuChecks;
  if Tab = ActiveTab then
    FSplitView.Refresh(Tab, True);
end;

procedure TMainForm.EolClick(Sender: TObject);
var
  Tab: TEditorTab;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  SetEditorEol(Tab.Editor, TATLineEnds((Sender as TMenuItem).Tag), True);
  Tab.RefreshEolText;
  Tab.UpdateCaption;
  UpdateStatus;
  UpdateDocumentMenuChecks;
  if Tab = ActiveTab then
    FSplitView.Refresh(Tab, True);
end;

procedure TMainForm.LexerClick(Sender: TObject);
var
  Tab: TEditorTab;
  i: Integer;
begin
  i := (Sender as TMenuItem).Tag;
  if (i < 0) or (i >= FLexerNames.Count) then Exit;
  Tab := ActiveTab;
  if Tab = nil then Exit;
  Tab.SetLexer(FLanguage.FindByName(FLexerNames[i]));
  UpdateStatus;
  UpdateDocumentMenuChecks;
  FSplitView.InvalidateStyle;
  FSplitView.Refresh(Tab, True);
end;

procedure TMainForm.LexerAutoClick(Sender: TObject);
var
  Tab: TEditorTab;
begin
  Tab := ActiveTab;
  if (Tab = nil) or (Tab.FileName = '') then Exit;
  Tab.SetLexer(FLanguage.FindByFileName(Tab.FileName));
  UpdateStatus;
  UpdateDocumentMenuChecks;
  FSplitView.InvalidateStyle;
  FSplitView.Refresh(Tab, True);
end;

procedure TMainForm.LexerPlainClick(Sender: TObject);
var
  Tab: TEditorTab;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  Tab.SetLexer(nil);
  UpdateStatus;
  UpdateDocumentMenuChecks;
  FSplitView.InvalidateStyle;
  FSplitView.Refresh(Tab, True);
end;

procedure TMainForm.StatusMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
begin
  if Button <> mbRight then Exit;
  i := FStatusView.PanelAtPos(X, Y);
  case i of
    3: ShowStatusPopup(0);
    4: ShowStatusPopup(1);
    5: ShowStatusPopup(2);
  end;
end;

procedure TMainForm.ShowStatusPopup(AKind: Integer);
var
  Sub, It: TMenuItem;
  i: Integer;
  Tab: TEditorTab;
  Ed: TATSynEdit;
  CurEnc, LexName: string;
  CurEol: TATLineEnds;
begin
  while FStatusPopup.Items.Count > 0 do
    FStatusPopup.Items[0].Free;
  Tab := ActiveTab;
  if Tab = nil then Exit;
  Ed := Tab.Editor;
  CurEnc := Ed.EncodingName;
  CurEol := Ed.Strings.Endings;
  if (Tab.Adapter <> nil) and (Tab.Adapter.Lexer <> nil) then
    LexName := Tab.Adapter.Lexer.LexerName
  else
    LexName := '';

  if AKind = 0 then
  begin
    Sub := TMenuItem.Create(FStatusPopup);
    Sub.Caption := Tr('Convert to');
    FStatusPopup.Items.Add(Sub);
    for i := 0 to High(FEncodingChoices) do
    begin
      It := TMenuItem.Create(FStatusPopup);
      It.Caption := FEncodingChoices[i].Display;
      It.Tag := i;
      It.RadioItem := True;
      It.Checked := SameText(FEncodingChoices[i].Name, CurEnc);
      It.OnClick := @EncodingConvertClick;
      Sub.Add(It);
    end;
    Sub := TMenuItem.Create(FStatusPopup);
    Sub.Caption := Tr('Reload with');
    FStatusPopup.Items.Add(Sub);
    for i := 0 to High(FEncodingChoices) do
    begin
      It := TMenuItem.Create(FStatusPopup);
      It.Caption := FEncodingChoices[i].Display;
      It.Tag := i;
      It.RadioItem := True;
      It.Checked := SameText(FEncodingChoices[i].Name, CurEnc);
      It.OnClick := @EncodingReloadClick;
      Sub.Add(It);
    end;
  end
  else if AKind = 1 then
  begin
    It := TMenuItem.Create(FStatusPopup); It.Caption := Tr('Windows (CRLF)');
    It.Tag := Ord(TATLineEnds.Windows); It.RadioItem := True;
    It.Checked := CurEol = TATLineEnds.Windows; It.OnClick := @EolClick; FStatusPopup.Items.Add(It);
    It := TMenuItem.Create(FStatusPopup); It.Caption := Tr('Unix (LF)');
    It.Tag := Ord(TATLineEnds.Unix); It.RadioItem := True;
    It.Checked := CurEol = TATLineEnds.Unix; It.OnClick := @EolClick; FStatusPopup.Items.Add(It);
    It := TMenuItem.Create(FStatusPopup); It.Caption := Tr('Mac (CR)');
    It.Tag := Ord(TATLineEnds.Mac); It.RadioItem := True;
    It.Checked := CurEol = TATLineEnds.Mac; It.OnClick := @EolClick; FStatusPopup.Items.Add(It);
  end
  else if AKind = 2 then
  begin
    It := TMenuItem.Create(FStatusPopup); It.Caption := Tr('Auto Detect');
    It.Tag := -1; It.RadioItem := True; It.OnClick := @LexerAutoClick; FStatusPopup.Items.Add(It);
    It := TMenuItem.Create(FStatusPopup); It.Caption := Tr('Plain Text');
    It.Tag := -2; It.RadioItem := True; It.Checked := LexName = '';
    It.OnClick := @LexerPlainClick; FStatusPopup.Items.Add(It);
    for i := 0 to FLexerNames.Count - 1 do
    begin
      It := TMenuItem.Create(FStatusPopup);
      It.Caption := FLexerNames[i];
      It.Tag := i;
      It.RadioItem := True;
      It.Checked := (LexName <> '') and SameText(FLexerNames[i], LexName);
      It.OnClick := @LexerClick;
      FStatusPopup.Items.Add(It);
    end;
  end;

  FStatusPopup.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

procedure TMainForm.DoDropFiles(Sender: TObject; const FileNames: array of string);
begin
  if Length(FileNames) > 0 then
    OpenFiles(FileNames);
end;

procedure TMainForm.DoEditorCmd(ACommand: Integer);
begin
  if ActiveTab <> nil then
    ActiveTab.Editor.DoCommand(ACommand, TATCommandInvoke.MenuMain);
  UpdateStatus;
end;

procedure TMainForm.GoToMatchingBracket;
var
  Tab: TEditorTab;
  Ed: TATSynEdit;
  Line: UnicodeString;
  C1, C2, Target: WideChar;
  X, Y, I, Depth: Integer;
  Forward: Boolean;

  function LineAt(AIndex: Integer): UnicodeString;
  begin
    if (AIndex >= 0) and (AIndex < Ed.Strings.Count) then
      Result := Ed.Strings.Lines[AIndex]
    else
      Result := '';
  end;

  function PairOf(C: WideChar; out AOpen: WideChar): Boolean;
  begin
    AOpen := C;
    Result := True;
    case C of
      ')': AOpen := '(';
      ']': AOpen := '[';
      '}': AOpen := '{';
      '(': ;
      '[': ;
      '{': ;
    else
      Result := False;
    end;
  end;

  function CloseOf(AOpen: WideChar): WideChar;
  begin
    case AOpen of
      '(': Result := ')';
      '[': Result := ']';
      '{': Result := '}';
    else
      Result := #0;
    end;
  end;

begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  Ed := Tab.Editor;
  if Ed.Carets.Count = 0 then Exit;
  Y := Ed.Carets[0].PosY;
  X := Ed.Carets[0].PosX;
  Line := LineAt(Y);
  C1 := #0;
  if (X >= 0) and (X < Length(Line)) then C1 := Line[X + 1];
  if not PairOf(C1, Target) and (X > 0) and (X <= Length(Line)) then
  begin
    C1 := Line[X];
    if not PairOf(C1, Target) then Exit;
    Dec(X);
  end
  else if not PairOf(C1, Target) then
    Exit;

  Forward := (C1 = '(') or (C1 = '[') or (C1 = '{');
  Target := C1;
  if Forward then
    Target := CloseOf(C1);
  Depth := 1;
  if Forward then
  begin
    I := X + 2;
    while (Y < Ed.Strings.Count) and (Depth > 0) do
    begin
      Line := LineAt(Y);
      while I <= Length(Line) do
      begin
        if Line[I] = C1 then Inc(Depth)
        else if Line[I] = Target then
        begin
          Dec(Depth);
          if Depth = 0 then
          begin
            Ed.DoGotoPos(Point(I - 1, Y), Point(-1, -1), 0, 0, True,
              TATEditorActionIfFolded.Unfold);
            Exit;
          end;
        end;
        Inc(I);
      end;
      Inc(Y);
      I := 1;
    end;
  end
  else
  begin
    I := X;
    while (Y >= 0) and (Depth > 0) do
    begin
      Line := LineAt(Y);
      if I > Length(Line) then I := Length(Line);
      while I >= 1 do
      begin
        if Line[I] = C1 then Inc(Depth)
        else if Line[I] = Target then
        begin
          Dec(Depth);
          if Depth = 0 then
          begin
            Ed.DoGotoPos(Point(I - 1, Y), Point(-1, -1), 0, 0, True,
              TATEditorActionIfFolded.Unfold);
            Exit;
          end;
        end;
        Dec(I);
      end;
      Dec(Y);
      if Y >= 0 then I := Length(LineAt(Y));
    end;
  end;
end;

procedure TMainForm.ToggleComment(AAdd: Boolean);
var
  Tab: TEditorTab;
  Ed: TATSynEdit;
  Prefix: string;
  X1, Y1, X2, Y2: Integer;
  Sel: Boolean;
  i, N: Integer;
  Line, Indent: string;
  LexName: string;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  Ed := Tab.Editor;
  if Ed.Carets.Count = 0 then Exit;
  LexName := '';
  Prefix := '';
  if (Tab.Adapter <> nil) and (Tab.Adapter.Lexer <> nil) then
  begin
    LexName := LowerCase(Tab.Adapter.Lexer.LexerName);
    Prefix := Tab.Adapter.Lexer.LineComment;
  end;
  if Prefix = '' then
  begin
    if (Pos('python', LexName) > 0) or (Pos('shell', LexName) > 0) or
       (Pos('ruby', LexName) > 0) or (Pos('perl', LexName) > 0) or
       (Pos('yaml', LexName) > 0) or (Pos('powershell', LexName) > 0) then
      Prefix := '#'
    else if (Pos('sql', LexName) > 0) or (Pos('lua', LexName) > 0) then
      Prefix := '--'
    else if Pos('restructuredtext', LexName) > 0 then
      Prefix := '..'
    else if Pos('diff', LexName) > 0 then
      Exit
    else
      Prefix := '//';
  end;

  Ed.Carets[0].GetRange(X1, Y1, X2, Y2, Sel);
  if not Sel then
  begin
    X1 := 0; Y1 := Ed.Carets[0].PosY;
    X2 := 0; Y2 := Y1;
  end;
  if Y1 > Y2 then
  begin
    i := Y1; Y1 := Y2; Y2 := i;
  end;
  Ed.BeginUpdate;
  try
    for i := Y1 to Y2 do
    begin
      Line := Ed.Strings.Lines[i];
      Indent := Line;
      N := 0;
      while (N < Length(Line)) and ((Line[N + 1] = ' ') or (Line[N + 1] = #9)) do Inc(N);
      if AAdd then
        Ed.Strings.Lines[i] := Copy(Line, 1, N) + Prefix + Copy(Line, N + 1, MaxInt)
      else
      begin
        if Copy(Line, N + 1, Length(Prefix)) = Prefix then
          Ed.Strings.Lines[i] := Copy(Line, 1, N) + Copy(Line, N + 1 + Length(Prefix), MaxInt);
      end;
    end;
  finally
    Ed.EndUpdate;
  end;
  Ed.Modified := True;
  UpdateStatus;
end;

procedure TMainForm.ToggleBookmark;
begin
  if ActiveTab <> nil then
    ActiveTab.Editor.BookmarkToggleForCarets(FBookmarkGroup, True, FBookmarkGroup);
end;

procedure TMainForm.NextBookmark(ANext: Boolean);
begin
  if ActiveTab <> nil then
    ActiveTab.Editor.BookmarkGotoNext(ANext, 5, 5, False);
end;

procedure TMainForm.ShowBookmarkList;
var
  i, j: Integer;
  Tab: TEditorTab;
  P: PATBookmarkItem;
  E: TBookmarkEntry;
begin
  FBookmarkForm.Clear;
  for i := 0 to FTabs.Count - 1 do
  begin
    Tab := TEditorTab(FTabs[i]);
    for j := 0 to Tab.Editor.Strings.Bookmarks.Count - 1 do
    begin
      P := Tab.Editor.Strings.Bookmarks.ItemPtr[j];
      if (P = nil) or (not P^.Data.ShowInBookmarkList) then Continue;
      E := TBookmarkEntry.Create;
      E.FileName := Tab.FileName;
      E.Line := P^.Data.LineNum + 1;
      E.Group := P^.Data.Kind;
      if (P^.Data.LineNum >= 0) and (P^.Data.LineNum < Tab.Editor.Strings.Count) then
        E.Text := Tab.Editor.Strings.Lines[P^.Data.LineNum]
      else
        E.Text := '';
      if E.FileName = '' then E.FileName := Tab.BaseTitle;
      FBookmarkForm.Add(E);
    end;
  end;
  FBookmarkForm.ShowList;
end;

procedure TMainForm.SetBookmarkGroup(Sender: TObject);
begin
  FBookmarkGroup := (Sender as TMenuItem).Tag;
  if (FBookmarkGroup < 1) or (FBookmarkGroup > 5) then FBookmarkGroup := 1;
end;

procedure TMainForm.BookmarkJump(AEntry: TBookmarkEntry);
var
  Tab: TEditorTab;
  Files: array of string;
begin
  if AEntry = nil then Exit;
  Tab := FindTabByFile(AEntry.FileName);
  if (Tab = nil) and FileExists(AEntry.FileName) then
  begin
    SetLength(Files, 1);
    Files[0] := AEntry.FileName;
    OpenFiles(Files);
    Tab := FindTabByFile(AEntry.FileName);
  end;
  if Tab <> nil then
  begin
    SelectTab(Tab);
    Tab.GotoLineColumn(AEntry.Line - 1, 0);
  end;
end;

procedure TMainForm.BookmarkDelete(AEntry: TBookmarkEntry);
var
  Tab: TEditorTab;
  i: Integer;
begin
  if AEntry = nil then Exit;
  Tab := FindTabByFile(AEntry.FileName);
  if Tab = nil then Exit;
  for i := 0 to Tab.Editor.Strings.Bookmarks.Count - 1 do
    if Tab.Editor.Strings.Bookmarks.ItemPtr[i]^.Data.LineNum = AEntry.Line - 1 then
    begin
      Tab.Editor.Strings.Bookmarks.Delete(i);
      Break;
    end;
  ShowBookmarkList;
end;

procedure TMainForm.ClearBookmarks;
begin
  if ActiveTab <> nil then
    ActiveTab.Editor.BookmarkDeleteAll(True);
end;

procedure TMainForm.JoinLines;
var
  Ed: TATSynEdit;
  X1, Y1, X2, Y2, i, N: Integer;
  Sel: Boolean;
begin
  if ActiveTab = nil then Exit;
  Ed := ActiveTab.Editor;
  if Ed.Carets.Count = 0 then Exit;
  Ed.Carets[0].GetRange(X1, Y1, X2, Y2, Sel);
  if not Sel then
  begin
    Y1 := Ed.Carets[0].PosY;
    Y2 := Y1;
  end;
  if Y2 < Y1 then begin i := Y1; Y1 := Y2; Y2 := i; end;
  N := Y1;
  Ed.BeginUpdate;
  try
    while (N < Y2) and (N + 1 < Ed.Strings.Count) do
    begin
      Ed.Strings.Lines[N] := Ed.Strings.Lines[N] + Ed.Strings.Lines[N + 1];
      Ed.Strings.LineDelete(N + 1);
      Dec(Y2);
    end;
  finally
    Ed.EndUpdate;
  end;
  Ed.Modified := True;
  UpdateStatus;
end;

procedure TMainForm.SplitLine;
begin
  if ActiveTab <> nil then
    ActiveTab.Editor.TextInsertAtCarets(#10, False, False, False);
end;

procedure TMainForm.AddCaret(ADown: Boolean);
var
  Ed: TATSynEdit;
  C: TATCaretItem;
  X, Y: Integer;
begin
  if ActiveTab = nil then Exit;
  Ed := ActiveTab.Editor;
  if Ed.Carets.Count = 0 then Exit;
  C := Ed.Carets[Ed.Carets.Count - 1];
  X := C.PosX;
  Y := C.PosY;
  if ADown then Inc(Y) else Dec(Y);
  if Y < 0 then Y := 0;
  if Y >= Ed.Strings.Count then Y := Ed.Strings.Count - 1;
  Ed.Carets.ManyAllowed := True;
  Ed.Carets.Add(X, Y);
  Ed.Carets.Sort;
  UpdateStatus;
end;

procedure TMainForm.GoToLine;
var
  S: string;
  N: Integer;
  Tab: TEditorTab;
begin
  S := '1';
  if not TyInputQuery('Go to Line', 'Line number:', S) then Exit;
  N := StrToIntDef(S, 1);
  Tab := ActiveTab;
  if Tab <> nil then
    Tab.GotoLineColumn(N - 1, 0);
end;

procedure TMainForm.ShowFindDlg(AReplace: Boolean);
var
  Tab: TEditorTab;
  S: string;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  FFindForm.Editor := Tab.Editor;
  S := Tab.Editor.TextSelected;
  if S = '' then
    S := Tab.Editor.TextCurrentWord;
  if S <> '' then
    FFindForm.SetFindText(S);
  FFindForm.ShowFind(AReplace);
end;

procedure TMainForm.ShowFindInFilesDlg(AReplace: Boolean);
var
  Dir, S: string;
  Tab: TEditorTab;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  if Tab.FileName <> '' then
    Dir := ExtractFileDir(Tab.FileName)
  else
    Dir := FSettings.LastDir;
  S := Tab.Editor.TextSelected;
  if S = '' then
    S := Tab.Editor.TextCurrentWord;
  FResultsView.Clear;
  FResultsView.Visible := True;
  FBottomHost.Height := FStatusView.Height + 180;
  FResultsItem.Checked := True;
  FFindFilesForm.ShowDialog(Dir, S, '', AReplace);
end;

procedure TMainForm.FindNext;
begin
  if ActiveTab <> nil then
  begin
    FFindForm.Editor := ActiveTab.Editor;
    FFindForm.FindNext;
  end;
end;

procedure TMainForm.FindPrevious;
begin
  if ActiveTab <> nil then
  begin
    FFindForm.Editor := ActiveTab.Editor;
    FFindForm.FindPrevious;
  end;
end;

procedure TMainForm.ToggleWrap;
begin
  FSettings.WordWrap := not FSettings.WordWrap;
  ApplySettingsToAll;
  FWrapItem.Checked := FSettings.WordWrap;
end;

procedure TMainForm.ToggleWhitespace;
begin
  FSettings.ShowWhitespace := not FSettings.ShowWhitespace;
  ApplySettingsToAll;
  FWhitespaceItem.Checked := FSettings.ShowWhitespace;
end;

procedure TMainForm.ToggleNumbers;
begin
  FSettings.ShowNumbers := not FSettings.ShowNumbers;
  ApplySettingsToAll;
  FNumbersItem.Checked := FSettings.ShowNumbers;
end;

procedure TMainForm.ToggleFolding;
begin
  FSettings.ShowFolding := not FSettings.ShowFolding;
  ApplySettingsToAll;
  FFoldingItem.Checked := FSettings.ShowFolding;
end;

procedure TMainForm.ToggleMinimap;
begin
  FSettings.ShowMinimap := not FSettings.ShowMinimap;
  ApplySettingsToAll;
  FMinimapItem.Checked := FSettings.ShowMinimap;
end;

procedure TMainForm.ToggleMicromap;
begin
  FSettings.ShowMicromap := not FSettings.ShowMicromap;
  ApplySettingsToAll;
  FMicromapItem.Checked := FSettings.ShowMicromap;
end;

procedure TMainForm.InstanceTimerTick(Sender: TObject);
var
  Files: TStringList;
  Focus: Boolean;
  i: Integer;
  Arr: array of string;
begin
  if TakeOpenRequests(Files, Focus) then
  try
    if Focus then
    begin
      Show;
      BringToFront;
      SetFocus;
    end;
    if Files.Count > 0 then
    begin
      SetLength(Arr, Files.Count);
      for i := 0 to Files.Count - 1 do Arr[i] := Files[i];
      OpenFiles(Arr);
    end;
  finally
    Files.Free;
  end
  else
    Files.Free;
end;

procedure TMainForm.EditColorScheme;
var
  Dlg: TColorSchemeEditorForm;
  P: TEditorPalette;
  Dest: string;
begin
  Dlg := TColorSchemeEditorForm.Create(Self, CurrentPalette);
  try
    if not Dlg.Execute then Exit;
    P := Dlg.Palette;
    Dest := AppConfigDir + 'custom-scheme.json';
    try
      SavePaletteFile(Dest, P);
      FSettings.CustomColorSchemeFile := Dest;
      FSettings.ColorScheme := 'Custom';
      RebuildColorSchemeMenu;
      ApplyAppTheme;
    except
      on E: Exception do
        TyMessageDlg(Format(Tr('Cannot save color scheme: %s'), [E.Message]),
          mtError, [mbOK]);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.ImportColorScheme;
var
  D: TOpenDialog;
  P: TEditorPalette;
  Dest: string;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := Tr('JSON files') + '|*.json|' + Tr('All files') + '|*.*';
    if not D.Execute then Exit;
    if not LoadPaletteFile(D.FileName, P) then
    begin
      TyMessageDlg(Tr('Invalid color scheme file.'), mtError, [mbOK]);
      Exit;
    end;
    Dest := AppConfigDir + 'custom-scheme.json';
    try
      SavePaletteFile(Dest, P);
      FSettings.CustomColorSchemeFile := Dest;
      FSettings.ColorScheme := 'Custom';
      RebuildColorSchemeMenu;
      ApplyAppTheme;
    except
      on E: Exception do
        TyMessageDlg(Format(Tr('Cannot import color scheme: %s'), [E.Message]),
          mtError, [mbOK]);
    end;
  finally
    D.Free;
  end;
end;

procedure TMainForm.ExportColorScheme;
var
  D: TSaveDialog;
  P: TEditorPalette;
begin
  D := TSaveDialog.Create(Self);
  try
    D.FileName := 'tyeditor-color-scheme.json';
    D.Filter := Tr('JSON files') + '|*.json|' + Tr('All files') + '|*.*';
    if not D.Execute then Exit;
    P := CurrentPalette;
    try
      SavePaletteFile(D.FileName, P);
    except
      on E: Exception do
        TyMessageDlg(Format(Tr('Cannot export color scheme: %s'), [E.Message]),
          mtError, [mbOK]);
    end;
  finally
    D.Free;
  end;
end;

procedure TMainForm.TogglePinActive;
begin
  if ActiveTab = nil then Exit;
  ActiveTab.Pinned := not ActiveTab.Pinned;
  ActiveTab.UpdateCaption;
  RebuildOpenTabsMenu;
  if ActiveTab.Pinned then
    FStatusView.SetText(7, Tr('Tab pinned'))
  else
    FStatusView.SetText(7, '');
end;

procedure TMainForm.ToggleSplitView;
begin
  FSplitView.Toggle(ActiveTab);
  FSplitViewItem.Checked := FSplitView.Visible;
end;

procedure TMainForm.ToggleResults;
begin
  FResultsView.Visible := not FResultsView.Visible;
  if FResultsView.Visible then
    FBottomHost.Height := FStatusView.Height + 180
  else
    FBottomHost.Height := FStatusView.Height + 2;
  FResultsItem.Checked := FResultsView.Visible;
end;

procedure TMainForm.ToggleTheme;
begin
  FSettings.DarkMode := not FSettings.DarkMode;
  ApplyAppTheme;
end;

procedure TMainForm.ApplyTopMostLater(Data: PtrInt);
begin
  if FSettings.AlwaysOnTop then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
  SetNativeTopMost(Self, FSettings.AlwaysOnTop);
  ApplyDialogStayOnTop;
end;

procedure TMainForm.ToggleAlwaysOnTop;
begin
  FSettings.AlwaysOnTop := not FSettings.AlwaysOnTop;
  if FSettings.AlwaysOnTop then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
  FAlwaysOnTopItem.Checked := FSettings.AlwaysOnTop;
  SetNativeTopMost(Self, FSettings.AlwaysOnTop);
  ApplyDialogStayOnTop;
  Application.QueueAsyncCall(@ApplyTopMostLater, 0);
end;

procedure TMainForm.ApplyDialogStayOnTop;
var
  i: Integer;
begin
  for i := 0 to Screen.CustomFormCount - 1 do
    if Screen.CustomForms[i] <> Self then
    begin
      if FSettings.AlwaysOnTop then
        Screen.CustomForms[i].FormStyle := fsStayOnTop
      else
        Screen.CustomForms[i].FormStyle := fsNormal;
      SetNativeTopMost(Screen.CustomForms[i], FSettings.AlwaysOnTop);
    end;
end;

procedure TMainForm.ToggleFullScreen;
begin
  if WindowState = wsFullScreen then
    WindowState := wsNormal
  else
    WindowState := wsFullScreen;
end;

procedure TMainForm.ApplySettingsToAll;
var
  i: Integer;
begin
  if FTabs = nil then Exit;
  for i := 0 to FTabs.Count - 1 do
  begin
    TEditorTab(FTabs[i]).ApplySettings;
    ApplyEditorTheme(TEditorTab(FTabs[i]).Editor);
  end;
  FSplitView.InvalidateStyle;
  FSplitView.Refresh(ActiveTab);
end;

procedure TMainForm.ApplyEditorTheme(AEditor: TATSynEdit);
begin
  if AEditor = nil then Exit;
  ApplyPalette(AEditor, CurrentPalette);
  ApplyScrollbarTheme(TyDefaultController.Mode = 'dark');
  AEditor.Invalidate;
end;

procedure TMainForm.ApplyScrollbarTheme(ADark: Boolean);
var
  Track, Thumb, ThumbHover, ThumbActive: TTyStyleSet;

  function FillColor(const S: TTyStyleSet; ADefault: TColor): TColor;
  begin
    if (tpBackground in S.Present) and (S.Background.Kind = tfkSolid) then
      Result := TyColorToLCL(S.Background.Color)
    else
      Result := ADefault;
  end;

  function LineColor(const S: TTyStyleSet; ADefault: TColor): TColor;
  begin
    if (tpBorderColor in S.Present) and (S.BorderWidth > 0) then
      Result := TyColorToLCL(S.BorderColor)
    else
      Result := ADefault;
  end;

  function FallbackThumb(ADefault: TColor): TColor;
  begin
    if tpTextColor in Thumb.Present then
      Result := TyColorToLCL(Thumb.TextColor)
    else
      Result := ADefault;
  end;

begin
  ATScrollbarTheme.ArrowStyleV := asaArrowsHidden;
  ATScrollbarTheme.ArrowStyleH := asaArrowsHidden;

  Track := TyDefaultController.Model.ResolveStyle('TyScrollBar', '', []);
  Thumb := TyDefaultController.Model.ResolveStyle('TyScrollThumb', '', []);
  ThumbHover := TyDefaultController.Model.ResolveStyle('TyScrollThumb', '', [tysHover]);
  ThumbActive := TyDefaultController.Model.ResolveStyle('TyScrollThumb', '', [tysActive]);

  if ADark then
  begin
    ATScrollbarTheme.ColorBG := FillColor(Track, $00202020);
    ATScrollbarTheme.ColorBorder := LineColor(Track, $00303030);
    ATScrollbarTheme.ColorThumbBorder := LineColor(Thumb, $00383838);
    ATScrollbarTheme.ColorThumbFill := FillColor(Thumb, FallbackThumb($004A4A4A));
    ATScrollbarTheme.ColorThumbFillOver := FillColor(ThumbHover, $00606060);
    ATScrollbarTheme.ColorThumbFillPressed := FillColor(ThumbActive, $00787878);
    ATScrollbarTheme.ColorThumbDecor := $00606060;
    ATScrollbarTheme.ColorThumbDecor2 := $00808080;
    ATScrollbarTheme.ColorArrowBorder := $00303030;
    ATScrollbarTheme.ColorArrowFill := $00202020;
    ATScrollbarTheme.ColorArrowFillOver := $00303030;
    ATScrollbarTheme.ColorArrowFillPressed := $00404040;
    ATScrollbarTheme.ColorArrowSign := $00A0A0A0;
    ATScrollbarTheme.ColorArrowSignOver := $00D0D0D0;
    ATScrollbarTheme.ColorArrowSignPressed := $00FFFFFF;
    ATScrollbarTheme.ColorScrolled := $002A2A2A;
  end
  else
  begin
    ATScrollbarTheme.ColorBG := FillColor(Track, clWhite);
    ATScrollbarTheme.ColorBorder := LineColor(Track, $00E0E0E0);
    ATScrollbarTheme.ColorThumbBorder := LineColor(Thumb, $00D0D0D0);
    ATScrollbarTheme.ColorThumbFill := FillColor(Thumb, FallbackThumb($00C0C0C0));
    ATScrollbarTheme.ColorThumbFillOver := FillColor(ThumbHover, $00A8A8A8);
    ATScrollbarTheme.ColorThumbFillPressed := FillColor(ThumbActive, $00909090);
    ATScrollbarTheme.ColorThumbDecor := $00A0A0A0;
    ATScrollbarTheme.ColorThumbDecor2 := $00808080;
    ATScrollbarTheme.ColorArrowBorder := $00E0E0E0;
    ATScrollbarTheme.ColorArrowFill := $00F0F0F0;
    ATScrollbarTheme.ColorArrowFillOver := $00E0E0E0;
    ATScrollbarTheme.ColorArrowFillPressed := $00D0D0D0;
    ATScrollbarTheme.ColorArrowSign := $00606060;
    ATScrollbarTheme.ColorArrowSignOver := $00404040;
    ATScrollbarTheme.ColorArrowSignPressed := $00202020;
    ATScrollbarTheme.ColorScrolled := $00F5F5F5;
  end;
end;

procedure TMainForm.MacroRecord;
begin
  if FMacro.Recording then
  begin
    FMacro.Recording := False;
    FMacroRecordItem.Checked := False;
    FStatusView.SetText(7, Format(Tr('Macro recording stopped: %d command(s).'),
      [FMacro.Count]));
    UpdateStatus;
  end
  else
  begin
    FMacro.Clear;
    FMacro.Recording := True;
    FMacroRecordItem.Checked := True;
    FStatusView.SetText(7, Tr('Macro recording started.'));
  end;
end;

procedure TMainForm.MacroPlay;
begin
  if ActiveTab = nil then Exit;
  if FMacro.Count = 0 then
  begin
    TyMessageDlg(Tr('Macro is empty.'), mtInformation, [mbOK]);
    Exit;
  end;
  FMacro.Play(ActiveTab.Editor, 1);
  UpdateStatus;
end;

procedure TMainForm.MacroPlayN;
var
  S: string;
  N: Integer;
begin
  if ActiveTab = nil then Exit;
  S := '2';
  if not TyInputQuery('Play Macro', 'Repeat count:', S) then Exit;
  N := StrToIntDef(S, 1);
  FMacro.Play(ActiveTab.Editor, N);
  UpdateStatus;
end;

procedure TMainForm.MacroSave;
var
  Dlg: TSaveDialog;
begin
  if FMacro.Count = 0 then Exit;
  EnsureDir(MacrosDir);
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.InitialDir := MacrosDir;
    Dlg.FileName := 'macro.json';
    Dlg.Filter := 'TyEditor macro|*.json|All files|*.*';
    if not Dlg.Execute then Exit;
    try
      FMacro.SaveToFile(Dlg.FileName);
    except
      on E: Exception do
        TyMessageDlg(Tr('Cannot save macro:') + ' ' + E.Message, mtError, [mbOK]);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.MacroLoad;
var
  Dlg: TOpenDialog;
begin
  EnsureDir(MacrosDir);
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.InitialDir := MacrosDir;
    Dlg.Filter := 'TyEditor macro|*.json|All files|*.*';
    if not Dlg.Execute then Exit;
    try
      FMacro.LoadFromFile(Dlg.FileName);
      FSettings.MacroPath := Dlg.FileName;
      TyMessageDlg(Format(Tr('Macro loaded: %d command(s).'), [FMacro.Count]),
        mtInformation, [mbOK]);
    except
      on E: Exception do
        TyMessageDlg(Tr('Cannot load macro:') + ' ' + E.Message, mtError, [mbOK]);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.ShowMacroManager;
var
  Dlg: TMacroManagerForm;
  P: string;
begin
  Dlg := TMacroManagerForm.Create(Self, MacrosDir);
  try
    P := Dlg.Execute;
    if P <> '' then
    begin
      try
        FMacro.LoadFromFile(P);
        FSettings.MacroPath := P;
      except
        on E: Exception do
          TyMessageDlg(Format(Tr('Cannot load macro: %s'), [E.Message]), mtError, [mbOK]);
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.PlayBoundMacro;
begin
  if (FSettings.MacroPath = '') or (not FileExists(FSettings.MacroPath)) then
  begin
    TyMessageDlg(Tr('No macro is bound. Use Macro > Load Macro first.'),
      mtInformation, [mbOK]);
    Exit;
  end;
  MacroPlay;
end;

procedure TMainForm.SaveSettingsNow;
begin
  UpdateWindowSettings;
  FSettings.Save;
end;

procedure TMainForm.UpdateWindowSettings;
begin
  FSettings.WindowMaximized := WindowState = wsMaximized;
  if WindowState = wsNormal then
  begin
    FSettings.WindowLeft := Left;
    FSettings.WindowTop := Top;
    FSettings.WindowWidth := Width;
    FSettings.WindowHeight := Height;
  end;
end;

procedure TMainForm.SaveSessionAndSettings;
begin
  try
    UpdateWindowSettings;
    FSettings.Save;
    if FTabs <> nil then
    begin
      if not SaveSession(FTabs, FPages.ActivePageIndex, FBackupConfig) then
        ; // session errors must not prevent closing
      CleanupOldBackups(FTabs, FBackupConfig);
    end;
  except
    // closing must never be blocked by persistence errors
  end;
  if FRunningMarker <> '' then
    DeleteFile(FRunningMarker);
  if FSettings.SingleInstance then
    ReleaseSingleInstance;
end;

procedure TMainForm.DoFormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if FClosing then
  begin
    CloseAction := caFree;
    Exit;
  end;
  FClosing := True;
  SaveSessionAndSettings;
  CloseAction := caFree;
end;

procedure TMainForm.DoFormShow(Sender: TObject);
var
  i: Integer;
  Files: array of string;
begin
  if FStartupDone then Exit;
  FStartupDone := True;
  SetNativeTopMost(Self, FSettings.AlwaysOnTop);
  ApplyDialogStayOnTop;
  if FStartupRestorePending then
  begin
    FStartupRestorePending := False;
    RestoreSession;
    if FTabs.Count = 0 then
      NewUntitled;
    if FPages.ActivePageIndex >= 0 then
      SelectTab(ActiveTab);
  end;
  if ParamCount > 0 then
  begin
    SetLength(Files, ParamCount);
    for i := 1 to ParamCount do
      Files[i - 1] := ParamStr(i);
    OpenFiles(Files);
  end;
  if ActiveTab <> nil then
    ActiveTab.Editor.SetFocus;
end;

procedure TMainForm.RestoreSession;
var
  Root: TJSONObject;
  Obj: TJSONObject;
  Arr: TJSONArray;
  i, ActiveIdx: Integer;
  Tab: TEditorTab;
  BackupName, FileName, Title, Msg, BDir: string;
  TabObj: TJSONObject;
begin
  Root := LoadSessionJSON;
  if Root = nil then Exit;
  BDir := BackupDirFor(FBackupConfig);
  if FStartupWasUnclean then
  begin
    Msg := Tr('TyEditor did not shut down normally. Restore the previous session?');
    Msg := Msg + LineEnding + LineEnding +
      Format(Tr('Session file: %s'), [SessionFileName]);
    if FileAge(SessionFileName) >= 0 then
      Msg := Msg + LineEnding +
        Format(Tr('Last modified: %s'), [DateTimeToStr(FileDateToDateTime(FileAge(SessionFileName)))]);
    if Root.Find('tabs') is TJSONArray then
      Msg := Msg + LineEnding +
        Format(Tr('Tabs: %d'), [TJSONArray(Root.Find('tabs')).Count]);
    if TyMessageDlg(Msg, mtConfirmation, [mbYes, mbNo]) <> mrYes then
    begin
      Root.Free;
      Exit;
    end;
  end;
  FRestoring := True;
  try
    try
      if not (Root.Find('tabs') is TJSONArray) then Exit;
      Arr := TJSONArray(Root.Find('tabs'));
      for i := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[i] is TJSONObject) then Continue;
        Obj := Arr.Items[i] as TJSONObject;
        Title := Tr('Untitled');
        if Obj.IndexOfName('title') >= 0 then Title := Obj.Get('title', Title);
        FileName := '';
        if Obj.IndexOfName('file') >= 0 then FileName := Obj.Get('file', '');
        BackupName := '';
        if Obj.IndexOfName('backup') >= 0 then BackupName := Obj.Get('backup', '');
        Tab := CreateTab(Title, Obj.Get('id', NewSessionId));
        Tab.FileName := FileName;
        Tab.UntitledName := Title;
        if (BackupName <> '') and FileExists(BDir + BackupName) then
        begin
          Tab.BackupFile := BDir + BackupName;
          LoadTabBackup(Tab, Tab.BackupFile);
        end
        else if (FileName <> '') and FileExists(FileName) then
          Tab.LoadFromFile(FileName)
        else
        begin
          Tab.Editor.Text := '';
          Tab.Editor.Modified := False;
        end;
        RestoreTabState(Tab, Obj, FLanguage);
        Tab.RefreshEolText;
        if Tab.Adapter.Lexer = nil then
        begin
          if Tab.FileName <> '' then
            Tab.SetLexer(FLanguage.FindByFileName(Tab.FileName));
        end;
        Tab.UpdateCaption;
        if BackupName <> '' then
          Tab.BackupFile := BDir + BackupName;
      end;
      ActiveIdx := 0;
      if Root.IndexOfName('active_tab') >= 0 then
        ActiveIdx := Root.Get('active_tab', 0);
      if (ActiveIdx >= 0) and (ActiveIdx < FPages.PageCount) then
        FPages.ActivePageIndex := ActiveIdx;
      UpdateDocumentMenuChecks;
      RebuildOpenTabsMenu;
    except
      // a broken session must not stop startup; whatever was created stays
    end;
  finally
    FRestoring := False;
    Root.Free;
  end;
end;

procedure TMainForm.SessionTimerTick(Sender: TObject);
begin
  if FClosing or FRestoring then Exit;
  if FTabs.Count = 0 then Exit;
  try
    SaveSession(FTabs, FPages.ActivePageIndex, FBackupConfig);
  except
    // automatic session saves are best effort
  end;
end;

procedure TMainForm.FindFileResult(const AFileName: string; ALine, ACol: Integer;
  const AText: string);
begin
  FResultsView.Add(AFileName, ALine, ACol, AText);
  FResultsView.SelectLast;
end;

procedure TMainForm.ResultsOpen(AHit: TSearchHit);
var
  Tab: TEditorTab;
  Allow: Boolean;
begin
  Tab := FindTabByFile(AHit.FileName);
  if Tab = nil then
  begin
    if not FileExists(AHit.FileName) then Exit;
    Tab := CreateTab(ExtractFileName(AHit.FileName));
    if not LoadFileIntoTab(Tab, AHit.FileName) then
    begin
      if FPages.PageCount > 0 then
      begin
        Allow := True;
        CloseTab(Tab, False, Allow, False);
      end;
      Exit;
    end;
  end;
  SelectTab(Tab);
  Tab.GotoLineColumn(AHit.Line - 1, AHit.Col - 1);
end;

procedure TMainForm.CopyPath;
begin
  if (ActiveTab <> nil) and (ActiveTab.FileName <> '') then
    Clipboard.AsText := ActiveTab.FileName;
end;

procedure TMainForm.ExportResults;
begin
  FResultsView.ExportResults(FSettings.LastDir);
end;

procedure TMainForm.CloseAppLater(Data: PtrInt);
begin
  Close;
end;

procedure TMainForm.MaybeCloseAfterTabClose(Data: PtrInt);
begin
  if (FPages.PageCount = 0) and (not FClosing) then
    Close;
end;

procedure TMainForm.ShowAbout;
begin
  TyMessageDlg('TyEditor ' + TyEditorVersion + LineEnding + LineEnding +
    Tr('A lightweight, multi-tab text editor for Linux, Windows and macOS.') +
    LineEnding + LineEnding +
    'Copyright (c) 2026 TyEditor contributors' + LineEnding +
    Tr('Licensed under the Apache License 2.0.'),
    mtInformation, [mbOK]);
end;
procedure TMainForm.ShowPreferences;
var
  OldLang: string;
  Dlg: TSettingsForm;
begin
  OldLang := FSettings.Language;
  Dlg := TSettingsForm.Create(Self, FSettings);
  try
    if Dlg.Execute then
    begin
          if FSettings.SingleInstance then
      begin
        AcquireSingleInstance;
        if FInstanceTimer <> nil then FInstanceTimer.Enabled := True;
      end
      else
      begin
        ReleaseSingleInstance;
        if FInstanceTimer <> nil then FInstanceTimer.Enabled := False;
      end;
      ApplyAppTheme;
      FWrapItem.Checked := FSettings.WordWrap;
      FWhitespaceItem.Checked := FSettings.ShowWhitespace;
      FNumbersItem.Checked := FSettings.ShowNumbers;
      FFoldingItem.Checked := FSettings.ShowFolding;
      FMinimapItem.Checked := FSettings.ShowMinimap;
      FMicromapItem.Checked := FSettings.ShowMicromap;
      FRulerItem.Checked := FSettings.ShowRuler;
      FBookmarkMarginItem.Checked := FSettings.ShowBookmarkMargin;
      FSessionTimer.Interval := FSettings.AutoSnapshotSec * 1000;
      FFindForm.ApplyDefaults(FSettings.FindCase, FSettings.FindWords, FSettings.FindRegex, FSettings.FindWrap);
      FFindFilesForm.ApplyDefaults(FSettings.FindCase, FSettings.FindWords, FSettings.FindRegex);
      RebuildRecentMenu;
      if not SameText(OldLang, FSettings.Language) then
        TyMessageDlg(Tr('The language will change after restarting TyEditor.'),
          mtInformation, [mbOK]);
    end;
  finally
    Dlg.Free;
  end;
end;

end.
