# TyEditor 阶段 2 任务与验收记录

状态：阶段 2 计划项已落地。以下每项都列出了验收方式；“可选”项按计划明确不强制启用。

## 2.1 编码

- [x] BOM/UTF-8/UTF-16/GBK/Big5/Shift-JIS/EUC-KR 自动检测。
- [x] 低置信度不自动改编码（阈值 60，用户可从 Encoding 菜单手动重载）。
- [x] 每文件编码记忆（`settings.json` 的 `encoding_by_file`）。
- [x] 最近编码菜单、BOM 添加/移除（选择对应 Encoding 名称）、按编码重载。
- [x] `tests/testencoding` 覆盖样本矩阵。

验收：`./tests/testencoding` 全 PASS；GUI 打开 GBK/Big5/Shift-JIS/EUC-KR 文件状态栏编码正确；UTF-8 BOM 保存后字节仍为 `EF BB BF`。

## 2.2 会话与备份

- [x] `running.marker` 崩溃标记与恢复提示。
- [x] 恢复提示显示会话路径、修改时间、标签数、最近 5 个快照。
- [x] 备份目录、保留数量、快照间隔可配置。
- [x] `session.json` 通过临时文件写入，保留 `.bak` 回退。
- [x] 会话和未保存内容统一保存为原子 JSON，保留 `.bak`；不再生成未使用的定时 `session_*.json` 快照。
- [x] 正常关闭删除标记；最后一个标签关闭语义不变。

验收：kill 进程后重启出现提示并可恢复；自定义 `/tmp/tybackups` + `backup_keep=2` 时只保留 2 个文本备份和 2 个快照；正常关闭后 lock/marker 删除。

## 2.3 在文件中查找

- [x] 工作线程扫描，UI 定时取结果。
- [x] 进度计数、Stop/取消。
- [x] 包含/排除目录、通配符、子目录。
- [x] 结果导出文本/JSON (`Search > Export Results...`)。
- [x] 替换仍在 UI 线程执行，替换前确认且不覆盖正在运行的搜索。
- [x] `tests/testfindasync` 验证结果、排除和取消。

验收：`./tests/testfindasync` 输出 `35`、`30`、取消任务不崩溃；GUI 搜索时窗口可操作，Stop 生效。

## 2.4 标签页

- [x] 标签右键菜单（关闭、关闭其他、关闭右侧、复制路径、打开目录、固定、重开）。
- [x] 固定标签不参与 Close Others/Close All，X 关闭会提示先取消固定。
- [x] `Ctrl+Shift+T` 重开最近关闭标签，恢复路径/内容/编码/光标。
- [x] `View > Open Tabs` 溢出列表。
- [x] 固定状态写入会话。

验收：固定标签重启后仍固定；关闭中间标签不误关下一个；重开未保存标签恢复内容。

## 2.5 编辑与查找体验

- [x] 缩进参考线设置（默认关闭）。
- [x] `Ctrl+B` 跳转匹配括号。
- [x] 每语言 Tab 宽度/空格/自动缩进覆盖（`settings.json` 的 `language_indent`）。
- [x] 查找历史下拉。
- [x] 正则/普通替换预览。
- [x] 选区内查找、结果列表、结果过滤。
- [x] 行操作和多光标保持既有显式命令。
- [ ] 自动补全（计划标为可选，默认关闭，未启用）。

验收：默认文本模式无自动缩进/自动括号/虚拟空格；语言覆盖切换 lexer 后生效，切回纯文本恢复全局值；预览取消不改文件字节。

## 2.6 宏与书签

- [x] 宏管理窗口：加载、删除、重命名、导入、导出。
- [x] 绑定宏与 `Ctrl+F9` 播放。
- [x] 旧 JSON 宏格式兼容。
- [x] 书签列表：跳转、删除、按组显示。
- [x] 书签 1–5 组、组颜色、会话持久化。
- [ ] 鼠标点击/滚动录制（计划标为可选，默认关闭，未启用）。

验收：管理窗口可完成文件操作；`Ctrl+F9` 播放绑定宏；书签组/颜色重启后保留。

## 2.7 界面与系统集成

- [x] F8 只读分屏/文档预览，滚动和光标独立，不共享编辑缓冲区。
- [x] 配色方案编辑器（TTyPropertyGrid + TyControls 颜色编辑）、导入、导出 JSON。
- [x] 单实例：第二实例把文件交给第一实例并退出。
- [x] Windows Inno Setup 脚本、Linux desktop/安装脚本、文件关联注册。
- [x] Wine + Inno Setup 实际生成 `dist/TyEditorSetup-0.1.0.exe`，静默安装/卸载验证通过，卸载保留 `%APPDATA%\TyEditor`。
- [x] 只读/长路径/网络路径验收步骤写入 `docs/TESTING.md`。

验收：F8 两侧滚动独立；颜色方案使用属性网格和颜色对话框，重启后仍生效；第二实例退出并触发第一实例打开文件；安装脚本卸载不删除 `%APPDATA%\TyEditor`。

## 2.8 测试与出口

- [x] `tests/testencoding`。
- [x] `tests/testfindasync`。
- [x] Linux Qt6、Windows i386、macOS universal 构建。
- [x] 手工验收清单 `docs/TESTING.md` 更新。
- [x] README/ROADMAP/PHASE2_PLAN/TESTING 同步。

构建命令：

```bash
./scripts/build.sh
./scripts/build-win32.sh
./scripts/build-macos.sh
./scripts/build-installer.sh
./tests/testencoding
./tests/testfindasync
```
