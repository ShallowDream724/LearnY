# LearnX Flutter — 全功能蓝图 v1

> 每一个功能，精确到最大细节。这是下一阶段的唯一参考。

---

## 一、会话与认证

### 1.1 登录流程

**原版**：输入账密 → 弹框确认 SSO → WebView id.tsinghua.edu.cn → 自动注入账密并提交 → 截获 roaming ticket → `dispatch(login(formData))` → 完成

**我们的设计改进**：
- **引导勾选"信任浏览器"**：WebView 顶部叠加半透明引导条："建议勾选'信任浏览器'以减少登录次数"，不强制，用户自选
- **无确认弹框**：点击"登录"直接打开 WebView，减少一步操作
- **WebView 内自动填充**：注入 JS 填写用户名密码（同原版），但如果用户已勾选"信任浏览器"且 SSO cookie 仍有效，WebView 会自动跳转完成，无需用户操作
- **Ticket 截获**：监听 URL 跳转到 `learn.tsinghua.edu.cn/b/j_spring_security_thauth_roaming_entry` → 拦截 → [loginWithTicket()](file:///d:/learnx-flutter/lib/core/api/learn_api.dart#338-356) → 完成

**当前状态**：✅ 基本实现（有引导文字缺失，无 Banner 引导）
**需改动**：
- [login_screen.dart](file:///d:/learnx-flutter/lib/features/auth/login_screen.dart)：WebView 上方添加信任浏览器引导条

### 1.2 会话持久化（三层防线）

**Layer 1 — PersistCookieJar**
- [CookieJar()](file:///d:/learnx-flutter/lib/features/auth/login_screen.dart#331-336) → `PersistCookieJar`（cookie_jar 自带）
- 存储路径：`applicationSupportDirectory/cookies/`
- 覆盖场景：App 重启后 Cookie 还在 → 直接发 API 请求 → 成功 → 零延迟

**Layer 2 — 静默重认证**
- **触发条件**：任意 API 请求返回 302 到 SSO 登录页，或者获得登录态失效的响应
- **实现**：在 Dio 拦截器中检测，自动用 PersistCookieJar 中的 SSO cookie 访问 roaming URL
- **如果 SSO cookie 有效**（用户勾选了信任浏览器 → 有效数周-数月）→ 自动获得新 session → 重试原请求 → 用户无感知
- **如果 SSO cookie 也过期**→ 进入 Layer 3

**Layer 3 — 优雅降级**
- 不清空页面，不跳回登录页
- 顶部 MaterialBanner："会话已过期" + "重新登录"按钮
- 用户可继续浏览所有缓存数据
- 点击按钮 → 打开 SSO WebView → 重新认证 → Banner 消失

**需改动**：
- [learn_api.dart](file:///d:/learnx-flutter/lib/core/api/learn_api.dart)：构造函数接受 `PersistCookieJar`
- [providers.dart](file:///d:/learnx-flutter/lib/core/providers/providers.dart)：异步初始化 PersistCookieJar（需 `FutureProvider`）
- [learn_api.dart](file:///d:/learnx-flutter/lib/core/api/learn_api.dart)：新增 Dio 拦截器检测 302 → SSO 重定向 → 自动重认证
- [main.dart](file:///d:/learnx-flutter/lib/main.dart) 或 shell：支持显示 session 过期 Banner
- [router.dart](file:///d:/learnx-flutter/lib/core/router/router.dart)：session expired 时不跳回 login，改为显示 Banner

### 1.3 自动重登录（App Resume）

**原版**：[AppState](file:///d:/learnx-flutter/lib/core/database/database.dart#131-138) listener，后台→前台时如果 >10min 自动 [login({ reset: true })](file:///d:/learnx-flutter/lib/core/api/learn_api.dart#292-337)

**我们的设计**：
- `WidgetsBindingObserver.didChangeAppLifecycleState`
- `resumed` 时：先尝试一个轻量 API（如 [getUserInfo](file:///d:/learnx-flutter/lib/core/api/learn_api.dart#476-486)）→ 成功 → 不做任何事 → 失败 → 触发 Layer 2
- 不需要计时器，直接靠 API 调用结果判断
- 成功续期后 toast "欢迎回来，XXX"

**需改动**：
- [main.dart](file:///d:/learnx-flutter/lib/main.dart)：添加 `WidgetsBindingObserver` mixin
- 新增 `session_manager.dart`：封装续期逻辑

---

## 二、数据架构

### 2.1 响应式数据层（Drift `.watch()`）

**原版**：Redux store，手动 dispatch 更新
**我们**：Drift 响应式 Stream，数据写入 → UI 自动更新

**具体改动**：
- [database.dart](file:///d:/learnx-flutter/lib/core/database/database.dart) 新增 `watch` 系列方法：
  ```dart
  Stream<List<Notification>> watchNotificationsByCourse(String courseId)
  Stream<List<CourseFile>> watchFilesByCourse(String courseId)
  Stream<List<Homework>> watchHomeworksByCourse(String courseId)
  Stream<List<Course>> watchCoursesBySemester(String semesterId)
  Stream<List<Notification>> watchUnreadNotifications()
  ```
- [course_detail_screen.dart](file:///d:/learnx-flutter/lib/features/courses/course_detail_screen.dart)：`FutureProvider.family` → `StreamProvider.family`
- [home_screen.dart](file:///d:/learnx-flutter/lib/features/home/home_screen.dart)：`homeDataProvider` 从 `FutureProvider` 改为 `StreamProvider`
- 需运行 `dart run build_runner build` 重新生成

### 2.2 增量同步

**原版**：每次全量拉取全部课程的全部数据
**我们的改进**：
- 每门课在 DB 中记录 `lastSyncTime`
- 同步时先检查：如果 `lastSyncTime` < 5min 前 → 跳过该课程
- 首次同步必须全量（DB 为空）
- 手动下拉刷新 = 强制全量（忽略 lastSyncTime）
- 后台同步 = 增量（只拉 lastSyncTime 过期的课程）

> [!NOTE]
> 网络学堂 API 不支持服务端增量（无 `since` 参数），所以"增量"是指**跳过近期已同步的课程**，而非只拉新数据。同一门课一旦拉，仍是全量。

**需改动**：
- [database.dart](file:///d:/learnx-flutter/lib/core/database/database.dart)：Courses 表新增 `lastSyncTime` 列（或 AppState 存）
- [sync_provider.dart](file:///d:/learnx-flutter/lib/core/providers/sync_provider.dart)：同步逻辑添加时间戳检查
- Schema version 升级（1 → 2，需迁移）

### 2.3 同步优化

- **并发控制**：最多 3 门课同时同步（`Semaphore` 或手动队列）
- **课间延迟**：每门课同步完等 200ms 再开始下一门（避免触发封号）
- **通知+作业+文件 并行**：同一门课的 3 类数据同时拉取
- **进度报告**：`syncProgressProvider` 报告 "正在同步 3/14..."

**需改动**：
- [sync_provider.dart](file:///d:/learnx-flutter/lib/core/providers/sync_provider.dart)：队列重构 + 并发控制 + 进度报告

---

## 三、首页

### 3.1 当前状态
- ✅ 用户名/问候语
- ✅ 统计卡片（课程数/待交/未读）
- ✅ 紧急作业列表（DeadlineCard）
- ✅ 未读通知列表（NotificationCard）
- ❌ 今日课表条
- ❌ 新文件 Section
- ❌ 新批改 Section
- ❌ 下拉刷新

### 3.2 需补齐

#### Section: 今日课表条
- 数据源：[getCalendar](file:///d:/learnx-flutter/lib/core/api/learn_api.dart#491-534) API → 取今日范围
- 单行横向滚动，每个课程是一个 Chip（课程名 + 时间 + 地点）
- 无课时："今天没有课 🎉"（用 Material Symbol，不用 emoji）
- **需新增**：`today_schedule_bar.dart`

#### Section: 新文件
- 筛选：`isNew = true`（服务端字段）且 `hasReadLocal = false`
- 每条：文件类型图标（圆角方块渐变色 + 白色扩展名文字）+ 文件名 + 课程名·大小·时间
- 默认显示 3 条 + "查看全部"
- **需新增**：`new_files_section.dart`, `file_card.dart`, `file_type_icon.dart`

#### Section: 新批改
- 筛选：`graded = true` 且 ID 不在 `viewedGradeIds`（AppState 存）
- 每条：课程名 + 作业名 + 成绩显示
- **成绩显示规则**（`grade_display.dart`）：
  - [grade](file:///d:/learnx-flutter/lib/features/courses/course_detail_screen.dart#777-784) 有数值 → 大号数字 "**92**"
  - [gradeLevel](file:///d:/learnx-flutter/lib/features/assignments/homework_detail_screen.dart#664-678) 有值 → "**A+**"
  - 都有 → "**A+** ^(95)"
  - 只有 `gradeContent` → "**已批改**" + 评语预览
  - 什么都没有但 `graded=true` → "**已批改**"
- **需新增**：`new_grades_section.dart`, `grade_display.dart`

#### 下拉刷新
- `RefreshIndicator` 包裹整个首页 `CustomScrollView`
- [onRefresh](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#40-72)：强制全量同步
- 成功反馈：自定义 ✓ 动画（绿色圆形 + checkmark，600ms 显示后消失）
- 失败：SnackBar "刷新失败"
- **需改动**：[home_screen.dart](file:///d:/learnx-flutter/lib/features/home/home_screen.dart)

---

## 四、作业页

### 4.1 当前状态
- ✅ 作业列表基本显示
- ❌ 顶部统计面板
- ❌ 筛选栏（未完成/全部/已完成/收藏/归档）
- ❌ 截止进度条
- ❌ 状态标签组合
- ❌ 操作：点进去红屏（URI crash 已修）

### 4.2 需补齐

#### 顶部面板 `assignment_panel.dart`
- 3 个统计卡：待提交（琥珀色）/ 已提交（绿色）/ 已过期（红色）
- "最近截止" 信息条
- **需新增**：`assignment_panel.dart`

#### 筛选栏 `filter_bar.dart`
- 胶囊 pill 水平滚动：未完成（默认）/ 全部 / 已完成 / 收藏 / 归档
- 选择持久化到 DB（AppState）
- **需新增**：`filter_bar.dart`（通用组件，课程详情也用）

#### 截止进度条 `deadline_bar.dart`
- 3px 高圆角条，渐变色：绿(0-60%) → 黄(60-85%) → 红(85-100%)
- 已截止 = 100% 红
- 已提交不显示
- **需新增**：`deadline_bar.dart`

#### 作业卡片重构 `assignment_card.dart`
- 课程名·老师（浅色小字）
- 作业标题
- 进度条 + 截止文字
- 状态 pill 组合（未提交/已过期/已交/已批+成绩）
- 已完成卡片 opacity 0.65
- **需新增**：或重构 [deadline_card.dart](file:///d:/learnx-flutter/lib/features/home/widgets/deadline_card.dart) → `assignment_card.dart`

#### 下拉刷新
- 同首页

---

## 五、课程页

### 5.1 当前状态
- ✅ 课程列表（基本）
- ❌ 顶部面板（课程数/提交率/待处理）
- ❌ 学期信息条 + 切换
- ❌ 课程卡片色条 + 统计角标
- ❌ 长按屏蔽
- ❌ 下拉刷新

### 5.2 需补齐

#### 顶部面板
- 3 统计卡：课程数 / 提交率 / 待处理
- **需新增**：`course_panel.dart`

#### 学期切换
- "2024-2025 秋季学期" + "切换学期" 按钮
- 底部弹出 Sheet，列出所有学期，选中高亮
- 切换后 → 更新 `currentSemesterIdProvider` → UI 自动刷新
- **需改动**：[courses_screen.dart](file:///d:/learnx-flutter/lib/features/courses/courses_screen.dart), [providers.dart](file:///d:/learnx-flutter/lib/core/providers/providers.dart)

#### 课程卡片重设计
- 2 列网格
- 顶部 4px 渐变色条（每门课唯一颜色，从色板轮流）
- 课程名（14sp SemiBold）+ 教师名（12sp 灰色）
- 底部统计角标：通知数·待交数·新文件数
- **需重构**：[courses_screen.dart](file:///d:/learnx-flutter/lib/features/courses/courses_screen.dart) 卡片部分

#### 课程屏蔽
- 长按弹出菜单：屏蔽/取消屏蔽
- 被屏蔽课程不出现在首页、不计入角标
- 屏蔽列表在设置页可管理
- **需新增**：DB `hiddenCourseIds` 存储 + UI 过滤逻辑

---

## 六、课程详情

### 6.1 当前状态
- ✅ SliverAppBar + TabBar（通知/文件/作业）
- ✅ 头部课程名+老师名（刚修复重叠）
- ❌ 仪表盘头部（统计卡 + 待提交列表）
- ❌ Tab 数据为空（FutureProvider 问题）
- ❌ 下拉刷新
- ❌ Tab 角标数字

### 6.2 需补齐

#### 仪表盘头部 `course_dashboard.dart`
- 课程名 + 学期标签
- 老师名
- 3 统计卡：作业数 / 已提交 / 均分
  - 均分计算：数值成绩取平均，等级成绩取众数，混合显示 "—"
- 待提交作业列表（琥珀色渐变卡片，每项可点击）
- 无待提交时隐藏

#### Tab 数据修复
- `FutureProvider.family` → `StreamProvider.family` + Drift `.watch()`
- 进入页面 → 骨架屏 → 数据到达 → 实时填充

#### Tab 角标
- Tab 文字后显示数量："通知(3) | 作业(12) | 文件(28)"

#### 下拉刷新（每个 Tab）
- [onRefresh](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#40-72)：仅拉该课程的对应数据类型
- 通知 Tab 刷新 → 调 `api.getNotificationList(courseId)`
- 3 类数据独立刷新，不影响其他 Tab

---

## 七、通知详情

### 7.1 当前状态
- ✅ 基本页面（标题/时间/HTML 内容）
- ❌ 进入自动标已读
- ❌ 附件链接
- ❌ 发布者/过期时间

### 7.2 需补齐
- 进入详情 → `db.markNotificationRead(id)` → 首页未读数自动减（Stream 响应）
- 附件：如果通知有附件字段 → 显示可点击文件链接 → 进入文件详情
- 完整元信息：发布者 + 发布时间 + 过期时间（如有）

---

## 八、作业详情

### 8.1 当前状态
- ✅ 基本页面
- ❌ 完整信息块结构
- ❌ 成绩显示
- ❌ 提交按钮/页面

### 8.2 需补齐

#### 信息块（按顺序）
1. **教师附件**：可点击 → 文件详情
2. **我的提交**：提交内容 + 附件 + 时间 + 迟交标记
3. **成绩**：成绩显示（`grade_display.dart` 规则）+ 教师评语（完整，可复制）+ 批改人 + 时间
4. **参考答案**（如有）
5. **优秀作业**（如有）

#### 提交页面 `assignment_submission_screen.dart`
- 文本输入框（多行）
- 附件选择（`file_picker`）+ 自定义附件名
- "删除附件"选项（如已提交过）
- 提交确认弹窗
- 上传进度条
- 成功 → toast + 返回 + 刷新作业列表

**需新增**：`assignment_submission_screen.dart`
**需改动**：[homework_detail_screen.dart](file:///d:/learnx-flutter/lib/features/assignments/homework_detail_screen.dart) 重构

---

## 九、文件详情

### 9.1 当前状态
- ❌ 完全没有独立的文件详情页（只有下载服务）

### 9.2 需新建 `file_detail_screen.dart`

#### 三态显示
1. **下载中**：顶部 `LinearProgressIndicator` + 骨架屏
2. **下载失败**：居中错误图标 + "下载失败" + 重试按钮
3. **下载成功**：
   - PDF → `flutter_pdfview` 内嵌预览
   - 图片 → `Image.file` 显示
   - 其他 → 文件信息卡（类型图标 + 名称 + 大小 + 上传者 + 时间 + 描述）+ "用其他应用打开"按钮

#### 导航栏按钮
- 刷新（重新下载）
- 分享（`share_plus`）
- 用其他应用打开（`open_filex`）

### 9.3 文件缓存策略

**设计原则**：不给设备带来存储负担

- 缓存目录：`applicationSupportDirectory/learnx_files/`
- **LRU 淘汰**：缓存超过 500MB → 自动删除最久未访问的文件
- **缓存上限用户可设置**：设置页可选 200MB / 500MB / 1GB / 无限制
- 每次打开文件时更新 `lastAccessTime`
- 清除缓存按钮（设置页）
- DB 记录下载状态 + 本地路径 + lastAccessTime + 文件大小

**需改动**：
- [file_download_service.dart](file:///d:/learnx-flutter/lib/core/services/file_download_service.dart)：添加 LRU 淘汰逻辑
- [database.dart](file:///d:/learnx-flutter/lib/core/database/database.dart)：CourseFiles 增加 `lastAccessTime`, `fileSize` 列
- 新增：`file_detail_screen.dart`
- 新增路由：`Routes.fileDetail`

---

## 十、搜索

### 10.1 当前状态
- ✅ 基本搜索页（[search_screen.dart](file:///d:/learnx-flutter/lib/features/search/search_screen.dart)）
- ？ 需检查是否能跑

### 10.2 设计要求
- 实时过滤（debounce 300ms）
- 搜索范围：标题 + 课程名 + 发布者 + 文件描述
- 结果按类型分组：通知 | 作业 | 文件
- 无结果 → 空状态组件
- 入口：首页 + 作业页导航栏搜索图标

---

## 十一、设置（"我的"Tab）

### 11.1 当前状态
- ✅ 基本框架（[profile_screen.dart](file:///d:/learnx-flutter/lib/features/profile/profile_screen.dart)）
- ❌ 大部分设置项

### 11.2 需补齐

**用户信息区**：圆形头像（姓名首字母 + 渐变色）+ 姓名 + 院系

**设置项**：
| 分组 | 项目 | 状态 |
|------|------|------|
| 核心 | 学期选择 | ❌ |
| 核心 | 文件设置（缓存上限/命名/存储位置） | ❌ |
| 信息 | 课程信息分享 | ❌ |
| 关于 | 更新日志 | ❌ |
| 关于 | 发现新版本 | ❌ |
| 关于 | 帮助与反馈 | ❌ |
| 关于 | 关于 | ❌ |
| 危险 | 退出登录 | ✅ |

---

## 十二、交互体系

### 12.1 下拉刷新（全局）

**成功动画**：
- `RefreshIndicator` 原生转圈
- 成功后替换为 ✓ 图标（绿色圆底 + 白色 checkmark）
- 显示 600ms → 瞬间消失
- 实现：自定义 `RefreshIndicator` 或在 onRefresh 完成后叠加 overlay

**失败**：SnackBar "刷新失败，请重试" 2s

### 12.2 已读/未读管理

**优先级链**：`manuallyUnread` > `manuallyRead` > 服务端 `hasRead`

**操作**：
- 进入详情 → 自动标已读
- 左滑 → 标已读（不进详情）
- 长按 → 切换已读/未读

**需改动**：
- DB：通知和文件表添加 `hasReadLocal` 列（✅ 已有）
- 需补全：标已读/未读的 DAO 方法
- [notification_card.dart](file:///d:/learnx-flutter/lib/features/home/widgets/notification_card.dart)：添加滑动操作

### 12.3 收藏/归档

**操作**：
- 左滑 → 归档（灰色底）
- 右滑 → 收藏（黄色底心形图标）
- 再次操作可撤销

**存储**：DB AppState 中存 `favorites` / `archived` ID 集合

**UI 影响**：归档项从"全部"和"未读"中移除，有独立筛选视图

**需新增**：
- `swipe_action_wrapper.dart`（通用滑动操作组件）
- DB 存储 favorites/archived

### 12.4 滑动手势实现

使用 `flutter_slidable` 包：
- 通知卡片：左滑标已读，右滑收藏
- 作业卡片：左滑归档，右滑收藏
- 文件卡片：左滑标已读，右滑下载

---

## 十三、错误处理

### 13.1 消灭 `catch (_) {}`

当前 15 个静默 catch → 每一个都替换为分级处理：

```dart
// ❌ 当前
try { ... } catch (_) {}

// ✅ 改为
try { ... } catch (e) {
  warnings.add('${course.name}: 通知同步失败');
  debugPrint('[Sync] notification sync failed for ${course.name}: $e');
}
```

### 13.2 分级错误反馈

| 级别 | 处理 |
|------|------|
| 单课程同步失败 | 记录 warning，不影响其他课程，同步完后统一提示 "N 门课同步失败" |
| 全量同步失败 | SnackBar "同步失败，请下拉重试" |
| Session 过期 | Banner（Layer 3） |
| 网络断开 | Banner "离线模式" + 缓存数据正常使用 |

---

## 十四、安全

| 维度 | 措施 |
|------|------|
| 不存密码 | WebView SSO，凭据只在 WebView 沙箱内 |
| 请求节流 | 课间 200ms 延迟 + 最多 3 并发 |
| Cookie 安全 | PersistCookieJar 存 app 私有目录 |
| CSRF | 每次登录后提取，API 请求自动附加 |
| 数据安全 | SQLite 文件在 app 私有目录，非 root 不可读 |

---

## 十五、性能

| 优化项 | 措施 |
|--------|------|
| 增量同步 | 跳过 5min 内已同步的课程 |
| 并发控制 | 最多 3 门课同时同步 |
| 懒加载 Tab | 课程详情 Tab 使用 `AutomaticKeepAliveClientMixin` |
| 滚动性能 | 列表使用 `ListView.builder`（已做），卡片避免重绘 |
| 图片缓存 | 文件类型图标预渲染为 CustomPaint |
| 启动速度 | 先显示 DB 缓存数据 → 后台同步新数据 |
| 内存 | StreamProvider 自动 dispose，不持有过期 Stream |

---

## 十六、优先级排序

### 第一轮（阻塞使用）
1. ~~URI 编码 crash~~ ✅
2. PersistCookieJar + 静默续期
3. 课程详情 StreamProvider + Drift watch
4. 下拉刷新（首页 + 课程详情）

### 第二轮（功能完整性）
5. 文件详情页 + PDF 预览
6. 作业详情完善 + 提交页面
7. 首页新文件/新批改 Section
8. 通知详情自动标已读

### 第三轮（交互打磨）
9. 滑动操作（已读/收藏/归档）
10. 筛选栏
11. 截止进度条
12. 课程卡片重设计 + 学期切换

### 第四轮（设置+高级）
13. 设置页完善
14. 文件缓存 LRU
15. 课程屏蔽
16. 增量同步
17. 今日课表条

### 第五轮（精调）
18. 动画打磨
19. 暗色模式精调
20. 空状态设计
21. 错误处理消灭 catch
22. 性能优化
