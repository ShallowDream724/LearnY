# Offline UI Preview

Render actual Flutter application routes and schedule widgets with isolated demo data.
This runner does not open application windows or connect to a school account.
It is outside default regression test discovery.

For the stable 0.1.4 layout changes, run only
`--plain-name 'render release 014 headers and extreme timetable'` with
`LEARNY_CAPTURE_UI=1`. It writes `build/ui_preview/release014/` captures of
360 px Android and 1280 px Windows layouts. The actual daily header includes
2025/12/12 and an 8000-hour pending range. The actual weekly dialog uses a shared
fixture with a blank 08:00 slot, 13:30–16:55, 15:20–17:10, 16:10–18:40 and the
two different 19:20 evening durations; tall captures show the entire axis.

`--plain-name 'render phone timetable vertical scrolling'` uses an ordinary
390×844 phone viewport with six classes per weekday and morning classes ending
at 12:15. It verifies the compact lunch separator and a real upward
drag reaches the evening classes without moving the date header or changing the
week, then opens an evening class to verify its complete time remains available.
Screenshots before/after scrolling are in `build/ui_preview/weekly_lunch/`.

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

`LEARNY_PREVIEW_PIXEL_RATIO=3` exports higher-resolution captures without changing
the logical viewport. `LEARNY_PREVIEW_WALLPAPER=warm_hills` and
`LEARNY_PREVIEW_INTENSITY=65` select a saved wallpaper/intensity in the isolated
preview database; they do not change application defaults or the user's settings.

`--plain-name 'render reading material while scrolling at phone pixel density'`
uses a real 3× test view (1170×2532 physical, 390×844 logical), drags the actual
home and settings scroll views, and captures 31 frames each at 40 ms intervals
under `build/ui_preview/reading_scroll/`. Use `LEARNY_PREVIEW_PIXEL_RATIO=3` to
retain physical pixel detail in the PNGs. The test also checks that scrolling
reuses the Gaussian wallpaper texture. These are Skia test frames, not an Android
Impeller recording or a frame-rate benchmark.

Use `--plain-name 'render floating navigation motion'` for the mobile glass and
navigation study. It captures actual light/dark course pages, the selected home
state, the profile header, and frame sequences
under `build/ui_preview/liquid_navigation/`, exercising a partial horizontal drag,
reversal/cancellation, and a direct tab selection. The selected indicator follows
the real pager; the capture does not animate a mock indicator.

Run `python tool/ui_preview/export_navigation_preview.py` in the aider environment
to export cropped PNGs and motion previews. The lossless animated WebP is the
visual reference; GIF uses an all-frame palette with dithering as a fallback.
Use `--stills-only` when only the static material captures changed.
Do not build GIF palettes from only the first frame: when another page has a
different background, that produces false bands in otherwise smooth glass.

For actual Impeller refraction, run the isolated demo entry point on Android:

```sh
flutter run -d <android-device> --enable-impeller -t tool/ui_preview/device_preview.dart
```

It uses in-memory demo data and the same wallpaper/intensity defines, without a
school account. Ordinary widget captures use Skia: they show the shared lighting,
shadows, and blur fallback, but cannot prove Impeller backdrop refraction.

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
It opens the wallpaper picker through the actual profile page, selects each
platform's own artwork collection, waits for assets to decode, checks all four
mobile choices and independent intensity persistence, and skips
the course icon picker/atlas.
This is a visual study using demo course data, not campus-service validation.
