# First TestFlight upload: problems and fixes

What went wrong when Half Unit 1.0.0 (1) first went to TestFlight through Xcode Cloud (October 2026), and how each problem was fixed. Read it before the next release, or before setting up another app the same way.

The steps themselves are in [deploy-guide.md](deploy-guide.md).

## Summary

| # | Where it failed | Message (short) | Fix |
|---|---|---|---|
| 1 | Xcode Cloud, before build | `HalfUnit.xcodeproj does not exist` | `ci_scripts/ci_post_clone.sh` runs XcodeGen |
| 2 | Xcode Organizer, Distribute | `DistributionAppRecordProviderError error 0` | Create the app record in App Store Connect |
| 3 | Xcode Cloud workflow | Build ran but nothing reached TestFlight | Use an **Archive** action, not Build |
| 4 | Prepare build for App Store Connect | `Missing purpose string … NSHealthShareUsageDescription` | Add the Health "share" string |
| 5 | Prepare build for App Store Connect | `Invalid bundle … orientations … iPad multitasking` | iPhone-only, plus all four iPad orientations |
| 6 | Your Mac, `git pull` | Local changes would be overwritten | Stop Xcode editing the string catalogs |

Problems 4 and 5 only show up at the "Prepare build for App Store Connect" step, where Apple validates the build. Local builds, simulators and tests all pass with them.

## 1. Xcode Cloud: the project file does not exist

**Message**

```
xcodebuild: error: '/Volumes/workspace/repository/HalfUnit.xcodeproj' does not exist.
Project HalfUnit.xcodeproj does not exist at the root of the repository
```

**Cause.** The `.xcodeproj` is generated from `project.yml` by XcodeGen and is git-ignored. Xcode Cloud only clones the repository, so it found no project.

**Fix**

- `ci_scripts/ci_post_clone.sh` (must be executable, in a folder named exactly `ci_scripts` next to the project). Xcode Cloud runs it after cloning, and it runs `./scripts/bootstrap.sh`, which installs XcodeGen and generates the project.
- The Team ID is never committed. The script writes `Config/Local.xcconfig` from the workflow environment variable `HALFUNIT_TEAM_ID`. Set it in App Store Connect → Xcode Cloud → workflow → **Environment → Environment Variables**.

**Next time.** Any project that uses XcodeGen (or Tuist) needs this script before the first Xcode Cloud build.

## 2. Organizer: DistributionAppRecordProviderError

**Message**

```
The operation couldn't be completed. (IDEDistribution.DistributionAppRecordProviderError error 0.)
```

**Cause.** Xcode could not find or create the app in App Store Connect. Usually there is no app record for the bundle ID yet. Other causes are an unaccepted agreement under **Business**, or Xcode signed in with an account that lacks the App Manager or Admin role.

**Fix.** Create the app in App Store Connect → **Apps → +  → New App**: platform iOS, bundle ID `es.opinasdeque.halfunit`, SKU of your choice. (Half Unit's app ID is 6826375845.) Then check that **Business** shows no pending agreements.

**Next time.** Create the App Store Connect app record right after registering the App IDs, before the first upload.

## 3. Xcode Cloud workflow: building is not uploading

**Cause.** The default workflow has a **Build** action. It compiles but makes no archive, so nothing is sent to App Store Connect.

**Fix.** In the workflow:

- **Actions**: remove Build and add **Archive – iOS**, scheme **HalfUnit**.
- **Deployment Preparation**: **TestFlight and App Store** is the better long-term choice. It allows external testers and App Store submission of the same build. **TestFlight (Internal Testing Only)** builds can never go to external testers or the App Store.
- **Post-Actions**: **TestFlight Internal Testing** with your tester group.

**Internal vs external testers**

- Internal testers are up to 100 people in your App Store Connect team. Builds are available as soon as processing ends, with no review.
- External testers are anyone with an email or a public link, up to 10,000. The first build of each version needs a short Beta App Review. You must also have filled in the test information (contact email, description, privacy policy URL).

## 4. Missing purpose string NSHealthShareUsageDescription

**Message**

```
Missing purpose string in Info.plist. … The Info.plist file for the "HalfUnit.app" bundle
should contain a NSHealthShareUsageDescription key with a user-facing purpose string …
```

**Cause.** Half Unit only writes to Apple Health, so it had only `NSHealthUpdateUsageDescription`. App Store Connect requires the share (read) string for every app with the HealthKit entitlement, even one that never reads.

**Fix.** Added `NSHealthShareUsageDescription` in `project.yml` and translated it in `Resources/InfoPlist.xcstrings` (en, de). It says plainly that the app does not read Health data. When reading arrives in 1.1, reword it (noted in `AGENTS.md`).

**Next time.** Any app with HealthKit: include both Health strings from the start.

## 5. Invalid bundle: iPad orientations

**Message**

```
Invalid bundle. The "UIInterfaceOrientationPortrait" orientations were provided for the
UISupportedInterfaceOrientations Info.plist key in the es.opinasdeque.halfunit bundle, but you
need to include all of the "UIInterfaceOrientationPortrait, UIInterfaceOrientationPortraitUpsideDown,
UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationLandscapeRight" orientations to support
iPad multitasking.
```

**Cause.** The app is portrait-only. The iOS targets were also built for iPhone and iPad (the default device family), so Apple applied the iPad multitasking rule.

**Fix (two attempts)**

1. Set `TARGETED_DEVICE_FAMILY: "1"` (iPhone only) on the iOS app, the widget extension and the tests. On its own this was **not enough**: the same error came back.
2. Also added `UISupportedInterfaceOrientations~ipad` with all four orientations in `project.yml`. iPhones ignore the `~ipad` key, so the app stays portrait-only on iPhone, and validation passes.

**Next time.** For a portrait-only iPhone app, set the device family to iPhone and add the `~ipad` key with all four orientations, before the first upload.

## 6. Xcode keeps changing the string catalogs on your Mac

**Symptom.** `git pull` refused to run. `git status` showed `Resources/Localizable.xcstrings` and `Resources/InfoPlist.xcstrings` as modified, but nobody had edited them.

**Cause.** With the project open, Xcode extracts text from the code into the catalogs, adds entries and re-sorts the file. Half Unit's catalogs are maintained by hand, so these edits are unwanted.

**Fix**

- `Config/Shared.xcconfig` now has `SWIFT_EMIT_LOC_STRINGS = NO`, so Xcode stops extracting.
- If it happens again, close Xcode and discard the edits, then pull:

  ```bash
  cd ~/Desktop/Projects/HalfUnit
  git checkout -- Resources/InfoPlist.xcstrings Resources/Localizable.xcstrings
  git pull
  ./scripts/bootstrap.sh
  ```

## Done in advance, so it never failed

These were set before the first upload. Keep them.

- **Export compliance.** `ITSAppUsesNonExemptEncryption = NO` in the iOS and watch Info.plists. Without it, every build waits in "Missing Compliance" until you answer the encryption question.
- **Version numbers.** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Shared.xcconfig`. Each upload needs a higher build number. Xcode Cloud can also set its own build number: workflow → **Archive** → *Build number*.
- **App IDs and capabilities.** Four App IDs (app, widgets, watch app, watch widgets) with App Groups and iCloud. HealthKit is on the iPhone app only. Push is on the iPhone and watch apps (CloudKit sync needs it).
- **Team ID** lives only in `Config/Local.xcconfig` on the Mac and in `HALFUNIT_TEAM_ID` in Xcode Cloud. It is never committed.

## Still to do after the first upload

- **CloudKit schema → Production.** TestFlight builds use iCloud Production. Run a development build on the iPhone once, then deploy the schema in the CloudKit Console (deploy guide, steps 2–3). Until then, sync between iPhone and Watch does not work in TestFlight builds.
- **For external testers.** Add test information (email, description, privacy policy URL), then submit the build for Beta App Review.

## Checklist for the next app

1. Register the App IDs and capabilities, the App Group and the iCloud container.
2. Create the App Store Connect app record (problem 2).
3. If the project is generated (XcodeGen), add `ci_scripts/ci_post_clone.sh` and the Team ID environment variable (problem 1).
4. Info.plist: a purpose string for every protected API or entitlement, including both Health strings (problem 4), and `ITSAppUsesNonExemptEncryption`.
5. iPhone-only portrait app: device family `1`, plus `~ipad` with all four orientations (problem 5).
6. Xcode Cloud: Archive action, Deployment Preparation **TestFlight and App Store** (problem 3).
7. Deploy the CloudKit schema to Production before testers sync.
