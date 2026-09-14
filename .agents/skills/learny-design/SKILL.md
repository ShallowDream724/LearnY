---
name: learny-design
description: Design and refine LearnY Flutter interfaces and complete student workflows across Android, Windows, and tablets. Use for UI, interaction, navigation, visual hierarchy, and component behavior changes in this project.
---

# LearnY Design Engineering

Read [the project design system](../../../docs/DESIGN_SYSTEM.md) and the relevant feature contract before changing a workflow. For substantial design work, also read [the source study and application notes](../../../docs/DESIGN_REFERENCE_REVIEW.md). This project-local skill carries LearnY decisions; the globally installed `emil-design-eng` supplies the full design references and implementation recipes.

When the global skill is available, read its foundation guides and the relevant component recipe, not only its entrypoint. Otherwise use the pinned upstream references linked in the study document, with that document's platform and scope qualifications. Do not install React, Expo, or Swift dependencies merely because those references demonstrate them.

## Judge The Whole Interaction

Trace what brings the student here, what they must recognize, their most likely action, waiting and failure states, the result, and how they return. Make internal session and synchronization work automatic. A new visible control needs a user task, a clear scope and useful feedback.

Before polishing, decide information priority and density using real sparse, dense, empty and failed states. Keep the daily schedule compact and the weekly timetable independently dismissible. Preserve confirmed semester navigation behavior. Treat the full app as one product: a detail view, toast, icon button and empty row all inherit the same interaction contract.

## Apply The Underlying Principles

- Immediate feedback: acknowledge press immediately; commit on release and permit cancellation. Give pointer, focus, disabled and loading states deliberate treatment.
- Spatial consistency: position menus near their triggers, preserve scroll and selection when opening details, and make dismissal and return predictable.
- Interruptibility: accept the next action during motion. Continue from the current visible state rather than restarting from an assumed endpoint. Preserve gesture velocity where it affects manipulation.
- Restraint: identify what motion communicates and how frequently it repeats. Shared motion tokens are starting points; inspect each component's purpose, interruption, and lifecycle. Fixed millisecond limits and prohibitions based solely on keyboard input are heuristics, not universal laws.
- Materials: use translucency only when it clarifies an overlapping functional layer and preserves text contrast. Check Flutter painting and compositing costs; CSS GPU assumptions do not transfer directly.
- Wallpaper and contrast: for this work, also read the global `emil-design-eng` reference `references/materials-and-contrast.md`. Apply the same foreground/material policy to Windows and Android, with appropriate optical fallbacks. Preserve wallpaper color between surfaces; keep small metadata readable through coordinated semantic foregrounds and local materials, not an all-screen gray veil, blanket text outlines or heavy shadows. The agreed direction and current implementation boundary are recorded in [the source study](../../../docs/DESIGN_REFERENCE_REVIEW.md).
- Typography: optimize Chinese text, numerals and metadata together. Keep important information readable with text scaling, stable control dimensions, and appropriate line wrapping.
- Compose with the bundled WenKai screen font from the beginning; do not lay out using a substitute and replace it at delivery. Distinguish breathing room from residual fixed-height space. Judge whole-page relationships before decorating individual components; the global composition study supplies the reasoning, while the project design system owns the current palette and product choices.
- Access: choose layout by the constraints of the actual content pane, and affordances by input capability. Support keyboard focus and reduced motion, including clear static alternatives. Do not assume a tablet is touch-only or a Windows device never uses touch.
- Defaults: reduce configuration burden; retained options must solve a real student need. Loading, stale data, retries and offline availability are part of the component design.

## Preserve LearnY's Interaction Contracts

- One normal campus sign-in coordinates service access. Backend ticket exchanges are not separate user authorizations. Manual verification appears when the school actually requires it; an empty timetable is not evidence of an expired identity.
- The home timetable remains compact and daily on phone, tablet, and Windows. The large weekly timetable has its own browsing scope. Preserve [semester and dismissal rules](../../../docs/SCHEDULE_DESIGN.md), including remaining at the boundary when cross-semester confirmation is cancelled.
- Preserve data provenance: official calendar, cached snapshot, and routine-derived schedule are not interchangeable. Unknown ending times remain unknown; never infer duration from credits. Unscheduled courses retain an accessible reminder.
- A detail visit returns to the previous list position, query, filters, and scope. A local timetable or preview interaction does not silently change the whole application's semester.
- Mobile lists mark unread items read by a left swipe, with no persistent read-state button. Desktop lists expose exactly one read-state button per row. The shared interaction owns the asynchronous operation; child cards must not add a duplicate. Detail-page read/unread controls remain available.
- Distinguish loading, background refresh, genuine emptiness, filtered emptiness, stale content, and failure. Design the presentation for the task and allocated area; a shared centered empty-state component is not automatically right for every region.
- Avoid decorative left-side accent bars. The user values quiet hierarchy and Apple-like continuity, with platform-appropriate input behavior. This does not prescribe one radius or material for every component.

## Work Within The Request

For a genuinely unsettled interaction, compare a small number of functional alternatives that differ in layout, density or behavior. For a settled fix, implement it directly. Delegation, audits, prototypes and tests are tools selected for the task; this skill never mandates agent counts, promotion, fixed opening replies or an audit-only stopping point.

Use existing Flutter semantics and accessible controls as foundations. Add a shared component when it unifies meaningful behavior. Keep business protocols out of visual components. Update the relevant product documentation alongside changed behavior, and use a small number of actual Flutter previews for visual checks. Respect the user's request to reserve real-device acceptance for them.

Treat design documents as contracts and direction, not proof of implementation. Inspect the current code and evidence before claiming behavior is finished. The 2026-09-07 integration is recorded in the architecture and design review documents; real-device and campus-service acceptance remains distinct from offline Flutter previews.
