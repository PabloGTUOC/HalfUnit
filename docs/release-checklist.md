# Release Checklist — Half Unit

This document serves as the master release readiness checklist for Half Unit version 1.0.0.

---

## 1. Release Placeholders (Must Be Filled Prior to Launch)

Before publishing documents or submitting to App Store Connect, replace all occurrences of the following template variables:

| Placeholder | Description | Current Location(s) |
|---|---|---|
| `{{OWNER_NAME}}` | Legal name of developer or organization | Privacy Policy, Support Page, App Review Notes |
| `{{CONTACT_EMAIL}}` | Public support and contact email address | Privacy Policy, Support Page, App Review Notes, TestFlight Notes |
| `{{POSTAL_ADDRESS}}` | Full legal postal address (required for German Impressum and EU Trader compliance) | Privacy Policy, Support Page |
| `{{PRIVACY_URL}}` | Public HTTPS URL where the privacy policy is hosted | Privacy Policy, Support Page, App Store Connect |
| `{{SUPPORT_URL}}` | Public HTTPS URL where the support page is hosted | Privacy Policy, Support Page, App Store Connect |

---

## 2. App Store Release Requirements (Day 1)

| Status | Item | Owner | Description / How to Verify |
|:---:|---|---|---|
| [ ] | **Apple Developer Account** | Owner | Apple Developer Program membership active with active signing certificates and provisioning profiles. |
| [ ] | **Bundle Identifiers & Entitlements** | Lead Dev | App IDs configured with HealthKit, App Groups (`group.es.opinasdeque.halfunit`), and CloudKit (`iCloud.es.opinasdeque.halfunit`) capabilities on developer.apple.com. |
| [ ] | **App Store Pricing & Business Model** | Owner | App set to **Free** on App Store Connect. No advertisements, no subscriptions, no in-app purchases, and no third-party commercial SDKs. |
| [ ] | **Online Privacy Policy & Support URLs** | Owner | Deploy `docs/privacy-policy.en.md` (or `.de.md`) and `docs/support.en.md` (or `.de.md`) to public HTTPS URLs (`{{PRIVACY_URL}}` and `{{SUPPORT_URL}}`). Required by Apple for HealthKit integration. |
| [ ] | **App Privacy Questionnaire** | Lead Dev / Owner | Complete questionnaire in App Store Connect as **Data Not Collected** using the guide in `docs/app-store/privacy-label.md`. |
| [ ] | **Age Rating Questionnaire** | Lead Dev / Owner | Complete questionnaire in App Store Connect honestly selecting **Frequent / Intense Alcohol References** resulting in a 17+ rating using `docs/app-store/age-rating.md`. |
| [ ] | **Store Metadata (English & German)** | Owner | Copy text from `docs/app-store/description.en.md` and `docs/app-store/description.de.md` into App Store Connect. Verify character limits: Subtitle ≤ 30, Promo ≤ 170, Description ≤ 4000, Keywords ≤ 100. |
| [ ] | **Store Screenshots** | Designer / Owner | Capture clean screenshots for iPhone (6.9" / 6.7" / 6.5" displays) and Apple Watch (Series / Ultra) in English and German. Do not include misleading BAC or health claims. |
| [ ] | **App Review Notes** | Lead Dev | Provide review instructions from `docs/app-store/app-review-notes.md` detailing how to test without existing data and clarifying write-only HealthKit usage. |
| [ ] | **EU Trader Status Declaration** | Owner | Declare EU trader or non-trader status in App Store Connect in accordance with EU Digital Services Act (DSA) requirements. |
| [ ] | **TestFlight Beta Period** | QA / Testers | Run a closed beta test using `docs/testflight/beta-notes.md` with external testers for at least 2 weeks before public launch. |

---

## 3. Real-Device Acceptance Criteria (MVP Verification)

The following verification steps must be tested on physical hardware (iPhone running iOS 26+ paired with Apple Watch running watchOS 26+):

| Status | Verification Area | Target Device | Step-by-Step Test Procedure | Acceptance Criteria |
|:---:|---|---|---|---|
| [ ] | **1-Tap Wrist Logging** | Apple Watch | Launch Half Unit on Apple Watch and tap any preset button on the 2 × 3 grid. | Tap records drink and delivers immediate haptic confirmation in under 0.3 seconds. |
| [ ] | **Standalone Watch Sync** | Apple Watch + iPhone | Put iPhone into Airplane Mode. Log a drink on Apple Watch. Re-enable iPhone connection. | Watch entry saves locally without error and syncs to iPhone within 1 minute of reconnection. |
| [ ] | **5-Second Undo** | iPhone & Apple Watch | Log a drink on the Today screen. Tap the Undo banner within 5 seconds. | The entry is completely removed from SwiftData store and any created Apple Health sample is deleted. |
| [ ] | **07:00 Day Boundary** | iPhone / Apple Watch | Set device clock to 01:30 AM or log an entry back-dated to 01:30 AM. | Entry is assigned to the previous calendar day's logical day (07:00 to 06:59 boundary); does not start a new drinking day. |
| [ ] | **Alcohol-Free Streak Count** | iPhone | Log a drink on Saturday night. Change device date to Monday morning (no drinks logged Monday). | Headline counter displays exactly "2 days without alcohol". |
| [ ] | **Long-Term Analytics** | iPhone | Load seeded multi-month dataset in test build. Navigate to Insights tab and switch between 7d, 30d, 3m, 12m, and 2y. | Total drinking days, percentage of days, total grams, and heaviest days match expected dataset sums exactly. |
| [ ] | **HealthKit Edit & Delete** | iPhone | Ensure Health sync is enabled. Log a drink. Edit volume/ABV in History. Then delete the drink in History. | Apple Health contains one updated sample (no duplicate), and deleting in Half Unit completely removes the sample from Apple Health. |
| [ ] | **Health Permission Denied** | iPhone | Reinstall app or revoke HealthKit permission in iOS Settings. Use the app normally. | All logging, streaks, history editing, charts, and CSV exports work with zero crashes or blocking alert dialogs. |
| [ ] | **Widgets & Complications** | iPhone & Apple Watch | Add Home Screen widget and Watch complication. Log drinks and advance past 07:00 AM day boundary. | Widget and complication refresh streak immediately after logging and automatically transition at the day boundary. |
| [ ] | **CSV / JSON Export** | iPhone | Go to Settings → Data → Export CSV. Send file to Mac/PC or open locally. | CSV opens cleanly with proper headers, delimiters, and dates in Apple Numbers and Microsoft Excel. |
| [ ] | **Biometric App Lock** | iPhone | Enable Face ID / Passcode lock in Settings. Move app to background and reopen. | iOS authentication prompt appears; contents remain obscured until authentication succeeds. |
| [ ] | **Evening Reminder** | iPhone | Enable evening reminder in Settings at a designated test time. Lock device. | Local notification triggers at scheduled time ("Anything to log today?"); tapping notification opens Half Unit. |

---

## 4. Final Submission Checklist

- [ ] All placeholders replaced in production text and URLs.
- [ ] Code signed with Release configuration and distribution profile.
- [ ] No private or undocumented APIs used.
- [ ] `./scripts/lint.sh` and unit tests pass with zero warnings or errors.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) included in app bundle.
- [ ] TestFlight build validated without warnings in App Store Connect.
