# 发布构建

正式入口为 `lib/main.dart`。`tool/ui_preview/device_preview.dart` 等演示入口不用于发布。

1. 同步 `pubspec.yaml` 的版本和递增构建号、`CHANGELOG.md`、README 下载链接及 `docs/releases/<版本>.md`。运行 `flutter analyze --no-pub lib test tool`，检查自有源码、测试和工具；根目录全扫描还会包含本机 build 内的旧预览草稿和第三方示例。完成与改动相称的检查和 Flutter 界面预览；不要为重新打包重复运行无关的完整检查。
2. Windows 使用 `./tool/windows_dev.ps1 -Action build -Configuration release`，该脚本规范化本机 PATH 并保留 Git／Flutter／系统工具。Android 使用 `flutter build apk --release --no-pub --target lib/main.dart`；两个构建使用相同源码和版本。
3. 在 PowerShell 调用 `./tool/package_release.ps1 -Version 0.1.4 -BuildNumber 30 -AaptPath <Android SDK 的 aapt.exe>`。脚本核对 EXE／APK 的内嵌版本、Windows 运行资源，复制完整 Windows 目录，并生成 APK、免安装 ZIP 和 SHA256SUMS。输出在 `dist/releases/v<版本>-build<构建号>/`，已存在目录不会覆盖。
4. 只提交本次源码、文档和工具，不提交账户数据、个人环境文件或整个 output/dist。版本 tag 指向构建使用的源码提交；正式发布使用独立 `v<版本>` tag，不挪动历史 Beta tag。
5. 在用户授权发布的范围内推送对应源码/tag，使用 `gh release create` 的 `--notes-file docs/releases/<版本>.md` 上传两端产物与校验值，正式版不设置 prerelease。确认 tag 目标、Latest 状态、内嵌版本和 GitHub 资产 SHA-256 与本地一致。

Windows 分发必须包含 EXE、插件 DLL、Flutter runtime 和 `data/`。Flutter 桌面应用不能只复制单个 EXE；免安装 ZIP 解压即可运行，无安装向导。

## Android 签名连续性

当前 `android/app/build.gradle.kts` 的 release 配置沿用既有 debug signing config。
0.1.4 与 Beta build 29 已核对为同一证书，SHA-256 指纹为
`a103a8442a1431d781f05e9d2ef2bf5c4ead155934fa7a343dc2e1a115833269`，因此可覆盖升级。
换构建机器时必须由维护者保留原签名密钥，不能生成新 debug keystore 后直接替换发布；
专用发布签名与升级迁移应作为独立工程任务处理，密钥不进入仓库。可使用 Android SDK 的
`apksigner verify --print-certs <apk>` 比较新旧安装包证书。
