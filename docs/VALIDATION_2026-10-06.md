# 2026-10-06 阅读材质修订验证

用户反馈 build 40 安装后出现粗糙、杂乱的模糊斑块，之前的静态图片未暴露实际问题。九点稀疏核是本项目自己的近似，不是所引用设计项目的实现。诊断还确认 shader 取样默认为最近邻，而壁纸本身使用平滑过滤；原保护范围包括按钮的完整点击区域，使模糊面积过大。

本轮撤销稀疏核，使用原生 `ImageFilter.blur` 生成共享纹理，sigma 减至 3 dp；字段只做双线性取样和柔和融合。`StudyReadingInk` 在布局时缓存文字/图标的选择框并保留 4 dp 光学空间，不缩小点击热区。背景根节点汇总祖先裁剪，以可见比例淡出；模糊在卡片下面，不遮挡内容。导航自身的光学参数和交互不变。

## 检查与证据

- `flutter test --no-pub test/core/design test/course_glass_test.dart test/core/shell test/features/profile/appearance_menu_test.dart test/features/files/file_type_filter_navigation_test.dart`：35 项通过。1×/2×/3× 脉冲剖面只有一个平滑峰值，亚像素移动前后没有重复影子；220×96 点击区域保持原尺寸，远离文字的热区背景像素不被模糊。原菜单返回、外壳滚动/切页和导航对比回归通过。
- 纹理缓存检查涵盖过期请求、尺寸上限、复用、窗口调整合并、销毁中的任务和退役纹理。检查发现仅添加 post-frame 回调而未请求帧时，独立缓存的旧纹理不会及时释放；现已在安排退役时请求一次帧，销毁时也释放全部退役资源。
- 课程玻璃测试原来只等待系统栏的小图取样，可能在完整范围分析完成前捕获不同阶段。本次明确等待范围表和共享纹理完成，保留原坐标与像素误差阈值，没有靠放宽阈值掩盖失败。
- `flutter analyze --no-pub lib test tool` 无问题。
- 实际手机测试视图为 1170×2532 物理、390×844 逻辑、DPR 3；首页和设置各拖动并捕获 31 帧，期间纹理身份保持不变。使用「远山」80% 强度、隔离演示数据，PNG 及无损动画在 `build/ui_preview/reading_scroll/`。这些是 Skia 测试帧，不能代表 Android Impeller 实测，也不能作为帧率基准。
- Windows 平台配置下实际页面布局检查覆盖 390/800/1440、明暗主题、大字号、课程整理及菜单；没有启动真实账户应用替代用户验收。

## 资源边界

全页保留一份长边最多 1024 的纹理，单份 RGBA 至多 4 MiB；生成、替换时有新旧纹理和原生过滤暂存资源，不能把该数字称为总内存上限。任务串行、排队只保留最新请求；窗口同图调整合并 120 ms，滚动和强度变化不生成纹理。源图 clone、旧结果、定时器和 shader 均有释放路径，没有新增 Dart 像素读回。光学边界测量只发生在布局阶段，滚动使用缓存的选择框与坐标投影。

本地日志：`output/ui41-tests.log`、`ui41-regression-tests.log`、`ui41-analyze.log`、`ui41-scroll-preview.log`、`ui41-layouts.log`、`ui41-motion-export.log`。

## 构建与分发

两端正式入口构建为 `0.1.5+41`。Windows 覆盖原 `build/windows/x64/runner/Release`；Android 使用离线依赖，包名 `com.learny.learn_y`，证书 SHA-256 延续 `a103a8442a1431d781f05e9d2ef2bf5c4ead155934fa7a343dc2e1a115833269`。打包核对版本和三份 shader，两个产物通过 `sha256sum --check`。

本地目录为 `dist/releases/v0.1.5-build41/`。APK SHA-256 `7e4ab2a32e37307d0013a6790293b9800651da884c88baa69b6f3bd0a8d0c2d7`，Windows ZIP `b9305096fab7436cc4c562dc490306b911d3898516b1961012bc33954651512d`。沿用用户已确认的 0.1.5 替换入口、既有文件名和 Release ID `403753619`；tag 对应本次构建源码，历史安装包保留在本机分发目录。

动画导出为无损 WebP，重复的静止帧由编码器合并，总时长均为 1240 ms。逐帧按时间对应原 PNG 比较 RGB，像素相同；没有用调色、降采样或有损压缩美化证据。导出是测试视图的播放记录，不是设备性能数据。

构建、签名、打包与远端核对日志在 `output/ui41-*-build.log`、`ui41-signature.log`、`ui41-package.log`、`ui41-release-*.log`。
