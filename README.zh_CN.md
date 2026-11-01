<p align="center"><img src="assets/branding/tyeditor.svg" width="96" height="96" alt="TyEditor"></p>

# TyEditor

**基于 Lazarus / Free Pascal 构建的轻量、跨平台文本编辑器。**

TyEditor 面向 Linux、Windows 和 macOS，保留经典文本编辑器的使用习惯：多标签、会话恢复、编码转换、查找替换、宏、书签和语法高亮。它**不是 IDE**：没有 LSP、终端、调试器、工程/工作区、Git 集成或代码智能功能。

[English](README.md) · [简体中文](README.zh_CN.md)

<p align="center"><img src="assets/screenshot.png" width="820" alt="TyEditor 截图"></p>

## 功能亮点

- **原生、快速**：使用 Lazarus/LCL 与 TyControls；Linux 使用 Qt6，Windows 使用原生 Win32，macOS 使用 Cocoa。
- **工作内容可恢复**：恢复标签、光标、选区、滚动位置、编码/换行符、语言、书签和折叠状态；未保存内容写入备份，异常退出后下次启动可恢复。
- **编码感知**：自动识别 UTF-8/16/32 BOM、ANSI 代码页、GBK、Big5、Shift-JIS、EUC-KR 等；可在状态栏转换编码或按编码重新载入。
- **搜索不阻塞界面**：查找/替换支持正则、大小写、全字和选区内模式；在文件中查找/替换异步执行，支持进度、取消和结果导出。
- **文本编辑器语义**：多光标、列编辑、行操作、注释切换、括号跳转、宏和书签。
- **58 个内置语法词法**：19 个 EControl 词法与 39 个 TyEditor 语言定义，按扩展名自动识别。高亮为词法级：关键字、类型、常量、字符串、注释、数字和运算符。
- **可安装插件 v1**：`.typlugin` 插件包拥有独立清单、命令、选项和翻译。进程与 PascalScript 运行时共用 JSON 请求/响应边界；可在插件管理器中安装、启用、重载和卸载。
- **外部工具**：在 **工具 > 管理工具...** 中配置自己的命令。工具从标准输入接收选区或整个文档，向标准输出写回结果，支持 `${file}`、`${line}` 等占位符，并在后台运行，可取消、可设超时。外部工具与插件系统相互独立。
- **适合长时间阅读**：7 套编辑器配色方案（每套含浅色/深色）、TyControls 界面主题、minimap/micromap、行号、标尺、空白字符显示，以及 `F8` 只读文档地图。
- **打印与自定义**：打印预览、可选打印选区、语法高亮打印、页边距、页眉/页脚和行号；重新设计的偏好设置与键盘快捷键编辑器，无需手改 JSON 即可配置。
- **桌面集成**：单实例命令行打开、拖放打开、Linux 桌面入口、Windows 安装包（可选关联 `.txt`）和 macOS app bundle。

## 快速开始

### 从源码构建

需要 Lazarus、FPC、TyControls、ATSynEdit、ATSynEdit_Ex、EControl、EncConv、Printer4Lazarus 和 PascalScript 组件包。Linux 还需要 Qt6 开发库。

```bash
git clone https://github.com/ACTom/TyEditor.git
cd TyEditor
cp scripts/env.example.sh scripts/env.local.sh
# 根据本机路径修改 lazbuild、TyControls 和 CCR 路径。
./scripts/build.sh
```

默认目标为 Linux x86_64 / Qt6，产物位于
`dist/linux-x86_64/TyEditor`。其他目标：`linux-aarch64`、`win32`、`win64`、
`macos`（Intel x86_64 与 Apple Silicon arm64 两个版本）、`macos-x86_64`、
`macos-aarch64` 和 `all`。

完整依赖、交叉编译和打包命令见[构建与安装](docs/user/installing.md)。

### 运行

```bash
dist/linux-x86_64/TyEditor
dist/linux-x86_64/TyEditor 文件1.txt 文件2.md
```

首次启动时创建配置和会话目录：

| 平台 | 配置目录 |
| --- | --- |
| Linux | `~/.config/TyEditor/` |
| Windows | `%APPDATA%\TyEditor\` |
| macOS | `~/Library/Application Support/TyEditor/` |

## 文档

| 文档 | 内容 |
| --- | --- |
| [构建与安装](docs/user/installing.md) | 依赖、构建目标、打包和桌面安装 |
| [使用指南](docs/user/features.md) | 会话、编码、搜索、编辑、视图和设置 |
| [语言与语法高亮](docs/user/languages.md) | 内置语言、扩展名和限制 |
| [插件](docs/user/plugins.md) | 安装、使用和编写插件 |
| [外部工具](docs/user/tools.md) | 配置作用于当前文档的命令 |
| [快捷键](docs/user/shortcuts.md) | 菜单快捷键和常用编辑按键 |
| [架构](docs/dev/ARCHITECTURE.md) | 源码结构和扩展点 |
| [构建与发布流程](docs/dev/BUILDING.md) | 脚本流程、交叉编译和发布检查 |
| [插件协议](docs/dev/PLUGIN_PROTOCOL.md) | 包格式、清单、运行时和 JSON 协议 |
| [测试](docs/dev/TESTING.md) | 自动化测试和手工验收清单 |
| [路线图](docs/dev/ROADMAP.md) | 当前范围和后续计划 |

## 插件

TyEditor v1 插件是可直接安装的 `.typlugin` 包：ZIP 根目录包含 `plugin.json`，并可选带 `locales/` 翻译和插件自身的脚本或可执行文件。插件包声明独立 ID、版本、编辑器/平台兼容范围、运行时、权限、命令和选项。同 ID 的用户插件会覆盖内置插件。

内置示例位于 `data/plugins/`：

- **Base64 Tools**：编码/解码当前选区。
- **Text Tools**：转大写、转小写、标题大小写、去除行尾空格。
- **Caesar Cipher**：演示加密/解密（移位 3，不安全，仅作示例）。
- **JSON Formatter**：格式化/压缩 JSON，支持缩进和键排序选项。

四个示例都使用内嵌的 PascalScript 运行时，在所有受支持的平台上都能运行，无需外部解释器。若要运行 `clang-format` 等外部格式化工具，请改用 **工具 > 管理工具...** 配置，而不是安装插件。

使用 **插件 > 管理插件...** 安装插件包、启用/禁用、重载、打开用户插件目录或卸载。管理状态保存在 `plugins.json`；不兼容插件仍会显示，但会被禁用并给出原因。插件在后台运行并支持取消；进程插件还支持超时和捕获 stderr。每个插件包拥有独立翻译，按精确区域、基础语言、默认区域和英语依次回退。

安装和使用插件见 [docs/user/plugins.md](docs/user/plugins.md)；开发插件见 [docs/dev/PLUGIN_PROTOCOL.md](docs/dev/PLUGIN_PROTOCOL.md)。

## 外部工具

外部工具是用户自行配置的普通命令，不属于插件，也不会从 `.typlugin` 包安装。打开 **工具 > 管理工具...** 即可添加命令、选择标准输入来源（无、选区或整个文档）、选择输出去向，并设置超时。参数每行一个，不经过 shell。`${file}`、`${dir}`、`${line}`、`${col}`、`${lexer}`、`${inputfile}` 等占位符把命令与当前文档和光标位置连接起来。

启用的工具会直接出现在 **工具** 菜单中。执行在后台线程进行，可随时取消；非零退出码、超时和命令缺失都会连同标准错误一起提示。工具定义保存在配置目录的 `tools.json` 中。

完整选项和示例见 [docs/user/tools.md](docs/user/tools.md)。

## 范围

TyEditor 专注于成为一款好用的文本编辑器：

- 不提供语言服务器、补全引擎或诊断面板。
- 不提供内置终端、调试器或项目任务运行器。
- 不提供工程/工作区模型或 Git 集成。
- 不提供可编辑分屏；`F8` 只打开只读文档地图。

## 许可证

TyEditor 使用 [Apache License 2.0](LICENSE)。第三方组件和数据保留各自许可证，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 和 [NOTICE](NOTICE)。
