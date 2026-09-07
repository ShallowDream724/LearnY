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

The `estimated` sample includes jagged inferred-duration blocks, provenance,
and an unassigned lab reminder. Dense samples retain 30 and 35 occurrences;
the timetable scrolls vertically when needed. Every width also captures the
compact daily entry before opening the independent weekly overlay.

Fixtures include summer/autumn bounds. `boundary_<width>.png` captures the
semester-end confirmation with the current week still visible underneath.
