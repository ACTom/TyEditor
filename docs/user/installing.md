# Building and installing TyEditor

TyEditor is built with Lazarus/Free Pascal. The repository does not contain
prebuilt binaries; build artifacts are written to `build/` and `dist/`, both of
which are ignored by Git.

## Dependencies

Tested versions are listed in [Dependencies](../dev/DEPENDENCIES.md). You need:

- Lazarus / `lazbuild` and FPC.
- TyControls source.
- ATSynEdit, ATSynEdit_Ex, EControl, ATFlatControls, EncConv and PascalScript
  packages.
- Python 3 (version generation and process-runtime test fixtures).
- Linux: Qt6 development libraries (`pkg-config --modversion Qt6Widgets`).
- Optional cross-compilation toolchains for Windows, macOS and Linux aarch64.

The Lazarus packages must be registered in the Lazarus primary config (`PCP`)
that `lazbuild` uses. If they are not registered, see
[Dependencies](../dev/DEPENDENCIES.md) for the `--add-package-link` commands.

## Configure the environment

Copy the example environment file and edit the paths for your machine:

```bash
cp scripts/env.example.sh scripts/env.local.sh
```

`scripts/env.local.sh` is ignored by Git. At minimum set:

```bash
export LAZBUILD="/path/to/lazbuild"
export TYCONTROLS_DIR="/path/to/TyControls/source"
export CCR_DIR="/path/to/fpcupdeluxe/ccr"
```

Other useful variables:

| Variable | Purpose |
| --- | --- |
| `PCP` | Lazarus primary config path, if not the default |
| `PYTHON` | Python 3 interpreter used by scripts |
| `STRIP` | Strip tool (`llvm-strip`, `strip`, …) |
| `RESCOMP` | Windows resource compiler (`llvm-rc` or `windres`) |
| `OBJCOPY` | Windows section remover (`llvm-objcopy` or `objcopy`) |
| `CROSS_BIN` | aarch64 binutils directory |
| `SYSROOT` | aarch64 glibc/Qt6 sysroot |
| `QT6PAS_LIB` | directory containing the aarch64 `libQt6Pas.so` |
| `WINE` / `WINE_PREFIX` / `ISCC` | Windows installer build |

Alternatively, point `TYEDITOR_ENV` at another environment file.

## Build targets

```bash
./scripts/build.sh                 # Linux x86_64, Qt6 (default)
./scripts/build.sh linux-aarch64   # Linux aarch64, Qt6
./scripts/build.sh win32           # Windows i386, native Win32 widgetset
./scripts/build.sh win64           # Windows x86_64, native Win32 widgetset
./scripts/build.sh macos           # macOS x86_64 + Apple Silicon (arm64)
./scripts/build.sh macos-x86_64    # macOS Intel only
./scripts/build.sh macos-aarch64   # macOS Apple Silicon only
./scripts/build.sh all             # Linux x86_64 + Windows i386/x86_64
```

Outputs:

| Target | Output |
| --- | --- |
| `linux-x86_64` | `dist/linux-x86_64/TyEditor` |
| `linux-aarch64` | `dist/linux-aarch64/TyEditor` (with `libQt6Pas.so*`) |
| `win32` | `dist/win32-i386/TyEditor.exe` |
| `win64` | `dist/win64-x86_64/TyEditor.exe` |
| `macos` | `dist/macos-x86_64/TyEditor.app`, `dist/macos-aarch64/TyEditor.app` |
| `macos-x86_64` | `dist/macos-x86_64/TyEditor.app` |
| `macos-aarch64` | `dist/macos-aarch64/TyEditor.app` |

Each target copies `data/`, `languages/`, `LICENSE`, `NOTICE` and
`THIRD_PARTY_NOTICES.md` next to the executable (or into the macOS app bundle),
because runtime resource discovery depends on them. `data/plugins/` is included
in that copy.

## Plugin packages

Bundled plugins are ordinary directories. To create installable `.typlugin`
archives for distribution, run:

```bash
./scripts/dev/package-plugins.sh
# dist/plugins/*.typlugin
```

To package one plugin:

```bash
./scripts/dev/package-plugin.py data/plugins/base64
```

Users install these archives from **Plugins > Manage Plugins...**. See the
[plugin guide](plugins.md) for the package format and user workflow.

### Linux

Install the Qt6 base development package for your distribution, then:

```bash
./scripts/build.sh linux-x86_64
dist/linux-x86_64/TyEditor
```

The build uses `--ws=qt6`. If Qt6 is missing, `lazbuild` will fail while building
the LCL Qt6 widgetset.

### Windows

The Windows builds use the native Win32 widgetset, not Qt6. On Linux, cross
compilation requires a Windows-capable FPC and a resource compiler
(`llvm-rc` is the usual choice). The scripts compile the application icon into
the PE file explicitly.

```bash
./scripts/build.sh win32
./scripts/build.sh win64
```

### macOS

```bash
./scripts/build.sh macos           # both architectures
./scripts/build.sh macos-x86_64    # Intel only
./scripts/build.sh macos-aarch64   # Apple Silicon only
```

This cross-compiles two independent app bundles instead of a universal binary:
`dist/macos-x86_64/TyEditor.app` for Intel and
`dist/macos-aarch64/TyEditor.app` for Apple Silicon. Each bundle includes
`data/` and `languages/` under `Contents/Resources/`. The output is not signed
or notarized; sign each bundle with your own Apple credentials before
distribution.

### Linux aarch64

This is a cross build. The script requires `CROSS_BIN`, `SYSROOT` and
`QT6PAS_LIB`; see the comments at the top of
`scripts/build/linux-aarch64.sh`. The resulting directory contains the
aarch64 `libQt6Pas.so*`, loaded through `$ORIGIN` RUNPATH.

## Packaging and desktop installation

### Linux desktop entry

After building the Linux target:

```bash
./scripts/package/install-desktop.sh
# or
PREFIX=/usr/local ./scripts/package/install-desktop.sh
```

This installs the binary, `data/`, `languages/`, the desktop entry and the
256×256 icon under `$PREFIX` (default `~/.local`).

### Windows installer

The Inno Setup script is `packaging/windows/tyeditor.iss`. The wrapper builds
the 32-bit Windows binary and invokes Inno Setup through Wine:

```bash
export ISCC="/path/to/ISCC.exe"
./scripts/package/installer.sh
```

The result is `dist/TyEditorSetup-<version>.exe`. The installer creates an
optional `.txt` file association; the uninstaller intentionally leaves user
settings and sessions in `%APPDATA%\TyEditor`.

## Versioning

`TyEditor.lpi` is the single source of truth for the version. The build scripts
run:

```bash
python3 scripts/dev/version.py --write TyEditor.lpi src/version.inc
```

`src/version.inc` is generated and should not be edited by hand. To update the
version, edit `VersionInfo` in `TyEditor.lpi` and rebuild.

## Tests and checks

```bash
./scripts/dev/run-tests.sh
python3 scripts/dev/check-translations.py
./scripts/dev/check-hardcoded-paths.sh
```

The test runner builds and runs the automated tests; `testfindfiles` needs a
directory, mask and query and is invoked by the runner. See
[Testing](../dev/TESTING.md) for details.
