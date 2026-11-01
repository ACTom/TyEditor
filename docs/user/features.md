# Using TyEditor

TyEditor is a text editor. It does not try to manage projects, build systems or
language servers. This guide covers the features you are likely to use every
day.

## Tabs and sessions

- Every tab keeps its own editor state: caret, selection, scroll position,
  encoding, line endings, language, bookmarks and folding.
- Create a new document with `Ctrl+N`, double-clicking empty space in the tab
  bar, or **File > New**.
- Tabs can be pinned, reordered, closed individually, or closed with
  **Close Others** / **Close All**. Pinned tabs are skipped by bulk close.
- The last closed tab can be reopened with `Ctrl+Shift+T`.
- Closing the last tab exits TyEditor. Closing an individual tab still asks
  whether to save, discard or cancel.
- On exit, TyEditor does not block on unsaved buffers. It writes backups and
  restores the session on the next launch. If the previous process did not exit
  cleanly, a crash-recovery prompt offers the last snapshot.
- Session data, backups and settings live in the configuration directory
  (`~/.config/TyEditor` on Linux, `%APPDATA%\TyEditor` on Windows).

## Files and encodings

The status bar shows the current encoding and line-ending style. Click either
indicator to:

- Reload the file with another encoding.
- Convert the buffer to another encoding and save it.
- Change between CRLF, LF and CR.

TyEditor detects BOMs, UTF-8, UTF-16 and common multi-byte encodings. When an
ANSI or legacy encoding is detected with low confidence, reload it explicitly
from the status bar. The encoding is stored per tab and restored with the
session.

## Finding and replacing

- `Ctrl+F` opens Find; `Ctrl+H` opens Replace.
- Options include case sensitivity, whole words, regular expressions, wrap
  around and selection-only search.
- **Find All** lists matches; double-click a result to jump to it.
- `F3` / `Shift+F3` find the next or previous match.
- **Search > Find in Files** (`Ctrl+Shift+F`) scans a directory with a file
  mask, optional subdirectories and include/exclude directory filters. It runs
  asynchronously, reports progress, can be cancelled, and can export results.
- **Replace in Files** (`Ctrl+Shift+H`) asks for confirmation before modifying
  files and preserves each file’s encoding and line endings.

## Editing

Common commands include:

- Undo/redo, cut/copy/paste, delete and select all.
- Duplicate, delete, move up/down, indent/unindent and comment/uncomment.
- Change case, sort lines (ascending/descending, case-sensitive or not), remove
  duplicate lines, trim trailing spaces, join/split lines.
- Multi-caret editing with `Ctrl+Alt+Up/Down`; column selection; indent guides;
  bracket matching.
- `Ctrl+G` goes to a line; `F2` toggles a bookmark and `Ctrl+F2` /
  `Shift+Ctrl+F2` move between bookmarks. The bookmark list supports jump and
  delete, and bookmark groups keep their colors across restarts.

TyEditor intentionally uses text-editor caret semantics: the caret cannot move
past the end of a line, auto-indent and auto-pair are off by default, and
copy/cut with no selection does not copy the whole line. Those defaults can be
changed in Preferences.

## Macros and bookmarks

Macros record editor commands and text insertion. From the **Macro** menu you
can start/stop recording, play once, play N times, save/load a JSON macro and
open the macro manager. `Ctrl+F9` plays the macro bound to the current
document type.

Macros do not record mouse clicks, scrolling or external dialogs.

## View and layout

- **View > Word Wrap**, **Show Whitespace**, **Line Numbers**, **Folding**,
  **Ruler**, **Bookmark Margin**.
- **Minimap** and **Micromap** provide a compact overview of the document.
- `Ctrl+Mouse Wheel` zooms; `F11` toggles full screen; **Always on Top** keeps
  the window above other applications.
- `F8` opens the **read-only document map**. The map has its own scroll and
  caret position but never writes to the editor buffer. There is no editable
  split view.
- **View > Interface Theme** changes the TyControls window/dialog theme.
  **View > Dark Theme** switches the light/dark mode of the current interface
  theme.

The default layout follows a text-editor habit: line numbers are shown, while
ruler and bookmark margin are off. The folding margin appears only when a
syntax lexer is active.

## Color schemes

Editor colors are independent from the interface theme. Each built-in scheme
has a light and a dark palette, selected automatically by **Dark Theme**:

- GitHub
- One Dark
- Solarized
- Monokai
- Dracula
- Gruvbox
- High Contrast

Choose a scheme from **View > Editor Color Scheme**. You can also edit, import
and export a JSON scheme from the same menu; the selected scheme is stored in
`settings.json`.

The scheme controls the editor background, text, gutter, selection, current
line, caret, bookmarks and EControl token colors (comments, strings, numbers,
keywords, functions, types, tags, attributes and so on). Changes apply without
restarting.

## External tools

**Tools > Manage Tools...** configures commands that operate on the current
document without installing a plugin. A tool is a plain executable: arguments
are one per line and are never passed through a shell. Choose what is sent to
standard input (nothing, selection or document), where output goes (ignored,
shown in a window, inserted at the caret, or replacing the selection/document),
and whether the file is saved first.

Placeholders such as `${file}`, `${dir}`, `${line}`, `${col}`, `${lexer}` and
`${inputfile}` let commands use the current document and caret. Tools run in the
background with cancellation and a configurable timeout; failures show the exit
code and standard error.

See [External tools](tools.md) for the full option list and examples.

## Printing

**File > Print Preview** opens a dialog with the page on the left and live
options on the right: print font and size, line numbers, wrapping, header and
footer, selection-only mode, and margins. Changes rebuild the preview
immediately. Use **File > Print...** to send the same layout to a printer, or
**File > Page Setup...** for a compact margins/options dialog. If text is
selected, direct printing asks whether to print only the selection; in the
preview the **Print selection only** option is enabled whenever a selection
exists.

Page options are also available under **Settings > Preferences... > Printing**
and are stored in `settings.json`.

## Settings

Open **Settings > Preferences...** (`Ctrl+Alt+P`). The redesigned dialog uses a
scrollable category list:

- **General** — interface language and theme, dark mode, session restore,
  single-instance mode, always-on-top and the recent-file limit.
- **Appearance** — editor font family and size, font ligatures and color scheme.
- **Editor** — tab width, spaces for tabs, word wrap, whitespace, line numbers and
  number style, current line, indent guides, folding, ruler, bookmark margin,
  minimap/micromap, auto-indent, auto-pair, smooth scrolling and caret blinking.
- **Files** — default encoding and line endings, trim trailing spaces on save,
  ensure final newline, backup folder, retain count and automatic session-save
  interval.
- **Printing** — font family and size, line numbers, wrapping, header/footer,
  selection-only mode and page margins.

The backup folder shows the effective default (the configuration directory's
`backups/` folder) instead of an empty field. Choose **Default** to restore it.
Search dialogs no longer have their own Preferences page; each dialog remembers
its last-used case, whole-word, regex and wrap options.

Use **Settings > Keyboard Shortcuts...** to inspect and change menu shortcuts.
Defaults are restored with **Reset Selected** or **Reset All**; assigning a
shortcut that is already in use asks whether to replace the existing command.
On macOS, Preferences and Keyboard Shortcuts live in the application menu and
are not user-customizable.

Settings are JSON and are stored next to the session file. Automatic snapshots
also save settings, so there is no separate **Save Settings Now** command.

## Interface language

The default `"language": "auto"` follows the system locale: Chinese systems use
Simplified Chinese, other systems fall back to English. You can choose `en` or
`zh_CN` explicitly. The Preferences dialog scans `languages/tyeditor.*.json`, so
additional installed translations appear automatically.

## Single instance and file associations

TyEditor starts a second process for a file opened from a file manager or a
terminal command; the second process forwards the file to the running instance
and exits. The Windows installer can optionally associate `.txt` files with
TyEditor. Linux installation provides a desktop entry and icon.

Drag and drop is handled by LCL and opens dropped files as tabs, subject to the
platform widgetset.
