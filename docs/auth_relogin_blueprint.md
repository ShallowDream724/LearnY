# LearnY 认证与自动重登重构蓝图

> 目标：把“首次登录”“自动重新登录授权”“会话过期恢复”“用户引导”收敛成一套统一架构，避免当前两套浏览器上下文、状态语义不清、用户重复输入密码的问题。

---

## 1. 先定义问题

当前实现存在 4 个核心问题：

1. 普通登录流与自动重登 enrollment 流割裂。
   普通登录在 [login_screen.dart](/D:/learnx-flutter/lib/features/auth/login_screen.dart)。
   自动重登 enrollment 在 [auto_relogin_enrollment_screen.dart](/D:/learnx-flutter/lib/features/profile/widgets/auto_relogin_enrollment_screen.dart)。
   两者分别打开独立 WebView，而且 enrollment 还会主动清 cookie 和 local storage，导致用户第一次登录时已经信任设备，后面开自动重登时仍可能被当成“新浏览器”。

2. 自动重登状态语义混乱。
   [profile_screen.dart](/D:/learnx-flutter/lib/features/profile/profile_screen.dart) 里“已验证”与“最近恢复”混在一起展示，但当前 `recordVerified()` 只记录能力建立，不记录真实恢复或真实探针结果，用户会误判为“已经稳定可用”。

3. 首页登录没有承接“开启自动重登”的最佳时机。
   用户第一次登录后，最容易一次性完成“勾选信任设备 + 完成二验 + 立即保存自动重登能力”。当前流程却要求用户事后再去“我的页”单独开一遍。

4. 未来功能引导没有统一架构。
   现在即使只加一个登录引导，也不该做成散落文案。后续文件页、收藏页、课表、作业页都要用到类似的引导能力。

---

## 2. 目标与原则

### 2.1 目标

- 首次登录时即可完成自动重登授权。
- 自动重登授权必须复用同一套统一身份浏览器上下文。
- 用户只要同意开启自动重登，就只输一次密码。
- 开启后必须做一次真实静默重登探针，不允许“看起来配置好了，实际没用”。
- 状态展示必须区分：
  - 已配置
  - 已探针验证
  - 最近自动恢复
  - 最近失败
- 登录引导必须是可复用的 Guide 系统，不做一次性特判 UI。

### 2.2 非目标

- 不改网络学堂接口协议本身。
- 不把账号密码暴露进 Riverpod 普通状态或 Drift。
- 不为了“更智能”而引入复杂状态机屎山。

### 2.3 架构原则

- 会话状态、敏感凭据、浏览器上下文、恢复能力必须分层。
- 登录与自动重登是同一条能力链路，不是两套功能。
- 所有“可用”结论都必须有真实探针支撑。
- UI 展示只消费明确定义的 capability state，不自己拼业务逻辑。

---

## 3. 目标架构

```text
Login UI / Profile UI / Guide UI
            ↓
AuthEntryCoordinator
            ↓
IdentityWebSessionOrchestrator
            ↓
TrustedBrowserCapture + TicketBootstrap
            ↓
CredentialVault + ReloginProbeService
            ↓
AutoReloginCapabilityStore
            ↓
SessionRecoveryCoordinator
```

### 3.1 角色定义

#### `AuthEntryCoordinator`

职责：

- 统一编排“首次登录”“首次登录时顺带开启自动重登”“我的页手动开启自动重登”。
- 决定走哪种 entry mode，不直接碰底层 WebView 注入细节。

建议位置：

- `lib/core/auth/auth_entry_coordinator.dart`

#### `IdentityWebSessionOrchestrator`

职责：

- 管理统一身份登录 WebView 的完整生命周期。
- 负责“同一浏览器上下文”的复用。
- 输出：
  - ticket
  - 登录表单快照
  - trusted browser 参数
  - 是否完成二验

建议位置：

- `lib/core/auth/identity/identity_web_session_orchestrator.dart`

#### `TrustedBrowserCapture`

职责：

- 专门抓 `fingerPrint / fingerGenPrint / fingerGenPrint3 / deviceName / singleLogin`
- 只做参数提取与可信性判断，不负责 UI，不负责最终保存。

建议位置：

- `lib/core/auth/identity/trusted_browser_capture.dart`

#### `ReloginProbeService`

职责：

- 在用户同意开启自动重登后，使用独立 `CookieJar` 真实跑一次静默重登。
- 这次探针不是“恢复”，而是“能力验证”。
- 只有探针成功，才允许把 capability 标成 ready。

建议位置：

- `lib/core/auth/relogin_probe_service.dart`

#### `AutoReloginCapabilityStore`

职责：

- 只保存自动重登能力状态。
- 不负责 session expired，不直接保存密码。
- UI 只读这里。

建议位置：

- `lib/core/auth/auto_relogin_capability_store.dart`

#### `GuideRegistry / GuidePresenter / GuideStateStore`

职责：

- 管理登录页及未来功能页引导。
- 支持：
  - 首次展示
  - 只展示一次
  - 某条件下再次展示
  - 锚点式高亮
  - 卡片式引导

建议位置：

- `lib/core/guides/guide_registry.dart`
- `lib/core/guides/guide_presenter.dart`
- `lib/core/guides/guide_state_store.dart`

---

## 4. 状态模型必须重写

当前 [auth_relogin_models.dart](/D:/learnx-flutter/lib/core/auth/auth_relogin_models.dart) 里的 `AutoReloginStatusSnapshot` 不够精确，至少要升级成下面这套语义。

## 4.1 新状态

### `AutoReloginCapabilityPhase`

- `disabled`
- `needs_setup`
- `probing`
- `ready`
- `degraded`

### 关键字段

- `enabledByUser`
- `hasStoredCredential`
- `lastConfiguredAt`
- `lastProbeAt`
- `lastProbeMethod`
- `lastRecoveryAt`
- `lastRecoveryMethod`
- `lastFailureAt`
- `lastFailureStage`
- `lastFailureReason`
- `trustedBrowserReady`

### 语义

- `lastConfiguredAt`
  代表用户完成授权并写入凭据。

- `lastProbeAt`
  代表系统真实跑过一次静默重登探针。
  这是“能力验证”，不是“会话恢复”。

- `lastRecoveryAt`
  代表运行中会话真的过期过，且系统自动恢复成功。

### UI 文案映射

- `disabled` -> `关闭`
- `needs_setup` -> `需配置`
- `probing` -> `正在验证`
- `ready` 且只有 `lastProbeAt` -> `已就绪 · 最近校验 xx-xx xx:xx`
- `ready` 且有 `lastRecoveryAt` -> `已就绪 · 最近恢复 SSO 漫游 xx-xx xx:xx`
- `degraded` -> `最近失败：...`

注意：

- 不再用“已验证”这个词。
- “最近恢复”绝不能拿首次探针冒充。

---

## 5. 三条业务流要合并

## 5.1 流一：首次登录且用户未开启自动重登

1. 登录页展示正常登录入口。
2. 登录前展示引导卡片，可选勾选“登录后同时启用自动重新登录”。
3. 用户若不勾选，只走普通登录。
4. 登录成功后 capability 不变。

## 5.2 流二：首次登录时同时开启自动重登

这是目标主路径。

1. 用户在登录页勾选“同时启用自动重新登录”。
2. `AuthEntryCoordinator` 以 `loginWithEnrollment` 模式启动。
3. 使用同一个 `IdentityWebSessionOrchestrator` 打开统一身份 WebView。
4. 用户在这个真实登录过程中完成验证码、二验、信任设备。
5. 系统从同一 WebView 上下文抓取 trusted browser 参数。
6. ticket 建立学堂会话成功。
7. `ReloginProbeService` 立即使用保存前的参数做一次真实静默重登探针。
8. 探针成功才保存到 `CredentialVault`。
9. `CapabilityStore` 写入：
   - `enabledByUser=true`
   - `hasStoredCredential=true`
   - `lastConfiguredAt=now`
   - `lastProbeAt=now`
   - `lastProbeMethod=secureCredential`
   - `phase=ready`

这样用户只登一次，自动重登能力当场闭环。

## 5.3 流三：用户事后在“我的页”开启自动重登

1. 如果当前 App 内还有活跃统一身份浏览器上下文，优先复用。
2. 如果没有，再显式进入 enrollment 页面。
3. enrollment 不得无脑 `clearCookies()`。
   只能在以下场景清：
   - 用户明确点“重新验证”
   - 当前上下文已污染且判定不可复用
4. 抓完 trusted browser 参数后，同样跑一次真实探针。
5. 成功后再落 capability。

---

## 6. 为什么当前实现会让已信任设备再次二验

核心原因在 [auto_relogin_enrollment_screen.dart](/D:/learnx-flutter/lib/features/profile/widgets/auto_relogin_enrollment_screen.dart)：

- `clearLocalStorage()`
- `clearCookies()`

这会直接把 enrollment 变成“新浏览器”。

改法：

- 登录页主 WebView 和 enrollment WebView 不应该各自裸管。
- 浏览器上下文要抽成 `IdentityBrowserContextHandle`，由 orchestrator 统一管理。

### `IdentityBrowserContextHandle`

字段建议：

- `contextId`
- `createdAt`
- `hasSuccessfulLogin`
- `trustedBrowserObserved`
- `cookieSnapshotAvailable`
- `canReuseForEnrollment`

规则：

- 同一线程内首次登录成功后，默认保留一个短期可复用 context。
- 用户若立即开启自动重登，直接复用。
- 只有用户主动要求“全新验证”时才清理。

---

## 7. Guide 系统蓝图

登录页不是特例，直接做成通用系统。

## 7.1 组件

### `GuideRegistry`

声明所有 guide：

- `login.autoRelogin`
- `files.favorite`
- `assignments.submission`
- `home.schedule`

### `GuideStateStore`

保存：

- 是否展示过
- 是否被用户关闭
- 是否因版本升级需要重新展示

### `GuidePresenter`

支持三种形式：

- `inlineCard`
- `anchoredCoachmark`
- `modalWalkthrough`

### `GuideAnchor`

页面可注册锚点，供引导层定位。

## 7.2 登录页 guide 的视觉要求

不是“写几行字”。

应是一个轻量但精致的登录页功能卡片：

- 标题：`建议开启自动重新登录`
- 副文案：
  - `首次登录时一并完成授权`
  - `如出现“信任当前设备 / 180天”，建议勾选`
  - `后续会话过期时可自动恢复`
- 控件：
  - 开关
  - 一个 `了解详情` 次级入口

视觉原则：

- 不能抢主按钮
- 但必须像“浏览器插件首次引导”一样专业可靠
- 登录页、我的页展示同一能力，不要写成两套文案

---

## 8. 模块落点建议

建议新增或重组：

- `lib/core/auth/auth_entry_coordinator.dart`
- `lib/core/auth/relogin_probe_service.dart`
- `lib/core/auth/auto_relogin_capability_store.dart`
- `lib/core/auth/identity/identity_web_session_orchestrator.dart`
- `lib/core/auth/identity/trusted_browser_capture.dart`
- `lib/core/auth/identity/identity_browser_context_handle.dart`
- `lib/core/guides/guide_registry.dart`
- `lib/core/guides/guide_presenter.dart`
- `lib/core/guides/guide_state_store.dart`
- `lib/features/auth/widgets/login_auto_relogin_card.dart`

建议被削薄的现有文件：

- [login_screen.dart](/D:/learnx-flutter/lib/features/auth/login_screen.dart)
- [auto_relogin_enrollment_screen.dart](/D:/learnx-flutter/lib/features/profile/widgets/auto_relogin_enrollment_screen.dart)
- [profile_screen.dart](/D:/learnx-flutter/lib/features/profile/profile_screen.dart)
- [auth_preferences_provider.dart](/D:/learnx-flutter/lib/core/providers/auth_preferences_provider.dart)

---

## 9. 分阶段实施

## Phase 1：修正状态语义

- 把 `已验证` 改成 `已就绪/最近校验`
- 增加 `lastProbeAt`
- 首次 enrollment 成功后写 `lastProbeAt`
- Profile 文案与状态映射重写

这是低风险改动，可先做。

## Phase 2：统一首次登录与 enrollment 编排

- 引入 `AuthEntryCoordinator`
- 登录页增加“同时启用自动重新登录”入口
- enrollment 与登录流共享同一 orchestrator

这是本轮最关键的结构改动。

## Phase 3：引入复用浏览器上下文

- 去掉 enrollment 默认清 cookie
- 登录成功后保留短期 context handle
- 我的页开启自动重登时优先复用

这是解决“第一次已信任，第二次还二验”的根因修复。

## Phase 4：Guide 系统正式落地

- 登录页 guide 先接入
- Guide 架构抽象稳定后，拓展到文件、收藏、作业、课表

---

## 10. 验收标准

满足以下条件才算完成：

1. 用户首次安装后，在登录页勾选自动重登，只输入一次密码。
2. 若统一身份要求二验，用户在同一 WebView 中完成。
3. 若用户勾选信任设备，系统能直接复用这次登录产出的 trusted browser 参数。
4. 登录成功后立即完成一次真实静默重登探针。
5. “我的页”能显示：
   - 最近校验
   - 最近恢复
   - 最近失败
   三者语义不混。
6. 用户第一次正常登录时已信任设备，随后立刻去开启自动重登，不应再被当成新浏览器重新走完整二验。
7. Guide 能被后续页面复用，不是登录页特判实现。

---

## 11. 最终判断

这次重构不该被当成“修一个自动登录 bug”。

它本质上是：

- 认证入口架构重构
- 自动重登能力建模重构
- 浏览器上下文复用重构
- 产品引导系统落地

只有按这个粒度设计，后面别的 AI 接手时，才不会再把登录系统写成开盲盒。
