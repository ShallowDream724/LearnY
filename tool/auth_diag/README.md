# LearnY Auth Diagnostics

Local diagnostics for the login, ticket bootstrap, fallback bootstrap, and
auto-relogin recovery chain.

## Registrar Calendar Probe

`capture_calendar_gateway.mjs` opens an isolated Edge profile for manual campus
authorization. It saves campus cookies to ignored `.out/calendar-gateway/`.
`calendar_probe_runner_test.dart` reads a snapshot of app cookies into memory,
optionally imports that capture, and calls the production calendar client.
It never changes the installed app's cookie files or prints cookie values.

For a bounded network-route comparison, set `LEARNY_PROBE_SINGLE_RANGE=1` and
run sequentially with `LEARNY_PROBE_TRANSPORT=direct` then `proxy`. The proxy mode
uses `127.0.0.1:20808`; neither mode changes system proxy settings. These probes
use only the cookie snapshot, never supply a stored password, and log only
status codes, query-free destinations and identity-page structure. A trusted
device `checkSingle` form is not evidence of a CAPTCHA or a changed password.

```powershell
conda activate aider
node tool/auth_diag/capture_calendar_gateway.mjs
$env:LEARNY_PROBE_COOKIES = "$env:APPDATA/LearnY/LearnY/cookies"
$env:LEARNY_PROBE_GATEWAY_COOKIES = "$PWD/tool/auth_diag/.out/calendar-gateway/cookies.json"
$env:LEARNY_PROBE_EXTENDED = '1'
flutter test --no-pub tool/auth_diag/calendar_probe_runner_test.dart
Remove-Item Env:LEARNY_PROBE_COOKIES, Env:LEARNY_PROBE_GATEWAY_COOKIES, Env:LEARNY_PROBE_EXTENDED
```

The extended probe independently checks a historical week, the graduate
calendar variant, the autumn Learn roster, and the actual schedule repository
using a fresh in-memory database. It reports counts and classified failures;
an empty response is not proof that a term is unpublished or fully authorized.
Inspect reported statuses: the diagnostic runner can finish successfully even
when a school service reports an error. Browser profiles and captures contain
credentials and must remain untracked.

## Why this exists

- Keep auth debugging out of production UI flows.
- Reuse the real `Learn2018Helper` and auth core instead of writing a second
  login implementation.
- Let the operator type credentials locally without exposing them in chat.
- Produce detailed masked logs with no automatic retries or concurrency.

## Files

- `capture_login_context.mjs`
  Opens a real browser, captures the real login request body, ticket,
  browser cookies, and authenticated learn page snapshot.
- `auth_diagnostics.dart`
  Replays the captured data through production auth primitives.
- `run_auth_diag.ps1`
  Wrapper that prompts for secrets locally and stores outputs under `.out/`.

## Default flow

1. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tool\auth_diag\run_auth_diag.ps1
   ```

2. A real browser opens. Finish the login in that browser.
   Default mode is manual: type the password directly in the browser.
3. The wrapper saves:
   - `capture.json`
   - `auth-diagnostics.log`
   - `summary.json`

## Stages

- `captured_ticket_bootstrap`
  Replays a roaming ticket only when it was explicitly preserved before the
  browser consumed it.
- `captured_fallback_bootstrap`
  Replays the production-like fallback path that only has `document.cookie`
  plus the learn page HTML snapshot.
- `captured_full_cookie_session`
  Imports the full browser cookie jar and checks whether that session is
  immediately usable from Dart.
- `silent_sso_cookie_recovery`
  Removes the learn-domain session cookie and tests whether remaining cookies
  can silently recover the learn session.
- `fresh_credential_chain`
  Reuses the captured fingerprint fields and fresh credentials to run the real
  login chain end-to-end.

## Safety

- Headed browser only by default.
- Manual browser password entry by default.
- No background polling against learn servers.
- No automatic retries.
- Fresh credential submission is at most one extra sequential attempt.
- Password is never written to disk by the tool.
- Console and log output mask ticket and cookie values.

## Optional modes

- `-Prefill`
  Re-enable script-side prefill for the browser capture. Not recommended while
  debugging credential handling.
- `-PreserveTicket`
  Abort the roaming request after capturing the ticket so
  `captured_ticket_bootstrap` can replay an unconsumed ticket.
- `-SkipFreshCredentialChain`
  Avoid the extra sequential credential-based login attempt.

## Re-run without a new browser session

If you already have a previous `capture.json`, you can reuse it:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\auth_diag\run_auth_diag.ps1 `
  -ExistingCapture .\tool\auth_diag\.out\20260327-123456\capture.json
```

## Skip the fresh credential chain

This avoids the extra credential submission and only verifies the captured
browser-based flows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\auth_diag\run_auth_diag.ps1 `
  -SkipFreshCredentialChain
```

## Preserve ticket for Stage 1

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\auth_diag\run_auth_diag.ps1 `
  -PreserveTicket -SkipFreshCredentialChain
```
