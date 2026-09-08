# 字体

本项目随包附带未经修改的 **LXGW WenKai GB Screen / 霞鹜文楷 GB 屏幕阅读版**，版本 `1.501; October 10, 2024`。字体来自开发者本机已安装的原始 TTF；采用 SIL Open Font License 1.1，许可原文见 [OFL.txt](OFL.txt)，也收录于应用「设置 → 开源许可」。

上游：[lxgw/LxgwWenKai-Screen](https://github.com/lxgw/LxgwWenKai-Screen)。作者说明屏幕版增强字重、调整度量以适合 PC 和 Android 屏幕，明确允许嵌入软件与随软件分发。

保留整个原始字体，不按当前 UI 字符子集化，以覆盖课程名称、通知及用户内容。字体 family、asset 路径与许可证注册由 `lib/core/design/app_font.dart` 管理；排版角色由 `AppTypography` 管理。以后升级时同时记录版本、来源和许可证，并验证中英文、数字和长标题的真实布局。
