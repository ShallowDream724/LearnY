# 课程颜色

课程使用 20 个命名柔和色，每色统一定义浅色、深色与玻璃表面的取色。颜色用于辅助识别，课程名称、图形和状态仍然保留，不能仅靠颜色传达信息。

在课程菜单选择“更换颜色”进入选择器。色块显示当前选择，带点的颜色表示已有其他课程使用，悬停可查看课程名称，读屏可获得使用数量；用户仍可有意选择相同颜色。“自动分配”恢复由系统选择。选择器“完成”更新整理草稿，“取消”、关闭、返回或 Esc 放弃本次选择；整理页“完成”统一保存，“取消”保留已保存颜色。

自动分配按账号、学期和课程保存，初次分配以课程 ID 的稳定顺序处理，并优先选择当前使用最少的颜色。同学期首次分配 20 门以内不重复，36 门时每色至多分配两门。已保存的自动颜色和手动选择优先保留，排序、待办数量和刷新不改变课程颜色；新增课程优先填补空闲颜色。手动重复允许保留，课程暂时离开名单时不删除其保存记录，以便再次出现时恢复身份。

`StudyTone` 定义稳定编号与主题色；`assignCourseColors` 负责纯分配规则。`CourseIdentityRepository` 从所有已缓存学期加载课程并保存缺失的自动颜色，同时合并课程原名、简称与图标；`courseIdentitiesProvider` 绑定当前账号。应用通过 `CourseIdentityScope` 向各路由与弹层提供只读身份索引，`StudyPalette.course(context, id)` 统一解析颜色，设计组件不依赖 Riverpod，也没有全局可变取色缓存。整理中的卡片和图标选择器可以传入草稿颜色即时显示。

持久字段沿用 `CourseDisplayPrefs.accentKey`：手动色为稳定色名，自动色为 `auto:<色名>`，无需数据库迁移。自动创建的偏好记录使用 `sortOrder = -1`，不参与用户排序，避免自动保存颜色改变按待办排列的默认课程顺序。整理保存使用 upsert 并显式写入已清除的简称、图标；暂时缺席课程的记录得以保留。无法识别的颜色在显示时采用自动回退，后台不会覆盖非空的未知值。

必要行为验证：`flutter test --no-pub test/features/courses/course_color_assignment_test.dart test/features/courses/course_workbench_models_test.dart test/features/courses/course_workbench_controller_test.dart`。实际设备观感由项目负责人验收。
