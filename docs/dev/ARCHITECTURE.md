# Architecture

TyEditor is a native LCL application. The main window is a `TTyForm` with a
TyControls title bar, menu bar and page control. Each tab owns a `TATSynEdit`
instance and an EControl adapter.

## Source layout

| Path | Responsibility |
| --- | --- |
| `TyEditor.lpr` | Program entry point; creates `TMainForm` |
| `src/core/` | Settings, session, encoding, macros, commands, color schemes, editor tab |
| `src/ui/` | Main window, menus, dialogs, results, split view, status view |
| `src/syntax/` | EControl library loading and TyEditor language definitions |
| `src/plugins/` | Plugin package model, manifests, discovery, runtimes and manager |
| `src/platform/` | Platform-specific single-instance and window helpers |
| `data/` | Runtime icons, lexer library and bundled plugins |
| `languages/` | Application and TyControls translations |
| `packaging/` | Installer, desktop entry and macOS bundle assets |
| `scripts/` | Build, packaging, development and test scripts |
| `tests/` | Standalone FPC test projects |

Build output goes to `build/`; distributable packages go to `dist/`. Both are
ignored by Git.

## Main objects

- `TMainForm` (`src/ui/umain.pas`) is the application controller. It owns the
  tab list, menu commands, settings, session timer, find dialogs, plugin host
  and split view.
- `TMenuBuilder` (`src/ui/umenubuilder.pas`) builds the static menu tree and
  emits `TMenuCmd` tags. `TMainForm` dispatches those tags in `MenuClick`.
- `TEditorTab` (`src/core/ueditortab.pas`) wraps one `TTyTabSheet`, one
  `TATSynEdit`, its EControl adapter, file state and per-document settings.
- `TAppSettings` (`src/core/usettings.pas`) loads and saves JSON settings.
- `TSession` (`src/core/usession.pas`) serializes window and tab state.
- `TLanguageManager` (`src/syntax/ulanguage.pas`) loads `data/lexlib/lib.lxl`,
  registers extended lexers, applies palettes and resolves language names and
  extensions.
- `TPluginManager` (`src/plugins/upluginmanager.pas`) owns package installation,
  enable state and `TPluginHost`; the host scans manifests and dispatches to a
  runtime. `TMainForm` owns the UI and applies responses to the active tab.
- `TToolStore` (`src/core/utools.pas`) loads and saves user-defined external
  tools in `tools.json`. The same unit expands placeholders and runs a command
  with stdin/stdout, timeout and cancellation; `TMainForm` shows the progress
  and output dialogs and applies the result to the active tab. External tools do
  not use the plugin system.

## Startup flow

1. `Application.CreateForm` constructs `TMainForm`.
2. Settings load from `settings.json`; the backup configuration is derived.
3. The tab list, plugin manager/host, tools store and syntax manager are
   created.
4. Plugin packages are loaded from bundled and user directories before the menu
   is built, so the Plugins menu is populated on startup.
5. `tools.json` is loaded before the menu is built, so the Tools menu lists
   enabled external tools on startup.
6. `BuildChrome` creates the form surface, title bar, page control and bottom
   panels; `BuildMenu` adds menus and dynamic submenus.
7. Session restore is deferred to `OnShow`, so crash-recovery dialogs are
   themed correctly and `Application.MainForm` exists.
8. A session timer writes snapshots while the application runs.

## Tabs and documents

`NewUntitled` creates an empty `TEditorTab`. Opening a file loads it into the
active tab or a new tab depending on the command. Each tab preserves:

- file name and untitled display name;
- text, encoding and EOL style;
- caret/selection and scroll position;
- language, bookmarks and folding;
- pinned state and session identity.

Closing a tab writes a backup for unsaved text, removes the page from the tab
strip and frees the editor after the tab control finishes its close callback.
The last tab close exits the application.

The `F8` split view is a separate read-only `TATSynEdit` used as a document map.
It never edits the primary buffer.

## Syntax extension point

The base lexers are third-party EControl definitions. `src/syntax/usyntaxdefs.pas`
adds language definitions using EControl’s `TecSyntAnalyzer` API:

- formats map to palette categories (`Keyword`, `Type`, `String`, `Comment`,
  `Number`, `Function`, `Constant`, `Operator`, `Attribute`, and so on);
- token rules use EControl regular expressions;
- comment and string styles are marked so the palette and folding code can
  classify them;
- `LexerName` and `Extentions` drive the Language menu and filename lookup.

Definitions are intentionally lexical. Add a language by extending the
`SyntaxDefs` array; no edits to `data/lexlib/lib.lxl` are required.

## Plugin extension point

Plugins are installable `.typlugin` packages, not in-process DLLs. The package,
manifest, request/response, i18n and runtime contract are documented in
[PLUGIN_PROTOCOL.md](PLUGIN_PROTOCOL.md). The host:

1. discovers `plugin.json` files under bundled and user roots;
2. parses the package manifest, locales and compatibility constraints;
3. applies user-over-plugin precedence and enable state from `plugins.json`;
4. dispatches commands to a runtime implementing the same JSON boundary;
5. runs process or PascalScript plugins off the UI thread with timeout and
   cancellation;
6. returns actions that `TMainForm` applies to the active editor tab.

`TPluginManager` installs archives by extracting to a temporary directory,
validating the manifest, path safety and compatibility, then copying to the user
plugin directory. The manager UI exposes install, uninstall, enable/disable,
reload, open-folder and error views. Plugin options are shown before each
command.

The runtime boundary deliberately exposes no editor Pascal objects or UI
handles. A future JavaScript or native runtime should implement the same
request/response contract behind the manifest’s `runtime` field. Lua is not a
planned runtime.

## Persistence

On Linux, `AppConfigDir` resolves to `~/.config/TyEditor/`; Windows uses
`%APPDATA%\TyEditor\` and macOS uses `~/Library/Application Support/TyEditor/`.
The directory contains:

- `settings.json`
- `session.json` and `session.json.bak`
- `running.marker`
- `backups/`
- `macros/`
- `plugins/`
- `custom-scheme.json` when a custom scheme is used

Writes use a temporary file and rename where the platform permits. Resource
lookup checks the executable directory, macOS `Resources`, parent directories,
the configuration directory and the current directory.

## Scope boundary

TyEditor intentionally has no project/workspace model, LSP, completion,
terminal, debugger, Git integration or editable split view. Keep new features
within the text-editor scope; do not turn the tab container into an IDE shell.

## Development conventions

- Keep UI code in `src/ui`, document/file logic in `src/core`, and platform
  code isolated in `src/platform`.
- Use `Tr()` for user-visible strings and update
  `languages/tyeditor.zh_CN.json`; run `scripts/dev/check-translations.py`.
- Never hardcode personal paths in scripts. Use `scripts/env.local.sh` or
  environment variables.
- Treat `TyEditor.lpi` as the version source of truth. `src/version.inc` is
  generated by `scripts/dev/version.py`.
- Add or update an automated test when touching encoding, search, plugins or
  syntax registration.
