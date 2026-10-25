---
title: Privacy Policy
permalink: /privacy/
lang: en
---

# Privacy Policy — Half Unit

Last updated: October 2026

Half Unit is built from the ground up to respect your personal privacy. We believe that your drinking habits and health data are private matters that belong solely to you. Half Unit operates without user accounts, maintains no remote servers, includes no third-party software development kits (SDKs), runs no advertising networks, and conducts no tracking or telemetry.

This Privacy Policy explains how Half Unit stores and processes information on your devices and within your private iCloud account.

---

## 1. Summary of Data Practices

| Category | Policy in Half Unit |
|---|---|
| **User accounts** | None required and none supported. |
| **Developer servers** | None. We operate no remote servers and have no access to your logs. |
| **Analytics & telemetry** | None. No third-party analytics or crash reporting SDKs. |
| **Advertising & tracking** | None. App Store privacy classification is **Data Not Collected**. |
| **Local storage** | Stored on-device via Apple SwiftData in an App Group container. |
| **Cloud sync** | Via your private Apple iCloud database (CloudKit); encrypted in transit and at rest. |
| **Apple Health** | Optional on iOS: writes logged drinks as Alcoholic Beverages. |
| **App lock** | Optional (off by default): protected via Face ID, Touch ID, or device passcode. |
| **Local reminders** | Optional (off by default): on-device evening reminder; no external push servers. |
| **Data export** | User-initiated CSV and JSON export through the system share sheet. |

---

## 2. Information Storage and iCloud Sync

### Local On-Device Storage
When you log drinks or adjust settings in Half Unit, your entries are saved directly onto your device using Apple's SwiftData framework. The database resides within an Apple App Group container (`group.es.opinasdeque.halfunit`), allowing the iOS application, the Apple Watch application, interactive widgets, and Siri App Shortcuts to access the same local data store safely.

Per-device operational preferences (such as whether onboarding has been completed and whether Apple Health sync is turned on) are saved locally in the App Group `UserDefaults` under required-reason API category `NSPrivacyAccessedAPICategoryUserDefaults` (reason code `1C8F.1`).

### Private iCloud Sync (CloudKit)
If you enable iCloud on your Apple devices, Half Unit synchronizes your drink records and preset configurations between your iPhone and Apple Watch using Apple's CloudKit private database (`iCloud.es.opinasdeque.halfunit`).

- Your data syncs through your private iCloud database. Apple encrypts it in transit and at rest.
- With Advanced Data Protection enabled on your Apple account, this data is end-to-end encrypted.
- The developer cannot access your private CloudKit database, encryption keys, or stored entries.
- Synchronization relies exclusively on Apple's infrastructure.

---

## 3. Apple Health Integration (HealthKit)

On iOS devices, Half Unit offers optional integration with Apple HealthKit.

### What Half Unit Writes
- When enabled by you, Half Unit writes logged drinks to the Apple Health app as samples of `Alcoholic Beverages` (`HKQuantityTypeIdentifier.numberOfAlcoholicBeverages`).
- Drinks are written as standard drink counts, calculated as pure alcohol grams divided by 10 (`grams / 10`), matching Apple Health conventions.
- Each sample includes sync identifiers so edits and deletions made in Half Unit update or remove the corresponding Health sample when the iPhone app next syncs (immediately if the change is made in the open iPhone app; drinks, edits, or deletes logged from the Apple Watch, widgets, or Siri are written when the iPhone app is next opened or brought to the foreground).
- Only the iPhone application writes to Apple Health.

### Limitations and Protections
- In version 1, Half Unit **only writes** data to Apple Health. It does not read alcohol entries from other applications or inspect historical health records.
- HealthKit data is never used for marketing, advertising, or data mining.
- HealthKit data is never transmitted to any third party or external server.
- Apple Health access is completely optional. If you decline or revoke Health permissions, all features of Half Unit continue to operate normally.

---

## 4. Notifications and Device Security

- **Evening Reminder:** You can optionally enable an evening reminder ("Anything to log today?") at a time of your choice. Reminders are optional, off by default, and scheduled locally on your device using Apple's UserNotifications framework. No external notification server is contacted.
- **Biometric App Lock:** You can optionally enable Face ID, Touch ID, or device passcode authentication to open the app. This feature is optional, off by default, and handled entirely by the iOS system (`LocalAuthentication`). Half Unit never accesses or stores your biometric data.

---

## 5. Data Export and Deletion

- **Export:** You can export your complete history at any time as a CSV file or JSON file through the iOS share sheet.
- **Deletions:** When you delete a drink in Half Unit, the entry is marked with a deletion date and removed from active views and statistics. It is removed from Apple Health when the iPhone app next syncs (immediately if deleted in the open iPhone app, or when the iPhone app is next opened if deleted elsewhere). Deleted records are permanently purged after 30 days.
- **App Removal:** Deleting Half Unit from your devices deletes all local application data. You can manage and delete your CloudKit data at any time through your device settings under `Settings > [Your Name] > iCloud > Manage Storage`.

---

## 6. Health and Medical Disclaimer

Half Unit is a personal logging tool for your own use. It is an informational tracking tool designed solely for personal awareness and habit logging. 

- Half Unit is **not a medical device** and does not provide medical advice, diagnosis or treatment. It is not intended to diagnose, treat, cure, or prevent any medical condition or alcohol use disorder.
- If you are worried about your drinking, talk to a doctor or a counselling service.
- The app does not compute blood alcohol concentration (BAC) and does not provide intoxication or safe to drive estimates. Never rely on the app to determine fitness to drive or operate machinery.
- Official low-risk drinking guidelines vary by country. For health guidance and support resources, please consult official public health authorities:
  - Germany: [Kenn dein Limit](https://www.kenn-dein-limit.de)
  - United Kingdom: [NHS Alcohol Advice](https://www.nhs.uk/live-well/alcohol-advice/)

---

## 7. Contact Information

If you have questions about this Privacy Policy or Half Unit, please contact:

- **Developer:** Pablo Gonzalez Torres
- **Email:** pbsitio@gmail.com
- **Postal Address:** 10557 Berlin, Germany
- **Website:** https://pablogtuoc.github.io/HalfUnit/support/
- **Privacy Policy URL:** https://pablogtuoc.github.io/HalfUnit/privacy/
