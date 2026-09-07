# Offline UI Preview

Render actual Flutter application routes and schedule widgets with isolated demo data.
This runner does not open application windows or connect to a school account.
It is outside default regression test discovery.

From PowerShell on Windows:

```powershell
conda activate aider
$env:LEARNY_CAPTURE_UI = '1'
$env:LEARNY_PREVIEW_FONT = 'C:/Windows/Fonts/msyh.ttc'
flutter test --no-pub tool/ui_preview/schedule_preview_runner.dart --plain-name 'render the actual home and shell'
Remove-Item Env:LEARNY_CAPTURE_UI, Env:LEARNY_PREVIEW_FONT
```

The aider environment's `Library/bin` must precede other SQLite installations
on PATH. LibreOffice's `sqlite3.dll` lacks symbols needed by these tests. In Git
Bash, prefix the command with `PATH="/d/anaconda/envs/aider/Library/bin:$PATH"`.

Use a locally installed CJK font. Fonts are read only and are not copied into
the repository. PNGs are written under `build/ui_preview/`. Application captures:

- 390x844 and 1440x900: home, assignments, courses, profile, unread files, files,
  course detail, homework detail, and the submission editor.
- 800x1000: home and courses using the actual shell pane constraints.
- Course editor at all three widths, plus the desktop anchored course menu.
- 390x844: enlarged text on home/assignments/courses and dark home.

Set `LEARNY_PREVIEW_ROUTES=courses` to capture only course surfaces when changing
course interactions. The comma-separated filter also accepts the route names
above. Unset it to restore full coverage. Shadows are rendered rather than the
test framework's solid-outline substitute.

Detail routes are pushed from the shell so captures include real return controls.
The editor is opened through its real homework detail action; no submission is
sent. Screenshots complement targeted behavioral assertions and do not replace
device or campus-service acceptance.

For the separate full schedule matrix, replace `--plain-name` with
`'render sparse dense and empty schedules with actual fonts'`. This renders
360, 600, and 1280 widths; it need not run for every unrelated UI edit.

The `estimated` sample includes jagged inferred-duration blocks, provenance,
and an unassigned lab reminder. Dense samples retain 30 and 35 occurrences;
the timetable scrolls vertically when needed. Every width also captures the
compact daily entry before opening the independent weekly overlay.

Fixtures include summer/autumn bounds. `boundary_<width>.png` captures the
semester-end confirmation with the current week still visible underneath.
