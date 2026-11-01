program testsyntax;
{$mode objfpc}{$H+}
uses
  Interfaces, SysUtils, ec_SyntAnal, ec_proc_lexer, usyntaxdefs;

function Check(ACond: Boolean; const AMessage: string): Boolean;
begin
  Result := ACond;
  if not Result then
    WriteLn('FAIL: ', AMessage);
end;

function FindRule(An: TecSyntAnalyzer; const AName: string): TecTokenRule;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to An.TokenRules.Count - 1 do
    if An.TokenRules[i].DisplayName = AName then
      Exit(An.TokenRules[i]);
end;

var
  Manager: TecSyntaxManager;
  An: TecSyntAnalyzer;
  Names: array[0..8] of string = (
    'Java', 'TypeScript', 'Rust', 'SQL', 'YAML', 'Dockerfile',
    'Makefile', 'LaTeX', 'Fish');
  Files: array[0..7] of string = (
    'Main.java', 'app.ts', 'main.rs', 'query.sql', 'config.yml',
    'Makefile', 'Dockerfile', 'CMakeLists.txt');
  i, j: Integer;
  BaseLib: string;
begin
  BaseLib := IncludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0)))) +
    '..' + PathDelim + 'data' + PathDelim + 'lexlib' + PathDelim + 'lib.lxl';
  Manager := TecSyntaxManager.Create(nil);
  try
    if not Check(FileExists(BaseLib), 'base lexer library missing') then
      Halt(1);
    Manager.LoadFromFile(BaseLib);
    RegisterExtendedLexers(Manager);
    if not Check(Manager.AnalyzerCount >= 58, 'expected at least 58 lexers') then
      Halt(1);
    for i := 0 to Manager.AnalyzerCount - 1 do
    begin
      An := Manager.Analyzers[i];
      for j := 0 to An.TokenRules.Count - 1 do
        if not Check(not An.TokenRules[j].IsInvalid,
          'invalid token rule in ' + An.LexerName + ': ' + An.TokenRules[j].DisplayName) then
          Halt(3);
    end;
    for i := Low(Names) to High(Names) do
    begin
      An := Manager.FindAnalyzer(Names[i]);
      if not Check(An <> nil, 'missing lexer ' + Names[i]) then Halt(2);
      if not Check(An.TokenRules.Count > 0, 'no token rules for ' + Names[i]) then
        Halt(3);
      for j := 0 to An.TokenRules.Count - 1 do
        if not Check(not An.TokenRules[j].IsInvalid,
          'invalid token rule in ' + Names[i] + ': ' + An.TokenRules[j].DisplayName) then
          Halt(3);
      if not Check(FindRule(An, 'Number') <> nil, 'no number rule in ' + Names[i]) then
        Halt(3);
    end;
    An := Manager.FindAnalyzer('LaTeX');
    if not Check(FindRule(An, 'LaTeX command').Match('\section', 1) > 0,
      'LaTeX command rule does not match: ' + string(FindRule(An, 'LaTeX command').Expression)) then Halt(5);
    An := Manager.FindAnalyzer('SQL');
    if not Check(FindRule(An, 'Line comment').Match('-- comment', 1) > 0,
      'SQL comment rule does not match') then Halt(5);
    An := Manager.FindAnalyzer('Dockerfile');
    if not Check(FindRule(An, 'Keywords').Match('FROM alpine', 1) > 0,
      'Dockerfile keyword rule does not match') then Halt(5);
    for i := Low(Files) to High(Files) do
    begin
      An := Lexer_FindForFilename(Manager, Files[i]);
      if not Check(An <> nil, 'no filename match for ' + Files[i]) then Halt(4);
    end;
  finally
    Manager.Free;
  end;

  WriteLn('RESULT ok');
end.
