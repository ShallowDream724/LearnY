# 2026-10-05 修复与验收

## 范围

本轮交付课程卡片密度、作业详情和提交布局、导航交互、背景对比度、自动登录收尾、课表暂时失败恢复以及文件预览内存边界。Course X、个人日程、课程包分享和 AI 功能仍属于后续迭代，不在本版本中宣称完成。

## 诊断证据

- 使用现有账户 Cookie 的内存副本运行正式课表协议探针，禁用密码提交。2026-10-05 完整秋季查询返回 75 条教务事件；经过教务 → OAuth → WebVPN → 教务日历的实际重定向。诊断不写回应用 Cookie，也不保存密码。
- 随后三次同条件复测均遇到 WebVPN 会话失效：学堂仍已登录，教务链返回身份 checkSingle 表单。仅注入进程内用户环境凭据、未提供可信设备指纹的一次受限诊断进入学校二次认证；没有完成该认证。观测到二次认证 HTML 中的 checkSingle 字样被旧检测误认为快捷登录页，导致清 Cookie 后再提交密码。本轮改为识别真实表单，收到二次认证后停止重复提交，交由原 WebView 完成。
- Chrome 插件和内置浏览器连接超时；本轮网络证据来自同一生产 API 的脱敏逐跳日志，未取得浏览器 DevTools 录制。
- 原 Windows Release 冷启动后静置：工作集 219.4 MiB、私有内存 223.2 MiB。未复现用户报告的 1–2 GiB，因此不能声称已找到所有长期增长原因。测量进程随后关闭。
- 原代码存在整包读取 ZIP、PDF 单阅读器默认较高图像缓存、隐藏分支动画继续运行和旧 API 客户端未显式释放等可确认的资源成本，本轮分别处理。

## 验证记录

- `flutter test --no-pub`：333 项全部通过。包括二次认证不重复密码、启用自动登录完成顺序、暂时课表失败定时恢复／身份挑战停止重试、导航取消与键盘访问、压缩包并发清理和损坏输出重试。
- `flutter analyze --no-pub lib test tool`：无问题。实际 Flutter 页面预览通过，包含 390 / 800 / 1440 宽度、大字号与深色场景；手机课程双列、手机要求展开及桌面作业分栏已经检查。
- Windows 生产构建成功并覆盖 `build/windows/x64/runner/Release`，EXE 内嵌版本 `0.1.5+32`。Android 使用已有依赖离线构建成功，包名 `com.learny.learn_y`、版本 `0.1.5`、构建号 `32`。
- Android 签名 SHA-256 为 `a103a8442a1431d781f05e9d2ef2bf5c4ead155934fa7a343dc2e1a115833269`，与旧版本一致。
- 本地分发目录为 `dist/releases/v0.1.5-build32/`，含 APK、完整 Windows 目录、免安装 ZIP 和 `SHA256SUMS.txt`。没有推送源码或发布 GitHub Release。

新版 Windows Release 在启动后 15 / 45 / 75 秒采样，工作集为 249.9 / 239.7 / 239.7 MiB，私有内存为 257.3 / 247.3 / 246.2 MiB。采样进程已经关闭。旧版静置值为 219.4 / 223.2 MiB；两次网络会话状态并不完全相同，且新版空闲值没有下降，因此不以此宣称内存整体减少。已验证的是预览缓存边界、后台解压和资源释放行为；长期交互后的 1–2 GiB 占用仍需复现。

本地日志：`output/overhaul-verified-tests.log`、`overhaul-verified-analyze.log`、`overhaul-windows-build.log`、`overhaul-android-build.log`、`overhaul-package.log`、`memory-final-20261005.json`。日志和预览产物保留在本机，不提交账户快照或密钥。

## 未覆盖

- 已观测学校二次认证页，未完成短信和信任设备验证；登录流程通过离线测试覆盖成功发布顺序、校验失败和继续登录路径。
- 已复现学堂登录仍有效而教务要求身份续期，且查出二次认证误判。未覆盖携带真机可信设备状态的全部恢复路径，不能宣称所有间歇失败均已解决。
- widget 预览使用 Skia，不能证明 Android Impeller 折射效果达到 FLClash 的真机观感；导航基于交互观察独立实现。
- 作业界面以真实 Flutter 演示数据渲染，未向学校提交任何作业。

## 12:15 后续做：真实阅读器与同步性能

本次续做没有启动子代理。Windows 桌面工具可以操作生产构建；后台截图与控件索引存在工具问题，使用实际前台画面定位。Chrome 连接仍报 fetch failed，已存在的内置浏览器标签绑定也在 30 秒后超时，因此没有新的浏览器认证验收结果。

在 build 32 的同一个 Release 进程内，实测已缓存资料，不产生大文件下载：

| 场景 | 工作集 MiB | 私有内存 MiB |
| --- | ---: | ---: |
| 首页与课程浏览前 | 262.0 | 261.3 |
| 打开 4 页 PDF | 365.4 | 361.9 |
| 跳到文档末页 | 413.5 | 409.0 |
| 返回课程列表 | 317.7 | 314.4 |
| 打开 690 页、24 MB 扫描 PDF | 405.4 | 400.9 |
| 跳到第 350 页 | 408.7 | 403.8 |
| 跳到第 533 页 | 419.1 | 415.1 |
| 关闭长文档后短时采样 | 415.1 | 411.5 |
| 再次打开同一长文档 | 386.3 | 382.6 |

测试进程已关闭。数据说明本次有限交互没有复现 1–2 GiB，也没有证明长期使用无泄漏；释放资源不保证操作系统立即收回所有已分配内存。重复打开时阅读位置回到第 1 页，记为后续阅读连续性改进，不在本轮并发修复中混入新的持久化逻辑。采样见本机 `output/memory-interaction-20261005.jsonl`。

代码确认的等待成本：课程排课元数据原来逐门串行读取，内容同步则每三门组成一批、等待整批后继续。build 33 共用最多三个工作循环的队列，已完成请求立即释放位置，顺序和部分失败语义不变；取消后不再增加请求，并等候进行中的请求结束。针对性 30 项测试已通过，覆盖慢项不阻塞下一项、并发上限、结果顺序、部分失败、取消与账户切换。

build 33 最终验证：337 项全套测试通过，`flutter analyze --no-pub lib test tool` 无问题；真实只读目录探测取得 6 门课程，6 门排课元数据全部成功，目录及元数据阶段总计 408 ms。此时间只描述本次网络条件，没有旧版同条件计时，不能推导固定加速比例；本次禁用密码提交，未请求作业写接口。

两端生产构建、内嵌版本和 APK 签名检查完成。Windows 已覆盖原 Release 目录，最新本地分发位于 `dist/releases/v0.1.5-build33/`，build 32 分发仍保留。构建和诊断日志使用 `output/build33-*` 前缀；新版本未推送或公开发布。

## build 34：作业操作链、顶栏与外壳协作

用户指出上一轮视觉验收不足，提供了只有一份要求附件的 Ch16 提交页和首页顶栏截图。本轮按完整操作链重组作业：身份/截止与要求在桌面左侧，编辑、附件、核对、提交在右侧同一表面，窄屏按同序纵向排列。移除全宽截止面板与独立底部提交白条。四个主页共用局部前景保护，保留壁纸连续性。

只读检查用户本机作业缓存，确认旧正则把 Ch16 的 HTML 注释截断为 `-->`；未修改数据库内容。本轮统一正文解析，排除注释，保留段落与实体字面文本。壁纸复核使用用户当时正在使用的 `alpine`、56% 强度；没有修改用户壁纸配置。

- 全套 `flutter test --no-pub`：339 项通过，`flutter analyze --no-pub lib test tool` 无问题。
- 新外壳行为测试使用生产路由和外壳、隔离演示仓储，覆盖纵向滚动不误切页、按压预览/松手提交、竖向取消、半途横滑后点击当前页归位、详情返回保留位置、键盘出现/关闭。没有向学校提交作业。
- Flutter 预览覆盖 1267×684 的附件作业、长要求、390 手机、950 大字号、键盘与选中文件；取消退出后保留输入。相关产物位于 `build/ui_preview/workflow/`，普通首页和深色预览仍在 `build/ui_preview/`。
- 用户随后明确要求自行复核界面，因此停止计划中的原生窗口复核；未启动新版应用代替用户验收。离线渲染和行为测试不等同于安卓真机光学效果验收。
- Windows 与 Android 生产构建完成，内嵌版本均为 `0.1.5+34`；Windows 已覆盖 `build/windows/x64/runner/Release`。Android 使用现有依赖离线构建，APK 签名与 build 33 一致。
- 本地分发：`dist/releases/v0.1.5-build34/`，包含 APK、完整 Windows 运行目录、便携 ZIP 与 SHA256SUMS。APK SHA-256 为 `078ada5fabca1261d775ea503a44de34d30ddeac8893934f4331e4464e600019`。没有推送或公开发布。

源码提交 `de3b378`。验证日志：`output/review-full-tests.log`、`review-ui-analyze.log`、`review-ui-preview.log`、`review-package.log`；两端构建日志为 `overhaul-windows-build.log` / `overhaul-android-build.log`（当前内容属于 build 34）。

## build 35：悬浮导航的选中对比

用户提供 Android 设置页截图：白色内容面板下的玻璃选中透镜接近不可见。保留已有几何和手势，只调整材质的明暗范围、选中面淡色调与静止投影。`NavigationGlassAppearance` 与通用 `GlassSurface.backdropTone` 分离导航语义和光学实现，实际背景颜色通过同一 GPU 过滤层连续进入材质，不新增 CPU 取色或逐帧截图。

- `flutter test --no-pub test/core/shell test/course_glass_test.dart test/core/design/material_contrast_test.dart`：8 项通过。新增渲染检查涵盖明暗主题各五种底色，选中面与栏体像素对比至少 1.2:1，图标与其所在面至少 3:1，背景变化仍改变材质颜色；高对比模式采用实心选中状态。原来的拖动、取消、页面协作和材质缓存检查继续通过。
- `flutter analyze --no-pub lib test tool` 无问题。上述像素检查由 Skia 渲染，Android Impeller 观感继续由用户真机复核，未操作用户的应用窗口。
- 两端生产构建与打包完成，内嵌版本 `0.1.5+35`。Windows 已覆盖原 `build/windows/x64/runner/Release`；APK 包名与签名延续 build 34，可覆盖更新。没有推送或公开发布。
- 分发目录 `dist/releases/v0.1.5-build35/`；APK SHA-256 `95ca34e127871bfea3ff9d4a27dec7f502a6f2cb4a3523a5c47b7d6c4e9595be`。源码提交 `c322264`。

日志：`output/nav-contrast-tests.log`、`nav-contrast-analyze.log`、`nav-contrast-package.log`。两端 `overhaul-*-build.log` 已更新为 build 35 记录。

## build 36：正文对齐与彩色统计的可读性

用户确认先前提出的方案后实施：作业身份与面板正文共用 20 dp 内边距，涵盖详情、提交编辑及两端布局；首页统计保留彩色色相、轻字重和原有入口，主题色阶与局部柔边阅读底协同。

针对用户提出的取色精度和性能要求，正文保护不再依据缩小图片的平均色。每张已解码壁纸通过一个串行工作 isolate 生成保守 RGB 范围，至多保留 12 KiB 表及 128 项查询缓存；窗口/滚动按同一裁剪变换查询，包含滤波边界。自定义图因解码分档重新加载时会重新分析，重复请求合并到最新图片；原始分析像素不长期保存。内存边界见 [材质文档](GLASS_MATERIAL.md)，本轮没有以缓存上限推导整个应用的内存下降。

- `flutter test --no-pub test/core/design test/course_glass_test.dart test/core/shell`：20 项通过。新增检查包括大面积白色中仅一个暗像素、透明像素、用户壁纸深色处理、裁剪区域和强度，以及明暗主题的彩色数字/标签在混合纹理下的对比。原有导航与外壳协作继续通过。
- `flutter analyze --no-pub lib test tool` 无问题。原 Flutter 布局预览的两项工作流检查通过，覆盖稀疏/长要求、手机、较矮桌面、大字号、键盘以及明暗主题。没有操作用户的应用窗口或提交实际作业，观感由用户复核。
- Windows / Android 生产构建、内嵌版本与签名检查完成，版本 `0.1.5+36`；Windows 已覆盖用户原 Release 目录。APK 包名和签名延续旧版本，依赖使用已有缓存离线构建。
- 分发 `dist/releases/v0.1.5-build36/`；APK SHA-256 `80d21eb99d9417dd4938038618dc3b8903056b086122d9c1717242de6d93183d`。没有推送或公开发布。

日志：`output/stats-reading-tests.log`、`stats-reading-analyze.log`、`stats-reading-layout.log`、`stats-reading-package.log`。`overhaul-*-build.log` 当前记录 build 36。

## build 37：统一阅读保护、标题边界与菜单返回

用户批准局部底色方案，并明确要求内容内部强度恒定、渐变向外发生。本轮将阅读颜色解析与绘制从壁纸生命周期模块拆出，共用 `StudyReadingGroup`；覆盖课程整理及顶栏操作、同步异常图标、作业待交摘要/筛选/全部分组、设置分组和红色退出按钮。各页面保留业务动作与布局。普通滚动标题取消壁纸切片重绘，固定/浮动标题继续遮住经过的内容，仅在工具栏外渐隐；标题不再把外侧保护截成硬边，并在系统状态栏前归零。

未读文件排序在左、类型按钮在右；空间不足时换行后仍靠右。原 `MenuAnchor` 没有注册路由返回拦截，返回页面时覆盖层随退出转场结束才被移除。类型和外观菜单改用共享 `StudyMenuAnchor`，菜单打开时先消费系统返回；选择、Esc 和外部点击共用关闭路径，焦点由触发器持有并释放。

- `flutter test --no-pub test/core/design test/course_glass_test.dart test/core/shell test/features/profile/appearance_menu_test.dart test/features/files/file_type_filter_navigation_test.dart`：29 项通过。像素检查覆盖保护内部平坦、外部渐隐、工具栏边界连续性、系统顶部 inset、固定标题在 30%/100% 下与经过内容的衔接；明暗主题按钮使用实际受保护色，混合纹理对比同时覆盖红色退出语义。系统返回测试要求一帧关闭菜单、保留页面，再次返回才退页；原焦点、外壳手势和底栏对比回归继续通过。
- `flutter analyze --no-pub lib test tool` 无问题。生产页面与隔离演示仓储的 Flutter 布局检查通过，使用 `alpine` 100% 强度，覆盖首页、作业、课程、设置及未读文件，包含 390/800/1440 宽度、大字号与明暗主题。未启动应用窗口代替用户审美或真机验收。
- 阅读标签没有新增模糊、离屏层、图片读回或图片分析任务；仅固定/浮动标题的遮挡有一个工具栏范围的临时 GPU 合成层，详细资源边界见 [材质文档](GLASS_MATERIAL.md)。没有用局部优化宣称长期应用内存问题全部解决。

- Windows 与 Android 最终生产构建、内嵌版本和签名检查完成，版本均为 `0.1.5+37`。Windows 已覆盖用户原 `build/windows/x64/runner/Release`；Android 使用已有依赖离线构建，包名 `com.learny.learn_y`，签名与 build 36 一致。
- 本地分发：`dist/releases/v0.1.5-build37/`。APK SHA-256 `a779822c5f33d8157f5dc62383daf7910b152dc534312fd43a018b19b4eb8d4f`，Windows ZIP `67c89c9114ec81cedf33bbe2866b61c9f4e16bcd0577dbe9baf0f4f103a30012`；完整运行目录和 SHA256SUMS 同时保留，没有推送或公开发布。

日志：`output/reading-groups-tests.log`、`reading-groups-analyze.log`、`reading-groups-layout.log`、`reading-groups-package.log`；`overhaul-*-build.log` 当前记录最终 build 37。

## 0.1.5 正式发布准备

用户明确授权发布正式 Release 0.1.5，沿用已构建、验证的 build 37。构建源码为 `28d985e`；随后提交仅整理公开发布说明、下载链接和打包校验文本格式，`lib/`、Android/Windows 工程、资源以及版本/依赖文件与该构建提交一致，没有重编译或替换安装包。SHA256SUMS 改为 UTF-8 无 BOM、LF 换行，两端文件通过 `sha256sum --check`；APK 和 Windows ZIP 的 SHA-256 沿用上方记录。

正式 Release 已发布并设为 Latest：`v0.1.5`，GitHub Release ID `403753619`。本地后续候选不替换该 tag 或发布资产。

## build 38：撤销扩散阅读底与标题遮挡

用户实际使用反馈表明，build 37 的白色阅读底在滚动时形成明显黏连，设置固定标题的外侧渐变还会覆盖下方卡片。此前像素测试只证明了渐变的数学连续性，不能证明交互和审美成立。本轮删除 `ReadingFeather`、`StudyReadableContent` 及标题壁纸切片，不继续叠加柔边补救。

普通四个主页标题随内容自然滚动，课程整理模式的取消/完成使用范围内的实底固定栏。设置分组名移入所属 `SettingsGroup` 面板；统计、作业筛选/折叠与退出使用共用 `StudyControlSurface`。固定材质只在控件圆角内合成，不随壁纸和滚动猜测颜色、生成外扩渐变或重复背景过滤。标题只保留小范围字形光影。作业标签的首字与标题及正文对齐，底色两侧独立延伸。

- 28 项相关回归检查均通过，失败后定点复测。涵盖有界控件之外像素不变、滚动内容不被标题遮挡、明暗主题所有课程语义色与退出红色在白/黑极端背景上至少 4.5:1，以及原菜单返回、外壳与导航行为。课程玻璃的滑动/跳转图像比较容许至多一个 8-bit 色阶的浮点变换舍入，场景内容不能变化。
- 实际 `AppBar` 会插入自己的 `IconButtonTheme`；仅改变 `ThemeData` 不足以覆盖它。本轮明确覆盖按钮继承作用域，并检查最终按钮 `Material.color`，避免主题参数看似正确、实际按钮仍透明的错误。
- `flutter analyze --no-pub lib test tool` 无问题。生产页面配隔离演示仓储的 Flutter 布局检查通过，包含 390/800/1440 宽度、大字号、明暗主题、课程整理，以及手机/桌面作业状态文字左边线。
- 按用户要求直接生成「远山」30% / 80% 的手机首页和设置图，使用当前 Flutter 页面及示例数据；图片保存在 `build/ui_preview/build38-30/`、`build/ui_preview/build38-80/`。没有启动真实账户应用代替用户验收。该预览使用 Skia，不是 Android 真机折射截图。
- 最终 Windows 与 Android 生产构建均为 `0.1.6+38`。Windows 已覆盖原 `build/windows/x64/runner/Release`；APK 包名与签名保持一致，Android 依赖离线构建。分发目录 `dist/releases/v0.1.6-build38/`，未推送或公开发布。
- APK SHA-256：`9fca20ff1a0e96115a0fc15a9c91b08beb31962f3da23e87a6251907342f2f64`；Windows ZIP：`58bf385c1729fd1b0bf015ecb1a22690340947fd9d4a900914d1a5ca9a0cad49`。已有公开 0.1.5 资产保留。

本地日志：`output/ui38-tests.log`、`ui38-glass-retest.log`、`ui38-control-retest.log`、`ui38-analyze.log`、`ui38-layouts.log`、`ui38-wallpaper30.log`、`ui38-wallpaper80.log`、`ui38-package.log`；`overhaul-*-build.log` 当前记录最终 build 38。

## build 39：透明阅读层与真实纹理模糊

用户继续明确要求壁纸透亮、文字处在透明层上，拒绝 build 38 的白色操作块。本轮删除 `StudyControlSurface`；标题、统计、作业摘要/筛选/折叠及退出入口使用共享 `StudyReadingInk`。背景根节点先绘制壁纸和实际纹理模糊，再绘制全部内容；模糊不会盖在卡片上。九点核上限 6 dp，外侧 32 dp 内步长与混合量同时平滑归零，保持原图颜色。前景调节有色阶上限，共用一个短暂运行的动画时钟；混合纹理不宣称无条件达到 4.5:1。

- `flutter test --no-pub test/core/design test/course_glass_test.dart test/core/shell test/features/profile/appearance_menu_test.dart test/features/files/file_type_filter_navigation_test.dart`：30 项通过。新增像素回归确认平坦彩色壁纸没有被增白、实际细纹理被平滑、重叠的实色卡片像素完全不变、保留但隐藏的路由没有模糊残留。前景变化在中途和结束呈连续色阶，减少动态效果直接定位，卸载后没有动画回调残留。
- 最终 `AppBar` 按钮在明暗主题的休止 `Material.color` 均透明。课程玻璃仍检查跳转与滑动的采样坐标误差小于 .001 dp；允许最多两个 8-bit 色阶的栅格舍入，平均字节差小于 .1，避免以宽容像素阈值代替坐标正确性。
- `flutter analyze --no-pub lib test tool` 无问题。生产 Flutter 页面配隔离演示仓储生成「远山」30% / 80% 首页、作业、课程和设置图，布局覆盖 390/800/1440、大字号、明暗主题及课程整理。手机对比图保存在 `build/ui_preview/build39-30/` 和 `build/ui_preview/build39-80/`。该预览使用 Skia 与示例数据，不是校园账户或 Android 真机折射截图。
- 复用已有壁纸和保守范围表，没有新增 CPU 像素读回、逐标签位图或整屏图片缓存。各 RenderObject 释放 shader，切图时隐藏字段也更新采样引用；只绘制可见区域。前景增加局部 ColorFilter 合成成本，未以此宣称整体内存或所有设备帧率已达标。

日志：`output/ui39-tests.log`、`ui39-motion-tests.log`、`ui39-analyze.log`、`ui39-wallpaper30.log`、`ui39-wallpaper80.log`。

最终 Windows 与 Android 生产构建均为 `0.1.6+39`。Windows 已覆盖用户原 `build/windows/x64/runner/Release`；Android 依赖离线构建，包名 `com.learny.learn_y`，证书 SHA-256 与前版一致（`a103a8442a1431d781f05e9d2ef2bf5c4ead155934fa7a343dc2e1a115833269`）。打包脚本核对两端内嵌版本，额外确认 Windows 和 APK 内均包含三份玻璃/阅读 shader。

分发目录 `dist/releases/v0.1.6-build39/`，APK SHA-256 `24c1a5f9d67a6c75bcbe7defe9bb77eebc16ba415f82a881e803dec28a5a4c8a`，Windows ZIP `1cb957cbd1c5ccec19a2a69c194fbe43980921dabf929426e7a3643a3e97eff2`；两份产物通过 `sha256sum --check`。源码和文档本地提交，未推送或公开发布，既有 0.1.5 tag 与资产保持不变。构建日志保存在 `output/ui39-windows-build.log`、`ui39-android-build.log`，版本、资源、签名和打包记录见 `ui39-package.log`、`ui39-apk-signature.log`。

## 0.1.5 build 40 替换发布

用户随后明确授权替换公开 0.1.5，限定只做发布。本轮只将内嵌版本统一为 `0.1.5+40` 并同步发布信息；`lib/`、Android/Windows 工程、资源、shader 和依赖锁文件与已验证的 `997a921` 无差异，不重做功能检查或增加实现。两端正式入口重新构建，Windows 与 APK 版本检查通过；APK 包名和证书延续 build 39，三份 shader 均存在于两端包内。

本地分发为 `dist/releases/v0.1.5-build40/`，APK SHA-256 `cc85b95515a4b338f92a17dd02b1f10b48182bae392e4dd370723c6ffcecf78c`，Windows ZIP `094b43046a0c3996378776e2908e60eefddb8b6a4e50c9729f7f96fe5ba6fdfd`，两份文件通过 `sha256sum --check`。替换使用原 Release ID `403753619`、tag `v0.1.5`、既有资产名称和下载 URL；源码 tag 按本次授权更新，其他历史 tag 保留。构建、签名、打包和远端核对记录保存在本机 `output/release015-*.log`。
