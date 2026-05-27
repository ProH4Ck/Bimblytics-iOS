# Bimblytics iOS Agent Guide

## Scope

This repository contains the native iOS frontend for Bimblytics. It is a
single SwiftUI application target with SwiftData local persistence and API/OIDC
synchronization with the Bimblytics backend.

## Project Map

- `Bimblytics/BimblyticsApp.swift`: app entry point and complete SwiftData
  model-container registration.
- `Bimblytics/ContentView.swift`: main navigation, baby selection, event
  timeline, onboarding, deletion, and synchronization entry points.
- `Bimblytics/Baby`: baby and synchronized-family models plus family and baby
  management views.
- `Bimblytics/Diapers`: diaper inventory, changes, catalog views, local domain
  models, and `DiaperInventoryService`.
- `Bimblytics/Feeding`: food catalog and feeding-event views and models.
- `Bimblytics/Api`: auth, device, family, baby, synchronization services and
  the persistent sync outbox.
- `Bimblytics/Infrastructure/AppEnvironment.swift`: typed access to values
  supplied by `Info.plist` and `.xcconfig`.
- `Bimblytics/Theme`, `Common`, and `Design`: reusable appearance/layout and
  in-memory preview fixtures.
- `Bimblytics/Config/Dev.xcconfig` and `Production.xcconfig`: environment,
  endpoint, app identity, and URL-scheme values.

## Toolchain And Commands

- Open/build `Bimblytics.xcodeproj` with scheme `Bimblytics`.
- The current project targets iOS `26.0` and sets `SWIFT_VERSION = 5.0`.
- Debug build from the command line:
  `xcodebuild -project Bimblytics.xcodeproj -scheme Bimblytics -configuration Debug -sdk iphonesimulator build`
- Device or archive builds may require local signing configuration.
- No XCTest target is currently present in the project; for UI/model changes,
  build the scheme and keep affected SwiftUI previews working.

## Architecture And Conventions

- Prefer feature-local additions under `Baby`, `Diapers`, or `Feeding`; place
  shared remote access in `Api`, shared styling in `Theme`, and common layout
  helpers in `Common`.
- Persist user-facing domain state with SwiftData `@Model` types. When adding a
  model, register it in `BimblyticsApp` and in relevant preview containers such
  as `Design/PreviewData.swift`.
- Views use `@Query`, `@Environment(\.modelContext)`, and small service types
  for mutations. Save the `ModelContext` after intentional local mutations.
- Preserve the app's visual vocabulary by using `AppColors`, existing button,
  form, container and text styles rather than embedding replacement palettes in
  individual views.
- Add or maintain `#Preview` cases for substantial view work, including dark
  appearance where adjacent views already provide it.
- Keep user-visible strings in English unless localization is introduced as a
  deliberate broader change; existing UI text is English.

## Authentication And Configuration

- Read environment-dependent URLs, identifiers, and callback schemes through
  `AppEnvironment`; do not hardcode production endpoints or client secrets in
  view or service code.
- OIDC uses authorization code flow with PKCE and persists session material in
  Keychain through `BimblyticsAuthService`. Do not log or persist access,
  refresh, or ID tokens outside the established secure path.
- Development TLS bypassing is intentionally restricted to local hosts and
  guarded by `#if DEBUG`; never broaden it into release behavior.
- If callback URL behavior changes, update the matching `.xcconfig`,
  `Info.plist`, `AppEnvironment`, and auth/deep-link consumers together.

## Persistence And Synchronization Invariants

- Remote synchronization and local offline behavior meet in
  `BimblyticsEventSyncCoordinator` and `SyncOutboxChange`. Mutating synced
  families, catalog records, or events must preserve outbox enqueue/flush
  behavior rather than silently updating local state only.
- Keep the backend entity-type strings, operation values, payload fields,
  UUIDs, timestamps, and family identifiers compatible with the API sync
  contracts. A sync payload change generally requires a coordinated backend
  update.
- Preserve ordering dependencies in the outbox: food categories and units must
  be sent before food items, which precede event records.
- Avoid discarding pending local changes while applying remote changes; the
  coordinator intentionally does not overwrite an entity with a queued local
  operation.
- Inventory operations belong in `DiaperInventoryService` so stock quantities
  and stock movement history remain consistent.

## Verification Expectations

- For any Swift change, build the `Bimblytics` scheme for Debug when the local
  Xcode/simulator environment permits it.
- Exercise relevant previews for layout or theme changes and verify both light
  and dark variants when present.
- For authentication or synchronization edits, verify the local development
  callback/deep-link flow and a create/update/delete synchronization path
  against the backend when it is available.
- Avoid incidental edits to `project.pbxproj`; change it only when adding,
  removing, or configuring project resources or targets.
