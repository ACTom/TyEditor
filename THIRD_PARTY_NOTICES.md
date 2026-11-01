# Third-party notices

TyEditor is licensed under the Apache License 2.0. The following components
are used by the application or its build and keep their own licenses.

## TyControls

- Project: TyControls
- License: modified LGPL (Lazarus/FPC linking exception)
- License files: `COPYING.LGPL.txt`, `COPYING.modifiedLGPL.txt` in the
  TyControls source tree.
- Usage: window chrome, tab strip, menus, status bar, dialogs.

## ATSynEdit / ATSynEdit_Ex

- Project: ATSynEdit
- License: MPL 2.0 or LGPL
- License file: `license.txt` in the ATSynEdit source tree.
- Usage: editor control, caret/selection handling, adapters.

## EControl

- Project: EControl Syntax Editor SDK (Lazarus port)
- License: MPL 2.0 or LGPL
- Usage: syntax parser, lexer manager, syntax highlighting.
- The bundled `data/lexlib/lib.lxl` contains lexer definitions derived from
  the EControl/ATSynEdit ecosystem.

## EncConv

- Project: EncConv
- License: MPL 2.0 or LGPL; some files follow the Lazarus license terms.
- Usage: encoding detection and conversion.

## RemObjects Pascal Script

- Project: RemObjects Pascal Script, created by Carlo Kok
- Copyright: 2000-2014 Carlo Kok and RemObjects Software, LLC
- License: zlib-style permissive license with attribution conditions
- Project home: https://www.remobjects.com/ps.aspx
- Usage: embedded `pascalscript` plugin runtime (`src/plugins/upluginruntime.pas`)
- TyEditor does not modify the PascalScript source distributed with Lazarus.

## Build-only components

The following tools are not distributed with TyEditor and are only used when
building or packaging:

- Free Pascal Compiler (FPC)
- Lazarus / lazbuild
- LLVM tools (`llvm-rc`, `llvm-strip`, `llvm-objcopy`)
- Inno Setup (Windows installer)
- Wine (optional, for building the Windows installer on Linux)

If you distribute a binary build of TyEditor, include this file and the
license texts required by the components above. For LGPL components, make
sure recipients can relink the application with modified versions of those
components as required by the LGPL.
