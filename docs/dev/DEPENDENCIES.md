# Dependencies

TyEditor is built from source with Lazarus/Free Pascal. The versions below were
used for the current verification; newer compatible releases may work.

## Toolchain

| Component | Verified version | Notes |
| --- | --- | --- |
| Lazarus / `lazbuild` | 5.99 | Must provide the LCL widgetset used by the target |
| FPC | 3.2.3 | `ppcx64` and, for cross builds, the matching cross compiler |
| TyControls | 3.99.x | Source checkout, added to the project search path |
| ATSynEdit | 2.28 | Lazarus package `atsynedit_package` |
| ATSynEdit_Ex | 2.2.2 | Lazarus package `atsynedit_ex_package` |
| EControl | 2.3.1 | Lazarus package `econtrol_package` |
| ATFlatControls | 2.3.1 | Lazarus package `atflatcontrols_package` |
| EncConv | 1.1 | Lazarus package `encconv_package` |
| PascalScript | Lazarus component | Embedded PascalScript plugin runtime |
| Python | 3.x | Version generation and process-runtime test fixtures |
| Qt6 | 6.x | Linux desktop build only |

The project file declares `LCL`, `tycontrols`, `atsynedit_package`,
`atsynedit_ex_package`, `econtrol_package`, `encconv_package` and
`pascalscript`.

## Environment variables

The build scripts do not contain machine-specific paths. Set them with
`scripts/env.local.sh`, `TYEDITOR_ENV`, or the environment:

```bash
export LAZBUILD="/path/to/lazbuild"
export PCP="/path/to/lazarus/config"          # optional
export TYCONTROLS_DIR="/path/to/TyControls/source"
export CCR_DIR="/path/to/fpcupdeluxe/ccr"
```

`CCR_DIR` is expected to contain the standard subdirectories:

```text
$CCR_DIR/atsynedit/atsynedit
$CCR_DIR/atsynedit_ex/atsynedit_ex
$CCR_DIR/econtrol/econtrol
$CCR_DIR/bgrabitmap/bgrabitmap
$CCR_DIR/atflatcontrols/atflatcontrols
$CCR_DIR/encconv/encconv
```

TyControls is searched at `$TYCONTROLS_DIR`; the common layout is a sibling
checkout at `../TyControls/source`.

## Registering Lazarus packages

If the packages are not already visible to the selected `PCP`, register them
with `lazbuild --add-package-link`:

```bash
"$LAZBUILD" --pcp="$PCP" --add-package-link "$CCR_DIR/atsynedit/atsynedit/atsynedit_package.lpk"
"$LAZBUILD" --pcp="$PCP" --add-package-link "$CCR_DIR/atsynedit_ex/atsynedit_ex/atsynedit_ex_package.lpk"
"$LAZBUILD" --pcp="$PCP" --add-package-link "$CCR_DIR/econtrol/econtrol/econtrol_package.lpk"
"$LAZBUILD" --pcp="$PCP" --add-package-link "$CCR_DIR/atflatcontrols/atflatcontrols/atflatcontrols_package.lpk"
"$LAZBUILD" --pcp="$PCP" --add-package-link "$CCR_DIR/encconv/encconv/encconv_package.lpk"
"$LAZBUILD" --pcp="$PCP" --add-package-link "$LAZARUS_DIR/components/PascalScript/Source/pascalscript.lpk"
```

Set `LAZARUS_DIR` to the Lazarus installation directory. PascalScript ships
with Lazarus but is not necessarily registered in a fresh profile.

Make sure only one compatible version of each package is registered for the
`PCP` used by the build. Mixing older ATSynEdit/EControl revisions can produce
API mismatches or duplicate-unit warnings.

## Platform requirements

### Linux

- Qt6 base development package; `pkg-config --modversion Qt6Widgets` should
  succeed.
- The Qt6 Lazarus widgetset must be available in `lazbuild`.

### Windows

- Windows builds use the native Win32 widgetset, not Qt6.
- Cross builds need a Windows-target FPC and an RC compiler such as `llvm-rc`.
- The optional installer needs Wine and Inno Setup (`ISCC.exe`).

### macOS

- Cocoa widgetset and an FPC macOS cross toolchain for cross builds.
- `llvm-lipo` or `lipo` for the universal binary.
- Output is unsigned and not notarized unless you sign it yourself.

### Linux aarch64

- aarch64 binutils and FPC aarch64 RTL/packages.
- an aarch64 sysroot with glibc and Qt6.
- an aarch64 `libQt6Pas.so`; configure `CROSS_BIN`, `SYSROOT` and
  `QT6PAS_LIB`.

## Lexer data

- Base EControl library: `data/lexlib/lib.lxl`
- Extended TyEditor definitions: `src/syntax/usyntaxdefs.pas`
- Runtime lookup: executable directory, macOS `Resources`, parent directories,
  configuration directory and current directory.

The base library is third-party data; see
[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md). TyEditor does not modify
it; the additional languages are registered at runtime.

## Translation data

- Application strings: `languages/tyeditor.<locale>.json`
- TyControls strings: `languages/tycontrols.<locale>.po`

Run `python3 scripts/dev/check-translations.py` after adding user-visible
strings.
