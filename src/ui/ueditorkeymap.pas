unit ueditorkeymap;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLType, ATSynEdit_Keymap, ATSynEdit_Keymap_Init,
  ATSynEdit_Commands, ucommands;

{ Build a private keymap for editor tabs.  Commands that also have a menu item
  are removed from the copy, so the menu shortcut is the only shortcut for
  those actions.  Non-menu editor keys remain available. }
function CreateManagedEditorKeymap: TATKeymap;
function EditorCommandForMenuCommand(ACommand: TMenuCmd): Integer;
function EditorKeyConflictName(AMap: TATKeymap; AShortCut: TShortCut): string;

implementation

function EditorCommandForMenuCommand(ACommand: TMenuCmd): Integer;
begin
  case ACommand of
    mcUndo: Result := cCommand_Undo;
    mcRedo: Result := cCommand_Redo;
    mcCut: Result := cCommand_ClipboardCut;
    mcCopy: Result := cCommand_ClipboardCopy;
    mcPaste: Result := cCommand_ClipboardPaste;
    mcDelete: Result := cCommand_TextDeleteSelection;
    mcSelectAll: Result := cCommand_SelectAll;
    mcDupLine: Result := cCommand_TextDuplicateLine;
    mcDelLine: Result := cCommand_TextDeleteLine;
    mcMoveUp: Result := cCommand_MoveSelectionUp;
    mcMoveDown: Result := cCommand_MoveSelectionDown;
    mcIndent: Result := cCommand_TextIndent;
    mcUnindent: Result := cCommand_TextUnindent;
    mcUpper: Result := cCommand_TextCaseUpper;
    mcLower: Result := cCommand_TextCaseLower;
    mcTitle: Result := cCommand_TextCaseTitle;
    mcSortAsc: Result := cCommand_Sort_Asc;
    mcSortDesc: Result := cCommand_Sort_Desc;
    mcSortAscNoCase: Result := cCommand_Sort_AscNoCase;
    mcSortDescNoCase: Result := cCommand_Sort_DescNoCase;
    mcTrimTrailing: Result := cCommand_TextTrimSpacesRight;
    mcRemoveDup: Result := cCommand_DeleteAdjacentDups;
    mcZoomIn: Result := cCommand_ZoomIn;
    mcZoomOut: Result := cCommand_ZoomOut;
    mcZoomReset: Result := cCommand_ZoomReset;
  else
    Result := 0;
  end;
end;

procedure RemoveEditorCommand(AMap: TATKeymap; ACommand: Integer);
var
  Index: Integer;
begin
  if (AMap = nil) or (ACommand <= 0) then Exit;
  Index := AMap.IndexOf(ACommand);
  while Index >= 0 do
  begin
    AMap.Delete(Index);
    Index := AMap.IndexOf(ACommand);
  end;
end;

function CreateManagedEditorKeymap: TATKeymap;
var
  Cmd: TMenuCmd;
begin
  Result := TATKeymap.Create;
  try
    Result.Assign(KeymapFull);
    for Cmd := Low(TMenuCmd) to High(TMenuCmd) do
      RemoveEditorCommand(Result, EditorCommandForMenuCommand(Cmd));
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function EditorKeyConflictName(AMap: TATKeymap;
  AShortCut: TShortCut): string;
var
  i: Integer;
  Item: TATKeymapItem;
begin
  Result := '';
  if (AMap = nil) or (AShortCut = 0) then Exit;
  for i := 0 to AMap.Count - 1 do
  begin
    Item := AMap.Items[i];
    if (Item.Keys1.Data[0] = AShortCut) and (Item.Keys1.Data[1] = 0) then
      Exit(Item.Name);
    if (Item.Keys2.Data[0] = AShortCut) and (Item.Keys2.Data[1] = 0) then
      Exit(Item.Name);
  end;
end;

end.
