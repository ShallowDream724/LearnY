# Theme Color Migration Handoff — 完整交接文档

## 背景：我们在做什么

LearnX 是一个 Flutter 教学助手 App。之前所有 widget/screen 文件中获取主题颜色的写法是：

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
final subColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
final tertiaryColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
```

这段代码在 17+ 个文件中重复出现（100+ 处实例）。我们已经创建了一个 [AppThemeColors](file:///d:/learnx-flutter/lib/core/design/app_theme_colors.dart#18-37) 扩展来替代：

```dart
// 新写法 — 一行搞定
final c = context.colors;
// 然后直接用 c.bg, c.surface, c.border, c.text, c.subtitle, c.tertiary
```

---

## 当前状态（0 编译错误，代码干净）

### 已完成并提交到 Git ✅

1. **[core/design/app_theme_colors.dart](file:///d:/learnx-flutter/lib/core/design/app_theme_colors.dart)** — 新建，定义 [AppThemeColors](file:///d:/learnx-flutter/lib/core/design/app_theme_colors.dart#18-37) 类和 `AppThemeX` 扩展
2. **[core/design/design.dart](file:///d:/learnx-flutter/lib/core/design/design.dart)** — 已添加 [app_theme_colors.dart](file:///d:/learnx-flutter/lib/core/design/app_theme_colors.dart) 的 export
3. **4 个 widget 文件已迁移：**
   - [features/home/widgets/notification_card.dart](file:///d:/learnx-flutter/lib/features/home/widgets/notification_card.dart) → 用 `c.surface`, `c.border`, `c.text`, `c.subtitle`, `c.tertiary`
   - [features/home/widgets/stat_card.dart](file:///d:/learnx-flutter/lib/features/home/widgets/stat_card.dart) → 用 `context.colors`，**已移除 `isDark` 构造参数**
   - [features/home/widgets/deadline_card.dart](file:///d:/learnx-flutter/lib/features/home/widgets/deadline_card.dart) → 用 `context.colors`
   - [features/files/widgets/file_card.dart](file:///d:/learnx-flutter/lib/features/files/widgets/file_card.dart) → 用 `context.colors`
4. **[home_screen.dart](file:///d:/learnx-flutter/lib/features/home/home_screen.dart)** 中 [StatCard](file:///d:/learnx-flutter/lib/features/home/widgets/stat_card.dart#8-73) 的 3 个调用点已移除 `isDark: isDark` 参数
5. **[sync_provider.dart](file:///d:/learnx-flutter/lib/core/providers/sync_provider.dart) 拆分为 3 个文件：**
   - [core/providers/sync_models.dart](file:///d:/learnx-flutter/lib/core/providers/sync_models.dart) — 所有数据模型类
   - [core/providers/home_data_provider.dart](file:///d:/learnx-flutter/lib/core/providers/home_data_provider.dart) — homeDataProvider
   - [core/providers/sync_provider.dart](file:///d:/learnx-flutter/lib/core/providers/sync_provider.dart) — 只含 SyncNotifier + re-export
   - 修了 `List<dynamic>` → `List<_SyncCourseRef>` 类型安全问题
6. **[core/design/action_sheet.dart](file:///d:/learnx-flutter/lib/core/design/action_sheet.dart)** — 新建，可复用 iOS 风格确认/取消 ActionSheet
7. **[core/design/file_type_utils.dart](file:///d:/learnx-flutter/lib/core/design/file_type_utils.dart)** — 新建，集中文件类型 icon/color 映射
8. **[core/design/cooldown_toast.dart](file:///d:/learnx-flutter/lib/core/design/cooldown_toast.dart)** — 修了黄线渲染 bug

### 未完成 ❌（17 个文件需要迁移）

以下文件仍使用 `isDark ? AppColors.dark... : AppColors.light...` 旧模式：

| # | 文件 | 复杂度 | 备注 |
|---|------|--------|------|
| 1 | [features/home/home_screen.dart](file:///d:/learnx-flutter/lib/features/home/home_screen.dart) | 高 | 主 build() + 3 个 helper methods（[_buildStatsRow(bool isDark)](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#340-382), [_buildEmptyState(bool isDark)](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#383-408)）+ 2 个 private widgets（[_SectionTitle](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#426-468), [_NewFileCard](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#473-587)）都接收 `isDark` 参数 |
| 2 | [features/search/search_screen.dart](file:///d:/learnx-flutter/lib/features/search/search_screen.dart) | 高 | 主 build() + 3 个 helper methods 传递颜色参数 + 2 个 private widgets（[_SearchField](file:///d:/learnx-flutter/lib/features/search/search_screen.dart#558-602), [_CategoryHeader](file:///d:/learnx-flutter/lib/features/search/search_screen.dart#607-656)）|
| 3 | [features/assignments/assignments_screen.dart](file:///d:/learnx-flutter/lib/features/assignments/assignments_screen.dart) | 高 | 主 build() + helper methods + 5 个 private widgets 都有 `isDark` |
| 4 | [features/assignments/homework_detail_screen.dart](file:///d:/learnx-flutter/lib/features/assignments/homework_detail_screen.dart) | 高 | 7 个 private widgets 都有 `isDark` 字段 |
| 5 | [features/assignments/assignment_submission_screen.dart](file:///d:/learnx-flutter/lib/features/assignments/assignment_submission_screen.dart) | 中 | 主 build() + 4 个 private widgets（[_FileCard](file:///d:/learnx-flutter/lib/features/assignments/assignment_submission_screen.dart#512-598), [_ExistingAttachmentCard](file:///d:/learnx-flutter/lib/features/assignments/assignment_submission_screen.dart#603-667), [_AddFileButton](file:///d:/learnx-flutter/lib/features/assignments/assignment_submission_screen.dart#672-711), [_ConfirmSheet](file:///d:/learnx-flutter/lib/features/assignments/assignment_submission_screen.dart#716-803)）|
| 6 | [features/files/unread_files_screen.dart](file:///d:/learnx-flutter/lib/features/files/unread_files_screen.dart) | 高 | 主 build() + helper methods + 3 个 private widgets |
| 7 | [features/files/file_detail_screen.dart](file:///d:/learnx-flutter/lib/features/files/file_detail_screen.dart) | 高 | 主 build() + helper method + private widgets |
| 8 | `features/files/file_manager_screen.dart` | 中 | 主 build() + helper method |
| 9 | `features/files/files_screen.dart` | 中 | 1 个 private widget |
| 10 | [features/courses/course_detail_screen.dart](file:///d:/learnx-flutter/lib/features/courses/course_detail_screen.dart) | 高 | 2 个 private widgets |
| 11 | [features/courses/courses_screen.dart](file:///d:/learnx-flutter/lib/features/courses/courses_screen.dart) | 中 | 1 个 private widget |
| 12 | `features/notifications/notification_detail_screen.dart` | 中 | 主 build() + 1 个 private widget |
| 13 | `features/profile/profile_screen.dart` | 低 | 只有主 build() |
| 14 | `features/auth/login_screen.dart` | 低 | 主 build() + 1 个 helper method |
| 15 | `core/shell/app_shell.dart` | 低 | 主 build() |
| 16 | [core/design/swipe_to_read.dart](file:///d:/learnx-flutter/lib/core/design/swipe_to_read.dart) | 低 | 主 build() |
| 17 | `core/design/shimmer.dart` | 低 | 主 build() |

---

## 迁移规则（必须严格遵守）

### 规则 1：替换 `isDark` 声明块

将每个 build() 方法开头的 isDark 块：

```dart
// 删掉这整块
final isDark = Theme.of(context).brightness == Brightness.dark;
final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
final subColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
final tertiaryColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
```

替换为：

```dart
final c = context.colors;
```

### 规则 2：更新变量引用

在同一个方法体内，将旧变量名按对照表替换：

| 旧变量名（不同文件用不同名） | 新写法 |
|---|---|
| `bg` | `c.bg` |
| `surface` | `c.surface` |
| `border`（仅作为颜色使用时） | `c.border` |
| `textColor` | `c.text` |
| `subColor` / [sub](file:///d:/learnx-flutter/lib/features/assignments/assignment_submission_screen.dart#100-144) / `subtitleColor` | `c.subtitle` |
| `tertiaryColor` / `tertiary` | `c.tertiary` |

> [!CAUTION]
> **`surface`、`border`、`text` 是 Flutter 常用标识符！** 只替换作为**颜色变量**使用的情况。
> 例如 `Border.all(color: border)` 中的 `border` ✅ 要替换
> 但 `border: Border.all(...)` 中的 `border` ❌ 是 widget 属性名，不要替换！
> 同理 `color: surface` ✅ 但 `child: Surface(...)` ❌

### 规则 3：处理接收 `isDark` 作为参数的 helper methods

```dart
// 旧代码
Widget _buildEmptyState(bool isDark) {
  final color = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
  ...
}

// 新代码 — 移除 isDark 参数，在方法内部自行获取
Widget _buildEmptyState() {
  final c = context.colors;
  ...
  // 将 color 替换为 c.tertiary
}
```

**同时更新所有调用点**：[_buildEmptyState(isDark)](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#383-408) → [_buildEmptyState()](file:///d:/learnx-flutter/lib/features/home/home_screen.dart#383-408)

### 规则 4：处理 Private Widget 类的 `isDark` 属性

```dart
// 旧代码
class _SectionTitle extends StatelessWidget {
  final bool isDark;
  const _SectionTitle({required this.isDark, ...});
  
  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    ...
  }
}

// 新代码 — 移除 isDark 字段和构造参数，在 build() 中获取
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({...}); // 移除 isDark
  
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    ...
    // 将 textColor 替换为 c.text
  }
}
```

**同时更新所有调用点**：移除 `isDark: isDark,`

### 规则 5：添加 import

每个被修改的文件需要确保有：

```dart
import '../../core/design/app_theme_colors.dart';
// 或根据文件层级调整相对路径
```

如果文件已经 `import '../../core/design/design.dart'`（barrel export），则不需要单独 import，因为 [design.dart](file:///d:/learnx-flutter/lib/core/design/design.dart) 已经 export 了 [app_theme_colors.dart](file:///d:/learnx-flutter/lib/core/design/app_theme_colors.dart)。

### 规则 6：一些 helper methods 不只传 isDark，还传颜色变量

某些方法签名像这样：
```dart
Widget _buildBody(bool isDark, Color textColor, Color subColor, 
    Color tertiaryColor, Color surface, Color border) {
```

这种情况：移除所有这些参数，在方法内用 `final c = context.colors;` 代替。

---

## AppThemeColors 定义（参考）

文件：[lib/core/design/app_theme_colors.dart](file:///d:/learnx-flutter/lib/core/design/app_theme_colors.dart)

```dart
class AppThemeColors {
  final bool isDark;
  const AppThemeColors({required this.isDark});

  Color get bg => isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surfaceHigh => isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh;
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get text => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get subtitle => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get tertiary => isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
}

extension AppThemeX on BuildContext {
  AppThemeColors get colors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return AppThemeColors(isDark: isDark);
  }
}
```

---

## 其他已完成但未被使用的工作

1. **[core/design/action_sheet.dart](file:///d:/learnx-flutter/lib/core/design/action_sheet.dart)** — 已创建但只在 [assignment_submission_screen.dart](file:///d:/learnx-flutter/lib/features/assignments/assignment_submission_screen.dart) 使用。可以在其他需要确认/取消的页面中复用
2. **[core/design/file_type_utils.dart](file:///d:/learnx-flutter/lib/core/design/file_type_utils.dart)** — 已创建但尚未在任何文件中使用。[file_detail_screen.dart](file:///d:/learnx-flutter/lib/features/files/file_detail_screen.dart) 和 [unread_files_screen.dart](file:///d:/learnx-flutter/lib/features/files/unread_files_screen.dart) 仍然有内联的 `_fileColor()` / `_fileIcon()` helpers，应该用 `FileTypeUtils.color()` / `FileTypeUtils.icon()` 替代

---

## 验证方法

每修改完一批文件后：

```bash
# 编译检查
dart analyze lib

# 如果 0 errors，热重启测试
# 在运行中的 flutter run 终端按 R

# 确认后 git commit
git add -A
git commit -m "refactor: migrate <文件名> to context.colors"
```

---

## 注意事项

1. **先从简单文件开始**（profile_screen, login_screen, app_shell, swipe_to_read, shimmer），这些只有一个 build() 方法，没有 private widgets
2. **复杂文件**（home_screen, search_screen, assignments_screen, homework_detail_screen）有多个 private widget 类和 helper methods，需要同时修改构造函数、字段、调用点
3. **千万不要用 regex 批量替换 `surface`、`border`、`text` 这些通用词**！只替换确定是颜色变量的上下文
4. 每个文件修改后立即 `dart analyze` 验证
