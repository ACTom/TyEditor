# UX Audit Results (2026-10-18)

This is the execution record for [UX_AUDIT_PLAN.md](UX_AUDIT_PLAN.md).

## P0 fixes verified

| Item | Fix | Evidence |
| --- | --- | --- |
| Split/Document Map blank/style/resize/sync | Rewritten as `TSplitView` (`src/usplitview.pas`). The component owns the panel, divider, preview editor, EControl adapter, source change listener and style synchronization; `TMainForm` only passes the active `TEditorTab`. It listens to the source `TATStrings.OnChangeEx2`, records the line/range change, and mirrors edited/added/deleted lines on the next event-loop turn. It does not assign the whole document or recreate the lexer per keystroke. Full reloads use a short read-only override because `Strings.ReadOnly` makes `Text :=` a no-op. Lexer changes are guarded (never call `SetLexer` for the same analyzer), EControl range updates are driven by the adapter, tab-close detaches the analyzer before the tab is freed, and the EOF marker is disabled. The preview wraps long lines and calls `UpdateWrapInfo` after line edits, so the tail of a changed line cannot remain clipped. A separate 8 px `TTyPanel` divider resizes the pane and is re-positioned on host/panel resize. | `1010.c`: right pane shows the full document, wrapped lines, line numbers, ruler and syntax colors; typing updates the same line without a lexer reset; dragging the divider changes the split width; resizing the window keeps it aligned; switching/closing tabs while split is open updates the map without a crash or stale lexer. |
| Find input | `TTyComboBox.Style := csDropDown`, `ReadOnly := False`; history items remain in the combo | Ctrl+F, type text, Enter performs Find Next |
| Find jump | Explicit `DoGotoPos(MatchEdPos, MatchEdEnd)` after find | Main editor moves to line 2 and selects `needle` |
| Find focus/Enter/Escape | `ShowFind` focuses and selects; Enter/Shift+Enter; Escape form handler | Keyboard-only find path tested |
| Always-on-top | Persisted setting; LCL FormStyle + Win32 `SetWindowPos`; dialogs follow main form | Linux `_NET_WM_STATE_ABOVE`; Windows Wine build shows `_NET_WM_STATE_ABOVE` on startup and toggles off/on; setting persists |
| Ruler theme | `RulerBG`/`RulerFont` added to palette, JSON and `ApplyPalette` | Ruler background follows dark editor background (pixel check) |
| Chinese localization | 43 `Tr` keys plus 7 raw menu captions added; checker now scans raw `AddItem`/`AddSub`/`AddLabel`/`AddCheck` captions | `scripts/check-translations.py` reports complete for 281 app strings; `dist/linux` and `dist/win32` language JSON are byte-identical to source |
| Color editor | Replaced hex input with `TTyColorButton`; click opens `TTyColorDialog` | `Choose color` TyControls dialog opens from swatch |

## Feature smoke matrix

| Area | Evidence |
| --- | --- |
| Encoding/BOM | `tests/testencoding` RESULT ok; GBK/Big5/Shift-JIS/EUC-KR GUI smoke |
| Async find in files | `tests/testfindasync` RESULT ok; progress/Stop UI exercised |
| Session/crash | kill -9 then restart prompt and restore verified |
| Backup retention | custom `/tmp/tybackups`, keep=2 retained 2 text backups; unused session snapshots removed |
| Tabs | new, close, reopen (`Ctrl+Shift+T`), pin/unpin, close-others protection tested |
| Bookmarks | F2 + `Ctrl+Alt+B` list showed file/line; group tag persisted in session |
| Macro | manager lists files; record/play inserted text; blocking start/stop info modals removed |
| Color editor | uses `TTyPropertyGrid` (`TPaletteObject` published TColor properties); color rows use TyControls color editing | `TTyPropertyGrid` opens with 18 palette rows, localized row labels, color swatches; no manual hex input remains |
| Single instance | second process exits; first opens transferred file; stale PID lock fixed |
| Long path/read-only | 163-char path opens; read-only save shows error dialog |
| Installer | Wine + Inno Setup produced `dist/TyEditorSetup-0.1.0.exe`; silent install/uninstall passed; user data retained |
| Cross build | Linux Qt6, Windows i386, macOS universal built |

## Remaining platform limits

- Windows functional checks were run under Wine, not a native Windows machine.
- Network-mounted path testing requires a mounted network filesystem in the test environment; the procedure is documented in `docs/TESTING.md`.
- Split view is intentionally a read-only document map, not an editable second buffer.
