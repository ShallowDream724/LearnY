# Offline UI Preview

Render the actual schedule widgets and the app home with isolated demo data.
This runner does not open application windows or connect to a school account.
It is outside default regression test discovery.

From PowerShell on Windows:

```powershell
conda activate aider
$env:LEARNY_CAPTURE_UI = '1'
$env:LEARNY_PREVIEW_FONT = 'C:/Windows/Fonts/msyh.ttc'
flutter test tool/ui_preview/schedule_preview_runner.dart
Remove-Item Env:LEARNY_CAPTURE_UI, Env:LEARNY_PREVIEW_FONT
```

Use a locally installed CJK font. Fonts are read only and are not copied into
the repository. PNGs are written under `build/ui_preview/`, including phone,
tablet, desktop, empty, sparse, and dense schedules, plus the actual home shell.
Screenshots complement behavioral assertions under `test/features/home/`.
