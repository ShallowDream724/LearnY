# Android 模拟器开发

Windows 上使用本地 Android SDK 和现有 AVD，保留已安装应用及用户数据：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/android_emulator.ps1
```

脚本从 `ANDROID_HOME`、`ANDROID_SDK_ROOT` 或 `%LOCALAPPDATA%\Android\Sdk` 查找 SDK，也可通过 `-SdkRoot` 指定。只有一个 AVD 时自动选择；多个时传 `-AvdName`。用 `-DryRun` 只检查路径并输出启动参数。

当前采用冷启动、4 个虚拟 CPU、硬件 OpenGL，并关闭 Vulkan、音频和快照读写。2026-09-10 的本机复现中，Emulator 36.4.10 / Android 36.1 在 SwiftShader 下进入课程页会触发宿主 `qemu-system-x86_64.exe` 的 `0xc0000005`；禁用 Vulkan 后仍会复现。同一个 APK 改为硬件 OpenGL 并禁用 Vulkan 后，课程卡片可以正常显示，连续 10 轮首页/课程切换通过。此配置是本机验证可用的运行方式，未据此断言底层故障已定位，也不改变 APK 的渲染配置。

安装并打开 APK（将 `adb` 替换为 SDK 下 `platform-tools/adb.exe`，如未加入 PATH）：

```powershell
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s emulator-5554 shell am start -n com.learny.learn_y/.MainActivity
```

验收应包含首页进入课程、滚动卡片、从「我的」切换壁纸后返回课程，并检查设备连接及应用进程是否持续存在。模拟器进程退出时同时保留启动日志和 Windows Application Error 记录；`adb logcat -b crash` 只记录 Android 内部崩溃，不能单独用于排除宿主故障。

build19 同时修正了应用中的独立绘制缺陷：课程页被 PageView 缓存时，位置投影可能是 NaN，旧实现会把它传给玻璃阴影的 `drawRRect`。真实页面切换的 Flutter 测试已能复现该错误；坐标保护让离屏层使用上次有效位置，返回时恢复实际映射。宿主访问冲突与这条非法绘制路径的关系需通过设备对照验证，不能单凭宿主进程名称排除应用触发因素。
