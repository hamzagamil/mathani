<!--
Sync Impact Report
- Version change: (unversioned template) → 1.0.0
- Modified principles (template placeholder → new title):
  - [PRINCIPLE_1_NAME] → I. Cross-Platform Parity (iOS & Android)
  - [PRINCIPLE_2_NAME] → II. Mobile-First Design
  - [PRINCIPLE_3_NAME] → III. Performance Is a Feature (NON-NEGOTIABLE)
  - [PRINCIPLE_4_NAME] → IV. Lean by Default
  - [PRINCIPLE_5_NAME] → V. Simplicity
- Added sections:
  - Platform & Store Requirements (was [SECTION_2_NAME])
  - Development Workflow & Quality Gates (was [SECTION_3_NAME])
  - Governance (filled)
- Removed sections: none
- Templates reviewed (read at runtime, not modified by this command):
  - .specify/templates/plan-template.md (Constitution Check gate reads this file) ✅ no edit needed
  - .specify/templates/spec-template.md ✅ no edit needed
  - .specify/templates/tasks-template.md ✅ no edit needed
- Deferred TODOs: none. Numeric performance/size budgets in Principles III–IV are initial
  defaults chosen at ratification and may be tuned by PATCH/MINOR amendment.
-->

# Mathani Constitution

## Core Principles

### I. Cross-Platform Parity (iOS & Android)

Mathani is a mobile app shipped to both the Apple App Store and Google Play.

- Every user-facing feature MUST work on both iOS and Android before it is considered done.
- A feature MUST NOT ship to one store while knowingly broken or missing on the other, unless
  the gap is documented in the spec with a justification and a tracked follow-up.
- Platform-specific behaviour (permissions, back navigation, notifications, share sheets,
  haptics) MUST follow each platform's conventions rather than forcing one platform's
  idiom onto the other.
- Specs and plans MUST state the minimum supported iOS and Android OS versions they target.

**Rationale**: Users on either store expect the same product; parity is a release
requirement, not an afterthought.

### II. Mobile-First Design

All design is mobile design. There is no desktop or web layout to fall back on.

- Every screen MUST be designed for phone-sized portrait viewports first; tablet or landscape
  support is an explicit, opt-in requirement in a spec.
- Touch targets MUST be at least 44×44 pt (iOS) / 48×48 dp (Android).
- Layouts MUST respect safe areas (notches, home indicator, status and navigation bars) and
  MUST NOT clip or overlap system UI.
- Screens MUST remain usable with system font scaling, dark mode, and screen readers
  (VoiceOver / TalkBack) enabled.
- Primary actions MUST be reachable one-handed; navigation MUST follow mobile patterns
  (tab bars, stacks, sheets), not desktop patterns (hover, right-click, wide sidebars).

**Rationale**: Designing for the device in hand produces a better product than adapting
designs made for larger screens.

### III. Performance Is a Feature (NON-NEGOTIABLE)

The app MUST be as fast as possible. Speed is a requirement and gates every release.

- Cold start to first interactive screen MUST be ≤ 2 s on a mid-range reference device
  (to be named in the first plan).
- UI MUST render at 60 fps during scrolling, transitions, and animations; dropped-frame
  regressions are bugs.
- Every tap MUST produce visible feedback within 100 ms; work that takes longer MUST show
  progress and MUST NOT block the UI thread.
- Network-dependent screens MUST render cached or skeleton content immediately rather than
  a blank screen, and MUST tolerate slow or absent connectivity.
- Lists MUST be virtualised; images MUST be sized for the device and cached.
- Any change that measurably regresses start time, frame rate, or memory use MUST be fixed
  or explicitly justified in the plan's Complexity Tracking before merge.

**Rationale**: Perceived speed drives retention and store ratings; it is far cheaper to keep
an app fast than to make a slow one fast later.

### IV. Lean by Default

The app MUST stay small and carry only what it needs.

- Every third-party dependency MUST be justified in the plan: what it replaces, its size
  cost, and why platform or existing code is insufficient. Prefer platform APIs and small,
  focused libraries over large frameworks.
- Unused code, assets, dependencies, and feature flags MUST be removed, not left dormant.
- Release builds MUST enable code shrinking/minification and asset optimisation.
- Initial store download size MUST stay ≤ 30 MB per platform; any increase over 1 MB in a
  single change MUST be called out in review.
- Assets MUST use efficient formats (vector where possible; compressed, appropriately
  sized raster images otherwise). Large or rarely used content SHOULD be loaded on demand.
- Background work, battery use, and data usage MUST be minimised; nothing runs in the
  background without a user-facing reason.

**Rationale**: Smaller apps install faster, convert better from store listings, start
faster, and are cheaper to maintain.

### V. Simplicity

- Build the simplest thing that satisfies the spec (YAGNI). No speculative abstractions,
  configuration, or extension points.
- One way to do a thing: shared UI components and patterns MUST be reused rather than
  duplicated with variations.
- Added complexity (new layers, patterns, services, or dependencies) MUST be justified in
  the plan's Complexity Tracking table.

**Rationale**: Simple code is faster to run, faster to change, and directly supports
Principles III and IV.

## Platform & Store Requirements

- Builds MUST comply with current Apple App Store Review Guidelines and Google Play
  Developer Policies, including privacy disclosures (App Privacy details, Data safety form)
  and target API level requirements.
- Permissions MUST be requested only when needed, in context, with a clear user-facing
  reason; the app MUST degrade gracefully when a permission is denied.
- Sensitive data MUST be stored using platform secure storage (Keychain / Keystore), never
  in plain-text local storage.
- Release builds MUST be signed, versioned consistently across both platforms, and
  reproducible from source control.

## Development Workflow & Quality Gates

- Every feature follows the Spec Kit flow: specify → plan → tasks → implement. Each plan
  MUST pass the Constitution Check before design work proceeds.
- Before merge, a change MUST be verified on at least one real or emulated iOS device and
  one Android device.
- Changes touching startup, navigation, lists, images, or dependencies MUST include a
  performance check against Principle III budgets and a size check against Principle IV.
- Code review MUST confirm compliance with all Core Principles; violations require either
  a fix or a documented justification in the plan.

## Governance

- This constitution supersedes other project practices and guidance. Where they conflict,
  the constitution wins.
- Amendments are made via `/speckit-constitution`, MUST include a Sync Impact Report, and
  MUST update the version and Last Amended date.
- Versioning follows semantic versioning:
  - MAJOR: a principle is removed or redefined in a backward-incompatible way.
  - MINOR: a principle or section is added or materially expanded.
  - PATCH: clarifications, wording, or tuning of numeric budgets that does not change intent.
- Compliance is reviewed at every plan (Constitution Check) and every code review.
  Unjustified complexity, size growth, or performance regressions block merge.

**Version**: 1.0.0 | **Ratified**: 2026-10-10 | **Last Amended**: 2026-10-10
