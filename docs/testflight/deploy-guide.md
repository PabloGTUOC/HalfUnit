# TestFlight deployment guide

Simple steps for the owner to put a Half Unit build on TestFlight. Do them in order.
Done once already: App IDs, App Group, iCloud container and the App Store Connect app record.

## 1. Get the latest code (every time)

In Terminal:

```bash
cd ~/Desktop/Projects/HalfUnit
git pull
./scripts/bootstrap.sh
open HalfUnit.xcodeproj
```

`Config/Local.xcconfig` must contain `DEVELOPMENT_TEAM = 63CZCUTA77` (it is git-ignored and already set on this Mac).

## 2. First time only: run on your own iPhone

This creates the iCloud data structure (CloudKit schema) that step 3 publishes.

1. Connect the iPhone with a cable. If asked, tap **Trust** on the iPhone, and turn on **Settings → Privacy & Security → Developer Mode** (the iPhone restarts).
2. In Xcode, top bar: scheme **HalfUnit**, destination **your iPhone**. Press **▶ Run**.
3. On the iPhone (signed in to iCloud), in Half Unit:
   - finish onboarding,
   - log one drink,
   - in Settings, change one preset (for example its name) and one setting (for example the display unit).
4. Leave the app open for about a minute so it syncs to iCloud.

## 3. First time only: publish the iCloud schema to Production

TestFlight and App Store builds use iCloud **Production**. Without this step, sync doesn't work for testers.

1. Open <https://icloud.developer.apple.com> → **CloudKit Database** → container `iCloud.es.opinasdeque.halfunit`.
2. Environment **Development** → **Record Types**: check that `CD_Drink`, `CD_Preset` and `CD_AppSettings` are there. If not, repeat step 2.
3. Click **Deploy Schema Changes…** → **Deploy**.

Repeat this only when a future version changes the data model (the lead will tell you).

## 4. Archive

1. In Xcode, destination **Any iOS Device (arm64)** (not a simulator, not your iPhone).
2. Menu **Product → Archive**. Wait for the Organizer window to open (a few minutes).

## 5. Upload

1. In the Organizer, select the new archive → **Distribute App**.
2. Choose **TestFlight Internal Only** → **Distribute**. Keep the default options (automatic signing).
3. Wait for "Upload successful".

## 6. Wait for processing

You get an email from App Store Connect when the build is processed (usually 10–30 minutes).
The build appears in <https://appstoreconnect.apple.com> → **Apps → Half Unit → TestFlight**.

## 7. Add yourself as tester (first time only)

1. TestFlight tab → **Internal Testing** → **+** → create a group, e.g. "Owner".
2. Add yourself as tester and add the build to the group.

## 8. Install

1. On the iPhone, install the **TestFlight** app from the App Store and sign in with the same Apple ID.
2. Open the invitation (email or TestFlight app) → **Install**.
3. Apple Watch: open the **Watch** app on the iPhone → Half Unit → **Install**, if it isn't installed automatically.

The TestFlight build uses iCloud Production, so it starts empty: drinks logged with the Xcode build in step 2 do not appear.

## 9. Quick check

- Log a drink on the iPhone and on the Watch; both appear on both devices (Watch → iPhone can take up to a minute).
- Undo works; the Home Screen widget updates after a tap.
- Apple Health (if allowed): Health app → Browse → Other Data → **Alcoholic Beverages** shows the drink.
- Settings → About shows "Not medical advice".

## Next builds

Each upload needs a higher build number. Ask the lead to bump `CURRENT_PROJECT_VERSION` in `Config/Shared.xcconfig`, then repeat steps 1, 4, 5, 6 and 8.

## If something fails

| Message | What to do |
|---|---|
| "No profiles for … were found" / signing error | Xcode → Settings → Accounts: make sure your Apple ID is signed in and the team is listed; then retry. |
| "The bundle version must be higher than the previously uploaded version" | Ask the lead to bump the build number. |
| Upload works but the build shows "Missing Compliance" | Answer "None of the algorithms mentioned above" once; the app already declares it uses no custom encryption. |
| iPhone and Watch don't sync in the TestFlight build | Step 3 was skipped or done before step 2 created all record types; redo steps 2 and 3. |
| Anything else | Copy the exact error text and send it to the lead. |
