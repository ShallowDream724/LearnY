# 光影背景试用

2026-09-09 使用项目负责人提供的大曲面玻璃原图，先接入课程页与应用外壳，供实际设备比较。布局、文案、课程颜色、图标和操作流程保持原有设计。本轮是材质与背景的试用，不代表所有页面已经完成背景改造。

`assets/artwork/source/glass_landscape.png` 保留提供的 1672 × 941 原图。`export_light_scene.py` 将浅色原图无损导出为 WebP，并生成同一构图的低曝光深色试用图；深色图是派生调色，不是另一次生图。Flutter 只打包两个 WebP，原图与导出工具不进入安装包。

```sh
python tool/artwork/export_light_scene.py
```

工具依赖 NumPy 与 Pillow，本机使用 conda `aider` 环境。

`StudyLightBackdrop` 在应用外壳统一加载图像；`StudyLightScene` 缓存与窗口尺寸对应的纹理变换。宽屏完整铺陈，窄屏逐渐向右侧曲面取景，通过 cover 裁切保持原图比例。课程卡片在绘制时取得其在共享背景中的位置，内面与边缘采样同一纹理，边缘略有折射位移。不存在逐卡片资源加载、布局后测量或背景模糊。窗口外的滚动缓存与边缘采样使用 clamp，避免出现颜色断层。

图像加载和主题更换通过 inherited scope 更新保留页面中的卡片，旧 ImageInfo 依照 Flutter Image 的方式在帧结束后释放。深色使用相同构图，避免主题切换后光源与形体位置改变。

真实 Flutter 预览可用 `tool/ui_preview/course_icons_preview_test.dart` 的 `LEARNY_PREVIEW_SCENE_ONLY` 参数，只输出课程页与手机滚动状态。实际设备观感由项目负责人直接检查，不以截图代替设备验收。
