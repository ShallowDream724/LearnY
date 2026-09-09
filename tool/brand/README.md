# LearnY 应用标识

应用标识采用已确认的日晷图案：暖白晷面、立起的晷针与投影，置于蓝色至暖橙色的背景上。保留原稿的构图、材质、光照与圆角轮廓。

`assets/brand/source/sundial.png` 是唯一原稿，外圈已去黑底并保留透明边缘。导出时裁去外围空白，各平台共用同一幅图。应用内使用 256 像素资源，原稿不打入 Flutter 资源包。Windows ICO 包含 16–256 像素尺寸，保留透明圆角。

Android 自适应图标将完整画面放在中央 72/108 区域，并延伸边缘颜色作为系统遮罩外的余量，避免裁掉晷针或产生双层图标。前景透明，圆形与圆角由启动器处理；当前原稿没有独立单色图层，不声明主题单色图标。iOS 导出为不带透明通道的方形资源，由系统裁切圆角。

重新生成：

```sh
python tool/brand/export_icons.py
```

Python 使用 Pillow，本机使用 conda `aider` 环境。生成结果覆盖 `assets/brand/app_icon.png`、Windows、Android 与 iOS 的既有应用图标资源；不得手工修改单个平台的导出文件。`build/brand/preview.png` 提供不同大小的预览，`round-preview.png` 检查圆形遮罩。登录、侧栏等应用内入口共用 `StudyMark`，直接保留图片自带的圆角，不重复裁切。
