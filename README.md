# LearnY

<div align="center">

Premium Flutter client for Tsinghua University Web Learning（网络学堂）

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.x-6C63FF)](https://riverpod.dev/)
[![Drift](https://img.shields.io/badge/Drift-SQLite-0A7EA4)](https://drift.simonbinder.eu/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v0.1.1--beta-purple)](https://github.com/ShallowDream724/LearnY/releases)

[下载最新版](https://github.com/ShallowDream724/LearnY/releases) · [问题反馈](https://github.com/ShallowDream724/LearnY/issues)

</div>

---

## 项目简介

LearnY 是一个以**商品级体验**为目标的网络学堂客户端。

它不是简单的功能复刻，而是希望在以下三件事上同时做好：

- **好用**：课程、作业、通知、文件统一组织，信息密度高但不乱
- **可靠**：离线缓存、会话恢复、同步容错、统一文件访问链路
- **好看**：强调细节、动效、层次和克制的视觉语言，而不是堆功能

## 当前能力

| 模块 | 能力 |
| --- | --- |
| 登录 | WebView SSO、Cookie 会话恢复、可选安全静默重登 |
| 首页 | 今日课程、紧急作业、未读通知、未读文件、收藏入口 |
| 课程 | 课程总览、课程详情、课程内搜索、通知/文件/作业分栏 |
| 作业 | 状态筛选、详情、提交附件、已交记录、教师批改结果 |
| 通知 | 列表、详情、标记已读/未读、附件访问 |
| 文件 | 课程文件、通知附件、作业附件、反馈附件、统一下载与缓存 |
| 预览 | PDF、DOCX、XLSX 内置预览；其余格式按能力降级处理 |
| 数据 | Drift 本地缓存、响应式刷新、离线浏览、增量同步 |

## 设计目标

> 不是“能跑就行”，而是“长期迭代也不长成屎山”。

- **UI/UX 冻结为契约**：重构优先改状态流、依赖边界、会话编排，不随手改视觉
- **Feature 边界清晰**：页面负责展示，Provider 负责状态，Core 负责基础能力
- **文件链路统一**：课程文件、附件、缓存、预览、下载走同一套模型与服务
- **离线优先**：远端拉取失败时仍可浏览缓存，恢复在线后静默修正
- **安全克制**：会话状态与敏感凭据隔离，自动重新登录必须由用户显式开启

## 架构概览

```text
lib/
├── app/                   # App 装配
├── core/
│   ├── api/               # thu-learn-lib Dart port / API 解析
│   ├── auth/              # 会话状态、恢复编排、安全登录
│   ├── database/          # Drift schema / DAO / app state
│   ├── design/            # colors / typography / responsive / theme
│   ├── files/             # 文件模型、访问解析、统一预览能力
│   ├── providers/         # 全局注入与偏好状态
│   ├── router/            # GoRouter / ShellRoute
│   ├── services/          # 下载、缓存、文件服务
│   └── sync/              # 同步引擎与冷却策略
├── features/
│   ├── assignments/       # 作业列表 / 详情 / 提交
│   ├── auth/              # 登录页
│   ├── courses/           # 课程页 / 详情 / 课程内搜索
│   ├── files/             # 收藏文件 / 未读文件 / 文件详情
│   ├── home/              # 首页聚合 / 今日课程
│   ├── notifications/     # 通知详情
│   ├── profile/           # 个人页 / 设置
│   └── search/            # 全局搜索
└── main.dart
```

## 技术栈

| 类别 | 方案 |
| --- | --- |
| Framework | Flutter + Dart |
| State | Riverpod |
| Routing | GoRouter |
| Local DB | Drift / SQLite |
| Network | Dio + CookieJar |
| Secure Storage | flutter_secure_storage |
| Animation | flutter_animate |
| Fonts | Google Fonts |

## 为什么不是传统“校园工具味”

- 信息布局尽量压缩，但保留呼吸感
- 首页不是简单列表堆砌，而是按“今天最值得看什么”组织
- 文件不是散落在多个页面里临时处理，而是有统一下载、缓存、路由和预览能力
- 会话管理不是“过期就踢”，而是尽量先无感恢复，再退回用户确认

## 开发

### 环境

- Flutter 3.x
- Dart 3.11
- Android SDK / Windows desktop toolchain

### 启动

```bash
flutter pub get
flutter run
```

### 常用校验

```bash
flutter analyze
flutter test
flutter build apk --release
```

## 路线图

- 更完整的文件预览能力与更强的文档体验
- 课程排序、自定义图标、主题系统深化
- 课表能力继续打磨：缓存、交互、课程详情联动
- 个人页和信息展示继续精修
- Windows / Android 发布流程继续稳定化

## 说明

- 本项目为非官方第三方客户端，与清华大学官方无隶属关系
- 请仅用于个人学习与课程管理，不要进行滥用请求或破坏性操作
- 网络学堂相关接口可能随学校端调整而变化

## License

MIT
