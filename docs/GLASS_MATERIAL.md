# 玻璃材质

`lib/core/design/glass_surface.dart` 只负责材质，不依赖路由、导航位置、课程或壁纸模型。背景来源始终是组件下方的实际页面，白色卡片和壁纸经过边缘时不会切换成两种取样来源。

## 组合与复用

| 部件 | 职责 |
| --- | --- |
| `GlassSurface` | 组合裁剪、底色、实时背景、内侧光影与外部阴影 |
| `GlassBackdrop` | 背景模糊和可用时的实时折射；裁剪由调用方负责 |
| `GlassLighting` | 子内容下方的细腻反光，无背景、底色、内阴影或输入行为 |
| `GlassShadow` | 绘制表面外侧的柔和投影，可独立用于 `CustomPaint` |
| `GlassOptics` | 模糊、折射、光照和投影强度，与组件业务职责分离 |

圆角由 `radius` 指定，自动限制在短边一半以内；胶囊可传 `999`，其他工具栏、卡片或浮动按钮可传实际圆角。材质不固定高度、内容、点击区域或页面用途。例如：

```dart
GlassSurface(
  radius: 20,
  optics: const GlassOptics(refraction: 8, shadow: .7),
  child: Padding(padding: const EdgeInsets.all(16), child: toolbar),
)
```

底部导航的 `FrostedNavigationSurface` 仅选择胶囊形状。导航状态与跟手动画继续留在 shell。不要为了复用材质引入导航状态，也不要为新组件复制 shader 或光照常量。

## 光学与资源

`glass_refraction.frag` 对真实背景按圆角形状连续位移取样。`glass_light.frag` 使用距离场、表面朝向和高斯衰减生成细窄、轻柔的反光；不绘制内侧暗环，也不以等宽描边模拟玻璃。厚度由细腻的反光与外侧投影共同表达，白色内容经过玻璃时保持内部通透。外侧投影使用高斯衰减，侧边比上下稍宽，接触阴影和远处投影均保持轻量。光影画在图标和文字下面，避免洗淡前景。

每个表面只有一个有界背景过滤层，折射与模糊由引擎在 GPU 合成；不对页面逐帧截图、CPU 读回或单独重画壁纸。shader 程序按资产缓存，每个材质实例独立拥有并释放可变 shader。加载失败时保留可用的底色、背景模糊和内容。

Flutter 3.41 的 `ImageFilter.shader` 仅支持 Impeller。运行时检查 `ImageFilter.isShaderFilterSupported`，Skia（包括 Windows 与普通 widget 预览）使用实时背景模糊，内侧光影 shader 仍可使用。高对比模式改用实底并禁用透光与光影。不能把 widget 预览当作 Android 折射效果的截图；设备预览入口见 [UI 预览](../tool/ui_preview/README.md)。

## 导航与阅读表面

导航按下时抬升放大透镜，拖动使用保留速度的弹簧跟踪，松手后按位置与有限速度投影提交目标页；取消回到当前页。图标在透镜内外分别裁切，避免双影。语义与焦点热区独立于绘制，键盘可直接选择。减少动态效果时立即停止弹簧并直接定位。交互参考 FLClash Android 导航，代码独立实现，未复制其 GPL 源码。

阅读表面与导航分别处理：`StudyLightScene` 在壁纸或视口变化时采样一个 16×32 色彩网格，按局部文字区域求保护层透明度，保持次级文字对比；不逐帧读回像素。保护层结果缓存上限 128 项。壁纸强度使用感知映射保留原图色彩，自定义图像按视口量化解码并限制最长尺寸 2560。关闭透光或高对比模式沿用实底。
