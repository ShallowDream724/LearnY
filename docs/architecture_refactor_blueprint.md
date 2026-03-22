# LearnY Architecture Refactor Blueprint

This document is the execution contract for the remaining refactor work.

## 1. Target

Keep current UI/UX behavior stable while rebuilding the internal structure so:

- feature growth stays linear instead of chaotic
- session, sync, files, and submissions have clear ownership
- any future AI can extend the project without creating new hidden coupling

## 2. Non-goals

- no visual redesign during architecture work
- no large rewrite of `lib/core/api/learn_api.dart`
- no academic multi-layer ceremony when a simpler boundary is enough

## 3. Final boundary map

### `lib/app/`

Owns only:

- app startup
- theme / router wiring
- lifecycle forwarding

Must not own:

- sync policy
- auth side effects
- feature business rules

### `lib/core/auth/`

Owns:

- persisted identity restore
- session health state
- login handoff from WebView to Dio
- logout cleanup
- app-level session coordination

Rules:

- persisted identity and live session health are different concepts
- session expiry does not destroy cached browsing ability

### `lib/core/sync/` + `lib/core/providers/sync_provider.dart`

Owns:

- sync orchestration
- cooldown rules
- sync state machine
- session-expired error mapping

Rules:

- screens only trigger sync intents
- sync internals never live inside screens

### `lib/features/*/providers/`

Own:

- read models for screens
- feature-scoped query composition

Rules:

- queries are read-only
- write operations do not happen inside query providers

### `lib/core/files/` + `lib/core/services/`

Own:

- asset identity
- cache registry
- download/open/delete state
- cache policy
- route payloads for all file-like content

Rules:

- files and attachments share one asset model
- downloaded state has one source of truth

### future `submission` slice

Will own:

- homework submission drafts
- upload tasks
- resubmit / replace / remove attachment flow

Rules:

- submission UI does not call API directly forever
- upload logic must become reusable, observable, and retryable

## 4. Hard invariants

These are non-negotiable.

1. screens do not call `learn_api.dart` directly
2. screens do not own app-wide side effects
3. router decisions depend on auth/session state only, not screen hacks
4. session expiry shows degradation UI instead of force-wiping cached content
5. file/attachment cache state comes from the asset domain, not per-screen flags
6. sync success/failure/session-expired uses one shared state machine
7. new features must enter through existing boundaries instead of inventing ad-hoc helpers

## 5. Current progress

Already in place:

- app shell banners for offline + session expired
- extracted session coordinator skeleton
- extracted router refresh notifier
- sync engine split from UI
- SSO ticket parsing, fallback page parsing, cookie bridging, and session
  bootstrap are separated from the login screen
- database access is split into focused DAO part files instead of a single god
  object body
- semester-scoped Drift watch methods now replace several full-table watches in
  home, courses, assignments, and file list flows
- unified file detail route/data model
- asset cache registry
- attachment cards shared across notifications and homework
- cache limit preference + policy enforcement
- search state/query orchestration moved from widget state into repository +
  controller
- assignments timeline stats/filter/grouping moved out of the screen and into
  provider-side presentation logic

Still to finish:

1. complete auth/session hardening
2. finish action-boundary consistency for favorites and similar mutations
3. finish asset domain convergence for all file origins
4. extract submission domain from screen-level logic
5. add preview capability registry before implementing more preview types
6. add regression coverage for session/sync/file flows

## 6. Delivery order

### Phase A - Session and auth

- finish the persisted identity vs session health split
- keep router and shell behavior stable
- reduce remaining app-level coupling

### Phase B - Query and action boundaries

- standardize feature queries
- prefer semester-scoped watches when the feature is already semester-bound
- move screen-owned filter/group/stats logic into provider-side presentation
  helpers
- reduce manual refresh glue where practical

### Phase C - Asset domain convergence

- treat course files, notification attachments, homework attachments,
  submitted files, and grade files as one asset family

### Phase D - Submission domain

- move homework submission flow out of pure screen code
- prepare reusable upload state

### Phase E - Preview architecture slot

- create capability registry and viewer contract
- do not implement Office/mp4/zip before product approval

### Phase F - Regression and handoff

- tests for auth/session/sync/file invariants
- AI-facing architecture handoff rules

## 7. Review checklist

Any new code should pass this review:

- does this screen talk only to providers/controllers?
- does this change create a second source of truth?
- does this couple feature UI to global runtime behavior?
- am I watching only the rows this feature actually needs?
- would another AI know where to add the next similar feature?
- can session expiry, logout, and restart still behave predictably?

If the answer is bad, refactor before extending.
