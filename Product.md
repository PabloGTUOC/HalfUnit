# PRODUCT.md — Half Unit

Product specification. Source of truth for *what* to build. `AGENTS.md` defines *how*.
Last updated: 22 Oct 2026 · Owner: Pablo Torres

## Overview

Half Unit is a native iPhone and Apple Watch app that logs each alcoholic drink in under 3 seconds and shows how many days you have gone without drinking. Logging lives on the wrist; insight lives on the phone. Every drink is also written to Apple Health.

**Problem.** People who want to drink less rarely know how often they actually drink. Existing trackers ask too many questions per drink, so logging stops after a week.

**Goals**

- Log a drink in 1 tap after opening the app (2 taps from a watch complication).
- Always show "days without alcohol" as the first thing on screen.
- Answer "how many days did I drink in the last 3 months / 12 months / 2 years?" instantly.
- Keep official grams of alcohol in the background, so data stays comparable and exportable.

**Success measures (first 3 months)**

- Median time to log a drink under 3 seconds.
- At least 90% of drinking days logged on the same day.
- App opened on at least 5 of 7 days per week.

## Principles and target user

The target user is an adult who drinks socially and wants honest awareness, not a sobriety program. Version 1 ships publicly on the App Store from day one, free, with no ads and no in-app purchases.

1. **Log first, ask never.** A drink is one tap. Type of drink, time and place are optional and editable later.
2. **Days, not judgement.** The headline metric is days without alcohol, shown neutrally. No shaming copy, no red warnings by default.
3. **Simple surface, rich data.** Buttons speak in simple units; the database also stores grams and drink category.
4. **Watch first for input, phone first for insight.** The watch never shows charts beyond today's total and the streak.
5. **Private by default.** Data stays on device and in the user's iCloud. No account, no analytics, no ads.

## Unit system

The app uses a simple scale in steps of 0.5 "HU" (Half Unit points), and stores grams of pure alcohol behind every entry. 0.5 HU is about 10 g, which is one German standard drink.

**Why both.** Official units differ by country: Germany and the WHO use 10 g per standard drink, the UK uses 8 g (10 ml), the US 14 g, Austria 20 g. A personal scale is easier to tap; grams keep the data honest and comparable.

**Default presets** (grams = ml × ABV × 0.8)

| Preset | Example serving | HU | Grams (default) | German std. drinks |
| --- | --- | --- | --- | --- |
| Small beer | 0.25–0.33 l, 5% | 0.5 | 10–13 | 1–1.3 |
| Small wine | 0.1–0.125 l, 12% | 0.5 | 10–12 | 1–1.2 |
| Beer | 0.5 l, 5% | 1 | 20 | 2 |
| Wine glass | 0.2 l, 12% | 1 | 19 | 1.9 |
| Shot | 4 cl, 40% | 1 | 13 | 1.3 |
| Long drink / double | 8 cl spirit, 40% | 2 | 26 | 2.6 |

**Rules**

- Every preset has editable defaults (name, icon, HU, volume, ABV); grams are recalculated from volume and ABV.
- The user can add custom presets (e.g. "Mass 1 l" = 4 HU, 40 g).
- A shot is rated 1 HU by owner choice, although by grams it is closer to 0.6. Keep it, but show grams on the detail screen.
- Only alcoholic drinks are logged; the smallest entry is 0.5 HU. Non-alcoholic drinks are not tracked.
- Display unit is selectable in Settings: HU (default), grams, German standard drinks (10 g) or UK units (8 g).

Sources: [EU Health Promotion Knowledge Gateway – national drinking guidelines](https://knowledge4policy.ec.europa.eu/health-promotion-knowledge-gateway/national-low-risk-drinking-recommendations-drinking-guidelines_en), [NHS – calculating alcohol units](https://www.nhs.uk/live-well/alcohol-advice/calculating-alcohol-units/), [Wikipedia – standard drink](https://en.wikipedia.org/wiki/Standard_drink).

## Core features

Version 1 has four features: quick logging, the days-without counter, drinking-day statistics and an editable history.

### F1 – Quick logging

- Six preset buttons (see Unit system) on both iPhone and Watch, large enough to hit without looking twice.
- One tap logs the drink with the current time; haptic confirmation plus a 5-second **Undo** banner.
- Long-press a button to log at a different time ("earlier tonight", or a date and time picker) for drinks logged the next morning.
- Tapping the same button several times adds several drinks; today's total updates instantly.
- Optional fields, editable later: note, ABV, volume, location (off by default).

### F2 – Days without alcohol

- Headline: **"24 days without alcohol"**, plus "Last drink: Sun 28 Sep, Beer".
- Formula: today's logical date minus the logical date of the last drinking day. Example: last drink Saturday night, today Monday = 2 days. If there is a drink today, the counter shows "Today" and the previous streak length.
- **Day boundary:** a logical day runs 07:00 to 06:59 (configurable). A beer at 01:30 belongs to the previous evening, so a night out never counts as two drinking days.
- Shows longest streak ever and longest streak this year.
- Milestone moments at 7, 14, 30, 60, 90, 180 and 365 days (gentle, optional).

### F3 – Drinking-day statistics

- Fixed periods: last 7 days, 30 days, 3 months, 12 months, 2 years, plus a custom date range.
- For each period: drinking days (e.g. "18 of 90 days"), % of days, alcohol-free days, total HU and grams, average HU per drinking day, heaviest day.
- Comparison with the previous period of the same length (e.g. "−4 drinking days vs previous 3 months").
- Calendar heatmap (one square per day, shade = HU) and a weekly bar chart of HU.
- Breakdown by drink type and by weekday ("Fridays are 41% of your drinking days").

### F4 – History and editing

- Reverse-chronological list grouped by logical day, with day totals.
- Swipe to delete, tap to edit (time, preset, HU, volume, ABV, note).
- Edits and deletes propagate to Apple Health and to the other device.
- CSV export of all drinks; JSON backup and restore.

## Apple Watch experience

The watch app is a standalone logger: it works without the iPhone nearby and syncs when it can.

**Main screen (single scroll, no navigation)**

1. Top: "24 days" (or "Today: 1.5 HU" once something is logged).
2. A 2 × 3 grid of preset buttons with icon and HU value.
3. Below the grid: "Undo last" and "Log earlier…".

**Behaviour**

- Tap = log + haptic + Undo for 5 seconds. Digital Crown scrolls; no confirmation dialogs.
- Writes to the watch's local store immediately, so the entry exists even if the phone is off; the iPhone writes it to Apple Health once it syncs.
- Shows only today's drinks and the streak; no charts.
- Works offline; entries sync to the iPhone through the shared iCloud store.
- Supports the Action button on Apple Watch Ultra and a Smart Stack widget (see Widgets).
- Minimum: watchOS 26.

## iPhone screens

The iPhone app has three tabs: Today, Insights and History, plus Settings behind a gear icon.

| Screen | Purpose | Key elements |
| --- | --- | --- |
| Today | Log and see the streak | Large "24 days without alcohol" card; last drink date and type; 6 preset buttons; today's drinks with total HU |
| Insights | Answer "how often do I drink?" | Period picker (7 d, 30 d, 3 m, 12 m, 2 y, custom); drinking days and % of days; total HU and grams; change vs previous period; calendar heatmap; weekly bars; weekday and drink-type breakdown; longest streaks |
| History | Review and correct | Days grouped with totals; swipe to delete; tap to edit; search by drink type or note |
| Settings | Tune the app | Presets editor; day-boundary hour; display unit; Apple Health on/off; reminders; Face ID lock; export and backup |
| Onboarding | First run, 3 screens | What a HU is; choose or adjust presets; Apple Health permission with a one-line reason |

**Design notes**

- Native SwiftUI look, Dynamic Type, Dark Mode and VoiceOver labels on every button (e.g. "Log beer, 1 unit").
- Neutral colour palette; the streak card can use a calm accent, never red.
- Empty states: "No drinks logged yet. Your counter starts now."

## Apple Health integration

Every drink is mirrored to Apple Health as an "Alcoholic Beverages" sample; the app's own database stays the source of truth.

**Data type**

- `HKQuantityTypeIdentifier.numberOfAlcoholicBeverages`, unit `HKUnit.count()`, one sample per drink, start = end = drink time.
- Value written: **German standard drinks (grams ÷ 10)** (decided). Apple Health's Alcoholic Beverages is a count of standard drinks, so the app converts grams to standard drinks instead of writing its own HU; a 0.5 l beer appears as 2 in Health.
- Metadata: `HKMetadataKeySyncIdentifier` = drink UUID, `HKMetadataKeySyncVersion` = edit counter, plus custom keys for preset, HU, grams, volume and ABV.

**Write rules**

- The iPhone app is the only Health writer, including for drinks logged on the watch once they sync. One writer means one Health source, so edits and deletes always find the original sample.
- Edit = save a new sample with the same sync identifier and a higher sync version; Health replaces the old one.
- Delete = delete the sample matched by sync identifier.
- If permission is denied, the app works fully and shows a small "Not syncing to Health" note in Settings.

**Read rules (optional, off by default)**

- "Include drinks from other apps": an anchored query reads alcohol samples from other sources and shows them in History marked "From Health". They count in stats and the streak.
- Read access is also used once at onboarding to import past history, if the user agrees.

**Setup for the developer**

- Enable the HealthKit capability on the iOS target (the watch target only if read features need it later).
- Info.plist: `NSHealthUpdateUsageDescription` (write) and `NSHealthShareUsageDescription` (read), each with a one-line plain reason.
- Check `HKHealthStore.isHealthDataAvailable()` first; use one shared `HKHealthStore`.
- HealthKit never reveals whether read permission was denied, so the UI must not depend on it.

Not in scope: blood alcohol content (`bloodAlcoholContent`) and any intoxication estimates.

## Widgets, complications and Siri

The fastest log is the one that skips opening the app, so every surface reuses one shared "Log drink" App Intent.

| Surface | Shows | Action |
| --- | --- | --- |
| Watch complication (circular, rectangular, corner) | Days without alcohol | Tap opens the logger grid |
| Watch Smart Stack widget | Streak + today's HU | Interactive buttons for the 2 most used presets |
| iPhone Home Screen widget (small, medium) | Streak; medium adds last drink and 3 preset buttons | Interactive log buttons (no app launch) |
| iPhone Lock Screen widget | "24 d" | Tap opens Today |
| Control Center control | Preset icon | Logs the chosen preset |
| Siri and Shortcuts | — | "Log a beer in Half Unit", "How many days without alcohol?" |
| Action button (iPhone, Watch Ultra) | — | Runs a chosen preset or opens the logger |

- Widgets read from the shared App Group store and refresh after every log and at the day boundary.
- App Intents: `LogDrinkIntent(preset, time?)`, `GetStreakIntent`, `GetStatsIntent(period)`.

## Data model, calculations and sync

Three entities cover version 1; all statistics are computed from Drink rows, never stored.

**Drink**

| Field | Type | Notes |
| --- | --- | --- |
| id | UUID | Also the HealthKit sync identifier |
| timestamp | Date | Actual time of the drink |
| logicalDate | Date (day) | Derived from timestamp and day-boundary hour; stored for fast queries |
| presetId | UUID? | Null for one-off custom drinks |
| name | String | Snapshot of preset name at log time |
| hu | Decimal | Multiple of 0.5, minimum 0.5 |
| volumeMl | Int? | Optional |
| abvPercent | Decimal? | Optional |
| grams | Decimal | volumeMl × abv × 0.8, or preset default |
| note | String? | Optional |
| source | Enum | watch, phone, widget, siri, healthImport |
| healthSyncVersion | Int | Increments on each edit |
| isDeleted | Bool | Tombstone, so deletes sync and remove the Health sample |
| createdAt, updatedAt | Date | Conflict resolution |

**Preset:** id, name, icon (SF Symbol), hu, volumeMl, abvPercent, sortOrder, isHidden.

**Settings:** dayBoundaryHour (default 7), displayUnit, healthReadEnabled, remindersEnabled, appLockEnabled.

**Calculations**

- Drinking day = a logicalDate with at least one non-deleted drink.
- Days without alcohol = today's logicalDate − most recent drinking day.
- Period stats = rolling window ending today, e.g. 3 months = the last 91 logical days including today; 12 months = 365; 2 years = 730.
- Longest streak = largest gap between consecutive drinking days (and from the first log date).
- When a period is longer than the time since first use, it only counts tracked days, shown as "18 of 40 tracked days".
- Recompute when the time zone changes; logicalDate uses the time zone where the drink was logged.

**Sync**

- SwiftData store in an App Group container, shared by app, widgets and intents.
- iCloud sync via CloudKit private database on iPhone and Watch; WatchConnectivity as a fast path to refresh the other device immediately.
- Conflicts: last writer wins per drink using updatedAt; deletes are tombstones kept 30 days.

## Privacy, tone and safety

The app handles health data, so privacy and tone are product features, not legal footnotes.

- No account, no server, no third-party SDKs, no tracking. App Store privacy label: "Data Not Collected".
- Data lives on device and in the user's private iCloud; Health data follows Apple's rules and is never used for advertising.
- Optional Face ID / passcode lock for the app; widgets can hide numbers on the Lock Screen.
- Copy is neutral and factual ("3 drinking days this week"), never moralising. Milestones celebrate; drinking days are simply recorded.
- No medical claims, no blood-alcohol or "safe to drive" estimates.
- Settings → About shows a short note that official low-risk guidance varies by country and links to a support resource (Germany: the DHS / "Kenn dein Limit" pages; UK: NHS).
- Optional reminders: an evening nudge ("Anything to log today?") at a chosen time, off by default.

## Technical architecture

One Xcode project, 100% Swift and SwiftUI, with a shared core package so the iPhone app, Watch app, widgets and intents run the same logic.

```
 iPhone app            Apple Watch app        Widgets + App Intents
 (Today/Insights/      (standalone logger)    (complications, Siri,
  History)                                     controls)
      │                       │                        │
      └───────────────────────┼────────────────────────┘
                              ▼
        ┌──────────── HalfUnitCore (Swift package) ────────────┐
        │  LogService      StatsEngine        HealthSync       │
        └───────┬──────────────────────────────────┬───────────┘
                ▼                                  ▼ (iPhone only)
   SwiftData store (App Group) ◀──▶ iCloud      Apple Health
   source of truth                  (CloudKit)  (Alcoholic Beverages)
```

| Area | Choice |
| --- | --- |
| Platforms | iOS 26 and watchOS 26 minimum |
| UI | SwiftUI, Swift Charts for heatmap and bars |
| Persistence | SwiftData in an App Group container |
| Sync | CloudKit private database; WatchConnectivity for instant refresh |
| Health | HealthKit (iOS target writes) |
| Shortcuts and widgets | App Intents, WidgetKit, ControlWidget |
| Targets | iOS app, watchOS app, widget extension (iOS + watchOS), shared Swift package `HalfUnitCore` |
| Tests | Swift Testing for StatsEngine (day boundary, streaks, periods, time zones); UI tests for the 1-tap log |
| Dependencies | None at runtime (Apple frameworks only) |

## MVP scope and acceptance criteria

The MVP is F1–F4 on iPhone and Watch, Apple Health write, one complication and one Home Screen widget, released free on the App Store; everything else follows.

**MVP must pass**

- [ ] Logging a preset on the Watch takes 1 tap from the app and gives haptic feedback within 0.3 s.
- [ ] A drink logged on the Watch with the phone off appears on the phone within 1 minute of reconnecting.
- [ ] Undo within 5 seconds removes the drink from the store and from Apple Health.
- [ ] A drink at 01:30 is assigned to the previous logical day (boundary 07:00).
- [ ] Last drink Saturday, today Monday → counter shows 2 days.
- [ ] Insights for 3 m / 12 m / 2 y show correct drinking-day counts against a seeded test dataset.
- [ ] Editing a drink updates its Health sample without creating a duplicate; deleting removes it.
- [ ] With Health permission denied, every feature except Health sync works.
- [ ] Complication and widget show the correct streak after logging and after the day boundary.
- [ ] CSV export opens correctly in Numbers and Excel.

**App Store release (day 1)**

- [ ] Apple Developer Program membership active; bundle IDs and HealthKit capability set up.
- [ ] Price: Free. No ads, no in-app purchases, no third-party SDKs.
- [ ] Privacy policy and support pages online (required for apps using HealthKit).
- [ ] App Privacy label: Data Not Collected.
- [ ] Age rating questionnaire answered honestly; alcohol references will raise the rating.
- [ ] Store text and screenshots (iPhone and Watch) in English and German; no medical claims.
- [ ] App Review notes explain why Health access is requested and how to test without data.
- [ ] EU trader status declared in App Store Connect.
- [ ] TestFlight beta with a few friends for at least 2 weeks before release.

**Later (version 1.1+)**

- Interactive widgets for all presets, Control Center control, Lock Screen widget.
- Optional goals: "max X drinking days per week" or "dry month", with progress ring.
- Read drinks from other apps via Health; import from CSV.
- Monthly summary notification; year-in-review screen.
- iPad layout and Mac for Insights.
- Localisation: Spanish.

## Decisions and open questions

**Decided on 22 Oct 2026**

- Name: Half Unit, kept for launch.
- Apple Health value: standard drinks (grams ÷ 10), aligned with Apple Health's own measure.
- Non-alcoholic drinks: not logged.
- Day boundary: 07:00.
- Distribution: public and free on the App Store from day 1.
- Stack: all native Swift (no Flutter / cross-platform).
- The iPhone app is the only writer to Apple Health.

**Still open**

- [ ] Final check that "Half Unit" is free on the App Store and as a domain for the privacy page.
- [ ] Launch languages beyond English and German (Spanish?).
