# 手工验收清单

以下步骤在 Linux x86_64 / Qt6 上验证。每次修改会话、编码或标签生命周期后至少执行 1-3 节。

## 1. 构建与启动

1. 运行 `./scripts/build.sh`，应无错误并生成 `dist/linux-x86_64/TyEditor`。
2. 运行 `./scripts/build-win32.sh`，应生成 `dist/win32-i386/TyEditor.exe`。
3. 直接运行 `dist/linux-x86_64/TyEditor`，应显示 `TTyForm` 窗口、标题栏内菜单、一个 Untitled 标签和状态栏。
4. 在编辑器中输入文字，标题出现 `*`，状态栏行列/行数更新。

## 2. 多标签与会话恢复

1. 新建两个标签，分别输入不同内容，不保存。
2. 关闭程序（窗口关闭按钮）；不应出现保存提示。
3. 重新运行 `./TyEditor`；两个标签、内容、活动标签、光标位置应恢复。
4. 切换标签，确认每个标签的光标/选区/滚动位置独立。
5. 关闭一个未保存标签；应出现“保存/不保存/取消”对话框；选择“不保存”后标签关闭。
6. 检查 `~/.config/TyEditor/session.json` 和 `backups/` 中存在对应记录和备份。
7. 等待 30 秒不退出，强制结束进程；重新启动后应从最近快照恢复。

## 3. 编码与换行符

1. 打开一个 UTF-8 文件，状态栏显示 `UTF-8`。
2. 打开一个带 BOM 的 UTF-16 文件，状态栏显示 `UTF-16 ... with BOM`。
3. 打开 GBK 文件：状态栏通常先显示 `ANSI (cp1252)`；点击状态栏编码面板，选择 `Reload with > ANSI cp936 / GBK`，中文应正确显示。
4. 再点击编码面板，选择 `Convert to > UTF-8`，保存；用外部工具确认文件变为 UTF-8。
5. 打开 CRLF 文件，状态栏显示 `CRLF`；点击 EOL 面板选择 `Unix (LF)`，保存后确认文件使用 LF。
6. 打开混合换行文件，状态栏应显示 `Mixed ...`。

## 4. 查找/替换

1. Ctrl+F 打开查找窗口，查找内容应自动带出选中文字或当前单词。
2. 测试大小写、全字、正则、循环、选区内选项。
3. 测试 Find All，双击结果行应跳转到对应位置。
4. Ctrl+H 测试替换和全部替换，确认撤销可用。

## 5. 在文件中查找/替换

1. 打开 Search > Find in Files。
2. 选择目录、通配符（例如 `*.pas`）、查找内容，点击 Find All。
3. 底部搜索结果面板应显示 `文件:行:列: 文本`；双击跳转到对应文件位置。
4. 使用 Replace in Files 前应弹出确认；替换后保留原编码和换行符。

## 6. 书签、折叠、视图

1. 在若干行按 F2，添加/删除书签；Ctrl+F2 / Shift+Ctrl+F2 跳转。
2. 关闭并重启，书签应恢复。
3. 打开 Pascal/C 文件，确认折叠标记和语法高亮。
4. 新建标签默认只显示行号；标尺、书签边栏默认关闭；打开代码文件时折叠边栏出现。
5. `View > Interface Theme` 切换 `breeze`、`antdesign`、`system` 等主题；主窗口和查找/替换对话框背景同时变化。
6. 切换自动换行、空白字符、行号、折叠、标尺、书签边栏、minimap、micromap、深色主题；重启后设置应保留。

## 7. 宏

1. Macro > Start/Stop Recording，输入一段文本，停止录制。
2. 将光标移到别处，Macro > Play；文本应按录制顺序插入。
3. Play N Times 输入次数，确认重复播放。
4. Save Macro / Load Macro 保存并重新载入 `.json` 宏。

## 8. 语法高亮

1. 打开 `TyTest.pas`，状态栏语言应显示 `Pascal`，关键字/注释/字符串有颜色。
2. 打开无扩展名或未知文件，语言显示 `Plain text`。
3. 使用 Language 菜单手动切换/关闭语言。

## 9. 国际化

1. 删除 `~/.config/TyEditor`，在 `LANG=zh_CN.UTF-8` 下启动，界面应为中文（`auto` 跟随系统）。
2. 在 `LANG=en_US.UTF-8` 下启动新配置，界面应为英文。
3. Settings > Preferences 的语言列表应包含 `auto (system)`、`English`、`简体中文`；选择后重启生效。
4. 在 `languages/` 增加 `tyeditor.ja.json`，重新打开 Preferences 应自动出现该语言。

## 10. 阶段 2 新增验收

1. 编码：分别打开 UTF-8、UTF-8 BOM、UTF-16 LE/BE、GBK、Big5、Shift-JIS、EUC-KR 文件，状态栏编码正确且中文/日文/韩文无乱码。
2. 单实例：先启动一个实例，再执行 `TyEditor /path/file.txt`；第二个进程应退出，文件在第一个实例打开。
3. 异步查找：在包含大量文件的目录执行 Find in Files，窗口应保持可操作；点击 Stop 后不再追加结果。
4. 查找体验：Find 对话框应有历史下拉、Preview 按钮、选区查找和结果列表。
5. 标签页：固定标签不参与 Close Others/Close All；`Ctrl+Shift+T` 重开最近关闭标签；`View > Open Tabs` 列出全部标签。
6. 崩溃恢复：kill 进程后重启，提示包含会话路径、修改时间、标签数和最近快照。
7. 分屏：F8 打开右侧只读副本，滚动主编辑器和副本互不影响。
8. 宏管理器：加载/删除/重命名/导入/导出宏；`Ctrl+F9` 播放绑定宏。
9. 书签：`Bookmark List` 跳转/删除；选择不同组后书签颜色变化，重启后组和颜色保留。
10. 配色方案：编辑/导入/导出 JSON，重启后仍使用自定义方案。
11. 只读/长路径/网络路径：打开并保存只读文件应报权限错误且不崩溃；长路径和网络挂载路径应能正常打开/保存。

## 11. 独立测试

```bash
/home/Tom/fpcupdeluxe/lazarus/lazbuild \
  --pcp=/home/Tom/fpcupdeluxe/config_lazarus tests/testencoding.lpi
./tests/testencoding

/home/Tom/fpcupdeluxe/lazarus/lazbuild \
  --pcp=/home/Tom/fpcupdeluxe/config_lazarus tests/testfindfiles.lpi
./tests/testfindfiles /tmp '*.pas' WriteLn
```

预期至少输出一行 `RESULT N matches in M files`。
