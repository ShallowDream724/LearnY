# LearnY AI Architecture Guardrails

This document is the follow-up contract after the refactor blueprint.

## Non-negotiables

- Treat current UI/UX as a contract unless the user explicitly asks for a redesign.
- Add new behavior through existing controllers/actions/providers before creating new helpers.
- Do not let screens call `learn_api.dart` or raw database writes directly.
- Do not create a second download/cache state outside the asset domain.
- Keep session expiry as graceful degradation: cached data stays browsable.

## Where new code belongs

### App shell

- `lib/app/` wires startup, theme, router, lifecycle.
- No feature business logic here.

### Auth and session

- `lib/core/auth/` owns restore, login handoff, logout, session health, lifecycle/session coordination.
- Router decisions must continue to depend on `AuthState` only.

### Sync

- `lib/core/providers/sync_provider.dart` owns sync state machine.
- `lib/core/sync/sync_actions.dart` is the screen-facing intent boundary for refreshes.
- If a new screen needs refresh behavior, add an intent here instead of calling the notifier directly.

### Files and attachments

- `lib/core/files/file_models.dart` defines the shared asset identity.
- `lib/core/files/file_asset_actions.dart` owns download/open/delete/read-state intents.
- `lib/core/files/file_asset_runtime.dart` owns UI-facing runtime state resolution.
- `lib/core/files/file_preview_registry.dart` is the only place that decides inline preview capability.
- Add new preview formats by extending the registry first, then wiring the viewer implementation.

### Feature queries

- `lib/features/*/providers/` are read-only query/view-model providers.
- Prefer stream-backed queries sourced from Drift watches over manual invalidation.
- When scope is already known, prefer semester-scoped DAO watches over
  `watchAll*()` plus in-memory filtering.
- If a screen starts owning filtering, grouping, or stats logic, move that
  logic into provider-side presentation builders before extending the UI.

### Notifications and submissions

- Notification mutations go through `lib/features/notifications/providers/notification_actions.dart`.
- Homework submission flow belongs in `lib/features/assignments/submission/`.

## Extension checklist

Before merging a new feature, check:

1. Would another AI immediately know where the next similar feature should go?
2. Did I reuse an existing action/controller boundary instead of inventing a one-off helper?
3. Did I preserve cached browsing when login/session state is degraded?
4. Did I keep download/cache state sourced from the asset domain?
5. Did I avoid visual drift unless the task explicitly asked for it?
6. Did I use the narrowest reactive query scope instead of watching unrelated
   rows?
