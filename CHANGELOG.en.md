# Changelog

All notable changes to **TyEditor** are documented in this file. The project uses
3-part semantic versions (`MAJOR.MINOR.PATCH`).

> 中文版见 [CHANGELOG.md](CHANGELOG.md).

## [0.2.0] — 2026-11-06

The first feature release after 0.1.0: printing and print preview, a keyboard
shortcuts editor, plugins v1 and external tools, plus a redesigned Preferences
dialog. It also fixes Windows icons, Wayland modal windows and macOS icons.

### Added

- Printing, print preview and page setup: line numbers, word wrap, header and
  footer, page margins, print font, and printing the selection only.
- The print preview is split into a page area and a settings panel. Changing the
  font, size, line numbers, wrapping, header, footer, selection or margins
  re-flows the preview immediately; both the whole document and the selection
  are kept so they can be switched at any time. Pages are centred horizontally
  in the preview area, and the bottom toolbar spans only the preview area.
- Syntax-highlighted printing: colours and bold/italic styles are taken from the
  EControl lexer, and light syntax colours are adapted to a white background.
- Keyboard shortcuts editor: every command can be rebound, with conflict
  replacement, per-entry and global reset, and persistence. Plugin and external
  tool commands share the same command registry, and editor key bindings stay in
  sync with menu shortcuts.
- Plugins v1: `.typlugin` packages with a manifest, process and PascalScript
  runtimes, a JSON request/response boundary, install/enable/reload/uninstall,
  plugin options, translations and compatibility checks. Plugins run in the
  background and report failures without disturbing the editor.
- Four built-in PascalScript example plugins: Base64, Text Tools, Caesar and
  JSON Formatter. Reloading a plugin keeps the current interface language.
- External tools: commands configured in `tools.json`, placeholders such as
  `${file}` and `${line}`, background execution with cancellation and timeouts,
  the selection or document on standard input, and standard output handling.
  The tool manager and dynamic Tools menu are separate from plugins.
- Drag files onto the main window to open them: one file opens one tab, several
  files open several tabs, an already open file switches to its tab, and
  non-file content is ignored.
- 58 built-in syntax lexers: 19 EControl lexers and 39 TyEditor language
  definitions, selected automatically by file extension.
- On macOS, Preferences and Keyboard Shortcuts are placed in the application
  menu instead of a top-level Settings menu.

### Changed

- The version is now 0.2.0. macOS builds are no longer universal: `macos-x86_64`
  and `macos-aarch64` are built separately, with matching build targets.
- Preferences were redesigned with category navigation and scrollable pages, a
  Printing category and Restore Defaults. The default search page was removed;
  Find and Find in Files remember their own last options. The backup directory
  shows the actual default path. The TyEditor colour scheme was renamed to
  GitHub with migration of the old setting. Save Settings Now was removed, and
  Copy File Path moved to the File menu.
- The About dialog now shows only the name, version, a short description,
  copyright and licence. Third-party notices are still included in the release
  packages.
- The built-in example plugins moved from Python to PascalScript so they run on
  every supported platform again; the External Formatter example, which
  duplicated external tools, was removed.
- Windows icons and resources now use Lazarus's standard mechanism:
  `ResourceType=res` and `Icon=0` in the project, with `TyEditor.ico` in the
  project root. The hand-written `.rc` file and the `RESCOMP` requirement were
  removed.
- The macOS icon follows the Big Sur grid: 824/1024 content, rounded mask, a
  slight shadow and Retina ICNS types.
- The dependency documentation now requires Lazarus 4.8 or later.

### Fixed

- On Wayland (KDE Plasma / KWin), opening or closing a modal dialog made the
  main window disappear and reappear centred on screen. Wayland has no
  client-side always-on-top request, but LCL clears and restores `fsStayOnTop`
  around every modal window, and the Qt6 implementation does that with
  `setWindowFlags`, which destroys and recreates the native `xdg_toplevel`. The
  widgetset no longer uses `fsStayOnTop` on Wayland; X11, Windows and macOS
  behave as before.
- Windows i386 cross builds could not find the dependency source directories.
- Building with the Lazarus 4.8 release failed: the code now uses its FileUtil
  directory signatures, a duplicate unit entry in the project file was removed,
  and Linux tests use Qt6 consistently.
- After reloading a plugin, its name, description and command titles fell back
  to English.
- Built-in example plugins failed only when their process was started on
  Windows and similar platforms; their manifests now declare Linux only, and
  the plugin manager shows them as incompatible and disabled.
- The print preview's bottom toolbar spanned the whole window and its buttons
  moved around; the toolbar now covers only the preview area and the buttons are
  fixed at the bottom of the settings panel.

### Build

- Added a release packaging script that bundles the Linux, Windows and both
  macOS architectures and writes `dist/SHA256SUMS`.
- Added Windows x86_64, Linux aarch64 and separate macOS architecture build
  targets, with cross-compilation notes.

## [0.1.0] — 2026-10-18

The first public release: tabbed editing, session restore, encoding detection
and conversion, find and replace, find in files, macros, bookmarks, folding,
syntax highlighting, seven editor colour schemes and a Windows installer.
