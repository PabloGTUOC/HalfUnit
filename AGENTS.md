# AGENTS.md — Half Unit

Instructions for every AI coding agent working in this repo (Claude Code, Codex, OpenCode, Gemini…), usually run in parallel from **Orca**, each in its own git worktree.
**Read `PRODUCT.md` first** — it defines what to build and what is out of scope. This file defines *how*.

> This is the single source of agent rules. `CLAUDE.md` only imports it. Edit rules here, never in two places.

## Project in one paragraph

A native iPhone + Apple Watch app that logs alcoholic drinks in one tap and shows "days without alcohol" plus drinking-day statistics (3 months, 12 months, 2 years). Drinks are measured in HU (Half Unit points, steps of 0.5) with grams of alcohol stored behind each entry. Data lives in SwiftData, syncs through the user's private iCloud (CloudKit), and is mirrored to Apple Health by the iPhone app. Free on the App Store, no accounts, no server, no third-party SDKs.

## Stack (do not change without asking)

| Layer | Choice |
|---|---|
| Language | Swift 6, strict concurrency on |
| UI | SwiftUI; Swift Charts for heatmap and bars |
| Platforms | iOS 26+, watchOS 26+ (iPhone and Apple Watch only) |
| Persistence | SwiftData in an App Group container |
| Sync | SwiftData + CloudKit private database; WatchConnectivity as fast path |
| Health | HealthKit — **written only by the iOS app** |
| Widgets / Siri | WidgetKit, App Intents (ControlWidget in 1.1) |
| Tests | Swift Testing (`import Testing`) for logic; XCTest only for UI tests |
| Project file | **XcodeGen** (`project.yml`). The `.xcodeproj` is generated and git-ignored |
| Lint / format | `swift format` (ships with the Xcode toolchain) |
| Runtime dependencies | **None.** Apple frameworks only. Dev tools via Homebrew: `xcodegen` |

## Repo layout

```
halfunit/
├── AGENTS.md                     # this file (source of truth for agents)
├── CLAUDE.md                     # imports AGENTS.md + Claude-only notes
├── PRODUCT.md                    # product spec
├── README.md
├── project.yml                   # XcodeGen spec — edit this, never the .xcodeproj
├── .swift-format
├── Config/
│   ├── Shared.xcconfig           # versions, deployment targets, BUNDLE_ID_PREFIX
│   ├── Local.xcconfig.example    # DEVELOPMENT_TEAM goes in Local.xcconfig (git-ignored)
│   └── Entitlements/             # iOS, watchOS, widgets (.entitlements)
├── Packages/HalfUnitCore/
│   ├── Package.swift
│   ├── Sources/HalfUnitCore/
│   │   ├── Model/                # @Model Drink, Preset, AppSettings (not `Settings`: clashes with SwiftUI)
│   │   ├── Domain/               # LogicalDay, Units (HU/grams/std drinks), default presets
│   │   ├── Logging/              # LogService: log, edit, delete, undo
│   │   ├── Stats/                # StatsEngine: pure functions, no SwiftData imports
│   │   ├── Health/               # HealthSync + HealthStoreClient protocol
│   │   ├── Sync/                 # WatchConnectivity bridge
│   │   ├── Intents/              # LogDrinkIntent, GetStreakIntent, GetStatsIntent
│   │   └── Export/               # CSV export, JSON backup/restore
│   └── Tests/HalfUnitCoreTests/  # fast, run on macOS with `swift test`
├── Apps/
│   ├── iOS/                      # App entry, Today, Insights, History, Settings, Onboarding
│   └── watchOS/                  # Logger grid, today list
├── Extensions/
│   ├── WidgetsiOS/               # Home Screen widget (v1); Lock Screen widget, Control (1.1)
│   └── WidgetsWatch/             # Streak complication (v1); interactive Smart Stack widget (1.1)
├── Resources/
│   ├── Localizable.xcstrings     # String Catalog: en (base), de
│   └── PrivacyInfo.xcprivacy     # privacy manifest
├── UITests/
├── docs/                         # privacy policy + support page sources
└── scripts/
    ├── bootstrap.sh              # checks tools, copies Local.xcconfig, runs xcodegen
    ├── test.sh                   # core tests + iOS + watchOS builds/tests
    └── lint.sh                   # swift format lint
```

XcodeGen globs source folders, so **adding a file to an existing folder needs no `project.yml` change**.

## Configuration

| Setting | Where | Notes |
|---|---|---|
| `BUNDLE_ID_PREFIX` | `Config/Shared.xcconfig` | e.g. `com.example` (TODO: owner sets real prefix) |
| Bundle IDs | derived | app `$(BUNDLE_ID_PREFIX).halfunit`, watch `.watchkitapp`, widgets `.widgets` / `.watchwidgets` |
| App Group | entitlements | `group.$(BUNDLE_ID_PREFIX).halfunit` |
| iCloud container | entitlements | `iCloud.$(BUNDLE_ID_PREFIX).halfunit` |
| `DEVELOPMENT_TEAM` | `Config/Local.xcconfig` | git-ignored; never commit a team ID or signing identity |
| Marketing / build version | `Config/Shared.xcconfig` | `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` |

## Implementation rules

### Domain (`Domain/`, `Stats/`)
- **One** function decides the logical day: `LogicalDay.of(_ date: Date, boundaryHour: Int, timeZone: TimeZone) -> LogicalDay`. Default boundary hour = 7. Nothing else does day math.
- Inject time: every service takes a `Clock`/`now: () -> Date`, a `Calendar` and a `TimeZone`. Never call `Date()` inside logic.
- HU is `Decimal`, always a multiple of 0.5, minimum 0.5. Grams = `volumeMl × abv/100 × 0.8`. Standard drinks for Health = `grams / 10`. Keep these three conversions in `Units.swift` only.
- `StatsEngine` is pure: input = array of value-type drink snapshots + settings + today; output = structs. No SwiftData, no HealthKit, no UI imports. This is where most tests live.
- Rounding: store grams and standard drinks unrounded (`Decimal`); write the unrounded standard-drink value to Health. Round only for display: grams to whole numbers, standard drinks and UK units to 1 decimal, HU as stored.
- Each drink stores `timeZoneIdentifier` (the zone where it was logged); its `logicalDate` is computed in that zone, not the device's current zone.
- Periods: 7 d = 7 logical days incl. today, 30 d = 30, 3 m = 91, 12 m = 365, 2 y = 730. When the period exceeds tracked history, report "x of n tracked days".
- Streaks count alcohol-free logical days. Current streak = today − last drinking day (today counts). Past streak between drinking days A and B = B − A − 1. Streak before the first drinking day = first drinking day − first-use day. Longest streak = max of all of these.

### Persistence and sync (`Model/`, `Sync/`)
- SwiftData + CloudKit constraints apply: **no `@Attribute(.unique)`**, every stored property optional or with a default value, all relationships optional. Plan model changes with a `VersionedSchema` + `SchemaMigrationPlan` from v1.
- The store lives in the App Group container so app, widgets and intents share it.
- Deletes are tombstones (`deletedAt` set to the delete time), purged 30 days after `deletedAt`. Never name a property `isDeleted`: it clashes with `PersistentModel.isDeleted`. Conflicts: last writer wins by `updatedAt`.
- WatchConnectivity: watch → phone uses `transferUserInfo` (queued, survives restarts); phone → watch uses `updateApplicationContext` for streak/today state. CloudKit remains the durable path.
- CloudKit: agents use the **Development** environment only. Never deploy the schema to Production.

### Apple Health (`Health/`)
- Only the iOS app writes to HealthKit, including drinks that arrived from the watch. The watch target has no HealthKit write code.
- Type: `numberOfAlcoholicBeverages`, unit `.count()`, value = standard drinks, start = end = drink timestamp.
- Metadata: `HKMetadataKeySyncIdentifier` = drink UUID string, `HKMetadataKeySyncVersion` = `healthSyncVersion`. Edit = save with same identifier and higher version. Delete = delete by sync identifier.
- All HealthKit calls go through a `HealthStoreClient` protocol so tests use a fake. Never require Health permission for any other feature to work.
- v1 only writes to Health: request share (write) authorization only, with `NSHealthUpdateUsageDescription`. Reading other apps' drinks is 1.1; add `NSHealthShareUsageDescription` then. Strings are plain, one line, localized.

### UI
- Today screen: streak card first, then the 6 preset buttons, then today's list. One tap logs; show a 5 s Undo banner; haptic on success.
- Watch: single scrolling screen, 2 × 3 grid, no confirmation dialogs, no charts.
- Every interactive element has an accessibility label ("Log beer, 1 unit"). Support Dynamic Type up to accessibility sizes and Dark Mode.
- All user-facing strings in `Localizable.xcstrings` (en + de). No hard-coded strings in views.
- Copy is neutral and factual. Never moralising, never red for drinking days, no medical claims, no BAC estimates.

### Widgets and intents
- One `LogDrinkIntent` used by app shortcuts and widgets in v1, and by the Control Center control and Action button in 1.1. Widgets call `WidgetCenter.shared.reloadAllTimelines()` after each log, and timelines refresh at the day boundary.

### Privacy
- No networking except CloudKit via SwiftData. No analytics, crash SDKs, ads or remote config.
- Keep `PrivacyInfo.xcprivacy` accurate (e.g. `UserDefaults` required-reason entry). Never log drink data with `print`; use `Logger` with `privacy: .private` for anything user-related.

## Working in parallel (Orca worktrees)

- One agent = one task = one branch = one worktree. Branch names: `agent/<area>-<short-desc>` (e.g. `agent/stats-period-counts`).
- After creating or switching a worktree, run `./scripts/bootstrap.sh` (the `.xcodeproj` is generated per worktree).
- Use a per-worktree build folder: always pass `-derivedDataPath .build/DerivedData` so parallel builds don't clobber each other.
- Simulators are shared by all worktrees. Never erase, reset or delete simulators. Only one agent runs UI tests at a time; unit tests (`swift test`) are always safe in parallel.
- Hot files where parallel edits collide: `project.yml`, `Package.swift`, `Model/*.swift`, `Localizable.xcstrings`. Touch them only if the task needs it, keep the diff minimal, and say so in the summary.
- Stay inside your task's folders. If you need a change in another area, stop and describe it instead of making it.
- Never commit generated files: `*.xcodeproj`, `.build/`, `DerivedData/`, `Local.xcconfig`, `*.xcuserstate`.

## Commands

```bash
./scripts/bootstrap.sh                                    # brew install xcodegen if missing; xcodegen generate
swift test --package-path Packages/HalfUnitCore           # fast core tests (macOS, no simulator)
./scripts/lint.sh                                         # swift format lint --recursive --strict .
./scripts/test.sh                                         # core tests + iOS and watchOS builds and unit tests

# iOS app (set SIM_IPHONE to an installed simulator, see `xcrun simctl list devices available`)
xcodebuild -project HalfUnit.xcodeproj -scheme HalfUnit \
  -destination "platform=iOS Simulator,name=$SIM_IPHONE" \
  -derivedDataPath .build/DerivedData test

# watchOS app
xcodebuild -project HalfUnit.xcodeproj -scheme HalfUnitWatch \
  -destination "platform=watchOS Simulator,name=$SIM_WATCH" \
  -derivedDataPath .build/DerivedData build
```

## Definition of done (every task / PR)

1. `./scripts/lint.sh` clean, `swift test` green, iOS and watchOS targets build with zero warnings.
2. New logic has Swift Testing tests. Anything touching dates tests: the 07:00 boundary, a drink at 01:30, a DST change week, and a time-zone change.
3. Acceptance criteria in `PRODUCT.md` that the task touches are checked and listed in the summary.
4. New strings are in the String Catalog with English and German values.
5. No new dependency, capability, entitlement or Info.plist key without stating why.
6. Summary at the end: what changed, files touched, how it was tested, anything left open.

## Don'ts

- Don't add third-party packages, analytics, ads, accounts or a backend.
- Don't edit the `.xcodeproj` by hand or commit it.
- Don't write to HealthKit from the watch, widgets or intents running outside the iOS app process.
- Don't use `@Attribute(.unique)` or non-optional relationships in SwiftData models.
- Don't call `Date()` or `Calendar.current` inside domain logic.
- Don't sign, archive, upload to App Store Connect, or touch CloudKit Production.
- Don't put real personal drink data in fixtures; use synthetic seeds.
- Don't silently change scope. If something in `PRODUCT.md` looks wrong or contradictory, stop and ask.

## Suggested build order

1. `HalfUnitCore`: `Units`, `LogicalDay`, default presets, `StatsEngine` + tests (no UI).
2. SwiftData models with versioned schema, `LogService` (log, edit, delete, undo) + tests with an in-memory container.
3. `project.yml`, xcconfigs, entitlements, `bootstrap.sh`; iOS app shell with the Today screen.
4. Watch app logger grid; WatchConnectivity bridge; CloudKit sync between devices.
5. `HealthSync` on iOS (write, edit, delete) with a fake store in tests; permission onboarding.
6. Insights (periods, heatmap, weekly bars) and History (edit, delete, search).
7. Widgets: one watch complication, one iOS Home Screen widget; `LogDrinkIntent`.
8. Settings, CSV/JSON export, localisation (en, de), privacy manifest.
9. Release prep from `PRODUCT.md` checklist: docs/privacy policy, TestFlight build notes.
