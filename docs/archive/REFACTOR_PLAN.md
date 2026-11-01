# TyEditor refactor plan

## Objective

Remove duplicated state/update paths without introducing speculative
abstractions. Each phase must keep behavior, build all targets, and pass the
existing regression tests.

## Principles

- One owner per piece of state.
- Shared primitives live in a utility unit, not copied between callers.
- UI extraction is by responsibility, not by line count.
- A refactor is complete only after Linux UI smoke plus Windows/macOS builds.
- No new compatibility shims for removed internal APIs.

## Phase 1 — Shared foundations (completed)

| Task | Files | Acceptance |
| --- | --- | --- |
| JSON accessors | `uutils`, `usettings`, `usession` | One `JsonStr/JsonInt/JsonBool` implementation; settings/session load unchanged |
| Resource lookup | `uutils`, `ulanguage`, `TyEditor.lpr` | Languages, icon and `lib.lxl` found from source and installed layouts |
| Backup configuration | `uutils`, `usession`, `umain` | No mutable backup globals; custom backup dir/keep still honored |
| View options | `ueditortab`, `usplitview` | Split copies global settings through one helper; per-tab deltas remain |
| Forced encoding reload | `ueditortab`, `uencoding`, `umain` | Reload-with-encoding retains BOM override semantics through the tab API |

## Phase 2 — Main form decomposition (completed)

- `uresults.pas`: results panel, `TSearchHit`, add/clear/select/export, open event.
- `ustatus.pas`: eight status panels and status text update.
- `ucommands.pas`: `TMenuCmd` and `SC` shortcut helper.
- `umenubuilder.pas`: static menu tree; main retains dynamic recent/encoding/
  language/theme menus because their data is runtime state.
- `umain.pas`: delegates UI construction and result/status updates; duplicate
  tab/status refresh paths removed.

Acceptance: menu accelerators (F8, Alt+F→N), Split content/edit/close, status bar,
results toggle/export, session close/restore.

## Phase 3 — Build and release (completed)

- `scripts/common.sh`: `ROOT`, `LAZBUILD`, `PCP`, `UNIT_OPTS`, `strip_binary`,
  `copy_runtime`.
- `VERSION` is the single version source; `scripts/common.sh` writes
  `src/version.inc`, the installer receives `/DAppVersion`, and the macOS
  `Info.plist` is updated from it.
- Windows PE debug sections are removed explicitly; the previous 64 MB
  unstripped artifact regression is covered.
- Linux installer copies `data/` and `languages/` next to the binary.

Acceptance: Linux, Windows/Wine, macOS universal, installer; installed binary
finds lexers, translations and icons.

## Phase 4 — Remaining controller extraction (planned)

The only substantial remaining unit is `umain.pas` (~3.1k lines), which still
orchestrates tab/file lifecycle, session restore, commands and dialogs. The next
safe boundary is a `TWorkspaceController`:

1. Define a narrow interface:
   - `CreateTab(title, id): TEditorTab`
   - `CloseTab(tab)`
   - `ActiveTab`
   - `OnActiveChanged`, `OnTabsChanged`
   - settings and language manager injected by constructor.
2. Move `RestoreSession`, session-write orchestration, closed-tab list and
   tab-order synchronization into it. The controller must not own forms or
   menus.
3. Keep `TMainForm` responsible only for UI actions and dialog results.
4. Acceptance: restore session with modified/untitled tabs (prompt deferred until the form is shown and themed), close/reopen,
   pin/unpin, tab reorder, crash-marker prompt, split refresh.
5. Do not move menu/status/results code again; those boundaries are already
   established.

Do this as a separate change after the current verification because it touches
file lifecycle and requires a full session regression matrix.

## Verification matrix

```text
testencoding                   RESULT ok
testfindasync                  RESULT ok
testfindfiles search           35 matches / 35 files
testfindfiles replace          only matching files rewritten
translation checker            283 app strings
Linux Qt6                      build + UI smoke
Windows i386                   build + Wine smoke
macOS universal                build + Info.plist version
Installer                      build + resource install
Linux install                  data/lexlib + languages
```
