# Offline UI Preview

Render actual Flutter application routes and schedule widgets with isolated demo data.
This runner does not open application windows or connect to a school account.
It is outside default regression test discovery.

From PowerShell on Windows:

```powershell
conda activate aider
$env:LEARNY_CAPTURE_UI = '1'
flutter test --no-pub tool/ui_preview/schedule_preview_runner.dart --plain-name 'render the actual home and shell'
Remove-Item Env:LEARNY_CAPTURE_UI
```

The aider environment's `Library/bin` must precede other SQLite installations
on PATH. LibreOffice's `sqlite3.dll` lacks symbols needed by these tests. In Git
Bash, prefix the command with `PATH="/d/anaconda/envs/aider/Library/bin:$PATH"`.

The runner loads the bundled WenKai screen font and both icon fonts used by the
production app. `LEARNY_PREVIEW_FONT` may optionally supply a local fallback font
for comparison; normal review needs no system font installation. PNGs are written
under `build/ui_preview/`. Application captures:

- 390x844 and 1440x900: home, assignments, courses, profile, unread files, files,
  course detail, homework detail, and the submission editor.
- 800x1000: home and courses using the actual shell pane constraints.
- Settings at all three widths, the appearance menu, enlarged text, and light/dark desktop and phone layouts.
- Course editor at all three widths, plus the desktop anchored course menu.
- 390x844: enlarged text on home/assignments/courses; home, courses, assignments
  and settings also render dark surfaces at phone and desktop sizes.

Set `LEARNY_PREVIEW_ROUTES=courses` to capture only course surfaces when changing
course interactions. The comma-separated filter also accepts the route names
above. Unset it to restore full coverage. Shadows are rendered rather than the
test framework's solid-outline substitute.

`LEARNY_PREVIEW_PLATFORM=windows` or `android` selects the target platform's
theme behavior. The actual bundled family is loaded in both cases; rare missing
glyphs that require system fallback remain part of real-device acceptance.

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

For the shared background study with the representative course collection:

```sh
flutter test --no-pub --dart-define=LEARNY_PREVIEW_SCENE_ONLY=true tool/ui_preview/course_icons_preview_test.dart
```

This produces Windows light/dark (2534 × 1369), Android light/dark/scroll
(1080 × 2340), and wallpaper picker PNGs in `build/ui_preview/light_scene/`.
It selects each platform's own artwork collection, waits for assets to decode,
checks all four mobile choices and independent intensity persistence, and skips
the course icon picker/atlas.
This is a visual study using demo course data, not campus-service validation.
