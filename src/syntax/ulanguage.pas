unit ulanguage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  ec_SyntAnal, ec_proc_lexer,
  ATSynEdit_Adapter_EControl, ucolorscheme;

type
  TLanguageManager = class
  private
    FManager: TecSyntaxManager;
    FLoaded: Boolean;
    FLibFile: string;
    function FindLibraryFile: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadLibrary;
    procedure ApplyPalette(const APalette: TEditorPalette);
    function LexerNames: TStringList;
    function FindByName(const AName: string): TecSyntAnalyzer;
    function FindByFileName(const AFileName: string): TecSyntAnalyzer;
    property Loaded: Boolean read FLoaded;
    property LibFile: string read FLibFile;
  end;

implementation

uses
  Forms, uutils, usyntaxdefs;

constructor TLanguageManager.Create;
begin
  inherited Create;
  FManager := TecSyntaxManager.Create(nil);
end;

destructor TLanguageManager.Destroy;
begin
  FManager.Free;
  inherited;
end;

function TLanguageManager.FindLibraryFile: string;
begin
  Result := FindResourcePath('data/lexlib/lib.lxl');
  if Result = '' then
    Result := FindResourcePath('lib.lxl');
end;

procedure TLanguageManager.LoadLibrary;
begin
  FLoaded := False;
  FLibFile := FindLibraryFile;
  if FLibFile <> '' then
  try
    FManager.LoadFromFile(FLibFile);
  except
    on E: Exception do
      FLoaded := False;
  end;
  { EControl's bundled library is intentionally small.  The declarative
    definitions below add the languages TyEditor exposes in its menu without
    depending on a second external lexer file. }
  try
    RegisterExtendedLexers(FManager);
  except
    on E: Exception do
      FLoaded := False;
  end;
  FLoaded := FManager.AnalyzerCount > 0;
end;

procedure TLanguageManager.ApplyPalette(const APalette: TEditorPalette);
var
  i: Integer;
begin
  if not FLoaded then Exit;
  for i := 0 to FManager.AnalyzerCount - 1 do
    ApplyPaletteToAnalyzer(FManager.Analyzers[i], APalette);
end;

function TLanguageManager.LexerNames: TStringList;
var
  i: Integer;
  An: TecSyntAnalyzer;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  if not FLoaded then Exit;
  for i := 0 to FManager.AnalyzerCount - 1 do
  begin
    An := FManager.Analyzers[i];
    if (An <> nil) and (not An.Deleted) and (An.LexerName <> '') then
      Result.AddObject(An.LexerName, An);
  end;
  Result.Sort;
end;

function TLanguageManager.FindByName(const AName: string): TecSyntAnalyzer;
begin
  if not FLoaded then Exit(nil);
  Result := FManager.FindAnalyzer(AName);
  if Result = nil then
  begin
    // CudaText names some lexers with a trailing " ^"; accept the plain name too.
    Result := FManager.FindAnalyzer(AName + ' ^');
  end;
end;

function TLanguageManager.FindByFileName(const AFileName: string): TecSyntAnalyzer;
begin
  if not FLoaded then Exit(nil);
  Result := Lexer_FindForFilename(FManager, AFileName);
end;

end.
