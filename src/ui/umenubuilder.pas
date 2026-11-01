unit umenubuilder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Menus, LCLType,
  utranslation, ucommands, ukeybindings;

type
  TMenuBuilder = class
  private
    FOwner: TComponent;
    FOnCommand: TNotifyEvent;
    FOnBookmarkGroup: TNotifyEvent;
    FMainMenu: TMainMenu;
    FRecentMenu, FConvertMenu, FReloadEncMenu, FRecentEncMenu: TMenuItem;
    FEolMenu, FLanguageMenu, FThemeMenu, FColorSchemeMenu: TMenuItem;
    FOpenTabsMenu: TMenuItem;
    FWrapItem, FWhitespaceItem, FNumbersItem, FFoldingItem: TMenuItem;
    FRulerItem, FBookmarkMarginItem, FSplitViewItem: TMenuItem;
    FMinimapItem, FMicromapItem, FAlwaysOnTopItem, FThemeDarkItem: TMenuItem;
    FResultsItem, FMacroRecordItem, FPluginMenu: TMenuItem;
    FToolsMenu: TMenuItem;
    FSettingsMenu: TMenuItem;
    function AddItem(AParent: TMenuItem; const ACaption: string;
      AShortCut: TShortCut; ACommand: TMenuCmd): TMenuItem;
    procedure AddSep(AParent: TMenuItem);
    function AddSub(AParent: TMenuItem; const ACaption: string): TMenuItem;
  public
    constructor Create(AOwner: TComponent; AOnCommand, AOnBookmarkGroup: TNotifyEvent);
    procedure Build;
    property MainMenu: TMainMenu read FMainMenu;
    property RecentMenu: TMenuItem read FRecentMenu;
    property ConvertMenu: TMenuItem read FConvertMenu;
    property ReloadEncMenu: TMenuItem read FReloadEncMenu;
    property RecentEncMenu: TMenuItem read FRecentEncMenu;
    property EolMenu: TMenuItem read FEolMenu;
    property LanguageMenu: TMenuItem read FLanguageMenu;
    property ThemeMenu: TMenuItem read FThemeMenu;
    property ColorSchemeMenu: TMenuItem read FColorSchemeMenu;
    property OpenTabsMenu: TMenuItem read FOpenTabsMenu;
    property WrapItem: TMenuItem read FWrapItem;
    property WhitespaceItem: TMenuItem read FWhitespaceItem;
    property NumbersItem: TMenuItem read FNumbersItem;
    property FoldingItem: TMenuItem read FFoldingItem;
    property RulerItem: TMenuItem read FRulerItem;
    property BookmarkMarginItem: TMenuItem read FBookmarkMarginItem;
    property SplitViewItem: TMenuItem read FSplitViewItem;
    property MinimapItem: TMenuItem read FMinimapItem;
    property MicromapItem: TMenuItem read FMicromapItem;
    property AlwaysOnTopItem: TMenuItem read FAlwaysOnTopItem;
    property ThemeDarkItem: TMenuItem read FThemeDarkItem;
    property ResultsItem: TMenuItem read FResultsItem;
    property MacroRecordItem: TMenuItem read FMacroRecordItem;
    property PluginMenu: TMenuItem read FPluginMenu;
    property ToolsMenu: TMenuItem read FToolsMenu;
    property SettingsMenu: TMenuItem read FSettingsMenu;
  end;

implementation

constructor TMenuBuilder.Create(AOwner: TComponent;
  AOnCommand, AOnBookmarkGroup: TNotifyEvent);
begin
  inherited Create;
  FOwner := AOwner;
  FOnCommand := AOnCommand;
  FOnBookmarkGroup := AOnBookmarkGroup;
end;

function TMenuBuilder.AddItem(AParent: TMenuItem; const ACaption: string;
  AShortCut: TShortCut; ACommand: TMenuCmd): TMenuItem;
begin
  Result := TMenuItem.Create(FOwner);
  Result.Caption := Tr(ACaption);
  if AShortCut <> 0 then
    Result.ShortCut := AShortCut;
  Result.Tag := Ord(ACommand);
  if ACommand <> mcNone then
    Result.Name := ShortcutCommandID(ACommand);
  Result.OnClick := FOnCommand;
  AParent.Add(Result);
end;

procedure TMenuBuilder.AddSep(AParent: TMenuItem);
begin
  AddItem(AParent, '-', 0, mcNone);
end;

function TMenuBuilder.AddSub(AParent: TMenuItem; const ACaption: string): TMenuItem;
begin
  Result := TMenuItem.Create(FOwner);
  Result.Caption := Tr(ACaption);
  AParent.Add(Result);
end;

procedure TMenuBuilder.Build;
var
  M, S: TMenuItem;
  i: Integer;
begin
  FMainMenu := TMainMenu.Create(FOwner);
  FMainMenu.Name := 'MainMenu';

  M := AddSub(FMainMenu.Items, '&File');
  AddItem(M, '&New', SC(Ord('N'), [ssCtrl]), mcNew);
  AddItem(M, '&Open...', SC(Ord('O'), [ssCtrl]), mcOpen);
  FRecentMenu := AddSub(M, 'Open &Recent');
  AddItem(M, '&Save', SC(Ord('S'), [ssCtrl]), mcSave);
  AddItem(M, 'Save &As...', 0, mcSaveAs);
  AddItem(M, 'Save A&ll', SC(Ord('S'), [ssCtrl, ssShift]), mcSaveAll);
  AddItem(M, '&Reload', SC(Ord('R'), [ssCtrl]), mcReload);
  AddItem(M, 'Copy File &Path', 0, mcCopyPath);
  AddSep(M);
  AddItem(M, '&Print...', SC(Ord('P'), [ssCtrl]), mcPrint);
  AddItem(M, 'Print Pre&view', SC(Ord('P'), [ssCtrl, ssShift]), mcPrintPreview);
  AddItem(M, 'Page Set&up...', 0, mcPageSetup);
  AddSep(M);
  AddItem(M, '&Close', SC(Ord('W'), [ssCtrl]), mcClose);
  AddItem(M, 'Close &Others', 0, mcCloseOthers);
  AddItem(M, 'Close All', 0, mcCloseAll);
  AddItem(M, 'Reopen Closed Tab', SC(Ord('T'), [ssCtrl, ssShift]), mcReopen);
  AddSep(M);
  AddItem(M, 'E&xit', 0, mcExit);

  M := AddSub(FMainMenu.Items, '&Edit');
  AddItem(M, '&Undo', SC(Ord('Z'), [ssCtrl]), mcUndo);
  AddItem(M, '&Redo', SC(Ord('Y'), [ssCtrl]), mcRedo);
  AddSep(M);
  AddItem(M, 'Cu&t', SC(Ord('X'), [ssCtrl]), mcCut);
  AddItem(M, '&Copy', SC(Ord('C'), [ssCtrl]), mcCopy);
  AddItem(M, '&Paste', SC(Ord('V'), [ssCtrl]), mcPaste);
  AddItem(M, '&Delete', SC(VK_DELETE, []), mcDelete);
  AddItem(M, 'Select &All', SC(Ord('A'), [ssCtrl]), mcSelectAll);
  AddSep(M);
  AddItem(M, '&Duplicate Line', SC(Ord('D'), [ssCtrl]), mcDupLine);
  AddItem(M, 'Delete Line', SC(Ord('L'), [ssCtrl, ssShift]), mcDelLine);
  AddItem(M, 'Move Line &Up', SC(VK_UP, [ssCtrl, ssShift]), mcMoveUp);
  AddItem(M, 'Move Line D&own', SC(VK_DOWN, [ssCtrl, ssShift]), mcMoveDown);
  AddItem(M, '&Indent', SC(VK_TAB, [ssCtrl]), mcIndent);
  AddItem(M, '&Unindent', SC(VK_TAB, [ssCtrl, ssShift]), mcUnindent);
  AddSep(M);
  AddItem(M, 'Toggle &Comment', SC(Ord('Q'), [ssCtrl]), mcComment);
  AddItem(M, '&Remove Comment', 0, mcUncomment);
  AddItem(M, 'Go to &Matching Bracket', SC(Ord('B'), [ssCtrl]), mcMatchBracket);
  AddSep(M);
  AddItem(M, 'To &Upper Case', SC(Ord('U'), [ssCtrl, ssShift]), mcUpper);
  AddItem(M, 'To &Lower Case', SC(Ord('L'), [ssCtrl]), mcLower);
  AddItem(M, 'To &Title Case', 0, mcTitle);
  AddSep(M);
  AddItem(M, 'Sort Ascending', 0, mcSortAsc);
  AddItem(M, 'Sort Descending', 0, mcSortDesc);
  AddItem(M, 'Sort Ascending (ignore case)', 0, mcSortAscNoCase);
  AddItem(M, 'Sort Descending (ignore case)', 0, mcSortDescNoCase);
  AddItem(M, 'Trim Trailing Spaces', 0, mcTrimTrailing);
  AddItem(M, 'Remove Duplicate Lines', 0, mcRemoveDup);
  AddSep(M);
  AddItem(M, '&Join Lines', SC(Ord('J'), [ssCtrl]), mcJoinLines);
  AddItem(M, 'S&plit Line', 0, mcSplitLine);
  AddSep(M);
  AddItem(M, 'Add Caret &Above', SC(VK_UP, [ssCtrl, ssAlt]), mcAddCaretAbove);
  AddItem(M, 'Add Caret &Below', SC(VK_DOWN, [ssCtrl, ssAlt]), mcAddCaretBelow);

  M := AddSub(FMainMenu.Items, '&Search');
  AddItem(M, '&Find...', SC(Ord('F'), [ssCtrl]), mcFind);
  AddItem(M, '&Replace...', SC(Ord('H'), [ssCtrl]), mcReplace);
  AddItem(M, 'Find &Next', SC(VK_F3, []), mcFindNext);
  AddItem(M, 'Find &Previous', SC(VK_F3, [ssShift]), mcFindPrev);
  AddSep(M);
  AddItem(M, 'Find in &Files...', SC(Ord('F'), [ssCtrl, ssShift]), mcFindInFiles);
  AddItem(M, 'Replace in Files...', SC(Ord('H'), [ssCtrl, ssShift]), mcReplaceInFiles);
  AddItem(M, 'Export Results...', 0, mcExportResults);
  AddSep(M);
  AddItem(M, '&Go to Line...', SC(Ord('G'), [ssCtrl]), mcGotoLine);
  AddSep(M);
  AddItem(M, 'Toggle Bookmark', SC(VK_F2, []), mcToggleBookmark);
  AddItem(M, 'Next Bookmark', SC(VK_F2, [ssCtrl]), mcNextBookmark);
  AddItem(M, 'Previous Bookmark', SC(VK_F2, [ssCtrl, ssShift]), mcPrevBookmark);
  AddItem(M, '&Bookmark List...', SC(Ord('B'), [ssCtrl, ssAlt]), mcBookmarkList);
  for i := 1 to 5 do
  begin
    S := TMenuItem.Create(FOwner);
    S.Caption := Format(Tr('Bookmark Group %d'), [i]);
    S.Tag := i;
    S.OnClick := FOnBookmarkGroup;
    M.Add(S);
  end;
  AddItem(M, 'Clear All Bookmarks', 0, mcClearBookmarks);

  M := AddSub(FMainMenu.Items, '&View');
  FWrapItem := AddItem(M, '&Word Wrap', 0, mcWrap);
  FWhitespaceItem := AddItem(M, 'Show &Whitespace', 0, mcWhitespace);
  FNumbersItem := AddItem(M, '&Line Numbers', 0, mcNumbers);
  FFoldingItem := AddItem(M, '&Folding', 0, mcFolding);
  FRulerItem := AddItem(M, '&Ruler', 0, mcRuler);
  FBookmarkMarginItem := AddItem(M, '&Bookmark Margin', 0, mcBookmarkMargin);
  FSplitViewItem := AddItem(M, '&Split View (read-only)', SC(VK_F8, []), mcSplitView);
  AddItem(M, '&Pin Current Tab', SC(Ord('G'), [ssCtrl, ssAlt]), mcPinTab);
  FMinimapItem := AddItem(M, '&Minimap', 0, mcMinimap);
  FMicromapItem := AddItem(M, '&Micromap', 0, mcMicromap);
  AddSep(M);
  AddItem(M, 'Zoom &In', SC(VK_ADD, [ssCtrl]), mcZoomIn);
  AddItem(M, 'Zoom &Out', SC(VK_SUBTRACT, [ssCtrl]), mcZoomOut);
  AddItem(M, '&Reset Zoom', SC(Ord('0'), [ssCtrl]), mcZoomReset);
  AddSep(M);
  AddItem(M, 'Toggle &Full Screen', SC(VK_F11, []), mcFullScreen);
  FAlwaysOnTopItem := AddItem(M, 'Always on &Top', SC(Ord('A'), [ssCtrl, ssAlt]), mcAlwaysOnTop);
  FThemeDarkItem := AddItem(M, '&Dark Theme', SC(Ord('D'), [ssCtrl, ssAlt]), mcThemeDark);
  FResultsItem := AddItem(M, 'Search &Results', SC(VK_F12, []), mcResults);
  FOpenTabsMenu := AddSub(M, 'Open &Tabs');
  AddSep(M);
  FThemeMenu := AddSub(M, '&Interface Theme');
  FColorSchemeMenu := AddSub(M, 'Editor &Color Scheme');

  M := AddSub(FMainMenu.Items, 'E&ncoding');
  FConvertMenu := AddSub(M, '&Convert to');
  FReloadEncMenu := AddSub(M, '&Reload with');
  FRecentEncMenu := AddSub(M, '&Recent Encodings');
  AddSep(M);
  FEolMenu := AddSub(M, '&EOL Conversion');

  M := AddSub(FMainMenu.Items, '&Language');
  FLanguageMenu := M;

  M := AddSub(FMainMenu.Items, '&Macro');
  FMacroRecordItem := AddItem(M, 'Start/Stop &Recording', SC(Ord('R'), [ssCtrl, ssAlt]), mcMacroRecord);
  AddItem(M, '&Play', SC(Ord('J'), [ssCtrl, ssAlt]), mcMacroPlay);
  AddItem(M, 'Play &N Times...', 0, mcMacroPlayN);
  AddSep(M);
  AddItem(M, '&Save Macro...', 0, mcMacroSave);
  AddItem(M, '&Load Macro...', 0, mcMacroLoad);
  AddSep(M);
  AddItem(M, 'Macro &Manager...', SC(Ord('M'), [ssCtrl, ssAlt]), mcMacroManager);
  AddItem(M, 'Play &Bound Macro', SC(VK_F9, [ssCtrl]), mcMacroPlayBound);

  FToolsMenu := AddSub(FMainMenu.Items, '&Tools');

  FPluginMenu := AddSub(FMainMenu.Items, '&Plugins');

  {$IFDEF LCLCocoa}
  { macOS puts these in the application menu; do not create a top-level
    Settings menu.  The hidden group is picked up by TMainForm. }
  FSettingsMenu := TMenuItem.Create(FOwner);
  FSettingsMenu.Name := 'AppSettingsMenu';
  AddItem(FSettingsMenu, '&Preferences...', SC(Ord(','), [ssMeta]), mcPreferences);
  AddItem(FSettingsMenu, '&Keyboard Shortcuts...', SC(Ord('K'), [ssMeta, ssAlt]), mcKeyboardShortcuts);
  {$ELSE}
  FSettingsMenu := AddSub(FMainMenu.Items, 'S&ettings');
  AddItem(FSettingsMenu, '&Preferences...', SC(Ord('P'), [ssCtrl, ssAlt]), mcPreferences);
  AddItem(FSettingsMenu, '&Keyboard Shortcuts...', 0, mcKeyboardShortcuts);
  {$ENDIF}

  M := AddSub(FMainMenu.Items, '&Help');
  AddItem(M, '&About TyEditor', 0, mcAbout);
end;

end.
