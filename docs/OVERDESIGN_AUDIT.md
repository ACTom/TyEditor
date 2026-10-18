# Whole-repository overdesign audit (2026-10-18)

The split-view rewrite exposed a broader pattern: several features had more
state owners, update paths, or compatibility layers than their behavior needed.
This audit covered all Pascal units, the tests, and the build/install scripts.
It distinguishes overdesign from justified complexity.

## Fixed in this pass

| Priority | Finding | Evidence | Change |
| --- | --- | --- | --- |
| P1 | Crash-recovery prompt was shown from the constructor before `Application.MainForm` existed, so it ignored the main controller and rendered dark in a light app | Defer session restore/crash prompt to `DoFormShow`; verified prompt uses the light controller |
| P1 | Page teardown called `PageChanged` after `TSplitView` was freed, causing an access violation on application close | `TMainForm.Destroy` freed `FSplitView` before the page control; `PageChanged` then called `FSplitView.Refresh` with a nil reference | Added a `FDestroying` guard and nil checks in `PageChanged`/`EditorChanged` |
| P1 | Every closed tab leaked its EControl adapter, parser client and ranges | `TEditorTab` created the adapter with the main form as owner and its destructor freed nothing; `DetachEditor` had no callers | `TEditorTab.Destroy` now detaches and frees the adapter; dead `DetachEditor` removed |
| P1 | Single-instance timer leaked a `TStringList` on every idle tick and rewrote the lock file twice per second | `TakeOpenRequests` always allocated the list; `InstanceTimerTick` freed it only on success; `HeartbeatSingleInstance` had no remaining consumer | Always free the list; heartbeat call/function removed |
| P1 | Replace-in-files used a second, blocking search engine that pumped the UI loop | Synchronous `FindInFiles` duplicated the threaded `TFindFileJob.Execute`; `DoReplace` used `ProcessMessages` | `TFindFileJob` now owns replace; sync engine and progress callback deleted; dialog uses the same job/timer for Find and Replace |
| P1 | Linux install helper installed only the binary | `scripts/linux/install-desktop.sh` omitted `data/` and `languages/`, disabling lexers/translations/icons | Copies both runtime directories next to the installed binary |
| P1 | Preferences OK leaked/replaced the bookmark form and reset bookmark group | `ShowPreferences` duplicated constructor lines and called `ApplySettingsToAll` twice | Duplicate block and second apply removed |
| P2 | Timestamped session snapshots were written every 30 s but never restored | `SaveSession` wrote `session_*.json`; restore only read `session.json` | Snapshot write/prune/list removed; live atomic session + `.bak` retained |
| P2 | Window geometry was persisted by settings and session; maximized flag was write-only | `TAppSettings` and `usession` both stored bounds; `WindowMaximized` was never read | Settings is the single owner; session window object removed; maximized state applied in `BuildChrome` |
| P2 | Startup re-applied global settings after session restore, overwriting per-tab wrap | Constructor called `ApplySettingsToAll` after `SelectTab` | Removed; each tab already receives settings at creation and session overrides after |
| P2 | `ThemeFormControls` re-bound the controller that `ActiveController` already falls back to | All calls passed `TyDefaultController`; TyControls returns it when `FController=nil` | Unit and nine calls removed |
| P2 | Theme change rebuilt every tab's lexer through `SetLexer` | `ApplyAppTheme` looped all tabs after palette application | Loop removed; palette formats + invalidation drive repaint |
| P2 | Encoding menus were fully rebuilt on every file open/encoding change | 66 menu items recreated; `FEncodingChoices` rebuilt | Menus built once; only Recent Encodings rebuilt; async wrapper deleted |
| P2 | System ANSI entry duplicated an entry already in the codepage list | `AddChoice` added `EncConvGetANSI`, then the loop added it again | Duplicate loop entry skipped |
| P2 | Encoding choice carried a never-read `FileEncoding` field and unused return | `TEncodingChoice.FileEncoding`; `AddChoice` result ignored | Field/parameter/result removed |
| P2 | `Tab.UpdateCaption` duplicated in `UpdateStatus`, `SelectTab` duplicated `PageChanged`, `CreateTab` rebuilt menus twice | Tab switch/status paths | State refresh only when the page was already active; duplicate title/menu refresh removed |
| P2 | Macro > Load did not bind the loaded macro | `MacroLoad` left `MacroPath` unchanged; `PlayBoundMacro` then reported no macro | Load binds path; bound play uses in-memory macro |
| P2 | Find-in-files dialog had dead replacement state and ignored the Replace menu entry | `FReplaceMode` write-only, counters unused, `AReplace` ignored | Dead fields removed; Replace focuses/selects the replace field |
| P2 | Dead/duplicate palette and API surface | GitHub palette identical to TyEditor; `TColorSchemeDef.Name`; language `ErrorMessage`/`LexerName`; `SetRecent`; `utranslation` nil guards | Removed or made non-exported |
| P2 | Palette I/O was non-atomic and used a second JSON read path | `LoadPaletteFile`/`SavePaletteFile` used `TStringList` | Uses `ReadTextFileSafe`/`AtomicWriteString` |
| P2 | `AtomicWriteString` deleted the destination before rename, breaking POSIX atomicity | `uutils` | Rename first; delete only on Windows-style failure and retry |
| P3 | LPR duplicated the language-directory search and `SetDefaultLang` | `TyEditor.lpr` vs `uutils.GetLanguageDir`/`umain` | Local `LangDir` and pre-form call removed |
| P3 | Session metadata was written but never read | `schema_version`, `app`, `app_version` | Removed |
| P3 | About dialog bypassed translations with a hardcoded Chinese branch | `ShowAbout` | Single `Tr`-based path, translations added |
| P3 | macOS clean build could fail before `dist/` existed | `build-macos.sh` copied to `dist/.TyEditor-*` before mkdir | `mkdir -p dist` added |
| P3 | Installer shortcut was gated by the `.txt` association task; association cache flag missing | `tyeditor.iss` | Desktop icon ungated; `ChangesAssociations=yes` |

## Structural refactors completed

1. **View options now have one mapping.** `ApplyEditorViewOptions` in
   `ueditortab.pas` is used by both `TEditorTab.ApplySettings` and `TSplitView`;
   the split keeps only per-tab and document-map deltas.
2. **Encoding reload has one implementation.** `TEditorTab.LoadFromFile` accepts
   `AForceEncoding`; `ReloadEditorWithEncoding` was removed.
3. **Backup configuration is explicit.** `TBackupConfig`/`MakeBackupConfig`/
   `BackupDirFor` replace global mutable `uutils` state; session calls receive
   the config.
4. **Build scripts share `scripts/common.sh`** (paths, lazbuild options, strip,
   runtime copy) and a single `VERSION` source generates `src/version.inc`.
5. **Resources use one locator.** `FindResourcePath` drives languages, icons and
   the lexer library; the LPR duplicate language search was removed.
6. **JSON accessors are shared.** `JsonStr/JsonInt/JsonBool` in `uutils` replace
   the duplicated `J*` and `Obj*` helpers.
7. **`umain` has been split further.** `uresults.pas` owns the results panel,
   hit objects and export; `ustatus.pas` owns the status bar; `ucommands.pas`
   owns the command enum and shortcut helper; `umenubuilder.pas` owns the static
   menu tree. `umain` is now ~3.1k lines and no longer builds the menu, status
   bar or result list itself.
8. **Linux install includes runtime resources**; build scripts compile version
   data into the installer, macOS bundle and About box.

The remaining `umain` responsibility is the actual application controller:
tab/file lifecycle, session orchestration, commands and dialog wiring. Further
extraction (a `TWorkspaceController`) is planned in
[REFACTOR_PLAN.md](REFACTOR_PLAN.md) but is not an abstraction required by the
current feature set.

## Justified complexity (not overdesign)

- `uencoding` detection heuristics: no standard Pascal detector for legacy CJK
  codepages; the conservative scoring is feature logic.
- `ucolorscheme.TPaletteObject`: the TyControls property grid requires
  published `TColor` properties; the record adapter is the price of that API.
- `uplatform.SetNativeTopMost`: LCL has no native always-on-top call on Windows;
  the Unix no-op is deliberate.
- `uwinproc` and the file-queue single-instance protocol: small, portable and
  already tested; removing them would require a socket/IPC replacement.
- `uencoding`/palette data tables: large but data, not abstraction.
- Find-in-files worker thread: justified for responsive search; only its
  duplicate synchronous engine was removed.

## Verification

- `testencoding`: `RESULT ok`
- `testfindasync`: `RESULT ok`
- `testfindfiles`: 35 matches / 35 files, and replacement test rewrote only
  matching files
- translation checker: 283 app strings complete
- Linux Qt6 build; dark-mode startup; Split content/highlight/edit;
  tab close with visible split; session save/restore; maximized setting
- Linux install smoke: `data/lexlib/lib.lxl` and `languages/tyeditor.zh_CN.json`
  present under the install prefix
- Windows/Wine, macOS, installer rebuilt after the changes
