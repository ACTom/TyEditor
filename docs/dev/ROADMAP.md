# Roadmap

TyEditor is a text editor, not an IDE. The scope boundary is deliberate and
appears at the end of this page.

## Completed foundation

- Lazarus/LCL + TyControls shell, title-bar menu, multi-tab editing.
- Session save/restore with unsaved-buffer backups, crash recovery and
  configurable snapshots.
- Encoding and EOL detection/conversion, including UTF-8/16/32, ANSI, GBK,
  Big5, Shift-JIS and EUC-KR.
- Find/replace, asynchronous find/replace in files, results panel and export.
- Bookmarks, macros, line operations, multi-caret/column editing, bracket
  matching, read-only document map.
- Seven editor color schemes with light/dark palettes, TyControls interface
  themes, minimap/micromap and themed dialogs.
- Linux Qt6, Windows native Win32 and macOS Cocoa build paths; desktop entry,
  Windows installer and macOS app bundle.
- Apache-2.0 licensing, version generation from `TyEditor.lpi`, generic build
  scripts and hardcoded-path checks.

## Current extension work

- **Plugins v1** — installable `.typlugin` packages, process and PascalScript
  runtimes, package manager, options, per-plugin i18n, compatibility checks,
  background execution with timeout/cancellation, and user-over-plugin
  precedence. Bundled Base64, Text Tools, Caesar Cipher and JSON Formatter
  PascalScript examples; package/protocol documentation complete.
- **External tools** — user-configured commands in a separate Tools menu and
  manager, stored in `tools.json`, with placeholders, selection/document input,
  output application, background execution, cancellation and timeout.
- **Syntax expansion** — 39 new declarative EControl lexers covering common
  compiled, scripting, data/config and markup languages; extension lookup and
  language menus updated.
- **Documentation** — English landing README and `README.zh_CN.md`, user guides,
  architecture/plugin-protocol/developer docs.

## Next

1. Finish cross-platform release verification after the extension work:
   Linux, Windows (32/64 + installer), macOS and Linux aarch64.
2. Add a third syntax wave where useful: Zig, Nim, D, Solidity, Verilog/VHDL,
   GLSL, Fortran, Ada, COBOL, MATLAB and Vue/Svelte only if it can be done
   lexically without a parser.
3. Explore additional plugin runtimes (JavaScript, native libraries, named
   PascalScript entry points) behind the existing `runtime` field and
   request/response contract. Lua is not planned.
4. Add release automation and reproducible CI builds.
5. Improve accessibility and keyboard navigation.

## Not planned

These belong in an IDE or are outside the current product scope:

- Language server protocol, completion, diagnostics or refactoring.
- Integrated terminal, debugger or task runner.
- Project/workspace model.
- Git integration.
- Editable split view or multiple editable views of one buffer.
- Remote development or collaborative editing.

## Priorities

Keep the editor fast and predictable on large text files. Prefer lexical
highlighting and simple package plugins over language-aware infrastructure. Any
new extension point must preserve the text-editor scope above.
