# LearnY 应用标识

标识将展开的书页与 Y 的分叉轮廓结合。靛蓝底面、暖白书页和轻微折面明暗组成同一个识别图形，不使用校门建筑缩略图。小尺寸保留完整外轮廓，不增加缩小后无法辨认的细线或文字。

`learny_icon_art.dart` 是唯一绘制源；`render_brand_test.dart` 使用 Flutter 输出 1024 像素原稿、背景、透明前景和单色图层。Android 自适应前景留有系统遮罩与位移空间，单色图层供主题图标着色。Windows ICO 包含 16–256 像素尺寸；iOS 资源不含透明通道。

重新生成：

```sh
flutter test --no-pub tool/brand/render_brand_test.dart
python tool/brand/export_icons.py
```

Python 使用 Pillow，本机使用 conda `aider` 环境。生成结果覆盖 `assets/brand/app_icon.png`、Windows、Android 与 iOS 的既有应用图标资源；不得手工修改单个平台的导出文件。`build/brand/preview.png` 提供不同大小的原稿预览。登录、侧栏等应用内入口继续共用 `StudyMark`。
