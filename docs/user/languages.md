# Languages and syntax highlighting

TyEditor uses EControl for lexical highlighting. The base library
`data/lexlib/lib.lxl` supplies 19 lexers; TyEditor adds 39 declarative
definitions at runtime, for 58 built-in lexers in total.

Highlighting is purely lexical: comments, strings, numbers, keywords, types,
constants, operators and a few language-specific constructs. It does not parse
the language, resolve symbols or understand nested JSX/TSX expressions.

## Base EControl lexers

| Language | Common extensions |
| --- | --- |
| Assembly | `.asm` |
| Bash script | `.sh`, `.bash`, `.csh` |
| Batch files | `.bat`, `.cmd` |
| C | `.c`, `.h`, `.ch` |
| C# | `.cs` |
| C++ | `.cpp`, `.cxx`, `.hpp`, `.hxx`, `.cc`, `.inl` |
| CSS | `.css` |
| HTML | `.html`, `.htm`, `.xhtml`, `.asp`, `.aspx`, `.jsp` |
| Ini files | `.ini`, `.cfg`, `.inf`, … |
| JavaScript | `.js` |
| JSON | `.json` |
| Lua | `.lua` |
| Markdown | `.md`, `.markdown`, `.mkd` |
| Pascal | `.pas`, `.pp`, `.inc`, `.dpr`, `.lpr`, … |
| PHP | `.php` |
| Python | `.py`, `.pyw`, `.pyi`, … |
| Tcl | `.tcl`, `.tk`, `.tm` |
| VBScript | `.vb`, `.vbs` |
| XML | `.xml`, `.xsl`, `.xsd`, `.svg`, … |

## TyEditor language definitions

These are implemented in `src/syntax/usyntaxdefs.pas` and registered when the
language library loads.

| Language | Extensions / filenames | Notes |
| --- | --- | --- |
| Java | `.java` | keywords, types, strings, comments |
| TypeScript | `.ts`, `.mts`, `.cts` | keywords, types, template strings |
| JSX | `.jsx` | JavaScript-like keyword highlighting |
| TSX | `.tsx` | TypeScript-like keyword highlighting |
| Go | `.go` | keywords, types, backtick strings |
| Rust | `.rs` | keywords, types, block comments |
| Kotlin | `.kt`, `.kts` | keywords, types, triple-quoted strings |
| Swift | `.swift` | keywords, types |
| Objective-C | `.m`, `.mm` | `@directives`, C comments |
| Scala | `.scala`, `.sc` | keywords, types |
| Dart | `.dart` | keywords, types, triple-quoted strings |
| Ruby | `.rb`, `.rake`, `.gemspec` | symbols, instance/global variables |
| Perl | `.pl`, `.pm`, `.pod`, `.t` | keywords, comments |
| PowerShell | `.ps1`, `.psm1`, `.psd1` | variables, operators, block comments |
| R | `.r` | assignment operators, constants |
| SQL | `.sql` | keywords, types, `--` and `/* */` comments |
| YAML | `.yml`, `.yaml` | keys, comments, strings |
| TOML | `.toml` | tables, keys, comments |
| Dockerfile | `Dockerfile` | instructions, variables |
| Makefile | `.mk`, `.mak`, `makefile`, `Makefile` | variables, targets |
| CMake | `.cmake`, `CMakeLists.txt` | commands, variables |
| Diff | `.diff`, `.patch` | file headers, added/removed lines |
| GraphQL | `.graphql`, `.gql` | directives, variables |
| Protocol Buffers | `.proto` | keywords, types |
| Terraform | `.tf`, `.tfvars`, `.hcl` | interpolations |
| Nix | `.nix` | keywords, interpolations |
| LaTeX | `.tex`, `.sty`, `.cls`, `.lt` | commands, math |
| reStructuredText | `.rst`, `.rest` | roles, directives, headings |
| AsciiDoc | `.adoc`, `.asciidoc` | attributes, headings, comments |
| Groovy | `.groovy`, `.gvy`, `.gy`, `.gsh` | keywords, types |
| Julia | `.jl` | macros, block comments |
| Haskell | `.hs`, `.lhs` | types, block comments |
| Clojure | `.clj`, `.cljs`, `.cljc`, `.edn` | keywords |
| Elixir | `.ex`, `.exs` | atoms, module names |
| Erlang | `.erl`, `.hrl` | `%` comments, atoms |
| F# | `.fs`, `.fsi`, `.fsx` | keywords, block comments |
| Visual Basic .NET | `.vbnet` | `.vb` is kept by the older VBScript lexer |
| Zsh | `.zsh` | shell keywords |
| Fish | `.fish` | shell keywords |

Filename matching is case-insensitive on the usual platforms. Full filenames
such as `Dockerfile`, `Makefile` and `CMakeLists.txt` are matched as filenames,
not only by extension.

## Choosing a language

- The language is selected automatically from the filename when a file is
  opened.
- Use **Language** in the menu bar to switch or disable the language for the
  current tab.
- The chosen language is stored with the session; it does not rename the file or
  modify its contents.
- An unknown file has **Plain text** highlighting.
- The status bar shows the active language.

## Toggle comment

The comment prefix for **Edit > Toggle Comment** (`Ctrl+Q`) comes from the
active lexer’s line-comment setting. New definitions therefore work without a
hardcoded list; for example, SQL uses `--` and LaTeX uses `%`.

## Adding a language

Add a `TSyntaxDef` entry to `src/syntax/usyntaxdefs.pas` with the language name,
extensions, keyword lists, comment markers and string styles, then run the
syntax test:

```bash
./scripts/dev/run-tests.sh
```

The definition scanner adds formats and EControl token rules at startup. You do
not need to edit `data/lexlib/lib.lxl`. Keep rules lexical and cheap; complex
grammar or embedded-language parsing is outside this editor’s scope.
