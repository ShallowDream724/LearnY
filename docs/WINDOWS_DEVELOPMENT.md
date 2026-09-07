# Windows 开发与验收

## 环境

使用 Flutter 3.41.x、Dart 3.11.x、Git，以及带“使用 C++ 的桌面开发”的 Visual Studio Build Tools 和 Windows SDK。真实 SSO 还需要 WebView2 Runtime。先运行 `flutter doctor -v` 和 `flutter pub get`。

Windows 原生开发不需要 Android 模拟器。`flutter run -d windows` 支持热重载；安卓也可以通过 USB 或无线调试真机热重载。修改共用业务逻辑会同时影响两端，仍需分别构建和验收插件、权限及输入行为。

## 启动与构建

在项目目录的 PowerShell 中：

```powershell
# 隔离示例，支持热重载
.\tool\windows_dev.ps1 -Demo

# 正式入口，使用本机真实账户与缓存
.\tool\windows_dev.ps1

# 示例断网或延迟
.\tool\windows_dev.ps1 -Demo -Network offline
.\tool\windows_dev.ps1 -Demo -Network slow -PreviousSemester

# 构建，不启动窗口
.\tool\windows_dev.ps1 -Action build -Demo
.\tool\windows_dev.ps1 -Action build -Configuration release
```

示例 debug 可执行文件在 `build/windows/x64/runner/Debug/learn_y.exe`；正式 release 在 `build/windows/x64/runner/Release/learn_y.exe`。必须保留同目录 DLL 和 `data/`，不能只复制 EXE。入口和编译参数会覆盖同一构建配置的上一次输出。

脚本只在当前命令进程内整理 PATH 和 PATHEXT，确保 MSBuild 内部能找到 `where.exe`、Git 和 Flutter，执行结束恢复原环境。它不修改系统环境变量。本机曾因继承的异常 PATH 导致嵌套 Flutter 报 `Unable to find git in your PATH`。

## 自动检查

```powershell
conda activate aider
.\tool\windows_dev.ps1 -Action test
flutter analyze --no-pub lib test
```

本机测试必须优先加载 aider 的 `Library/bin/sqlite3.dll`。若出现 `sqlite3_initialize` 符号缺失，应检查 DLL 搜索顺序，避免加载 LibreOffice 自带的同名库。构建日志可能提示 `Nuget is not installed`；本机后续自动下载步骤成功，最终以构建退出码和产物为准。

## 人工验收重点

- 在正常、窄窗口和最大化状态查看首页、作业、课程及学期弹窗，检查文字、滚动和遮挡。
- 首页课表检查上一周、下一周、日期跳转和回到今天；在 9 月 7 日所在周之后仍可继续查询。日 / 周视图都应可用，焦点在课表时检查方向键、Home、End。
- 用空周、稀疏周、每天六节课及周末有课的数据检查布局。宽屏周概览仅在确认数据后隐藏空周末，可从显示选项恢复；手机按日查看，三节以上可展开。课程有唯一匹配时可进入详情。
- 宽布局学期入口、同步状态与刷新在侧栏，窄布局在顶部。检查作业与通知在正常课表下的可见性，以及空作业时的提醒设置入口。
- 课表刷新失败时应保留已缓存课程，并显示更新失败；空缓存请求失败不应显示“今天没有课”。
- 切到上一学期、当前学期，再快速往返；列表与搜索结果必须属于选中学期。正式入口重启后应保留选择。
- 刷新、模拟断网、恢复网络后重试，检查本地内容可浏览，加载能结束，错误可查看。
- 点击通知或文件主体应打开内容；右侧“标为已读”应只改变读状态。作业右键及“更多”应打开操作菜单。
- 验证真实登录、文件打开、正文和附件提交；这些需要人工连接学校服务，示例环境不能替代。

真实 Windows 窗口、鼠标、键盘与视觉验收由项目负责人完成。自动检查不声称完成这些人工项目。

已收到的人工结果：Windows 自动重新登录成功，恢复方式为 SSO 漫游。新的课表导航等待下一轮人工反馈。

课表和首页的离线截图检查见 `tool/ui_preview/README.md`，不连接真实账户、不启动桌面窗口。它补充布局检查，不替代真实学校数据和鼠标手感验收。
