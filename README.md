# TyEditor

TyEditor 是一个使用 **Lazarus + TyControls + ATSynEdit** 构建的多标签文本编辑器。主窗口是 `TTyForm`，菜单栏放在 `TTyTitleBar` 中，编辑器核心是 `TATSynEdit`，语法高亮使用 EControl + `lib.lxl`。

## 功能

- 多标签编辑；每个标签保存独立的光标、选区、滚动位置、编码、换行符、语言、书签、折叠和只读状态；关闭最后一个标签即退出程序。
- 打开无权限/不存在文件时提示错误，不留下空白标签；保存失败不会覆盖原文件，并显示错误。
- 退出程序不弹保存提示：未保存内容写入备份，启动时自动恢复全部标签；每 30 秒自动快照。
- 状态栏显示/转换字符编码：UTF-8、UTF-8 BOM、UTF-16 LE/BE、UTF-32 LE/BE、ANSI 系统代码页以及常用代码页（GBK、Big5、Shift-JIS、EUC-KR 等）。打开文件时自动识别 BOM、UTF-8、UTF-16 和常见多字节编码；低置信度或误判时可从状态栏手动重载。
- 状态栏显示/转换换行符：CRLF、LF、CR、Mixed。
- 文件：新建、打开、打开最近、保存、另存为、全部保存、重新载入、关闭、关闭其他、关闭全部；支持命令行打开和拖放打开（LCL 默认拖放）。
- 编辑：撤销/重做、剪贴板、行复制/删除/移动、缩进、注释切换、大小写、排序、去重、去行尾空格、合并/拆分行、多光标、列选择、缩进参考线、括号跳转。
- 查找/替换：普通/正则、区分大小写、全字匹配、循环、选区内、全部查找、计数。
- 在文件中查找/替换：目录、通配符、子目录、包含/排除目录、编码感知读取/保存；异步扫描、进度、取消、结果导出为文本/JSON。
- 书签、转到行。
- 宏：命令级录制、播放、播放 N 次、保存/载入 JSON 宏。
- 语法高亮：EControl 词法库，按扩展名自动识别，可手动切换或关闭。
- 视图：自动换行、空白字符、行号、折叠、标尺、书签边栏、minimap/micromap、缩放、全屏、置顶、界面主题、深色模式。
- 默认编辑区按 Notepad++ 习惯：只显示行号；标尺、书签边栏、变更状态边栏默认关闭；折叠边栏仅在启用语法高亮时显示。
- 设置保存到 JSON；界面语言默认跟随系统（中文系统显示中文，其他系统回退英文），也可显式选择 `en` / `zh_CN`。

## 依赖

详见 [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)。当前验证环境：

- Lazarus 5.99 / FPC 3.2.3
- TyControls 3.1
- ATSynEdit 2.28
- ATSynEdit_Ex 2.2.2
- EControl 2.3.1
- EncConv 1.1
- ATFlatControls 2.3.1

## 构建

```bash
./scripts/build.sh
```

构建脚本固定使用 **Qt6** widgetset，并在复制到 `dist` 前执行 `llvm-strip`（Windows 还会移除 `.stab`/`.stabstr`）：

```bash
/home/Tom/fpcupdeluxe/lazarus/lazbuild \
  --pcp=/home/Tom/fpcupdeluxe/config_lazarus \
  --ws=qt6 TyEditor.lpi
```

需要系统安装 Qt6 开发库（`pkg-config --modversion Qt6Widgets` 应能输出版本）。

运行：

```bash
dist/linux-x86_64/TyEditor
dist/linux-x86_64/TyEditor /path/to/file1 /path/to/file2
```

安装到 `~/.local`（同时安装 `data/` 和 `languages/`，否则语法库与翻译不可用）：

```bash
./scripts/linux/install-desktop.sh
# 或 PREFIX=/usr/local ./scripts/linux/install-desktop.sh
```

Windows 32 位构建（面向 Win2003/Win32，原生 Win32 widgetset）：

```bash
./scripts/build-win32.sh
```

输出为 `dist/win32-i386/TyEditor.exe`。

Windows 安装包（Wine + Inno Setup）：

```bash
./scripts/build-installer.sh
```

输出 `dist/TyEditorSetup-0.1.0.exe`。可通过 `ISCC=/path/to/ISCC.exe` 或 `WINE_PREFIX` 覆盖默认工具路径；卸载不会删除 `%APPDATA%\TyEditor`。Windows 构建使用原生 Win32 widgetset（Qt6 不提供官方 32 位 Windows 目标），目标为 Win2003 及之后的 32/64 位 Windows；exe 只静态导入经典系统 DLL，不依赖 Qt6 运行库。`data/` 与 `languages/` 已随 exe 复制到同一 `dist` 目录。

## 会话与设置位置

Linux 下为 `~/.config/TyEditor/`（从旧 TyEdit 升级时，首次启动会把旧配置复制到这里）：

- `running.marker`：运行标记；正常关闭会删除，异常退出后下次启动提示恢复会话。
- `session.json`：窗口、标签顺序、活动标签、每标签编辑状态。
- `session.json.bak`：上一次会话。
- `backups/<id>.txt`：未保存内容的 UTF-8 备份。
- `settings.json`：字体、缩进、视图、语言、最近文件、窗口位置。
- `macros/`：宏文件默认目录。

程序退出时不会因为未保存内容阻塞；单个标签关闭时仍会询问保存/不保存/取消。

## 常用快捷键

| 快捷键 | 功能 |
| --- | --- |
| Ctrl+N / Ctrl+O / Ctrl+S | 新建 / 打开 / 保存 |
| Ctrl+Shift+S | 全部保存 |
| Ctrl+W | 关闭当前标签 |
| Ctrl+F / Ctrl+H | 查找 / 替换 |
| F3 / Shift+F3 | 查找下一个 / 上一个 |
| Ctrl+Shift+F / Ctrl+Shift+H | 在文件中查找 / 替换 |
| Ctrl+G | 转到行 |
| F2 / Ctrl+F2 / Shift+Ctrl+F2 | 切换 / 下一个 / 上一个书签 |
| Ctrl+D / Ctrl+Shift+L | 复制行 / 删除行 |
| Ctrl+Shift+Up/Down | 上移 / 下移当前行 |
| Ctrl+Q | 切换行注释 |
| Ctrl+U / Ctrl+L | 转大写 / 转小写 |
| Ctrl+J | 合并行 |
| Ctrl+滚轮 | 缩放 |
| F11 | 全屏 |

## 界面语言

### 文本编辑器默认行为

ATSynEdit 的默认值偏向代码编辑器，TyEditor 在创建每个编辑器时改为文本编辑器语义：

- 光标不能越过行末；在短行右侧、空白区域点击时光标落在该行最后一个字符之后，不会产生虚拟空格，方向键也不会越过行末。
- 关闭自动缩进和自动闭合括号。
- 关闭“无选区时复制/剪切整行”。
- 关闭双击 URL 打开和字体连字。
- 默认只有一个光标；多光标仍可通过 `Ctrl+Alt+Up/Down` 显式添加。
- 保存时默认不删除行尾空格，也不强制末尾换行。

这些行为仍可在 `settings.json` 中通过 `auto_indent`、`auto_pair`、`trim_trailing_spaces`、`force_final_eol` 调整；虚拟光标不提供开关，保持文本编辑器语义。

默认 `"language": "auto"`：中文系统自动显示中文，其他系统回退英文。也可以显式设置：

```json
"language": "en"
```

或

```json
"language": "zh_CN"
```

`Settings > Preferences...` 会扫描 `languages/tyeditor.*.json`，把已安装语言列成下拉列表（`auto`、`English`、`简体中文` 以及新增的翻译文件），无需手动输入语言代码。中文菜单/对话框翻译位于 `languages/tyeditor.zh_CN.json`；TyControls 自带中文翻译位于 `languages/tycontrols.zh_CN.po`。

## 路线图

阶段 1 已完成；阶段 2 的实施计划见 [docs/PHASE2_PLAN.md](docs/PHASE2_PLAN.md)，任务/验收记录见 [docs/PHASE2_TASKS.md](docs/PHASE2_TASKS.md)，总路线见 [docs/ROADMAP.md](docs/ROADMAP.md)。

## 当前限制

- “在文件中查找/替换”是同步实现，适合常规项目；超大目录建议先缩小目录或通配符。
- 宏记录的是编辑器命令和文本插入，不记录鼠标点击、滚动和外部对话框。
- 尚未实现打印、拆分视图、UDL 自定义语言、插件系统和文件关联。
- 主题目前提供浅色/深色两套编辑器配色，未提供主题编辑器。

## 设置

`Settings > Preferences...`（快捷键 `Ctrl+Alt+P`）是一个单窗口、分类式设置对话框：

- **General**：界面语言（扫描 `languages/tyeditor.*.json`）、界面主题、深色模式、启动恢复会话、自动快照间隔。
- **Editor**：字体下拉框 + TyControls 字体对话框、字号、Tab 宽度、空格缩进、自动换行、空白字符、行号、行号显示方式（每行 / 每 5 行 / 每 10 行 / 相对行号 / 仅标记点）、当前行高亮、折叠、标尺、书签边栏、minimap/micromap、自动缩进、自动闭合括号、平滑滚动、光标闪烁、编辑器配色方案。

编辑区滚动条固定使用 ATSynEdit 主题化滚动条，不再提供系统原生滚动条选项。
- **Files**：默认编码、默认换行符、保存时去行尾空格、保存时确保末尾换行、最近文件数量。
- **Search**：默认区分大小写、全字匹配、正则、循环查找。

设置写入 `~/.config/TyEditor/settings.json`（Windows 为 `%APPDATA%\TyEditor`）。

## macOS 构建

```bash
./scripts/build-macos.sh
```

输出：

- `dist/macos-x86_64/TyEditor.app`
- `dist/macos-universal/TyEditor.app`（x86_64 + aarch64，使用 `llvm-lipo` 合并）

macOS 版本使用 Cocoa widgetset，从 Linux 交叉编译；Info.plist、`.icns` 图标、`data/`、`languages/` 已打包进 app bundle 的 `Contents/Resources/`。产物未做 Apple 签名/公证，首次打开可能需要右键“打开”，或自行执行 `codesign`。

## 编辑器配色方案

编辑器语法配色与 TyControls 界面主题分离，每个配色方案都提供 **浅色 / 深色两套 palette**，由当前 `View > Dark Theme` 自动选择。

内置方案：

| 方案 | 浅色 | 深色 |
| --- | --- | --- |
| TyEditor | ✓ | ✓ |
| One Dark | ✓ | ✓ |
| Solarized | ✓ | ✓ |
| Monokai | ✓ | ✓ |
| Dracula | ✓ | ✓ |
| Gruvbox | ✓ | ✓ |
| High Contrast | ✓ | ✓ |

设置位置：

- `View > Editor Color Scheme`：即时切换
- `Settings > Preferences... > Editor > Editor color scheme`：保存到 `settings.json`
- `settings.json` 的 `numbers_style` 字段控制行号显示方式：`all`、`each5`、`each10`、`relative`、`none`
- `settings.json` 的 `color_scheme` 字段：例如 `"One Dark"`

配色作用于编辑器背景、文字、行号栏、选择、当前行、光标、书签和 EControl 的注释/字符串/数字/关键字/函数/类型/标签/属性等 token 颜色；切换界面主题或配色时不需要重启。

## 界面主题

`View > Interface Theme` 列出 TyControls 内置主题（default、system、adwaita、aero、antdesign、bootstrap、breeze、classic、fluent、macos、material3、office、showcase、ubuntu、win10、win11、xp）。选择后立即应用到主窗口、查找/替换、在文件中查找等对话框，并保存到 `settings.json` 的 `theme` 字段。

`View > Dark Theme` 在主题的浅色/深色模式之间切换；`show_ruler`、`show_bookmark_margin` 默认均为 `false`。

## 图标

Logo 源文件为 `assets/tyeditor.svg`；运行时图标在 `data/icons/`：

- `tyeditor.svg`
- `tyeditor-256.png`、`tyeditor-128.png`、`tyeditor-64.png`、`tyeditor-32.png`
- `tyeditor.ico`（多尺寸）

程序启动时加载 `data/icons/tyeditor.ico`，并设置到 `Application.Icon` 与 TyControls 标题栏（`TitleBar.ShowIcon = True`）。

Windows 构建脚本会通过 `TyEditor.rc` 把该多尺寸图标编译进 PE 的 `.rsrc`，资源管理器、任务栏和 Alt+Tab 因此都有图标；不依赖 Lazarus 在命令行构建时生成 `.res`。

## 分屏、宏与书签

- `View > Split View (read-only)`（F8）在右侧显示只读副本，滚动和光标独立，不会覆盖编辑缓冲区。
- `Macro > Macro Manager...` 管理宏文件，`Ctrl+F9` 播放绑定宏。
- `Search > Bookmark List...` 显示全部书签，支持跳转/删除；书签菜单可选择 1–5 组，边栏颜色随组变化。
- `View > Editor Color Scheme > Edit / Import / Export...` 编辑或交换 JSON 配色方案。

## 第三方组件

- TyControls：见其仓库许可证。
- ATSynEdit / ATSynEdit_Ex：MPL 2.0 或 LGPL。
- EControl：见其仓库许可证。
- `data/lexlib/lib.lxl` 来自 ATSynEdit/CudaText 生态，随项目分发时保留来源说明。
