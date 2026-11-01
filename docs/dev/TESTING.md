# Testing and acceptance

## Automated tests

Configure the build environment first (`scripts/env.local.sh` or exported
variables), then:

```bash
./scripts/dev/run-tests.sh
```

The runner builds and executes:

| Test | What it covers |
| --- | --- |
| `tests/testencoding` | Encoding detection and round trips |
| `tests/testfindasync` | Asynchronous find-in-files cancellation and filters |
| `tests/testplugins` | Package/manifest parsing, locales, process runtime, timeouts, malformed responses, PascalScript, install/uninstall, unsafe archives and user override |
| `tests/testtools` | External-tool storage round trip, placeholder expansion, stdin/stdout execution, large input, exit codes, timeout, cancellation and invalid configuration |
| `tests/testsyntax` | Extended lexer registration, rule validity and filename matching |
| `tests/testfindfiles` | Find-in-files engine with an explicit directory, mask and query |

`testfindfiles` is not a unit assertion suite; it prints a match count and
requires arguments. The runner invokes it as:

```bash
./tests/testfindfiles "$ROOT" '*.pas' TyEditor
```

Static checks:

```bash
python3 scripts/dev/check-translations.py
python3 scripts/dev/version.py --check TyEditor.lpi src/version.inc
./scripts/dev/check-hardcoded-paths.sh
```

The translation check expects `languages/tyeditor.zh_CN.json` to cover every
`Tr()` string found in the application sources. The hardcoded-path check rejects
machine-specific paths in build/package scripts.

## Manual acceptance

The following checklist is for Linux x86_64/Qt6 unless a platform-specific item
says otherwise.

### 1. Build and launch

1. `./scripts/build.sh` finishes without errors and produces
   `dist/linux-x86_64/TyEditor`.
2. Launch `dist/linux-x86_64/TyEditor`: a `TTyForm` window, title-bar menu, one
   Untitled tab and the status bar appear.
3. Type text: the title gets `*`, and line/column/line count update.
4. Double-click empty tab-bar space: a new Untitled tab opens.
5. Run the binary with two file arguments: both files open in the first
   instance (or new tabs).

### 2. Tabs and session

1. Create two tabs with unsaved text, then exit from the window close button.
   There should be no blocking save prompt.
2. Restart: both tabs, text, active tab, caret, selection and scroll position
   return.
3. Close one modified tab: Save/Discard/Cancel appears; Cancel keeps it.
4. Pin a tab and use Close Others/Close All: the pinned tab is skipped.
5. Reopen a closed tab with `Ctrl+Shift+T`.
6. Check `session.json` and `backups/` in the configuration directory.
7. Kill the process while running; restart and verify the crash-recovery prompt
   and snapshot restore.

### 3. Encoding and EOL

1. Open UTF-8 and UTF-8-with-BOM files; status bar encoding is correct.
2. Open UTF-16 LE/BE with BOM, GBK, Big5, Shift-JIS and EUC-KR files.
3. Reload a legacy file with the correct encoding from the status bar; text is
   readable and saving preserves the chosen encoding.
4. Convert a buffer to UTF-8 and save; verify with an external tool.
5. Change CRLF to LF/CR and inspect the saved file; open a mixed-EOL file and
   verify the status shows Mixed.

### 4. Find and replace

1. `Ctrl+F` pre-fills selected text or the current word.
2. Exercise case, whole-word, regex, wrap and selection-only options.
3. Find All lists matches; double-clicking a result jumps to it.
4. `Ctrl+H` replaces one or all matches; undo still works.
5. `Ctrl+Shift+F` searches a directory with a mask and subdirectories.
6. During a large search, the UI stays responsive; Stop prevents further
   results; results export to text/JSON.
7. `Ctrl+Shift+H` asks for confirmation before replacing in files and preserves
   per-file encoding/EOL.

### 5. Editing, bookmarks and macros

1. Test line duplicate/delete/move, indent/unindent, comment toggle, case
   changes, sort, deduplicate, trim, join/split and multi-caret.
2. Toggle comment in Pascal, SQL, PowerShell, LaTeX and YAML; verify the prefix
   matches the lexer.
3. Add/remove bookmarks, jump next/previous, use the bookmark list and bookmark
   groups; restart and verify persistence.
4. Record a macro, play it once and N times, save/load JSON, and play a bound
   macro with `Ctrl+F9`.
5. Go to matching bracket and go to line.

### 6. Syntax highlighting

1. Open files for Java, TypeScript, TSX, Go, Rust, Kotlin, Swift, Objective-C,
   Scala, Dart, Ruby, Perl, PowerShell, R, SQL, YAML, TOML, Dockerfile,
   Makefile, CMake, Diff/Patch, GraphQL, Protobuf, Terraform, Nix, LaTeX, RST,
   AsciiDoc, Groovy, Julia, Haskell, Clojure, Elixir, Erlang, F#, VB.NET, Zsh
   and Fish.
2. Confirm the status bar language and filename-based selection.
3. Check keywords, types, constants, strings, comments, numbers and operators.
4. Switch language manually and disable highlighting; verify Plain text.
5. Open `Makefile`, `Dockerfile` and `CMakeLists.txt` by full filename.
6. Verify unknown extensions use Plain text and do not freeze the editor.

### 7. View and appearance

1. Toggle word wrap, whitespace, line numbers, folding, ruler, bookmark margin,
   minimap and micromap.
2. `F8` opens the read-only document map; scrolling it does not edit or change
   the primary buffer; closing it leaves the document intact.
3. Switch all seven editor color schemes and both light/dark palettes; syntax
   colors and selection/current-line colors update without restart.
4. Switch TyControls interface themes; main window and Find/Replace dialogs
   update.
5. Test zoom, full screen, always on top and tab pinning.

### 8. Plugins

Prerequisite: `python3` is available for the bundled process samples. The
bundled samples declare Linux only, so on Windows and macOS they appear as
disabled with a platform reason. The PascalScript package must be installed in
Lazarus; the fixture uses no external interpreter.

1. Open **Plugins**: Base64 Tools, Text Tools, Caesar Cipher, JSON Formatter
   and External Formatter are listed. Missing optional dependencies are reported
   when the command runs.
2. Select text and run **Base64 Encode**; selection is replaced. Run Decode on
   the result and verify the original text returns.
3. Run **Text Tools > Trim Trailing Spaces** on a document; line endings are
   preserved. Run **Caesar Cipher > Encrypt** then **Decrypt** on a selection and
   verify the original text returns.
4. Run **JSON Formatter > Format JSON** and change the indentation/sort options;
   verify the option dialog and localized labels.
5. Install `dist/plugins/sample.base64-1.0.0.typlugin` through **Manage
   Plugins...**; verify user-override behavior, disable/enable, reload and
   uninstall. Confirm the security prompt for user plugins.
6. Verify a PascalScript package runs, reports a localized message and can be
   cancelled from the progress dialog.
7. Break a manifest or remove its `command`; **Plugin Errors** reports it and
   the rest of the plugin menu still works.
8. Set a small `timeout_ms` and a blocking plugin; verify it is terminated and
   an error dialog appears. Verify the UI remains responsive during execution.
9. Verify unknown response actions do not crash the editor and `message`/`log`
   actions behave as documented. Verify zh_CN fallback for a package with only
   `en.json`.

### 9. External tools

1. Open **Tools**: it lists **Manage Tools...** and **Reload Tools**, plus
   **No tools configured** when the list is empty.
2. Create a tool with command `sort`, input **Selection**, output **Replace
   selection**. Select several lines, run it and verify they are sorted; run it
   with no selection and verify the explanatory error.
3. Create a tool with command `echo`, arguments `${file}`, `${line}`, `${col}`,
   `${encoding}` and `${eol}`, input **None**, output **Show in a window**.
   Verify the values, that the window is read-only, and that **Copy** works.
4. Create a tool with command `cat`, argument `${inputfile}`, input **Document**
   and output **Show in a window**; verify the document text appears.
5. Create a tool with command `sleep`, argument `5`, timeout 1 second: verify it
   is terminated and an error dialog appears. Repeat and press **Cancel**.
6. Create a tool with command `false`: verify the exit code and standard error
   are reported. Disable a tool and confirm it disappears from the menu; reorder
   tools and confirm the menu order follows.
7. Break `tools.json` and use **Reload Tools**: **Tool Errors** lists the
   problem, valid tools still load. Verify **Save before** saves a modified
   document. Verify insert/replace outputs mark the document modified.

### 10. Localization

1. Remove the configuration directory and start with `LANG=zh_CN.UTF-8`: the UI
   is Chinese with `language: auto`.
2. Start with `LANG=en_US.UTF-8`: the UI is English.
3. Preferences lists `auto`, English and Simplified Chinese; choosing one and
   restarting applies it.
4. Add `languages/tyeditor.ja.json` with one translation; Preferences discovers
   the new language automatically.
5. Check that new plugin, tool and syntax strings are translated in the Chinese
   UI.

### 11. Platform and packaging

1. Build `win32` and `win64`; launch the `.exe` on Windows or Wine; check the
   icon, resources and opening a file from Explorer/command line.
2. Build the Windows installer with `ISCC`; install, verify the optional `.txt`
   association and that uninstalling keeps `%APPDATA%\TyEditor`.
3. Build `macos`; open the `.app`, verify `data/`, `languages/` and icons are
   inside `Contents/Resources/`; unsigned first launch may require Finder’s
   **Open**.
4. Build `linux-aarch64`; check `libQt6Pas.so*` is present and the binary starts
   with `$ORIGIN` RUNPATH on an aarch64 system.
5. Install the Linux desktop entry with `scripts/package/install-desktop.sh` and
   verify the menu entry and icon.
