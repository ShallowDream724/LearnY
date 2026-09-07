# Tests

Run deterministic tests from the repository root:

```sh
flutter test
```

The suite under `test/` checks app behavior without a school account. App startup
tests use an in-memory database, seeded identity, offline connectivity, and fixed
update/data providers; access to the real API client or credential storage fails
the test. They cover login controls and cached/expired-session routing.

Office preview tests share a table of supported Office extensions and verify the
external-open policy without depending on complete explanatory UI sentences.

Schedule tests exercise week/date navigation, mouse and keyboard actions, touch
swiping, sparse and dense schedules, large text, independent week caches, network
failure, timeout, cancellation, and account cleanup. Projection and cache codec
checks run without widgets. The optional `tool/ui_preview/` runner renders real
widgets with local fonts and demo data for visual inspection.

Schedule regressions also cover authoritative enrollment updates, withdrawn
courses in stale registrar responses, historical retention, holiday moves,
bounded and enumerated weeks, unassigned courses, and inferred duration.
Campus-cookie tests check host isolation; actual Android CookieManager and
Windows WebView2 integration require device validation.

## Manual diagnostics

Files under `tool/auth_diag/` are explicit diagnostic entry points and have never
been included by the default `flutter test` discovery under `test/`. See
[`tool/auth_diag/README.md`](../tool/auth_diag/README.md) for full authentication
diagnostics.

The Dio transport probe reuses `tool/auth_diag/dio_probe.dart` and needs the
Flutter test runtime because it imports the production API helper:

```powershell
$env:LEARNY_DIO_PROBE = '1'
flutter test tool/auth_diag/dio_probe_runner.dart --reporter expanded
Remove-Item Env:LEARNY_DIO_PROBE
```

This is a manual network diagnostic, not a regression test: inspect its logged
HTTP status, redirect, and cookie counts. It fetches the identity login page with
fresh in-memory cookies and does not submit credentials. Without the environment
variable, the runner is skipped. The former `dio_probe_test.dart` duplicated this
probe and added print-only fake-credential attempts with no behavioral assertions.
