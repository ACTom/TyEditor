unit ucommands;

{$mode objfpc}{$H+}

interface

uses
  Classes, Menus;

type
  TMenuCmd = (
    mcNone,
    mcNew, mcOpen, mcSave, mcSaveAs, mcSaveAll, mcReload, mcClose,
    mcCloseOthers, mcCloseAll, mcReopen, mcExit,
    mcUndo, mcRedo, mcCut, mcCopy, mcPaste, mcDelete, mcSelectAll,
    mcDupLine, mcDelLine, mcMoveUp, mcMoveDown, mcIndent, mcUnindent,
    mcComment, mcUncomment, mcMatchBracket, mcUpper, mcLower, mcTitle,
    mcSortAsc, mcSortDesc, mcSortAscNoCase, mcSortDescNoCase,
    mcTrimTrailing, mcRemoveDup, mcJoinLines, mcSplitLine,
    mcAddCaretAbove, mcAddCaretBelow,
    mcFind, mcReplace, mcFindNext, mcFindPrev, mcFindInFiles,
    mcReplaceInFiles, mcExportResults, mcGotoLine,
    mcToggleBookmark, mcNextBookmark, mcPrevBookmark, mcClearBookmarks,
    mcBookmarkList, mcImportScheme, mcExportScheme, mcEditScheme,
    mcWrap, mcWhitespace, mcNumbers, mcFolding, mcMinimap, mcMicromap,
    mcZoomIn, mcZoomOut, mcZoomReset, mcFullScreen, mcAlwaysOnTop,
    mcRuler, mcBookmarkMargin, mcSplitView, mcPinTab,
    mcResults, mcThemeDark,
    mcMacroRecord, mcMacroPlay, mcMacroPlayN, mcMacroSave, mcMacroLoad,
    mcMacroManager, mcMacroPlayBound,
    mcCopyPath, mcAbout, mcPreferences, mcSaveSettings
  );

function SC(AKey: Word; AShift: TShiftState): TShortCut;

implementation

function SC(AKey: Word; AShift: TShiftState): TShortCut;
begin
  Result := ShortCut(AKey, AShift);
end;

end.
