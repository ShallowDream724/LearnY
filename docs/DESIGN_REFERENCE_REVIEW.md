# 设计资料研读与应用

## 来源与阅读范围

来源：[Emil Kowalski skills](https://github.com/emilkowalski/skills/tree/d23d7f88a2e21c9e4b1418c7abe420f5c1052ba7)，固定版本 `d23d7f88a2e21c9e4b1418c7abe420f5c1052ba7`。2026-09-07 已补齐 12 份指南、7 份配套 Markdown，以及 README 和 LICENSE。全局安装名为 `emil-design-eng`；所有指南与配方保存在其 `references/`，源 `SKILL.md` 改名为 `GUIDE.md`，由一个入口按任务读取。

全局版保留技术解释与代码配方、来源和 MIT 许可；调整推广开场、强制委派、禁止直接修复、固定报告格式和固定原型选择器。LearnY 的产品约定仍保存在项目内。阅读完成不等于已验证资料中的每项平台版本或性能断言，更不等于界面已经达到设计目标。

| 指南与配套文件 | 对本项目有意义的内容 |
| --- | --- |
| `emil-design-eng/SKILL.md` | 隐性细节的累积、合理默认值、频率与目的、组件整体一致性、输入和生命周期边界 |
| `apple-design/SKILL.md` | 可预测性、用户控制、熟悉感、简洁与精工；当前呈现值、速度交接、空间路径、材质与字体 |
| `animate/SKILL.md` + `RECIPES.md` | 完整组件的进入、退出、中断与状态反馈；按钮、菜单、提示、抽屉、通知、折叠与拖动配方 |
| `animate-expo/SKILL.md` + `RECIPES.md` | 手势识别器身份、轴向竞争、列表复用、键盘同步、运行时职责与触觉时机 |
| `review-animations/SKILL.md` + `STANDARDS.md` | 按影响审查动效，核对位置和实际代码；对不确定手感补充针对性观察 |
| `improve-animations/SKILL.md` + `AUDIT.md` + `PLAN-TEMPLATE.md` | 覆盖范围、分类审查、过滤误报、使无上下文的接手者理解目标与依据 |
| `find-animation-opportunities/SKILL.md` | 增加动效之前先判断用户是否获益，避免把改进任务变成装饰清单 |
| `animation-vocabulary/SKILL.md` | 用准确术语描述动效及其差异，减少实现时的含糊猜测 |
| `pick-ui-library/SKILL.md` | 优先成熟输入、焦点与生命周期能力；具体 React 库不直接用于 Flutter |
| `prototype/SKILL.md` + `PICKER.md` | 在真实尺度与相同内容下比较行为、布局或密度；避免把换色当成不同方案 |
| `ask-sonner/SKILL.md` + `API.md` | 同一操作按 ID 更新状态、通知层级、计时暂停、关闭和超时的区别 |
| `write-swift/SKILL.md` | 状态建模、异步所有权、取消、生命周期与性能测量；具体语法不移植到 Dart，版本声明需另核实 |

上表路径均相对于固定版本仓库的 `skills/`。例如：[Web 配方](https://github.com/emilkowalski/skills/blob/d23d7f88a2e21c9e4b1418c7abe420f5c1052ba7/skills/animate/RECIPES.md)、[原生交互配方](https://github.com/emilkowalski/skills/blob/d23d7f88a2e21c9e4b1418c7abe420f5c1052ba7/skills/animate-expo/RECIPES.md)、[Apple 设计](https://github.com/emilkowalski/skills/blob/d23d7f88a2e21c9e4b1418c7abe420f5c1052ba7/skills/apple-design/SKILL.md)。

## 要保留的深层关系

1. **用户预期决定界面关系。** 控件靠近什么，用户就会认为它影响什么。首页学期与周课表局部学期必须保持各自范围；打开课程详情后能回到刚才的位置，是允许用户放心浏览的基础。原文依据：`apple-design` 第 7、16 节。
2. **简洁需要减少判断成本。** 空作业页保留大型零统计和多组筛选，会让无用内容占据主要层级；把所有操作藏起来同样会增加成本。需要根据当前数据和任务决定信息层级。依据：`apple-design` 第 16 节的 Simplicity、Grouping 与 Wayfinding。
3. **流畅需要状态连续。** 按下马上反馈，取消不会误执行，拖动能反向，关闭中的弹层不会突然跳回端点。速度、位置、背景遮罩、焦点和生命周期必须由一致的行为驱动。依据：`apple-design` 第 1-10 节及两套拖动配方。
4. **体验的一致性包含工程接口。** 加载、完成和失败应属于同一个操作；课程列表刷新、通知计时、组件复用都需要正确身份和所有权。共享 token 只能统一取值，共享行为才能降低后续组件出错的概率。依据：主指南 Sonner principles、Sonner API、Expo 列表与键盘配方。
5. **视觉细节服务辨认。** 字重、行距、对比、数字宽度、材质厚度和空间位置共同解释内容主次。苹果式设计的价值包括这些协调关系；中性色、玻璃或圆角都只是可选手段。依据：`apple-design` 第 12、14-16 节。
6. **手感必须落到具体观察。** 同一个页面空、密、加载、失败、返回时是否仍清楚；一个动作是否可以打断；一个按钮是否有立即反馈。仅凭规则命中或截图不能证明这些。依据：主指南 Debugging、审查标准和 Prototype。

## 不机械移植的地方

- 通用审查写短于 300ms，抽屉配方却有 500ms，通知示例有 400ms。保留场景差异，分别判断首次反馈、运动距离、可中断性和总时长。
- `PICKER.md` 明确解释了滑块宽度动画的例外；主指南也谈到高度与透明度配合。Flutter 中评估布局、绘制和合成的真实代价，不能凭属性名认定免费或卡顿。
- 原文对键盘动画、强自定义曲线、纯淡入和组入场有强烈偏好。它们用于提醒审视反复等待、运动来源和阅读稳定性；合适的原生曲线、静态反馈或即时呈现可以成立。
- `apple-design` 第 14 节允许减少动态效果时使用静态过渡。因此 `Duration.zero` 不能单独判为 bug；需要看反馈与状态是否仍清楚。
- 材质与排版示例主要来自 Web 和英文语境。中文阅读、Android 与 Windows 字体、Flutter 约束布局和混合输入需要独立判断。
- 核心目标是可靠而自然的操作。依据用户的明确要求决定实施、审阅或比较阶段，原文的固定开场、委派数和强制停止不参与产品设计。

## 壁纸与材质补充（2026-09-14）

全局 `emil-design-eng` 的 `references/materials-and-contrast.md` 保存可跨项目复用的研究与设计规则，Apple 指南第 12 节已同步修正；项目内保留 LearnY 的选择与实施边界。

本次来源为 [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Microsoft Acrylic](https://learn.microsoft.com/en-us/windows/apps/design/style/acrylic) 与 [WCAG 文字对比基准](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)。公开指南描述的是材质分层、明度控制与语义前景等行为，不是 Apple 私有光学算法的实现规格。

项目负责人确认同时改进 Windows 与 Android：壁纸透亮，统计及动作像写在透明层上；阅读内容按任务提供稳定性。build 37 的白色渐变与 build 38 的白色操作块均因真实使用反馈撤销。build 39 在共享背景平面绘制保留原图颜色的局部模糊，强度与混合量向外连续归零；前景按实际范围有限调节明度，不把语义数字压成黑字。分组说明属于已有内容面，普通标题随内容自然滚动，模糊不能覆盖卡片。缓存共享分析，前景变化共用短暂运行的动画时钟；普通小字以 4.5:1 为目标，极端混合纹理不能作无条件保证。

2026-10-05 追加研读 [Apple：Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)、[HarmonyOS 高效模糊](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ui-use-blur-efficiently) 与 [HONOR MagicOS](https://www.honor.com/cn/magic-os/)。采用导航功能层与阅读内容分离、材质不过度套叠的原则；不把颜色渐变冒充背景模糊。普通标题的小范围字形光影不作为任意复杂壁纸的严格对比证明。Course X 待选课程和个人日程仍处于讨论阶段，不作为现有功能描述。

同日查看 OpenWebUI 官方仓库的 [Banner](https://github.com/open-webui/open-webui/blob/main/src/lib/components/common/Banner.svelte) 和 [Navbar](https://github.com/open-webui/open-webui/blob/main/src/lib/components/chat/Navbar.svelte)：Banner 组合真实 backdrop blur 与语义色，导航动作休止透明、悬停才显状态底。Navbar 在默认页面还使用白色渐变延伸；其默认底色关系不适合直接搬到 LearnY 的彩色壁纸。借鉴透明动作与实际模糊的关系，未复制源码或声称整个 OpenWebUI 都不使用底色。

2026-10-06 真机反馈再次拒绝 build 40 的粗糙阅读纹理。九点稀疏核是本项目自行选择的近似，没有来自 Apple、OpenWebUI 或其他参考项目的依据；静态预览和单频条纹方差不能证明高密度设备的连续效果。build 41 改用 [Flutter 原生 Gaussian](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.blur.html)，阅读范围与触控热区分开，依据裁剪可见比例淡出，并统一双线性取样。新增 1×/2×/3× 脉冲剖面和亚像素移动回归，使用实际页面的 3× 连续拖动帧作为补充；该证据仍不等于 Android Impeller 真机观测。

## 日程参考项目（仅研读）

项目负责人提供 [thu-info-community/thu-info-app](https://github.com/thu-info-community/thu-info-app)。2026-09-14 浅克隆到本机独立目录 `D:/learny-references/thu-info-app`，本次阅读固定于 `e684cf63bb76835fe6f86b6f81a766fedf038a4c`；路径仅用于本机查阅，应用与构建不依赖该目录。

- `apps/thu-info-app/src/components/schedule/scheduleAdd.tsx`：共享添加／编辑入口，区分「周次＋节次」与「日期＋时间」，重复项可按本次或整组编辑。可借鉴任务组织，不直接搬用 React Native 控件。
- `packages/thu-info-lib/src/models/schedule/schedule.ts`：14 小节的起止表，傍晚为 17:05–17:50、17:55–18:40，与 LearnY 当前解析表一致。自由时间仍应保留用户或上游的真实分钟值，不能吸附到模板。
- `scheduleAdd.tsx` 的冲突确认会删除已有冲突安排再新增，`redux/scheduleData.ts` 的区间判断将端点相接也视作冲突。这两点不适合本项目：用户明确需要保留叠课与重叠日程，相接时段不应算冲突。

后续讨论的边界：Course X 保留由第三方维护的网页，LearnY 提供将可靠课程信息加入个人课表并标为「待选」的本地能力；不执行学校选课，不把候选项当作已选课程上传。重复周以项目已核实校历为基础；完整编辑交互、重叠布局和数据模型仍待开发。

## 本轮应用结果

- 空间关系：`ContentLayout` 注入扣除侧栏后的内容宽度；根详情页回退到窗口宽度。`ReadingWidth` 只约束行长，修复了它意外占满高度及课程固定标签栏的高度不一致问题。
- 连续操作：移除独立学期横栏、自制底部导航动画和提示覆盖层；导航保留页面身份，提示使用 `ScaffoldMessenger`，菜单锚定触发位置。触控滑动和显式已读按钮共用异步写入，失败不会永久隐藏条目。
- 信息优先级：首页仍为每日入口，宽屏并列待办与更新；作业总览移除零统计大区块与装饰性时间线，单独呈现逾期；筛选空态保留解除入口。文件总览补齐真实路由和入口。
- 完整结果：作业提交保留正文与附件能力，退出编辑保护未保存修改，成功回执由用户关闭。搜索失败可以重试，分组过滤和返回位置有明确状态所有权。
- 主题一致性：导航、输入、按钮和分段筛选读取活动主题颜色，暗色前景使用 `primaryLight`。`NoSplash` 下保留按压、悬停和焦点状态层；真实输入手感仍须设备验收。
- 动效职责：普通过渡采用 `AppMotion`，直接操作继续交给 Flutter 手势、`PageView` 和 `Dismissible`；减少动态效果时停止骨架循环。删除未再使用的 `flutter_animate`、`shimmer` 依赖。
- 验证：实际 Flutter 页面覆盖 390、800、1440 宽度，补充手机大字号和深色首页、作业提交视图。针对性检查覆盖搜索竞态与恢复、作业分组与提交、跨学期导航及输入。截图使用隔离示例数据，不构成真实校园服务验收。

后续实现遵循 [设计体系](DESIGN_SYSTEM.md)、[课表设计](SCHEDULE_DESIGN.md) 及相关业务文档；验证规模按实际风险和用户已确认的设备测试分工控制。
