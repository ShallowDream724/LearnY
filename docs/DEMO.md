# 本地示例环境

使用独立入口体验首页、学期切换、课程、作业、通知和文件流程：

```sh
flutter run -d windows -t lib/main_demo.dart
flutter run -d <android-device-id> -t lib/main_demo.dart
```

示例有三个学期。当前学期包含待交、已交和已评分作业，截止时间相对启动时间生成。学校当前学期与界面选中的学期分别存储，切换历史学期不会修改学校当前学期。

```sh
flutter run -d windows -t lib/main_demo.dart --dart-define=LEARNY_DEMO_PREVIOUS_SEMESTER=true
flutter run -d windows -t lib/main_demo.dart --dart-define=LEARNY_DEMO_NETWORK=offline
flutter run -d windows -t lib/main_demo.dart --dart-define=LEARNY_DEMO_NETWORK=slow
```

`normal` 为默认模式；`offline` 在显示种子缓存后让 API 请求失败；`slow` 为每次 API 请求增加两秒延迟。自动同步和手动同步使用同一套示例 API，作业提交仅更新内存，后续同步能够读回提交结果。

数据库、Cookie 和安全凭据均在内存中。文件下载从示例 API 的内存字节生成，文件工作区位于操作系统临时目录下新建的 `learny-demo-*` 子目录；不会打开正式数据库、凭据库或文档目录。Dart HTTP 客户端被禁止，更新检查使用本地结果。示例身份固定，退出登录保持示例会话，避免进入真实 SSO WebView。重启进程可恢复初始数据。

强制结束进程或热重启可能留下独立的临时文件目录，可通过系统临时文件清理功能删除。示例运行不验证真实登录、真实学校服务、系统分享或外部浏览器。文件预览支持示例文本文件；作业支持正文提交，附件上传未模拟。
