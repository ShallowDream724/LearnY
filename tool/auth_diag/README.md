# LearnY Auth Diagnostics

Local diagnostics for the login, ticket bootstrap, fallback bootstrap, and
auto-relogin recovery chain.

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
