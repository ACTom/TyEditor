# 依赖与构建

## 工具链

| 组件 | 版本/路径 |
| --- | --- |
| Lazarus / lazbuild | 5.99，`/home/Tom/fpcupdeluxe/lazarus/lazbuild` |
| Lazarus 配置 | `/home/Tom/fpcupdeluxe/config_lazarus` |
| FPC | 3.2.3（`ppcx64` 输出） |
| Widgetset | Linux：Qt6（需要 Qt6Widgets）；Windows：Win32 |

构建：

```bash
./scripts/build.sh
```

脚本使用 `--ws=qt6`：

```bash
/home/Tom/fpcupdeluxe/lazarus/lazbuild \
  --pcp=/home/Tom/fpcupdeluxe/config_lazarus \
  --ws=qt6 TyEditor.lpi
```

Qt6 验证版本：`pkg-config --modversion Qt6Widgets` → `6.11.2`。

## Lazarus 包

项目 `.lpi` 声明：

- `LCL`
- `tycontrols`
- `atsynedit_package`
- `atsynedit_ex_package`
- `econtrol_package`
- `encconv_package`

当前注册并验证的源：

| 包 | 版本 | 路径 |
| --- | --- | --- |
| TyControls | 3.1 / `4a84e590` | `/home/Tom/Projects/TyControls` |
| ATSynEdit | 2.28 / `1a377b1` | `/home/Tom/fpcupdeluxe/ccr/atsynedit` |
| ATSynEdit_Ex | 2.2.2 | `/home/Tom/fpcupdeluxe/ccr/atsynedit_ex` |
| EControl | 2.3.1 | `/home/Tom/fpcupdeluxe/ccr/econtrol` |
| ATFlatControls | 2.3.1 | `/home/Tom/fpcupdeluxe/ccr/atflatcontrols` |
| EncConv | 1.1 | `/home/Tom/fpcupdeluxe/ccr/encconv` |

注意：`/home/Tom/fpcupdeluxe/ccr` 下的 ATSynEdit_Ex 2.2.2 与 EControl 2.3.1 与 ATSynEdit 2.28 的 API 匹配；不要同时注册 `/media/Data/.../ATSynEdit-master` 的旧版 2.14 包，否则会解析到错误的版本。TyEditor 源码没有修改第三方包。

如果包尚未注册：

```bash
LAZBUILD=/home/Tom/fpcupdeluxe/lazarus/lazbuild
PCP=/home/Tom/fpcupdeluxe/config_lazarus
$LAZBUILD --pcp="$PCP" --add-package-link /home/Tom/fpcupdeluxe/ccr/atsynedit/atsynedit/atsynedit_package.lpk
$LAZBUILD --pcp="$PCP" --add-package-link /home/Tom/fpcupdeluxe/ccr/atsynedit_ex/atsynedit_ex/atsynedit_ex_package.lpk
$LAZBUILD --pcp="$PCP" --add-package-link /home/Tom/fpcupdeluxe/ccr/econtrol/econtrol/econtrol_package.lpk
$LAZBUILD --pcp="$PCP" --add-package-link /home/Tom/fpcupdeluxe/ccr/atflatcontrols/atflatcontrols/atflatcontrols_package.lpk
```

## Windows i386 交叉构建

```bash
./scripts/build-win32.sh
```

产物在 `dist/win32-i386/TyEditor.exe`（PE32 Intel i386）。Qt6 没有官方 32 位 Windows 目标，因此 Windows 版本使用 Lazarus 原生 Win32 widgetset，面向 Win2003 及之后的 32/64 位 Windows；静态导入仅经典系统 DLL。

交叉构建时，Lazarus 需要重建 BGRABitmap/ATSynEdit/EControl 等依赖；当前配置下在这些包的 `.lpk` 搜索路径中加入了机器本地的源码目录，脚本也把相同源码路径传给项目编译。换机器或升级依赖时需要同步这些路径。

## Windows x86_64 交叉构建

```bash
./scripts/build-win64.sh
```

产物在 `dist/win64-x86_64/TyEditor.exe`（PE32+ x86-64），同样使用原生 Win32 widgetset，仅导入经典系统 DLL。

## Linux aarch64 交叉构建

```bash
./scripts/build-linux-aarch64.sh
```

产物在 `dist/linux-aarch64/TyEditor`，Qt6 widgetset，随包提供 `libQt6Pas.so.6`，通过 `$ORIGIN` RUNPATH 加载；运行环境需要 aarch64 Qt6（`qt6-qtbase-gui`）与 X11。

交叉工具链准备（Fedora 44）：

```bash
sudo dnf install gcc-aarch64-linux-gnu gcc-c++-aarch64-linux-gnu binutils-aarch64-linux-gnu
sudo dnf --forcearch=aarch64 --installroot=/opt/sysroot-aarch64 --use-host-config \
  --releasever=44 --disablerepo='*' --enablerepo=fedora --enablerepo=updates \
  install glibc glibc-devel libgcc libstdc++ qt6-qtbase-devel
```

FPC 交叉单元：使用 `ppcrossa64` 构建 `aarch64-linux` 的 RTL 与 packages，安装到 `/home/Tom/fpcupdeluxe/fpc/units/aarch64-linux`。`fpc.cfg` 的 `CPUAARCH64 && LINUX` 段需要把 `/opt/sysroot-aarch64/usr/lib64` 与 GCC 库目录放在 host 路径之前，否则链接器会选中 x86_64 的 `crti.o`/`libc.so`。交叉 binutils 需要以 `aarch64-linux-as`/`ld` 名称出现在 `PATH` 或 FPC bin 目录（脚本默认 `/opt/aarch64-bin`）。

`libQt6Pas.so.6`（Lazarus Qt6 绑定）需用同一 sysroot 交叉编译到 `/opt/qt6pas-aarch64/lib`。

## macOS 交叉构建

```bash
./scripts/build-macos.sh
```

- x86_64：`ppcrossx64` + Cocoa，输出 `dist/macos-x86_64/TyEditor.app`
- universal：额外用 `ppcrossa64` 构建 aarch64，再用 `llvm-lipo -create` 合并为 `dist/macos-universal/TyEditor.app`
- SDK：`/home/Tom/fpcupdeluxe/cross/lib/all-darwin/MacOSX12.3.sdk`
- 交叉链接器：`/home/Tom/fpcupdeluxe/cross/bin/all-apple/bin`
- FPC 单位：`/home/Tom/fpcupdeluxe/fpc/units/x86_64-darwin`、`aarch64-darwin`
- 产物未签名/未公证；分发前需要在 macOS 上使用 `codesign`/`notarytool` 处理。

## 图标

- 源文件：`assets/tyeditor.svg`
- 运行时：`data/icons/tyeditor.ico`，另有 256/128/64/32 PNG
- `.lpi` 的 `<Icon>` 指向 `data/icons/tyeditor.ico`
- Windows：`TyEditor.rc` 由 `scripts/build-win32.sh` 用 `llvm-rc` 编译为 `tyeditor_icon.res`，再由 `TyEditor.lpr` 的 `{$R 'tyeditor_icon.res'}` 链入 PE

## 词法库

- 文件：`data/lexlib/lib.lxl`
- 大小：321,670 字节
- MD5：`ac060a3fe758e5c052c22bba3389ae62`

运行时查找顺序：

1. `<exe>/data/lexlib/lib.lxl`
2. `<exe 上级>/data/lexlib/lib.lxl`
3. `GetAppConfigDir(False)/data/lexlib/lib.lxl`
4. 当前目录 `data/lexlib/lib.lxl`
5. 当前目录 `lib.lxl`

找不到或加载失败时禁用语法高亮，不阻止启动，状态栏显示 Plain text。

## 测试

`tests/testfindfiles.lpi` 是“在文件中查找”引擎的独立测试：

```bash
/home/Tom/fpcupdeluxe/lazarus/lazbuild --pcp=/home/Tom/fpcupdeluxe/config_lazarus tests/testfindfiles.lpi
./tests/testfindfiles /tmp '*.pas' WriteLn
```
