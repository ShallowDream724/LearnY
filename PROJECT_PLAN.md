# LearnX Flutter — 详细项目计划书 v2

> 以商品级质量重写 LearnX。从信息架构到像素级细节，每一处都经过深思熟虑。

---

## 一、信息架构

### 1.1 核心设计理念

旧架构按**数据类型**分 Tab（通知 / 作业 / 文件 / 课程 / 设置），用户需要逐个 Tab 检查才能掌握全貌。

新架构按**用户关心的问题**组织：

| Tab | 回答的问题 |
|------|----------|
| **首页** | "今天有什么需要我关注的？" |
| **作业** | "我有哪些作业？什么时候截止？" |
| **课程** | "这门课的情况怎么样？" |
| **我的** | "调整设置、管理账户" |

**通知 Tab 删除**：未读通知在首页浮上来（高频），历史通知在课程详情里按课程查（低频），全局搜索兜底。

**文件 Tab 删除**：新文件在首页浮上来（高频），按课程找文件在课程详情里（低频），全局搜索兜底。

### 1.2 底部 Tab 栏

```
 [home]首页  |  [edit]作业  |  [book]课程  |  [person]我的
```

（图标均使用 Material Symbols，不使用 emoji）

**角标规则**：
- 首页：红点 = 有未读通知 OR 新文件 OR 新批改
- 作业：琥珀色数字角标 = 待提交且未过期的作业数
- 课程：无角标
- 我的：红点 = 有新版本 OR 新 Changelog

### 1.3 全局导航行为

**所有可点击条目**（通知、作业、文件、成绩）点击后进入详情页。

**返回行为**：返回时恢复到**离开时的精确滚动位置**。实现方式：
- 每个列表/首页用 `ScrollController` 记录 `offset`
- Push 详情页时保存 offset 到 Provider
- Pop 回来时恢复 offset
- 首页的每个 Section 都要恢复，不是只恢复页面整体位置

---

## 二、技术栈

| 层 | 选型 | 选型理由 |
|----|------|---------|
| **语言** | Dart 3.x | 空安全、密封类、模式匹配 |
| **框架** | Flutter 3.x | 自绘引擎，Material 3 + 自定义设计系统 |
| **状态管理** | Riverpod 2 + freezed | 编译时安全、自动销毁、缓存一体化 |
| **网络** | Dio 5 + cookie_jar + dio_cookie_manager | 拦截器链、Cookie 持久化、FormData |
| **HTML 解析** | html (dart 官方) | 替代 cheerio |
| **本地数据库** | Drift (SQLite) | 类型安全 ORM，响应式查询流 |
| **安全存储** | flutter_secure_storage | AES 加密凭据 |
| **路由** | GoRouter + ShellRoute | 声明式路由、滚动位置恢复、平板双栏 |
| **文件操作** | path_provider + open_file + share_plus | 下载/打开/分享 |
| **日历/提醒** | device_calendar | 系统日历和提醒事项读写 |
| **WebView** | webview_flutter | 通知/作业 HTML 内容渲染 |
| **PDF** | flutter_pdfview | 内嵌 PDF 预览 |
| **国际化** | flutter_localizations + ARB | 中英双语 |
| **代码生成** | build_runner + freezed + json_serializable + riverpod_generator | 消除样板代码 |

---

## 三、目录结构

```
lib/
├── main.dart
├── app.dart                           # MaterialApp、GoRouter、ProviderScope
│
├── core/
│   ├── api/                           # thu-learn-lib Dart 移植（~1300 行 JS → Dart）
│   │   ├── learn_api.dart             # Learn2018Helper 主类（~20 个公开方法）
│   │   ├── urls.dart                  # ~30 个 endpoint URL
│   │   ├── parsers.dart               # HTML/JSON → 模型 的解析
│   │   └── exceptions.dart            # FailReason 枚举、ApiException
│   │
│   ├── models/                        # freezed 数据模型
│   │   ├── user_info.dart
│   │   ├── semester.dart
│   │   ├── course.dart
│   │   ├── notice.dart
│   │   ├── assignment.dart            # 含多种成绩类型字段
│   │   ├── file.dart
│   │   ├── file_category.dart
│   │   ├── remote_file.dart
│   │   ├── discussion.dart
│   │   ├── question.dart
│   │   ├── questionnaire.dart
│   │   ├── calendar_event.dart
│   │   ├── favorite_item.dart
│   │   ├── comment_item.dart
│   │   └── enums.dart                 # 所有枚举
│   │
│   ├── auth/
│   │   ├── auth_provider.dart
│   │   ├── sso_service.dart
│   │   └── credential_store.dart
│   │
│   ├── storage/
│   │   ├── database.dart              # Drift schema
│   │   ├── daos/                      # 按实体分 DAO
│   │   └── preferences.dart
│   │
│   ├── network/
│   │   ├── dio_client.dart
│   │   └── connectivity.dart
│   │
│   └── theme/
│       ├── app_theme.dart
│       ├── color_scheme.dart
│       ├── typography.dart
│       └── dimensions.dart
│
├── features/
│   ├── login/
│   │   ├── login_screen.dart
│   │   └── sso_screen.dart
│   │
│   ├── home/                          # ★ 新增：智能首页
│   │   ├── home_screen.dart
│   │   ├── providers/
│   │   │   └── home_provider.dart     # 聚合所有数据源
│   │   └── widgets/
│   │       ├── today_schedule_bar.dart # 今日课表条
│   │       ├── urgent_section.dart     # 即将截止
│   │       ├── unread_notices_section.dart
│   │       ├── new_files_section.dart
│   │       └── new_grades_section.dart
│   │
│   ├── assignments/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── assignment_list_screen.dart
│   │   │   ├── assignment_detail_screen.dart
│   │   │   └── assignment_submission_screen.dart
│   │   └── widgets/
│   │       ├── assignment_panel.dart   # 顶部面板
│   │       ├── assignment_card.dart
│   │       ├── deadline_bar.dart       # 截止日期进度条
│   │       └── grade_display.dart      # ★ 多种成绩格式统一显示
│   │
│   ├── courses/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── course_list_screen.dart
│   │   │   └── course_detail_screen.dart  # ★ 带仪表盘头部
│   │   └── widgets/
│   │       ├── course_panel.dart       # 课程页面板
│   │       ├── course_card.dart        # 网格卡片
│   │       └── course_dashboard.dart   # ★ 课程详情仪表盘
│   │
│   ├── notices/                       # 通知详情（无独立列表页）
│   │   ├── screens/
│   │   │   └── notice_detail_screen.dart
│   │   └── widgets/
│   │       └── notice_card.dart       # 首页/课程详情复用
│   │
│   ├── files/                         # 文件详情（无独立列表页）
│   │   ├── screens/
│   │   │   └── file_detail_screen.dart
│   │   └── widgets/
│   │       ├── file_card.dart         # 首页/课程详情复用
│   │       └── file_type_icon.dart    # PDF/DOC/PPT/XLS/ZIP 图标
│   │
│   ├── search/
│   │   └── search_screen.dart
│   │
│   └── settings/
│       ├── screens/ ...
│       └── providers/ ...
│
├── shared/
│   ├── widgets/
│   │   ├── app_scaffold.dart
│   │   ├── refresh_list.dart          # 下拉刷新 + ✓ 反馈
│   │   ├── filter_bar.dart            # 筛选 pill 胶囊
│   │   ├── swipe_action_wrapper.dart  # 左滑右滑操作
│   │   ├── section_header.dart        # Section 标题 + 操作按钮
│   │   ├── html_content.dart          # WebView 内嵌
│   │   ├── file_attachment_link.dart
│   │   ├── empty_state.dart
│   │   ├── skeleton_loader.dart
│   │   ├── table_cell.dart            # 设置页行组件
│   │   └── stat_card.dart             # 数字统计卡片
│   │
│   └── utils/ ...
│
└── l10n/
    ├── app_zh.arb
    └── app_en.arb
```

---

## 四、页面详细规格

### 4.1 首页 `home_screen.dart`

首页是一个**垂直滚动的 Section 列表**，每个 Section 对应一类信息。空 Section 自动隐藏。Section 顺序固定（不智能排序——避免用户找不到东西）。

下拉刷新整个首页：一次拉取学期 → 课程 → 通知+作业+文件（并行）。

#### Section 1：今日课表条 `today_schedule_bar.dart`

```
┌─────────────────────────────────────────┐
│ 📍  [线性代数] 08:00 六教6C301 → [概率论] 10:05 六教6A017 │
└─────────────────────────────────────────┘
```

- 单行横条，`surface` 色圆角卡片
- 课程名加**主题色背景的圆角标签**，视觉突出
- 数据来源：`getCalendar` API，取今日范围
- 无课时显示"今天没有课"，配合轻快的插画或自定义图标
- 点击 → 跳转到日历/课表设置页

#### Section 2：即将截止 `urgent_section.dart`

- 暖色渐变背景卡片（琥珀色调）
- 左上角脉冲动画小圆点 + "N 个作业即将截止"
- 每项显示：作业名 + 截止时间
  - < 24h：红色等宽字体倒计时 `05:32:17`
  - < 7 天：琥珀色 `周五 23:59`
  - ≥ 7 天：灰色普通日期
- **每项可点击** → `Push` 到 `assignment_detail_screen.dart`
- 仅显示：`submitted=false && deadline > now`，按截止时间升序
- 空时整个 Section 隐藏

#### Section 3：未读通知 `unread_notices_section.dart`

- Section 标题：自定义 mail 图标 + "未读通知" + 右侧 "全部已读" 操作按钮
- 默认显示前 3 条，底部 "查看全部 (N) →" 展开全部
- 每条通知卡片：
  - 顶行：课程名 · 发布者（浅色小字）+ 右侧蓝色未读圆点
  - 标题（15sp SemiBold，最多 2 行）
  - 时间（相对时间："2小时前"/"昨天"/"3天前"）
  - 重要通知：未读圆点变红色 + 标题前加自定义警告图标（Material Symbols `priority_high`）
- **左滑标已读**：卡片向左滑出屏幕，未读圆点消失，角标 -1
- **点击** → `Push` 到 `notice_detail_screen.dart`
- 数据筛选：`hasRead=false || manuallyUnread`，排除 `manuallyRead` 和 `hiddenCourseIds`

#### Section 4：新文件 `new_files_section.dart`

- Section 标题：自定义 folder 图标 + "新文件" + 右侧 "查看全部"
- 默认显示前 3 条
- 每条文件卡片：
  - 左侧文件类型图标（36×36 圆角方块，渐变色）
    - PDF = 红色渐变，DOC = 蓝色，PPT = 橙色，XLS = 绿色，ZIP = 灰色，其他 = 青色
  - 文件名（15sp SemiBold）
  - 课程名 · 文件大小 · 相对时间（浅色小字）
  - 右侧蓝色新文件圆点
- **左滑标已读** / **右滑下载**
- **点击** → `Push` 到 `file_detail_screen.dart`
- 数据筛选：`isNew=true || manuallyUnread`，排除 `manuallyRead` 和 `hiddenCourseIds`

#### Section 5：新批改 `new_grades_section.dart`

- Section 标题：自定义 grading 图标 + "新批改"
- 显示**用户尚未查看过的新成绩**
  - 追踪方式：`lastViewedGradeIds` Set，每次进入详情页记录，首页只显示不在集合中的
- 每条卡片：
  - 左侧：课程名（小字）+ 作业标题
  - 右侧：**成绩显示**（大号字，主题色）
  - 底行：教师评语预览（如有，最多 1 行，浅色）
- **点击** → `Push` 到 `assignment_detail_screen.dart`

**成绩显示规则 `grade_display.dart`**：

| 老师给的数据 | 显示方式 | 示例 |
|------------|---------|------|
| `grade` 有数值 | 大号数字 | **92** |
| `gradeLevel` 有值 | 等级文本 | **A+** / **优秀** / **已阅** / **通过** |
| `grade` + `gradeLevel` 都有 | 优先显示 `gradeLevel`，副文字显示数值 | **A+** ^(95) |
| 只有 `gradeContent`（评语） | 不显示成绩数字，显示 "已批改" 标签 + 评语预览 | **已批改** "写得不错..." |
| 什么都没有但 `graded=true` | 显示 "已批改" | **已批改** |

---

### 4.2 作业页 `assignment_list_screen.dart`

#### 顶部面板 `assignment_panel.dart`

```
┌─────────────────────────────────────┐
│  ┌─────┐  ┌─────┐  ┌─────┐        │
│  │  2  │  │ 15  │  │  1  │        │
│  │待提交│  │已提交│  │已过期│        │
│  └─────┘  └─────┘  └─────┘        │
│                                     │
│  ⏰ 最近截止：矩阵分解 · 明天23:59  │
└─────────────────────────────────────┘
```

- 3 个 `stat_card`：待提交（琥珀色）/ 已提交（绿色）/ 已过期（红色）
- "最近截止" 信息条：点击 → 跳转到该作业详情
- 面板在 `bg` 色卡片中，`surface` 色 stat cards

#### 筛选栏 `filter_bar.dart`

**胶囊 pill 样式**，水平滚动，当前选中项高亮（主题色填充）。选项：

- **未完成**（默认）：`submitted=false && deadline > now`，**按截止日期升序**（最紧急在最上面）
- **全部**：所有作业，按截止日期降序
- **已完成**：`submitted=true || deadline < now`
- **收藏**：在 `favorites` 中
- **归档**：在 `archived` 中

筛选选择持久化到 `SharedPreferences`。

#### 作业列表项 `assignment_card.dart`

```
┌─────────────────────────────────────┐
│ 线性代数 · 张明远                    │  ← card-course, 12sp, text3
│ 矩阵分解与 LU 分解                  │  ← card-title, 15sp, SemiBold
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░  明天截止          │  ← 进度条 + 截止文字
│ ⚠ 未提交                            │  ← 状态 pill
└─────────────────────────────────────┘
```

**截止进度条 `deadline_bar.dart`**：
- 3px 高，圆角，背景 `#E8E8ED`
- 填充渐变色：
  - 时间过了 0-60%：纯绿色
  - 60-85%：绿 → 黄渐变
  - 85-100%：黄 → 红渐变
- 已截止 = 100% 红色
- 已提交的作业不显示进度条

**状态标签组合 `st-row`**：

| 条件 | 显示 |
|------|------|
| 未提交且未过期 | `[warning_icon] 未提交`（琥珀底） |
| 未提交且已过期 | `[close_icon] 已过期`（红底） |
| 已提交未批改 | `[check_icon] 已提交`（绿底） |
| 已提交已批改 | `[check_icon] 已提交`（绿底）+ 成绩 pill（紫底）|
| 迟交 | 追加 `迟交` 标签（灰底） |

**已完成作业**：整卡 opacity 0.65，视觉退后

**滑动操作**：左滑归档 / 右滑收藏

**点击** → `Push` 到 `assignment_detail_screen.dart`

---

### 4.3 作业详情 `assignment_detail_screen.dart`

沿用现有 App 的信息块结构，但优化视觉层次。

#### 头部

- Chip 组：`个人作业` / `小组作业` + `网上提交` / `线下提交`
- 标题（22sp Bold）
- 截止时间区域：
  - 未提交时：实时倒计时红色加粗 "还剩 1 天 3 小时 22 分"（`useCountdown` hook）
  - 已提交/已过期：相对时间 + 格式化日期
  - 补交截止（如有）：单独一行

#### 信息块（图标 + 内容 + Divider）

1. **[attach] 教师附件**（如有）：可点击文件名 → Push `file_detail_screen.dart`
2. **[upload] 我的提交**（如有）：
   - 提交附件（可点击）
   - 提交文本内容
   - 提交时间 + 迟交标记
3. **[star] 成绩**（如有）：
   - 成绩显示（遵循 `grade_display.dart` 规则）
   - 批改附件（可点击）
   - **教师评语**（`gradeContent`，完整显示，可选中复制）
   - 批改人 + 批改时间
4. **[key] 参考答案**（如有）：答案附件 + 答案文本
5. **[trophy] 优秀作业**（如有）：每项含附件 + 作者名（匿名则显示"匿名"）

#### 作业描述

WebView 渲染 HTML，自适应亮色/暗色主题背景。无内容时显示占位文字。

#### 提交按钮

导航栏右侧上传图标，截止后禁用。点击 → Push `assignment_submission_screen.dart`。

---

### 4.4 通知详情 `notice_detail_screen.dart`

- 标题（22sp Bold）
- 发布者 + 发布时间
- 过期时间（如有）
- 附件链接（如有）→ Push `file_detail_screen.dart`
- HTML 正文（WebView）

进入详情自动标记已读（从 `manuallyUnread` 移除，加入 `manuallyRead`）。

---

### 4.5 文件详情 `file_detail_screen.dart`

#### 三态显示

1. **下载中**：骨架屏 + 顶部 `LinearProgressIndicator`
2. **下载失败**：居中错误图标 + "下载失败" + 重试按钮
3. **下载成功**：
   - 可预览（PDF / 支持的格式）→ 直接渲染预览
   - 不可预览 → 文件信息卡（分类 Chip + 标题 + 上传者 + 时间 + 类型 + 大小 + 描述）+ 底部操作栏

#### 导航栏按钮

- 刷新（重新下载）
- 分享
- 用其他应用打开（Android）
- 信息/预览切换

#### 设置联动

- `openFileAfterDownload`：非 PDF 下载完自动打开
- `fileUseDocumentDir`：保存到文档目录 vs 缓存目录
- `fileOmitCourseName`：文件名是否含课程名

---

### 4.6 课程页 `course_list_screen.dart`

#### 顶部面板 `course_panel.dart`

```
┌─────────────────────────────────────┐
│  ┌─────┐  ┌─────┐  ┌─────┐        │
│  │  6  │  │ 83% │  │  5  │        │
│  │ 课程 │  │提交率│  │待处理│        │
│  └─────┘  └─────┘  └─────┘        │
└─────────────────────────────────────┘
```

- 提交率 = 已提交作业 / 总作业数（所有课程）
- 待处理 = 未提交且未过期的作业总数

#### 学期信息条

"2024-2025 秋季学期" + 右侧 "切换学期" 文字按钮

#### 课程网格

2 列瀑布流卡片，每个卡片：
- 顶部 4px 渐变色条（每门课一个唯一颜色，从预定义色板轮流分配）
- 课程名（14sp SemiBold）
- 教师名（12sp 灰色）
- 底部统计角标（如有未读/待交/新文件）：[notification] 2  [edit] 1  [folder] 1（Material Symbols 图标）

**点击** → Push 到 `course_detail_screen.dart`

**长按** → 弹出选项：屏蔽/取消屏蔽

---

### 4.7 课程详情 `course_detail_screen.dart`

#### 仪表盘头部 `course_dashboard.dart`

```
┌─────────────────────────────────────┐
│  线性代数                  2024 秋  │
│  张明远 教授                        │
│                                     │
│  ┌─────┐  ┌─────┐  ┌─────┐        │
│  │ 12  │  │ 10  │  │ A-  │        │
│  │作业数│  │已提交│  │均分  │        │
│  └─────┘  └─────┘  └─────┘        │
│                                     │
│  ⏳ 2 个作业待提交                   │
│  ├ 矩阵分解 ── 明天 23:59          │
│  └ 特征值分析 ── 周五 23:59        │
└─────────────────────────────────────┘
```

**均分计算规则**：
- 如果该课程有**数值成绩**（`grade` 字段），计算平均分显示数字
- 如果只有**等级成绩**（`gradeLevel`），按频率取众数，如 "A-"
- 如果成绩类型混合或没有成绩，显示 "—"
- 只计算已批改的作业

**待提交区域**：
- 琥珀色渐变背景卡片（同首页的 urgent section）
- 每项可点击 → Push 作业详情
- 没有待提交时此区域隐藏

#### 内容 Sub-Tabs

```
 通知(3)  |  作业(12)  |  文件(28)
```

**胶囊切换 Tab**，数字角标显示在标签旁。

- **通知 Tab**：该课程的通知列表，复用 `notice_card.dart`，支持滑动操作
- **作业 Tab**：该课程的作业列表，复用 `assignment_card.dart`，含进度条
- **文件 Tab**：该课程的文件列表，复用 `file_card.dart`

所有列表支持下拉刷新。

---

### 4.8 搜索 `search_screen.dart`

- 顶部搜索栏：自动获取焦点，实时过滤
- 结果按类型分组（SectionList 风格）：通知 / 作业 / 文件
- 搜索范围：标题 + 课程名 + 发布者/教师名 + 文件描述
- 无结果 → Empty 组件
- 入口：首页/作业页导航栏的搜索图标

---

### 4.9 设置模块（"我的"Tab）

#### 4.9.1 设置主页

**用户信息区**：
- 圆形头像（姓名首字母 + 主题色渐变背景），56dp
- 姓名（18sp SemiBold）+ 院系（13sp 灰色）

**设置分组**（iOS 风格圆角分组列表）：

**第一组**（核心功能）：
1. 学期选择 → 所有学期列表，选中项高亮
2. 日历与提醒 → 完整日历同步设置页（同现有 App）
3. 文件设置 → 存储/缓存/命名设置

**第二组**（信息）：
4. 课程信息分享 → 说明页 + 开关

**第三组**（关于）：
5. 更新日志（有新版本时显示红点）
6. 发现新版本 v2.1.0（仅 Android，动态显示）
7. 帮助与反馈
8. 关于

**第四组**（危险操作）：
9. 退出登录（红色居中文字，点击弹确认弹窗）

---

### 4.10 登录模块

#### 登录页 `login_screen.dart`

- Logo 居中
- 用户名输入框：`autocomplete: username`，ASCII 键盘，回车跳到密码
- 密码输入框：安全输入，`autocomplete: password`
- 研究生开关 + 说明文字
- "登录" 按钮（loading 状态 + 禁用）
- 条件显示（有已保存凭据时）：
  - "重试登录"：用已保存凭据直接重试
  - "离线模式"：跳过登录用本地缓存
- 安全说明文字（凭据加密存储）

#### SSO 页 `sso_screen.dart`

- 全屏 WebView 加载 `id.tsinghua.edu.cn`
- 自动注入用户名/密码
- 监听 URL 跳转截获 ticket → 调用 `login()` → 关闭 WebView

#### 自动重登录

- App 从后台恢复时检测 session
- 过期则自动重登录（`await` 完成后再刷新数据）
- 成功后显示 "欢迎回来，XXX" toast

---

## 五、通用交互规范

### 5.1 下拉刷新

```
下拉 → RefreshIndicator 转圈
成功 → 转圈消失 → 同位置显示 ✓（白色圆形底板 + 绿色 check）→ 600ms → 瞬间消失
失败 → SnackBar "刷新失败" → 2s 消失
```

### 5.2 已读/未读管理（通知 + 文件）

优先级链：`manuallyUnread` > `manuallyRead` > 服务端状态（`hasRead` / `isNew`）

- 进入详情：自动标已读
- 首页左滑：标已读（不进详情就完成）
- 长按：标已读/未读切换

### 5.3 收藏/归档（通知 + 作业 + 文件）

- 左滑：归档（灰色底，存入 `archived`）
- 右滑：收藏（黄色底心形图标，存入 `favorites`）
- 再次操作可撤销
- 归档项从"全部"和"未读"中移除，有独立筛选视图

### 5.4 课程屏蔽

- `courses.hidden[]` 存储被屏蔽课程 ID
- 被屏蔽课程的通知/作业/文件不出现在首页、不计入角标
- 课程列表中有独立视图查看屏蔽课程

### 5.5 平板自适应

- 手机：标准列表 → Push 详情
- 平板：左右双栏（GoRouter ShellRoute），左侧列表选中高亮，右侧详情面板
- 详情面板可全屏展开

---

## 六、UI/UX 设计规范

### 6.1 色彩系统

```
亮色模式：
  背景层：#F2F2F7（主背景）→ #FFFFFF（卡片/面板）
  主题色：#6B3FA0（清华紫衍生）→ Material 3 色阶
  语义色：
    未读      #007AFF（蓝）
    成功/已交  #34C759（绿）
    紧迫/截止  #FF9500（琥珀）→ #FF3B30（红）
    重要标记   #FF3B30
    成绩      #6B3FA0（主题色）

暗色模式：
  背景层：#000000（主背景）→ #1C1C1E（卡片/面板）→ #2C2C2E（凹陷区）
  主题色提亮：#BFA0D8
  分割线：rgba(255,255,255,0.06)
  WebView 内容背景色同步
```

### 6.2 字体层级

Inter（西文）+ 系统原生（中文），基于 4pt 递增：

| 级别 | 大小 | 字重 | 用途 |
|------|------|------|------|
| Display | 28sp | Bold (800) | 首页/Tab 大标题 |
| Headline | 22sp | Bold (700) | 详情页标题 |
| Title | 18sp | SemiBold (600) | Section 标题 |
| Body L | 16sp | Regular (400) | 描述正文 |
| Body | 15sp | SemiBold (600) | 卡片标题 |
| Label | 13sp | Medium (500) | 课程名、标签 |
| Caption | 12sp | Regular (400) | 时间戳、副信息 |
| Tiny | 11sp | Medium (500) | 角标文字、Chip |

### 6.3 间距系统（4dp 基数）

| Token | 值 | 用途 |
|-------|----|------|
| `xs` | 4dp | 图标与文字间 |
| `sm` | 8dp | 卡片内元素、列表间隔 |
| `md` | 12dp | Section 内 padding |
| `lg` | 16dp | 标准 padding、卡片边距 |
| `xl` | 20dp | 首页外边距 |
| `xxl` | 32dp | 设置页分组间距 |

### 6.4 过渡动画

| 场景 | 动画 | 参数 |
|------|------|------|
| 列表→详情 | 平台默认 Push | 300ms |
| Tab 切换 | 交叉淡入淡出 | 200ms easeInOut |
| 筛选 pill 切换 | 列表 AnimatedSwitcher | 150ms |
| 角标数字变化 | 缩放弹跳 | 300ms elasticOut |
| 下拉成功 ✓ | 出现 0ms → 停留 600ms → 消失 0ms | 瞬出瞬灭 |
| 骨架屏 | 微光扫过 | 1.2s 循环 |
| 左滑标已读 | 卡片滑出 + 高度折叠 | 250ms easeOut |
| Section 折叠/展开 | 高度动画 | 200ms ease |
| 课程详情 | 底部上滑 | 300ms decelerate |

### 6.5 暗色模式规范

- 背景和卡片用 `elevation overlay` 区分层次
- 分割线用 `white.withOpacity(0.06)` 非灰色
- 主题色提亮以保持可读性
- 文件类型图标渐变保持不变（暗色中是亮色锚点）
- WebView 内容背景 + 文字颜色同步主题
- 课程卡片顶部色条保持原色（暗色中作为识别色）

### 6.6 图标系统

> **绝对禁止使用 emoji。** 所有图标、元素均使用 Material Symbols 图标字体或自绘 SVG/CustomPaint。Emoji 是社交媒体的产物，不属于商品级软件。

**图标字体**：Material Symbols Rounded（可变字重 400-600，可变 fill 0-1，可变 grade -25~200）

**使用规则**：
- Tab 栏图标：weight 400，fill 0（未选中）→ fill 1（选中），24dp
- 列表行图标：weight 400，fill 0，20dp
- Section 标题图标：weight 600，fill 1，18dp
- 状态标签内图标：weight 600，14dp
- 文件类型图标：自绘 `file_type_icon.dart`（圆角方块 + 渐变底色 + 白色粗体扩展名文字），不使用系统图标
- 设置页行图标：30×30 圆角方块彩底 + 白色 Material Symbol 居中

**自定义图标**（需自绘、不使用现成图标的场景）：
- 文件类型标识（PDF / DOC / PPT / XLS / ZIP 从颜色和排版上区分）
- 空状态插画（每个列表有独立的轻量插画）
- 课程颜色标识（顶部渐变色条）
- Logo / 启动图

---

## 七、数据模型

### 7.1 成绩相关字段（Assignment 模型）

```dart
class Assignment {
  // ... 基础字段
  
  // 成绩 —— 以下字段都可能为 null
  final bool graded;
  final double? grade;              // 数值分（100分制/10分制/20分制都可能）
  final HomeworkGradeLevel? gradeLevel; // 等级：A+/A/B+/.../优秀/已阅/通过/不通过/...
  final String? graderName;         // 批改人
  final String? gradeTime;          // 批改时间
  final String? gradeContent;       // 教师评语（纯文本 or HTML）
  final RemoteFile? gradeAttachment; // 批改附件
}

enum HomeworkGradeLevel {
  checked,      // 已阅
  aPlus, a, aMinus,
  bPlus, b, bMinus,
  cPlus, c, cMinus,
  dPlus, d,
  g, p, f, w, i, ex, na,
  distinction,  // 优秀
  exemptedCourse, // 免课
  exemption,    // 免修
  pass,         // 通过
  failure,      // 不通过
  incomplete,   // 缓考
}
```

### 7.2 本地追踪状态

```dart
class LocalState {
  Set<String> favorites;       // 收藏的 ID
  Set<String> archived;        // 归档的 ID
  Set<String> manuallyRead;    // 手动标已读
  Set<String> manuallyUnread;  // 手动标未读
  Set<String> viewedGradeIds;  // 已查看过成绩的作业 ID（用于首页"新批改"判断）
}
```

---

## 八、开发阶段

### Phase 1：地基（第 1 周）
- [ ] Flutter 项目初始化 + 完整目录结构
- [ ] 设计系统（theme / colors / typography / dimensions）
- [ ] Dio 网络层 + Cookie 管理
- [ ] Drift 数据库 schema + DAO
- [ ] Riverpod 架构 + 代码生成配置
- [ ] GoRouter 路由定义 + 平板双栏 ShellRoute
- [ ] 国际化框架 + 首批翻译键

### Phase 2：API 层（第 2 周）
- [ ] 所有 freezed 数据模型
- [ ] URLs 常量
- [ ] learn_api.dart 核心方法移植
- [ ] HTML 解析逻辑
- [ ] 单元测试（覆盖所有 API 方法）

### Phase 3：认证 + 骨架（第 3 周）
- [ ] 登录页 + SSO 页
- [ ] 凭据存储 + 自动重登录
- [ ] 4 Tab 导航 + 角标逻辑
- [ ] 通用组件：RefreshList / FilterBar / SwipeAction / StatCard / SectionHeader

### Phase 4：首页 + 核心页面（第 4-5 周）
- [ ] 首页全部 5 个 Section
- [ ] 作业列表（面板 + 筛选 + 列表含进度条）
- [ ] 作业详情（完整信息块 + 成绩显示）
- [ ] 作业提交
- [ ] 通知详情
- [ ] 文件详情（下载/预览/分享）
- [ ] 课程列表（面板 + 网格）
- [ ] 课程详情（仪表盘 + Sub-Tabs）
- [ ] 搜索

### Phase 5：设置 + 高级功能（第 6 周）
- [ ] 设置全部子页面
- [ ] 日历/提醒同步（课程 + 作业）
- [ ] 文件缓存管理
- [ ] 学期切换
- [ ] 课程排序（拖拽）
- [ ] 更新检查

### Phase 6：打磨（第 7-8 周）
- [ ] 动画打磨（页面过渡、列表入场、角标弹跳、滑动操作）
- [ ] 骨架屏全面覆盖
- [ ] 空状态设计
- [ ] 暗色模式精调
- [ ] 平板双栏测试
- [ ] 性能优化
- [ ] APK 签名 + 发布构建

---

## 九、质量标准

| 指标 | 目标值 |
|------|--------|
| 冷启动到可交互 | < 1.5s |
| 列表滚动帧率 | 60fps |
| 首页刷新感知延迟 | < 2s |
| 断网可用性 | 全部缓存数据可离线浏览 |
| APK 大小 | < 20MB |
| API 层测试覆盖 | > 90% |
