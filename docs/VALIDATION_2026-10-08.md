# 2026-10-08 导航与课程返回修复

本地版本为 `0.1.5+42`，对应底栏轻点、Android 侧滑返回和课程列表末项遮挡三项反馈。

## 根因与实现

- 底栏原来在按下时直接朝完整透镜放大，短点抬起又立刻朝零回缩；位移速度还会独立触发大幅拉伸。`NavigationPressMotion` 为轻点提供小幅完整响应，继续按住或横向拖动才展开完整透镜；拉伸随按压幅度变化，抬起立即提交导航，不等待反馈动画。计时器随取消、减少动态效果和销毁清理，弹簧保留中断时的位置与速度。
- 普通系统返回没有复现丢失课程，Android `flutter/backgesture` 的真实平台消息路径复现了一次侧滑从文件页直接退到 `/courses`。根详情和嵌套课程路由同时响应预测返回。`ShellBranchBackScope` 汇总根路由可见性及当前分支，`ShellBranchRoute` 在分支详情自己的路由内限制 `PopScope`，确保只关闭最上层。没有重建来源课程来模拟恢复。
- 课程通知、文件、作业列表原来固定留白 32 dp。现在统一使用导航实际高度（含手势区）与 Scaffold 注入 padding 的较大值，内层 Scaffold 消耗 padding 后也成立；不重复相加。三类列表和空态都采用同一规则。

## 验证

- `flutter test --no-pub test/core/shell test/features/files/file_type_filter_navigation_test.dart`：15 项通过。
- 课程测试使用实际 `LearnYApp`、路由与隔离演示数据库，390×844 视图、24 dp 系统手势区。覆盖通知／文件／作业各 20 条数据，Android 预测返回取消与完成、作业附件逐层返回、隐藏课程分支不被误退、课程自身再次返回、原页签／实例／滚动位置保留。滚到底时，三个列表最后一张完整卡片均位于浮动导航上方。
- 轻点覆盖 0／16／60 ms，确认单次小幅响应、没有第二次放大；长按、拖动、快速再按、取消、减少动态效果与销毁正常。实际底栏回调在抬手时立即发生，原有拖动预览、键盘、语义、导航对比与筛选菜单返回检查通过。
- `flutter analyze --no-pub lib test tool` 无问题；`git diff --check` 通过。

这些检查验证 Flutter 行为与几何，不替代用户在 Android 设备上判断轻点手感。测试未操作真实学校账户、提交作业或启动用户桌面应用。

本地日志：`output/navigation42-tests.log`、`navigation42-analyze.log`。修复前的预测返回失败证据：`output/navigation42-predictive-repro.log`。

## 本地安装包

Android 和 Windows 正式入口 release 构建完成，版本均为 `0.1.5+42`。APK 包名 `com.learny.learn_y`、versionCode 42；签名 SHA-256 延续 `a103a8442a1431d781f05e9d2ef2bf5c4ead155934fa7a343dc2e1a115833269`，可覆盖已有安装。Windows 已覆盖 `build/windows/x64/runner/Release`。打包检查三份 shader 和运行时文件齐全。

交付目录：`dist/releases/v0.1.5-build42/`。APK SHA-256：`bdf6328ccc11cd849bd2ef63eee9dbef2874a2ad88b5e72c3c3da425b6b56d86`；Windows ZIP SHA-256：`6ce7da6f13809424b228539169220d1c2d739db3e914402e0f83c1055a8796c5`。

构建与打包日志：`output/navigation42-android-build.log`、`navigation42-windows-build.log`、`navigation42-package.log`、`navigation42-signature.log`。本轮为本地迭代，未替换公开 Release。
