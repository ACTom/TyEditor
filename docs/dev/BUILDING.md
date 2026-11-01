# Building and release workflow

The user-facing build instructions are in
[Building and installing](../user/installing.md). This page describes the
script flow and release checks for maintainers.

## Script layout

| Script | Purpose |
| --- | --- |
| `scripts/build.sh` | Target dispatcher |
| `scripts/build/linux-x86_64.sh` | Native Linux Qt6 build |
| `scripts/build/linux-aarch64.sh` | Linux aarch64 cross build |
| `scripts/build/win32.sh` | Windows i386 build |
| `scripts/build/win64.sh` | Windows x86_64 build |
| `scripts/build/macos.sh` | macOS x86_64 and universal app |
| `scripts/package/install-desktop.sh` | Install Linux binary and desktop entry |
| `scripts/package/installer.sh` | Build Windows installer through Wine |
| `scripts/dev/version.py` | Read/write version from `TyEditor.lpi` |
| `scripts/dev/run-tests.sh` | Build and run automated tests |
| `scripts/dev/check-translations.py` | Translation coverage check |
| `scripts/dev/check-hardcoded-paths.sh` | Reject machine-specific paths in scripts |
| `scripts/dev/package-plugin.py` | Build one installable `.typlugin` package |
| `scripts/dev/package-plugins.sh` | Package every bundled plugin into `dist/plugins/` |

`scripts/lib/common.sh` is sourced by all platform scripts. It:

- loads `scripts/env.local.sh` or `$TYEDITOR_ENV`;
- locates `lazbuild`, Python, TyControls and CCR paths;
- generates `src/version.inc` from `TyEditor.lpi`;
- builds common unit search path options;
- copies `data/`, `languages/` and license files into the distribution.

The scripts do not contain machine-specific paths. Add local values to the
ignored `scripts/env.local.sh` or pass them as environment variables.

## Build sequence

A typical Linux build:

```bash
cp scripts/env.example.sh scripts/env.local.sh
# edit scripts/env.local.sh
./scripts/build.sh linux-x86_64
```

Internally the platform script runs `lazbuild` with the selected widgetset and
`UNIT_OPTS`, then copies the executable to `dist/`, strips it, copies runtime
data and removes intermediate files from the repository root. The generated
`src/version.inc` is committed because Lazarus projects have no portable
version-info API; regenerate it through the scripts instead of editing it.

## Cross builds

Cross builds require:

- `CROSS_BIN`, `SYSROOT`, `QT6PAS_LIB` for Linux aarch64;
- a Windows-target FPC and `RESCOMP` for Windows;
- Cocoa/FPC units, SDK and linker paths, plus `llvm-lipo`, for macOS.

Set these in `scripts/env.local.sh`. See
[Building and installing](../user/installing.md) for the variable table and
outputs.

## Release checklist

1. Update `VersionInfo` in `TyEditor.lpi` (source of truth), then run any build
   to regenerate `src/version.inc`.
2. Update `NOTICE`, `LICENSE` or `THIRD_PARTY_NOTICES.md` if dependencies or
   bundled data changed.
3. Run checks:
   ```bash
   ./scripts/dev/run-tests.sh
   python3 scripts/dev/check-translations.py
   ./scripts/dev/check-hardcoded-paths.sh
   python3 scripts/dev/version.py --check TyEditor.lpi src/version.inc
   ```
4. Build the intended targets with `./scripts/build.sh`.
5. Package bundled plugins with `./scripts/dev/package-plugins.sh` and build the
   Windows installer with `./scripts/package/installer.sh` when releasing
   Windows packages.
6. Smoke-test each package on its target platform:
   - launch, open a file from the command line;
   - restore a session with an unsaved buffer;
   - switch encoding and EOL;
   - run find in files;
   - open a language from the new syntax list;
   - install a `.typlugin`, run it, disable it, then uninstall it;
   - run a bundled process plugin and the PascalScript fixture;
   - verify translations and dark mode.
7. Sign/notarize macOS output separately if distributing it publicly.
8. Archive release packages from `dist/`, including `dist/plugins/*.typlugin`.
9. Verify the generated installer filename uses the `.lpi` version.

## Packaging assets

- `packaging/windows/tyeditor.iss` — Inno Setup script; optional `.txt`
  association; uninstaller keeps `%APPDATA%\TyEditor`.
- `packaging/windows/tyeditor.rc` — Windows icon resource.
- `packaging/linux/tyeditor.desktop` — desktop entry.
- `packaging/macos/Info.plist` — macOS app metadata; the build script updates
  its version from `TyEditor.lpi`.

Build output directories (`build/`, `dist/`) and local environment files are
ignored by Git.
