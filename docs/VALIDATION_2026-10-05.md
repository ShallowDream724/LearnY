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
