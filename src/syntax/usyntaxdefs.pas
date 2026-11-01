unit usyntaxdefs;

{$mode objfpc}{$H+}

interface

uses
  ec_SyntAnal;

procedure RegisterExtendedLexers(AManager: TecSyntaxManager);

implementation

uses
  SysUtils, Classes, Graphics, ec_syntax_format;

type
  TSyntaxString = (ssDouble, ssSingle, ssBacktick, ssTripleDouble, ssTripleSingle);
  TSyntaxStrings = set of TSyntaxString;
  TSyntaxSpecial = (
    sxNone,
    sxAsciiDoc,
    sxCMake,
    sxDiff,
    sxDockerfile,
    sxElixir,
    sxErlang,
    sxFSharp,
    sxGraphQL,
    sxHaskell,
    sxHcl,
    sxJulia,
    sxLaTeX,
    sxMakefile,
    sxNix,
    sxObjC,
    sxPowerShell,
    sxR,
    sxRst,
    sxRuby,
    sxSql,
    sxToml,
    sxYaml
  );

  TSyntaxDef = record
    Name: string;
    Extensions: string;
    Keywords: string;
    Types: string;
    Constants: string;
    LineComment: string;
    BlockBegin: string;
    BlockEnd: string;
    Strings: TSyntaxStrings;
    Special: TSyntaxSpecial;
  end;

const
  SyntaxDefs: array[0..38] of TSyntaxDef = (
    (Name: 'Java';
     Extensions: 'java';
     Keywords: 'abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while var record sealed permits yield';
     Types: 'String Integer Boolean Object List Map Set Optional Stream';
     Constants: 'true false null';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle]; Special: sxNone),
    (Name: 'TypeScript';
     Extensions: 'ts mts cts';
     Keywords: 'abstract any as async await boolean break case catch class const constructor continue debugger declare default delete do else enum export extends false finally for from function get if implements import in infer instanceof interface is keyof let module namespace never new null of package private protected public readonly require return set static super switch symbol this throw true try type typeof undefined unique unknown var void while with yield';
     Types: 'number string boolean any unknown never void object Array Promise Record Readonly Partial Pick Omit';
     Constants: 'true false null undefined NaN Infinity';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle, ssBacktick]; Special: sxNone),
    (Name: 'JSX';
     Extensions: 'jsx';
     Keywords: 'as async await break case catch class const continue debugger default delete do else export extends finally for from function if import in instanceof let new of return static super switch this throw try typeof var void while with yield';
     Types: 'Array Boolean Date Error Function JSON Map Math Number Object Promise RegExp Set String Symbol';
     Constants: 'true false null undefined NaN Infinity';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle, ssBacktick]; Special: sxNone),
    (Name: 'TSX';
     Extensions: 'tsx';
     Keywords: 'abstract any as async await boolean break case catch class const constructor continue debugger declare default delete do else enum export extends false finally for from function get if implements import in infer instanceof interface is keyof let module namespace never new null of package private protected public readonly require return set static super switch symbol this throw true try type typeof undefined unique unknown var void while with yield';
     Types: 'number string boolean any unknown never void object Array Promise Record Readonly Partial Pick Omit';
     Constants: 'true false null undefined NaN Infinity';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle, ssBacktick]; Special: sxNone),
    (Name: 'Go';
     Extensions: 'go';
     Keywords: 'break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var';
     Types: 'bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr';
     Constants: 'true false iota nil';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssBacktick]; Special: sxNone),
    (Name: 'Rust';
     Extensions: 'rs';
     Keywords: 'as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while';
     Types: 'bool char f32 f64 i8 i16 i32 i64 i128 isize str u8 u16 u32 u64 u128 usize String Vec Option Result Box';
     Constants: 'true false None Some Ok Err';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble]; Special: sxNone),
    (Name: 'Kotlin';
     Extensions: 'kt kts';
     Keywords: 'as break class continue do else false for fun if in interface is null object package return super this throw true try typealias typeof val var when while by catch constructor delegate dynamic field file finally get import init param property receiver set setparam where actual abstract annotation companion const crossinline data enum expect external final infix inline inner internal lateinit noinline open operator out override private protected public reified sealed suspend tailrec vararg';
     Types: 'Any Boolean Byte Char Double Float Int Long Nothing Short String Unit Array List Map Set';
     Constants: 'true false null';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle, ssTripleDouble]; Special: sxNone),
    (Name: 'Swift';
     Extensions: 'swift';
     Keywords: 'associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private protocol public rethrows static struct subscript typealias var break case continue default defer do else fallthrough for guard if in repeat return switch where while as Any catch false is nil super self Self throw throws true try';
     Types: 'Int Double Float String Bool Character Array Dictionary Set Optional Result';
     Constants: 'true false nil';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble]; Special: sxNone),
    (Name: 'Objective-C';
     Extensions: 'm mm';
     Keywords: 'auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while interface implementation end protocol property synthesize dynamic class public private protected try catch finally throw selector encode autoreleasepool synchronized';
     Types: 'id NSObject NSString NSArray NSDictionary NSNumber BOOL CGFloat NSInteger NSUInteger';
     Constants: 'YES NO nil NULL';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble]; Special: sxObjC),
    (Name: 'Scala';
     Extensions: 'scala sc';
     Keywords: 'abstract case catch class def do else extends false final finally for forSome if implicit import lazy match new null object override package private protected return sealed super this throw trait try true type val var while with yield given enum export extension then';
     Types: 'Any AnyRef AnyVal Boolean Byte Char Double Float Int Long Nothing Null Short String Unit List Option Seq Map';
     Constants: 'true false null None Some';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle, ssTripleDouble]; Special: sxNone),
    (Name: 'Dart';
     Extensions: 'dart';
     Keywords: 'abstract as assert async await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for Function get hide if implements import in interface is late library mixin new null on operator part required rethrow return set show static super switch sync this throw true try typedef var void while with yield';
     Types: 'int double num String bool List Map Set Future Stream Object dynamic';
     Constants: 'true false null';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle, ssTripleDouble, ssTripleSingle]; Special: sxNone),
    (Name: 'Ruby';
     Extensions: 'rb rake gemspec';
     Keywords: 'BEGIN END alias and begin break case class def defined do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield';
     Types: 'Array Hash String Symbol Integer Float Range Proc';
     Constants: 'true false nil';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxRuby),
    (Name: 'Perl';
     Extensions: 'pl pm pod t';
     Keywords: 'my our local sub use no package require if elsif else unless while until for foreach do last next redo return state given when default die warn print printf';
     Types: 'ARRAY CODE HASH SCALAR';
     Constants: 'undef';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxNone),
    (Name: 'PowerShell';
     Extensions: 'ps1 psm1 psd1';
     Keywords: 'begin break catch class continue data do dynamicparam else elseif end exit filter finally for foreach from function if in parallel param process return switch throw trap try until using var while workflow';
     Types: 'int string bool array hashtable psobject';
     Constants: 'true false null';
     LineComment: '#'; BlockBegin: '<#'; BlockEnd: '#>';
     Strings: [ssDouble, ssSingle]; Special: sxPowerShell),
    (Name: 'R';
     Extensions: 'r';
     Keywords: 'if else repeat while function for in next break';
     Types: 'character numeric integer logical complex list data.frame factor matrix array';
     Constants: 'TRUE FALSE NULL Inf NaN NA NA_integer_ NA_real_ NA_character_';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxR),
    (Name: 'SQL';
     Extensions: 'sql';
     Keywords: 'select from where and or not insert into values update set delete create table alter drop index view join inner left right full outer on group by order having limit offset union all distinct as case when then else end begin commit rollback transaction';
     Types: 'int integer varchar char text date datetime timestamp boolean decimal numeric float double blob';
     Constants: 'null true false';
     LineComment: '--'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssSingle]; Special: sxSql),
    (Name: 'YAML';
     Extensions: 'yml yaml';
     Keywords: '';
     Types: '';
     Constants: 'true false null yes no on off';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxYaml),
    (Name: 'TOML';
     Extensions: 'toml';
     Keywords: '';
     Types: '';
     Constants: 'true false';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle, ssTripleDouble]; Special: sxToml),
    (Name: 'Dockerfile';
     Extensions: 'dockerfile /Dockerfile';
     Keywords: 'FROM RUN CMD LABEL EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR ARG ONBUILD STOPSIGNAL HEALTHCHECK SHELL';
     Types: '';
     Constants: 'true false';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxDockerfile),
    (Name: 'Makefile';
     Extensions: 'mk mak makefile /Makefile /makefile';
     Keywords: 'ifeq ifneq ifdef ifndef else endif include define endef export unexport override';
     Types: '';
     Constants: '';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxMakefile),
    (Name: 'CMake';
     Extensions: 'cmake /CMakeLists.txt';
     Keywords: 'if else elseif endif foreach endforeach while endwhile function endfunction macro endmacro set unset message project add_executable add_library target_link_libraries include find_package option configure_file install';
     Types: '';
     Constants: 'ON OFF TRUE FALSE';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxCMake),
    (Name: 'Diff';
     Extensions: 'diff patch';
     Keywords: '';
     Types: '';
     Constants: '';
     LineComment: ''; BlockBegin: ''; BlockEnd: '';
     Strings: []; Special: sxDiff),
    (Name: 'GraphQL';
     Extensions: 'graphql gql';
     Keywords: 'query mutation subscription fragment on type interface union enum input scalar schema extend directive';
     Types: 'Int Float String Boolean ID';
     Constants: 'true false null';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssTripleDouble]; Special: sxGraphQL),
    (Name: 'Protocol Buffers';
     Extensions: 'proto';
     Keywords: 'syntax package import option message enum service rpc returns repeated optional required oneof map reserved extend extensions group';
     Types: 'double float int32 int64 uint32 uint64 sint32 sint64 fixed32 fixed64 sfixed32 sfixed64 bool string bytes';
     Constants: 'true false';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble]; Special: sxNone),
    (Name: 'Terraform';
     Extensions: 'tf tfvars hcl';
     Keywords: 'resource data variable output module provider terraform locals dynamic for_each count depends_on lifecycle';
     Types: 'string number bool list map set object tuple any';
     Constants: 'true false null';
     LineComment: '#'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble]; Special: sxHcl),
    (Name: 'Nix';
     Extensions: 'nix';
     Keywords: 'let in with rec inherit if then else assert import builtins derivation';
     Types: 'string path bool int float list attrs';
     Constants: 'true false null';
     LineComment: '#'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle]; Special: sxNix),
    (Name: 'LaTeX';
     Extensions: 'tex sty cls lt';
     Keywords: '';
     Types: '';
     Constants: '';
     LineComment: '%'; BlockBegin: ''; BlockEnd: '';
     Strings: []; Special: sxLaTeX),
    (Name: 'reStructuredText';
     Extensions: 'rst rest';
     Keywords: '';
     Types: '';
     Constants: '';
     LineComment: ''; BlockBegin: ''; BlockEnd: '';
     Strings: []; Special: sxRst),
    (Name: 'AsciiDoc';
     Extensions: 'adoc asciidoc';
     Keywords: '';
     Types: '';
     Constants: '';
     LineComment: ''; BlockBegin: ''; BlockEnd: '';
     Strings: []; Special: sxAsciiDoc),
    (Name: 'Groovy';
     Extensions: 'groovy gvy gy gsh';
     Keywords: 'abstract as assert break case catch class const continue def default do else enum extends final finally for goto if implements import in instanceof interface native new package private protected public return static strictfp super switch synchronized this throw throws trait transient try var volatile while';
     Types: 'String Integer Boolean Object List Map Set BigDecimal';
     Constants: 'true false null';
     LineComment: '//'; BlockBegin: '/*'; BlockEnd: '*/';
     Strings: [ssDouble, ssSingle, ssTripleDouble, ssTripleSingle]; Special: sxNone),
    (Name: 'Julia';
     Extensions: 'jl';
     Keywords: 'baremodule begin break catch const continue do else elseif end export finally for function global if import in isa let local macro module quote return struct try using while';
     Types: 'Int Float64 Float32 Bool Char String Array Dict Tuple';
     Constants: 'true false nothing missing';
     LineComment: '#'; BlockBegin: '#='; BlockEnd: '=#';
     Strings: [ssDouble, ssTripleDouble]; Special: sxJulia),
    (Name: 'Haskell';
     Extensions: 'hs lhs';
     Keywords: 'case class data default deriving do else if import in infix infixl infixr instance let module newtype of then type where qualified as hiding';
     Types: 'Int Integer Float Double Char String Bool Maybe Either IO';
     Constants: 'True False Nothing';
     LineComment: '--'; BlockBegin: '{-'; BlockEnd: '-}';
     Strings: [ssDouble]; Special: sxHaskell),
    (Name: 'Clojure';
     Extensions: 'clj cljs cljc edn';
     Keywords: 'def defn defmacro defonce fn let letfn if if-let if-not do loop recur when when-not cond case try catch finally throw new set! quote var ns import require use';
     Types: 'String Long Double Boolean Keyword Symbol';
     Constants: 'true false nil';
     LineComment: ';'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble]; Special: sxNone),
    (Name: 'Elixir';
     Extensions: 'ex exs';
     Keywords: 'def defp defmodule defmacro defstruct defprotocol defimpl defdelegate defexception defguard defoverridable do end fn when case cond if unless with for try catch rescue after else receive raise import require use alias';
     Types: 'String Integer Float Boolean Atom List Map Tuple';
     Constants: 'true false nil';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssTripleDouble]; Special: sxElixir),
    (Name: 'Erlang';
     Extensions: 'erl hrl';
     Keywords: 'after begin case catch cond end fun if let of query receive try when and or xor not bnot div rem band bor bxor bsl bsr';
     Types: 'atom binary bitstring boolean byte char float function integer list map nil number pid port reference tuple';
     Constants: 'true false undefined';
     LineComment: '%'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxErlang),
    (Name: 'F#';
     Extensions: 'fs fsi fsx';
     Keywords: 'abstract and as assert base begin class default delegate do done downcast downto elif else end exception extern false finally for fun function global if in inherit inline interface internal lazy let match member module mutable namespace new null of open or override private public rec return sig static struct then to true try type upcast use val void when while with yield';
     Types: 'bool byte char decimal double float int int64 list option string unit';
     Constants: 'true false None Some';
     LineComment: '//'; BlockBegin: '(*'; BlockEnd: '*)';
     Strings: [ssDouble, ssTripleDouble]; Special: sxFSharp),
    (Name: 'Visual Basic .NET';
     Extensions: 'vbnet';
     Keywords: 'AddHandler AddressOf Alias And AndAlso As Boolean ByRef Byte ByVal Call Case Catch CBool CByte CChar CDate CDbl CDec Char CInt Class CLng CObj Const Continue CSByte CShort CSng CStr CType CUInt CULng CUShort Date Decimal Declare Default Delegate Dim DirectCast Do Double Each Else ElseIf End EndIf Enum Erase Error Event Exit False Finally For Friend Function Get GetType Global GoSub GoTo Handles If Implements Imports In Inherits Integer Interface Is IsNot Let Lib Like Long Loop Me Mod Module MustInherit MustOverride MyBase MyClass Namespace Narrowing New Next Not Nothing NotInheritable NotOverridable Object Of On Operator Option Optional Or OrElse Out Overloads Overridable Overrides ParamArray Partial Private Property Protected Public RaiseEvent ReadOnly ReDim REM RemoveHandler Resume Return SByte Select Set Shadows Shared Short Single Static Step Stop String Structure Sub SyncLock Then Throw To True Try TryCast TypeOf UInteger ULong UShort Using Variant Wend When While Widening With WithEvents WriteOnly Xor';
     Types: 'Boolean Byte Char Date Decimal Double Integer Long Object Short Single String';
     Constants: 'True False Nothing';
     LineComment: ''''; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble]; Special: sxNone),
    (Name: 'Zsh';
     Extensions: 'zsh';
     Keywords: 'if then else elif fi for while do done case esac function in select until repeat time coproc';
     Types: '';
     Constants: 'true false';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxNone),
    (Name: 'Fish';
     Extensions: 'fish';
     Keywords: 'if else end for while function switch case set and or not begin';
     Types: '';
     Constants: 'true false';
     LineComment: '#'; BlockBegin: ''; BlockEnd: '';
     Strings: [ssDouble, ssSingle]; Special: sxNone)
  );

function AddFormat(Analyzer: TecSyntAnalyzer; const AName: string;
  AKind: TecTokenKind): TecSyntaxFormat;
begin
  Result := Analyzer.Formats.Add;
  Result.DisplayName := AName;
  Result.TokenKind := AKind;
  Result.FormatType := ftColor;
  Result.BgColor := clNone;
end;

procedure AddRule(Analyzer: TecSyntAnalyzer; const AName, AStyle, AExpression: string);
var
  Rule: TecTokenRule;
begin
  if AExpression = '' then Exit;
  Rule := Analyzer.TokenRules.Add;
  Rule.DisplayName := AName;
  Rule.StyleName := AStyle;
  Rule.Expression := AExpression;
end;

function WordRule(const AWords: string): string;
var
  Parts: TStringList;
  i: Integer;
  S: string;
begin
  Result := '';
  if Trim(AWords) = '' then Exit;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ' ';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := AWords;
    S := '';
    for i := 0 to Parts.Count - 1 do
    begin
      if Parts[i] = '' then Continue;
      if S <> '' then S := S + '|';
      S := S + Parts[i];
    end;
    if S <> '' then
      Result := '\b(' + S + ')\b';
  finally
    Parts.Free;
  end;
end;

procedure AddStrings(Analyzer: TecSyntAnalyzer; AStrings: TSyntaxStrings);
const
  Quote = #39;
  Backtick = #96;
begin
  if ssDouble in AStrings then
    AddRule(Analyzer, 'String (double)', 'String', '"(\\"|\\\\|.)*?("|$)');
  if ssSingle in AStrings then
    AddRule(Analyzer, 'String (single)', 'String',
      Quote + '(\\' + Quote + '|\\\\|.)*?(' + Quote + '|$)');
  if ssBacktick in AStrings then
    AddRule(Analyzer, 'String (backtick)', 'String',
      Backtick + '(\\' + Backtick + '|\\\\|.)*?(' + Backtick + '|$)');
  if ssTripleDouble in AStrings then
    AddRule(Analyzer, 'String (triple double)', 'String', '(?s)""".*?"""');
  if ssTripleSingle in AStrings then
    AddRule(Analyzer, 'String (triple single)', 'String',
      '(?s)' + Quote + Quote + Quote + '.*?' + Quote + Quote + Quote);
end;

procedure AddSpecialRules(Analyzer: TecSyntAnalyzer; ASpecial: TSyntaxSpecial);
begin
  case ASpecial of
    sxObjC:
      AddRule(Analyzer, 'Objective-C directive', 'Preprocessor', '@\w+');
    sxRuby:
      begin
        AddRule(Analyzer, 'Ruby symbol', 'Constant', ':\w+');
        AddRule(Analyzer, 'Ruby instance variable', 'Attribute', '@\w+');
        AddRule(Analyzer, 'Ruby global variable', 'Constant', '\$\w+');
      end;
    sxPowerShell:
      begin
        AddRule(Analyzer, 'PowerShell variable', 'Constant', '\$[\w:]+');
        AddRule(Analyzer, 'PowerShell operator', 'Operator',
          '(?i)\b-(eq|ne|gt|ge|lt|le|like|notlike|match|notmatch|contains|notcontains|in|notin|replace|split|join|is|isnot|as|and|or|xor|not)\b');
      end;
    sxSql:
      AddRule(Analyzer, 'SQL parameter', 'Constant', '[:@]\w+');
    sxYaml:
      AddRule(Analyzer, 'YAML key', 'Attribute', '(?m)^\s*[A-Za-z0-9_.-]+\s*:');
    sxToml:
      begin
        AddRule(Analyzer, 'TOML table', 'Type', '(?m)^\s*\[[^\]]+\]');
        AddRule(Analyzer, 'TOML key', 'Attribute', '(?m)^\s*[A-Za-z0-9_.-]+\s*=');
      end;
    sxDockerfile:
      AddRule(Analyzer, 'Docker variable', 'Constant', '\$\{?[\w]+\}?');
    sxMakefile:
      begin
        AddRule(Analyzer, 'Make variable', 'Constant', '\$[({][^)}]*[)}]');
        AddRule(Analyzer, 'Make target', 'Function', '(?m)^[^\s:\#][^:=]*:');
      end;
    sxCMake:
      begin
        AddRule(Analyzer, 'CMake command', 'Function', '(?m)^\s*[A-Za-z_]\w*');
        AddRule(Analyzer, 'CMake variable', 'Constant', '\$\{[^}]+\}');
      end;
    sxDiff:
      begin
        AddRule(Analyzer, 'Diff file header', 'Preprocessor',
          '(?m)^(diff |Index: |--- |\+\+\+ |@@).*');
        AddRule(Analyzer, 'Diff added', 'Diff Added String', '(?m)^\+.*');
        AddRule(Analyzer, 'Diff removed', 'Diff Removed Comment', '(?m)^-.*');
      end;
    sxGraphQL:
      begin
        AddRule(Analyzer, 'GraphQL directive', 'Attribute', '@\w+');
        AddRule(Analyzer, 'GraphQL variable', 'Constant', '\$[A-Za-z_]\w*');
      end;
    sxHcl:
      AddRule(Analyzer, 'HCL interpolation', 'Constant', '\$\{[^}]*\}');
    sxNix:
      AddRule(Analyzer, 'Nix interpolation', 'Constant', '\$\{[^}]*\}');
    sxJulia:
      AddRule(Analyzer, 'Julia macro', 'Attribute', '@\w+');
    sxLaTeX:
      begin
        AddRule(Analyzer, 'LaTeX command', 'Keyword', '\\[A-Za-z@]+\*?');
        AddRule(Analyzer, 'LaTeX math', 'String', '(?s)\\\[.*?\\\]|\$[^$]*\$');
      end;
    sxRst:
      begin
        AddRule(Analyzer, 'reST role', 'Function', ':[a-zA-Z-]+:`[^`]+`');
        AddRule(Analyzer, 'reST directive', 'Keyword', '(?m)^\.\.\s+\w+::');
        AddRule(Analyzer, 'reST heading', 'Type', '(?m)^[=\-~^"\#*]{3,}\s*$');
      end;
    sxAsciiDoc:
      begin
        AddRule(Analyzer, 'AsciiDoc attribute', 'Attribute', '(?m)^:[\w-]+:');
        AddRule(Analyzer, 'AsciiDoc heading', 'Type', '(?m)^={1,6}\s.*$');
        AddRule(Analyzer, 'AsciiDoc comment', 'Comment', '(?m)^//.*');
      end;
    sxElixir:
      begin
        AddRule(Analyzer, 'Elixir atom', 'Constant', ':\w+');
        AddRule(Analyzer, 'Elixir module', 'Type', '\b[A-Z]\w*\b');
      end;
    sxErlang:
      AddRule(Analyzer, 'Erlang atom', 'Constant', ':[a-z]\w*');
    sxFSharp:
      AddRule(Analyzer, 'F# quotation', 'String', '<@.*?@>');
    sxHaskell:
      AddRule(Analyzer, 'Haskell type', 'Type', '\b[A-Z]\w*\b');
    sxR:
      AddRule(Analyzer, 'R assignment', 'Operator', '<-|->');
  end;
end;

procedure AddLanguage(AManager: TecSyntaxManager; const ADef: TSyntaxDef);
var
  Analyzer: TecSyntAnalyzer;
  Keywords, Types, Constants, LineComment, BlockBegin, BlockEnd: string;
begin
  if AManager.FindAnalyzer(ADef.Name) <> nil then Exit;

  Analyzer := AManager.AddAnalyzer;
  Analyzer.LexerName := ADef.Name;
  Analyzer.Extentions := LowerCase(ADef.Extensions);
  LineComment := ADef.LineComment;
  BlockBegin := ADef.BlockBegin;
  BlockEnd := ADef.BlockEnd;
  Analyzer.LineComment := LineComment;
  Analyzer.CommentRangeBegin := BlockBegin;
  Analyzer.CommentRangeEnd := BlockEnd;
  Analyzer.CommentFullLinesBegin := BlockBegin;
  Analyzer.CommentFullLinesEnd := BlockEnd;
  Analyzer.StylesOfComments := 'Comment,Diff Removed Comment';
  Analyzer.StylesOfStrings := 'String,Diff Added String';

  AddFormat(Analyzer, 'Default', etkOther);
  AddFormat(Analyzer, 'Keyword', etkOther);
  AddFormat(Analyzer, 'Type', etkOther);
  AddFormat(Analyzer, 'Function', etkOther);
  AddFormat(Analyzer, 'Constant', etkOther);
  AddFormat(Analyzer, 'Number', etkOther);
  AddFormat(Analyzer, 'String', etkString);
  AddFormat(Analyzer, 'Comment', etkComment);
  AddFormat(Analyzer, 'Preprocessor', etkOther);
  AddFormat(Analyzer, 'Attribute', etkOther);
  AddFormat(Analyzer, 'Operator', etkOther);
  AddFormat(Analyzer, 'Tag', etkOther);
  AddFormat(Analyzer, 'Link', etkOther);
  AddFormat(Analyzer, 'Diff Added String', etkString);
  AddFormat(Analyzer, 'Diff Removed Comment', etkComment);

  AddStrings(Analyzer, ADef.Strings);

  AddRule(Analyzer, 'Number', 'Number',
    '\b(0x[\da-f]+|\d+(\.\d+)?([eE][+-]?\d+)?)\b');
  if (BlockBegin <> '') and (BlockEnd <> '') then
  begin
    if (BlockBegin = '/*') and (BlockEnd = '*/') then
      AddRule(Analyzer, 'Block comment', 'Comment', '(?s)/\*.*?(\*/|\Z)')
    else if (BlockBegin = '<#') and (BlockEnd = '#>') then
      AddRule(Analyzer, 'Block comment', 'Comment', '(?s)<\#.*?(\#>|\Z)')
    else if (BlockBegin = '#=') and (BlockEnd = '=#') then
      AddRule(Analyzer, 'Block comment', 'Comment', '(?s)\#=.*?(=\#|\Z)')
    else if (BlockBegin = '(*') and (BlockEnd = '*)') then
      AddRule(Analyzer, 'Block comment', 'Comment', '(?s)\(\*.*?(\*\)|\Z)')
    else if (BlockBegin = '{-') and (BlockEnd = '-}') then
      AddRule(Analyzer, 'Block comment', 'Comment', '(?s)\{-.*?(-\}|\Z)')
    else if (BlockBegin = '<!--') and (BlockEnd = '-->') then
      AddRule(Analyzer, 'Block comment', 'Comment', '(?s)<!--.*?-->');
  end;
  if (LineComment <> '') and (LineComment <> '''') then
  begin
    if LineComment = '//' then
      AddRule(Analyzer, 'Line comment', 'Comment', '(?m)//.*')
    else if LineComment = '--' then
      AddRule(Analyzer, 'Line comment', 'Comment', '(?m)--.*')
    else if LineComment = ';' then
      AddRule(Analyzer, 'Line comment', 'Comment', '(?m);.*')
    else if LineComment = '%' then
      AddRule(Analyzer, 'Line comment', 'Comment', '(?m)%.*')
    else if LineComment = '''' then
      AddRule(Analyzer, 'Line comment', 'Comment', '(?m)''.*')
    else
      AddRule(Analyzer, 'Line comment', 'Comment', '(?m)' +
        StringReplace(LineComment, '#', '\#', [rfReplaceAll]) + '.*');
  end;

  Keywords := WordRule(ADef.Keywords);
  Types := WordRule(ADef.Types);
  Constants := WordRule(ADef.Constants);
  if Keywords <> '' then AddRule(Analyzer, 'Keywords', 'Keyword', Keywords);
  if Types <> '' then AddRule(Analyzer, 'Types', 'Type', Types);
  if Constants <> '' then AddRule(Analyzer, 'Constants', 'Constant', Constants);

  AddRule(Analyzer, 'Operators', 'Operator',
    '[\{\}\(\)\[\],;:+\-*/%=<>!&|^~?]+');
  AddSpecialRules(Analyzer, ADef.Special);
end;

procedure RegisterExtendedLexers(AManager: TecSyntaxManager);
var
  i: Integer;
begin
  if AManager = nil then Exit;
  for i := Low(SyntaxDefs) to High(SyntaxDefs) do
    AddLanguage(AManager, SyntaxDefs[i]);
end;

end.
