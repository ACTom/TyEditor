unit usettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uutils;

type
  TAppSettings = class
  private
    FRecent: TStringList;
    FEncodingHistory: TStringList;
    FFindHistory: TStringList;
    FLanguageIndent: TStringList;
    FEncodingByFile: TStringList;
    FShortcuts: TStringList;
  public
    FontName: string;
    FontSize: Integer;
    FontLigatures: Boolean;
    TabSize: Integer;
    TabSpaces: Boolean;
    WordWrap: Boolean;
    ShowNumbers: Boolean;
    NumbersStyle: string;
    ShowRuler: Boolean;
    ShowBookmarkMargin: Boolean;
    ShowCurLine: Boolean;
    ShowIndentGuides: Boolean;
    AutoIndent: Boolean;
    AutoPair: Boolean;
    SmoothScroll: Boolean;
    CaretBlink: Boolean;
    ColorScheme: string;
    CustomColorSchemeFile: string;
    DefaultEncoding: string;
    DefaultEol: string;
    TrimTrailingSpaces: Boolean;
    ForceFinalEol: Boolean;
    FindCase: Boolean;
    FindWords: Boolean;
    FindRegex: Boolean;
    FindWrap: Boolean;
    FindFilesCase: Boolean;
    FindFilesWords: Boolean;
    FindFilesRegex: Boolean;
    RecentMax: Integer;
    ShowWhitespace: Boolean;
    ShowFolding: Boolean;
    ShowMinimap: Boolean;
    ShowMicromap: Boolean;
    RestoreSession: Boolean;
    AutoSnapshotSec: Integer;
    BackupDir: string;
    BackupKeep: Integer;
    PrintFontName: string;
    PrintFontSize: Integer;
    PrintSelectionOnly: Boolean;
    PrintSyntaxHighlighting: Boolean;
    PrintLineNumbers: Boolean;
    PrintWrapLines: Boolean;
    PrintHeader: Boolean;
    PrintFooter: Boolean;
    PrintMarginLeft: Integer;
    PrintMarginTop: Integer;
    PrintMarginRight: Integer;
    PrintMarginBottom: Integer;
    Language: string;
    MacroPath: string;
    SingleInstance: Boolean;
    AlwaysOnTop: Boolean;
    Theme: string;
    DarkMode: Boolean;
    LastDir: string;
    WindowLeft: Integer;
    WindowTop: Integer;
    WindowWidth: Integer;
    WindowHeight: Integer;
    WindowMaximized: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Load;
    procedure Save;
    procedure AddRecent(const AFileName: string);
    procedure AddEncoding(const AName: string);
    function EncodingForFile(const AFileName: string): string;
    procedure SetEncodingForFile(const AFileName, AEncoding: string);
    property Recent: TStringList read FRecent;
    property EncodingHistory: TStringList read FEncodingHistory;
    property FindHistory: TStringList read FFindHistory;
    property LanguageIndent: TStringList read FLanguageIndent;
    property EncodingByFile: TStringList read FEncodingByFile;
    property Shortcuts: TStringList read FShortcuts;
  end;

implementation

constructor TAppSettings.Create;
begin
  inherited Create;
  FRecent := TStringList.Create;
  FEncodingHistory := TStringList.Create;
  FFindHistory := TStringList.Create;
  FLanguageIndent := TStringList.Create;
  FEncodingByFile := TStringList.Create;
  FShortcuts := TStringList.Create;
  FontName := 'DejaVu Sans Mono';
  FontSize := 11;
  FontLigatures := False;
  TabSize := 4;
  TabSpaces := False;
  WordWrap := False;
  ShowNumbers := True;
  NumbersStyle := 'all';
  ShowRuler := False;
  ShowBookmarkMargin := False;
  ShowCurLine := False;
  ShowIndentGuides := False;
  AutoIndent := False;
  AutoPair := False;
  SmoothScroll := True;
  CaretBlink := True;
  ColorScheme := 'GitHub';
  CustomColorSchemeFile := '';
  DefaultEncoding := 'UTF-8';
  {$IFDEF WINDOWS}
  DefaultEol := 'CRLF';
  {$ELSE}
  DefaultEol := 'LF';
  {$ENDIF}
  TrimTrailingSpaces := False;
  ForceFinalEol := False;
  FindCase := False;
  FindWords := False;
  FindRegex := False;
  FindWrap := True;
  FindFilesCase := False;
  FindFilesWords := False;
  FindFilesRegex := False;
  RecentMax := 15;
  ShowWhitespace := False;
  ShowFolding := True;
  ShowMinimap := False;
  ShowMicromap := False;
  RestoreSession := True;
  AutoSnapshotSec := 30;
  BackupDir := '';
  BackupKeep := 20;
  PrintFontName := 'Courier New';
  PrintFontSize := 10;
  PrintSelectionOnly := False;
  PrintSyntaxHighlighting := True;
  PrintLineNumbers := True;
  PrintWrapLines := True;
  PrintHeader := False;
  PrintFooter := True;
  PrintMarginLeft := 15;
  PrintMarginTop := 15;
  PrintMarginRight := 15;
  PrintMarginBottom := 15;
  Language := 'auto';
  MacroPath := '';
  SingleInstance := True;
  AlwaysOnTop := False;
  Theme := 'default';
  DarkMode := False;
  LastDir := GetUserDir;
  WindowLeft := 100;
  WindowTop := 80;
  WindowWidth := 1100;
  WindowHeight := 760;
  WindowMaximized := False;
end;

destructor TAppSettings.Destroy;
begin
  FRecent.Free;
  FEncodingHistory.Free;
  FFindHistory.Free;
  FLanguageIndent.Free;
  FEncodingByFile.Free;
  FShortcuts.Free;
  inherited;
end;

procedure TAppSettings.Load;
var
  Data: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  V: TJSONData;
  O: TJSONObject;
  i: Integer;
  S: string;
begin
  if not ReadTextFileSafe(SettingsFileName, S) then Exit;
  try
    Data := GetJSON(S);
    try
      if not (Data is TJSONObject) then Exit;
      Obj := TJSONObject(Data);
      FontName := JsonStr(Obj, 'font_name', FontName);
      FontSize := JsonInt(Obj, 'font_size', FontSize);
      FontLigatures := JsonBool(Obj, 'font_ligatures', FontLigatures);
      TabSize := JsonInt(Obj, 'tab_size', TabSize);
      TabSpaces := JsonBool(Obj, 'tab_spaces', TabSpaces);
      WordWrap := JsonBool(Obj, 'word_wrap', WordWrap);
      ShowNumbers := JsonBool(Obj, 'show_numbers', ShowNumbers);
      NumbersStyle := JsonStr(Obj, 'numbers_style', NumbersStyle);
      FEncodingHistory.Clear;
      FFindHistory.Clear;
      FEncodingByFile.Clear;
      if Obj.Find('encoding_by_file') is TJSONObject then
      begin
        O := TJSONObject(Obj.Find('encoding_by_file'));
        for i := 0 to O.Count - 1 do
          FEncodingByFile.Values[O.Names[i]] := O.Items[i].AsString;
      end;
      FLanguageIndent.Clear;
      if Obj.Find('language_indent') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('language_indent'));
        for i := 0 to Arr.Count - 1 do
          if Arr.Items[i].JSONType = jtString then
            FLanguageIndent.Add(Arr.Items[i].AsString);
      end;
      if Obj.Find('find_history') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('find_history'));
        for i := 0 to Arr.Count - 1 do
          if Arr.Items[i].JSONType = jtString then
            FFindHistory.Add(Arr.Items[i].AsString);
      end;
      if Obj.Find('encoding_history') is TJSONArray then
      begin
        Arr := TJSONArray(Obj.Find('encoding_history'));
        for i := 0 to Arr.Count - 1 do
          if Arr.Items[i].JSONType = jtString then
            FEncodingHistory.Add(Arr.Items[i].AsString);
      end;
      ShowRuler := JsonBool(Obj, 'show_ruler', ShowRuler);
      ShowBookmarkMargin := JsonBool(Obj, 'show_bookmark_margin', ShowBookmarkMargin);
      ShowCurLine := JsonBool(Obj, 'show_cur_line', ShowCurLine);
      ShowIndentGuides := JsonBool(Obj, 'show_indent_guides', ShowIndentGuides);
      AutoIndent := JsonBool(Obj, 'auto_indent', AutoIndent);
      AutoPair := JsonBool(Obj, 'auto_pair', AutoPair);
      SmoothScroll := JsonBool(Obj, 'smooth_scroll', SmoothScroll);
      CaretBlink := JsonBool(Obj, 'caret_blink', CaretBlink);
      ColorScheme := JsonStr(Obj, 'color_scheme', ColorScheme);
      if SameText(ColorScheme, 'TyEditor') then
        ColorScheme := 'GitHub';
      FShortcuts.Clear;
      if Obj.Find('shortcuts') is TJSONObject then
      begin
        O := TJSONObject(Obj.Find('shortcuts'));
        for i := 0 to O.Count - 1 do
          FShortcuts.Values[O.Names[i]] := O.Items[i].AsString;
      end;
      CustomColorSchemeFile := JsonStr(Obj, 'custom_color_scheme', CustomColorSchemeFile);
      DefaultEncoding := JsonStr(Obj, 'default_encoding', DefaultEncoding);
      DefaultEol := JsonStr(Obj, 'default_eol', DefaultEol);
      TrimTrailingSpaces := JsonBool(Obj, 'trim_trailing_spaces', TrimTrailingSpaces);
      ForceFinalEol := JsonBool(Obj, 'force_final_eol', ForceFinalEol);
      FindCase := JsonBool(Obj, 'find_case', FindCase);
      FindWords := JsonBool(Obj, 'find_words', FindWords);
      FindRegex := JsonBool(Obj, 'find_regex', FindRegex);
      FindWrap := JsonBool(Obj, 'find_wrap', FindWrap);
      FindFilesCase := JsonBool(Obj, 'find_files_case', FindFilesCase);
      FindFilesWords := JsonBool(Obj, 'find_files_words', FindFilesWords);
      FindFilesRegex := JsonBool(Obj, 'find_files_regex', FindFilesRegex);
      RecentMax := JsonInt(Obj, 'recent_max', RecentMax);
      if RecentMax < 1 then RecentMax := 1;
      ShowWhitespace := JsonBool(Obj, 'show_whitespace', ShowWhitespace);
      ShowFolding := JsonBool(Obj, 'show_folding', ShowFolding);
      ShowMinimap := JsonBool(Obj, 'show_minimap', ShowMinimap);
      ShowMicromap := JsonBool(Obj, 'show_micromap', ShowMicromap);
      RestoreSession := JsonBool(Obj, 'restore_session', RestoreSession);
      AutoSnapshotSec := JsonInt(Obj, 'auto_snapshot_sec', AutoSnapshotSec);
      BackupDir := JsonStr(Obj, 'backup_dir', BackupDir);
      BackupKeep := JsonInt(Obj, 'backup_keep', BackupKeep);
      PrintFontName := JsonStr(Obj, 'print_font_name', PrintFontName);
      PrintFontSize := JsonInt(Obj, 'print_font_size', PrintFontSize);
      PrintSelectionOnly := JsonBool(Obj, 'print_selection_only', PrintSelectionOnly);
      PrintSyntaxHighlighting := JsonBool(Obj, 'print_syntax_highlighting', PrintSyntaxHighlighting);
      PrintLineNumbers := JsonBool(Obj, 'print_line_numbers', PrintLineNumbers);
      PrintWrapLines := JsonBool(Obj, 'print_wrap_lines', PrintWrapLines);
      PrintHeader := JsonBool(Obj, 'print_header', PrintHeader);
      PrintFooter := JsonBool(Obj, 'print_footer', PrintFooter);
      PrintMarginLeft := JsonInt(Obj, 'print_margin_left', PrintMarginLeft);
      PrintMarginTop := JsonInt(Obj, 'print_margin_top', PrintMarginTop);
      PrintMarginRight := JsonInt(Obj, 'print_margin_right', PrintMarginRight);
      PrintMarginBottom := JsonInt(Obj, 'print_margin_bottom', PrintMarginBottom);
      if BackupKeep < 1 then BackupKeep := 1;
      if AutoSnapshotSec < 5 then AutoSnapshotSec := 5;
      Language := JsonStr(Obj, 'language', Language);
      MacroPath := JsonStr(Obj, 'macro_path', MacroPath);
      SingleInstance := JsonBool(Obj, 'single_instance', SingleInstance);
      AlwaysOnTop := JsonBool(Obj, 'always_on_top', AlwaysOnTop);
      Theme := JsonStr(Obj, 'theme', Theme);
      DarkMode := JsonBool(Obj, 'dark_mode', DarkMode);
      LastDir := JsonStr(Obj, 'last_dir', LastDir);
      WindowLeft := JsonInt(Obj, 'window_left', WindowLeft);
      WindowTop := JsonInt(Obj, 'window_top', WindowTop);
      WindowWidth := JsonInt(Obj, 'window_width', WindowWidth);
      WindowHeight := JsonInt(Obj, 'window_height', WindowHeight);
      WindowMaximized := JsonBool(Obj, 'window_maximized', WindowMaximized);
      FRecent.Clear;
      V := Obj.Find('recent');
      if V is TJSONArray then
      begin
        Arr := TJSONArray(V);
        for i := 0 to Arr.Count - 1 do
          if Arr.Strings[i] <> '' then
            FRecent.Add(Arr.Strings[i]);
      end;
    finally
      Data.Free;
    end;
  except
    // a broken settings file must never block startup
  end;
end;

procedure TAppSettings.Save;
var
  Obj, Obj2: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('font_name', FontName);
    Obj.Add('font_size', FontSize);
    Obj.Add('font_ligatures', FontLigatures);
    Obj.Add('tab_size', TabSize);
    Obj.Add('tab_spaces', TabSpaces);
    Obj.Add('word_wrap', WordWrap);
    Obj.Add('show_numbers', ShowNumbers);
    Obj.Add('numbers_style', NumbersStyle);
    Arr := TJSONArray.Create;
    for i := 0 to FEncodingHistory.Count - 1 do Arr.Add(FEncodingHistory[i]);
    Obj.Add('encoding_history', Arr);
    Arr := TJSONArray.Create;
    for i := 0 to FFindHistory.Count - 1 do Arr.Add(FFindHistory[i]);
    Obj.Add('find_history', Arr);
    Arr := TJSONArray.Create;
    for i := 0 to FLanguageIndent.Count - 1 do Arr.Add(FLanguageIndent[i]);
    Obj.Add('language_indent', Arr);
    Obj2 := TJSONObject.Create;
    for i := 0 to FEncodingByFile.Count - 1 do
      Obj2.Add(FEncodingByFile.Names[i], FEncodingByFile.ValueFromIndex[i]);
    Obj.Add('encoding_by_file', Obj2);
    Obj.Add('show_ruler', ShowRuler);
    Obj.Add('show_bookmark_margin', ShowBookmarkMargin);
    Obj.Add('show_cur_line', ShowCurLine);
    Obj.Add('show_indent_guides', ShowIndentGuides);
    Obj.Add('auto_indent', AutoIndent);
    Obj.Add('auto_pair', AutoPair);
    Obj.Add('smooth_scroll', SmoothScroll);
    Obj.Add('caret_blink', CaretBlink);
    Obj.Add('color_scheme', ColorScheme);
    Obj.Add('custom_color_scheme', CustomColorSchemeFile);
    Obj.Add('default_encoding', DefaultEncoding);
    Obj.Add('default_eol', DefaultEol);
    Obj.Add('trim_trailing_spaces', TrimTrailingSpaces);
    Obj.Add('force_final_eol', ForceFinalEol);
    Obj.Add('find_case', FindCase);
    Obj.Add('find_words', FindWords);
    Obj.Add('find_regex', FindRegex);
    Obj.Add('find_wrap', FindWrap);
    Obj.Add('find_files_case', FindFilesCase);
    Obj.Add('find_files_words', FindFilesWords);
    Obj.Add('find_files_regex', FindFilesRegex);
    Obj.Add('recent_max', RecentMax);
    Obj.Add('show_whitespace', ShowWhitespace);
    Obj.Add('show_folding', ShowFolding);
    Obj.Add('show_minimap', ShowMinimap);
    Obj.Add('show_micromap', ShowMicromap);
    Obj.Add('restore_session', RestoreSession);
    Obj.Add('auto_snapshot_sec', AutoSnapshotSec);
    Obj.Add('backup_dir', BackupDir);
    Obj.Add('backup_keep', BackupKeep);
    Obj.Add('print_font_name', PrintFontName);
    Obj.Add('print_font_size', PrintFontSize);
    Obj.Add('print_selection_only', PrintSelectionOnly);
    Obj.Add('print_syntax_highlighting', PrintSyntaxHighlighting);
    Obj.Add('print_line_numbers', PrintLineNumbers);
    Obj.Add('print_wrap_lines', PrintWrapLines);
    Obj.Add('print_header', PrintHeader);
    Obj.Add('print_footer', PrintFooter);
    Obj.Add('print_margin_left', PrintMarginLeft);
    Obj.Add('print_margin_top', PrintMarginTop);
    Obj.Add('print_margin_right', PrintMarginRight);
    Obj.Add('print_margin_bottom', PrintMarginBottom);
    Obj.Add('language', Language);
    Obj.Add('macro_path', MacroPath);
    Obj.Add('single_instance', SingleInstance);
    Obj.Add('always_on_top', AlwaysOnTop);
    Obj.Add('theme', Theme);
    Obj.Add('dark_mode', DarkMode);
    Obj.Add('last_dir', LastDir);
    Obj.Add('window_left', WindowLeft);
    Obj.Add('window_top', WindowTop);
    Obj.Add('window_width', WindowWidth);
    Obj.Add('window_height', WindowHeight);
    Obj.Add('window_maximized', WindowMaximized);
    Obj2 := TJSONObject.Create;
    for i := 0 to FShortcuts.Count - 1 do
      Obj2.Add(FShortcuts.Names[i], FShortcuts.ValueFromIndex[i]);
    Obj.Add('shortcuts', Obj2);
    Arr := TJSONArray.Create;
    for i := 0 to FRecent.Count - 1 do
      Arr.Add(FRecent[i]);
    Obj.Add('recent', Arr);
    AtomicWriteString(SettingsFileName, Obj.FormatJSON);
  finally
    Obj.Free;
  end;
end;

function TAppSettings.EncodingForFile(const AFileName: string): string;
begin
  Result := FEncodingByFile.Values[AFileName];
end;

procedure TAppSettings.SetEncodingForFile(const AFileName, AEncoding: string);
begin
  if (AFileName = '') or (AEncoding = '') then Exit;
  FEncodingByFile.Values[AFileName] := AEncoding;
end;

procedure TAppSettings.AddEncoding(const AName: string);
var
  i: Integer;
begin
  if AName = '' then Exit;
  i := FEncodingHistory.IndexOf(AName);
  if i >= 0 then FEncodingHistory.Delete(i);
  FEncodingHistory.Insert(0, AName);
  while FEncodingHistory.Count > 10 do
    FEncodingHistory.Delete(FEncodingHistory.Count - 1);
end;

procedure TAppSettings.AddRecent(const AFileName: string);
var
  i: Integer;
begin
  if AFileName = '' then Exit;
  i := FRecent.IndexOf(AFileName);
  if i >= 0 then
    FRecent.Delete(i);
  FRecent.Insert(0, AFileName);
  while FRecent.Count > RecentMax do
    FRecent.Delete(FRecent.Count - 1);
end;

end.
