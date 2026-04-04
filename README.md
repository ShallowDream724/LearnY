# LearnY

<div align="center">

清华大学网络学堂第三方客户端

[![Release](https://img.shields.io/github/v/release/ShallowDream724/LearnY?display_name=tag&label=Release)](https://github.com/ShallowDream724/LearnY/releases)
[![Platform](https://img.shields.io/badge/Platform-Android_APK-3DDC84?logo=android&logoColor=white)](https://github.com/ShallowDream724/LearnY/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Stars](https://img.shields.io/github/stars/ShallowDream724/LearnY?style=flat&label=Stars)](https://github.com/ShallowDream724/LearnY/stargazers)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[下载最新版](https://github.com/ShallowDream724/LearnY/releases/latest) · [更新日志](CHANGELOG.md) · [问题反馈](https://github.com/ShallowDream724/LearnY/issues)

如果这个项目对你有帮助，欢迎点一个 Star，这会让 LearnY 更容易被更多同学看到。

</div>

---

## LearnY 是什么

LearnY 面向清华大学网络学堂的日常使用场景，围绕课程、作业、通知和文件，提供一套更适合手机使用的客户端体验。

它的目标不是把网页简单搬进 App，而是把真正高频的内容重新组织起来，让你更快看到今天该看的课、该交的作业、未读通知和需要处理的文件。

## 当前提供的能力

- 首页聚合今日课程、紧急 DDL、未读通知、未读文件和收藏入口
- 课程页支持课程总览、课程详情、课程内搜索，以及通知 / 作业 / 文件统一查看
- 作业页支持状态筛选、提交记录、教师评语和反馈附件查看
- 通知支持已读 / 未读管理，附件可直接进入统一文件链路
- 文件支持收藏、下载、缓存、ZIP 浏览和 PDF 内置预览
- 全局搜索可覆盖课程、通知、作业、文件与附件，并支持拼音和常见后缀关键词
- 支持本地缓存、离线浏览、同步刷新，以及用户显式开启的自动重新登录

## 下载与平台

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Android | 已提供 | 当前公开发布以 APK 为主，请前往 GitHub Releases 下载 |
| iOS | 暂未公开提供 | 仓库中保留了 iOS 工程，但目前没有 macOS / Xcode 打包与签名环境 |

目前仓库首页暂不放真实课程截图，避免把个人课程数据直接公开在宣传页里。后续如果补展示图，会使用假数据重新生成。

## 适合用来做什么

- 更快查看今天最值得关注的课程与作业
- 用更集中、更顺手的方式管理课程通知和附件
- 在移动端稳定查看缓存内容，而不是每次都回网页里找
- 把课程文件、通知附件、作业附件放进同一条访问链路里处理

## 功能亮点

### 首页

- 今日课程、紧急作业、未读通知、未读文件集中展示
- 收藏文件提供轻量入口，减少来回翻课程页

### 课程

- 课程列表支持排序与自定义图标
- 课程详情把通知、作业、文件整合到同一处
- 课程内搜索直接覆盖课程相关内容，而不是只搜单一类型

### 作业

- 可查看截止时间、提交状态、提交记录和教师评语
- 支持将“无需提交”的作业降到列表底部，减少首页和作业页干扰

### 文件

- 统一处理课程文件、通知附件、作业附件、教师反馈附件
- ZIP 支持浏览压缩包内容
- PDF 提供内置阅读体验；其余文档格式优先调用系统或外部应用打开

### 搜索

- 支持课程、通知、作业、文件混合搜索
- 支持附件命中、拼音匹配、收藏 / 下载等意图词，以及常见后缀关键词

## 技术实现

| 类别 | 方案 |
| --- | --- |
| Framework | Flutter + Dart |
| State | Riverpod |
| Routing | GoRouter |
| Local Data | Drift / SQLite |
| Network | Dio + CookieJar |
| Secure Storage | flutter_secure_storage |
| File Preview | pdfrx + archive + external open fallback |

## 开发

### 环境

- Flutter 3.41.x
- Dart 3.11.x
- Android SDK

### 启动

```bash
flutter pub get
flutter run
```

### 校验

```bash
flutter analyze
flutter test
flutter build apk --release
```

## 路线图

- 继续打磨主题系统与课程页自定义能力
- 继续提升文件预览与阅读体验
- 逐步补齐更完整的对外展示素材
- 在具备 macOS 环境后推进 iOS 打包与分发

## 说明

- 本项目为非官方第三方客户端，与清华大学官方无隶属关系
- 请仅用于个人学习与课程管理，不要进行滥用请求或破坏性操作
- 网络学堂相关接口可能随学校端调整而变化

## License

MIT
