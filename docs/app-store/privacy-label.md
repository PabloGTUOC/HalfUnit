# App Store Privacy Label Questionnaire Guide — Half Unit

This guide details the exact responses and justifications for completing the **App Privacy** questionnaire in App Store Connect for Half Unit.

---

## 1. Summary Classification

- **App Store Privacy Label:** **Data Not Collected**
- **Tracking:** **No** (The app does not track users across apps and websites owned by other companies).

---

## 2. Tracking Questionnaire

| Question | Answer | Reason / Architecture |
|---|---|---|
| Do you or your third-party partners use data from this app to track users? | **No** | Half Unit includes no third-party SDKs, advertising frameworks, or cross-app tracking identifiers. |

---

## 3. Data Collection Questionnaire

| Question | Answer | Reason / Architecture |
|---|---|---|
| Do you or your third-party partners collect data from this app? | **No** | Under Apple's App Store Review Guidelines, data stored solely on the user's device and inside their personal iCloud account (where the developer has no access to the keys or records) is **not collected by the developer**. |

### Detailed Category Breakdown

| Data Category | App Store Connect Selection | Rationale |
|---|---|---|
| **Health & Fitness** (Health, Fitness) | **Not Collected** | Drink logs and alcohol records are stored locally on the device in SwiftData and optionally mirrored to Apple Health via HealthKit. Half Unit does not collect, transmit, or store this data on developer servers. Apple guidelines state that data stored strictly on-device or within Apple HealthKit is not considered collected by the developer. |
| **Contact Info** (Name, Email, Phone, Address) | **Not Collected** | No user registration, no account creation, and no contact collection. |
| **Financial Info** (Payment Info, Credit Info) | **Not Collected** | Half Unit is completely free with no subscriptions, in-app purchases, or payment processing. |
| **Location** (Precise / Coarse Location) | **Not Collected** | Version 1 does not request location permissions and does not record location coordinates. |
| **Sensitive Info** (Racial, Religious, Sexual, Biometric) | **Not Collected** | Biometric authentication (Face ID / Touch ID) is managed exclusively by the iOS `LocalAuthentication` framework on-device. The app receives only a boolean success/failure signal; biometric data never leaves the Secure Enclave. |
| **Contacts** | **Not Collected** | No access to the user's address book or contacts. |
| **User Content** (Emails, Texts, Photos, Audio, Drink Notes) | **Not Collected** | Optional user drink notes and custom presets remain stored locally and inside the user's private iCloud database (CloudKit). The developer cannot read or access this data. |
| **Browsing History** | **Not Collected** | No in-app web browser; external links open in the system default browser. |
| **Search History** | **Not Collected** | Search within History operates locally on the device store; no search terms are transmitted. |
| **Identifiers** (User ID, Device ID) | **Not Collected** | No user identifiers are generated or collected. Drink UUIDs are random identifiers stored locally and used for HealthKit synchronization. |
| **Purchases** | **Not Collected** | The app is free with no in-app purchases. |
| **Usage Data** (Product Interaction, Advertising Data) | **Not Collected** | No analytics SDKs (e.g., Firebase, Mixpanel, Amplitude) are bundled with the app. |
| **Diagnostics** (Crash Data, Performance Data) | **Not Collected** | No third-party crash reporters (e.g., Sentry, Crashlytics). Apple's built-in, opt-in developer crash logs are handled directly by Apple and do not constitute developer data collection under the privacy label. |
| **Other Data** | **Not Collected** | No other data is gathered. |

---

## 4. Privacy Manifest & Required Reason APIs

Half Unit includes a valid `PrivacyInfo.xcprivacy` manifest in its bundle complying with Apple's API privacy requirements:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>1C8F.1</string>
			</array>
		</dict>
	</array>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
</dict>
</plist>
```

### Justification for Declared Reason Code
- **API Category:** `NSPrivacyAccessedAPICategoryUserDefaults`
- **Reason Code:** `1C8F.1` ("Access user defaults to read and write information that is only accessible to the app itself, or by members of the same app group.")
- **Purpose:** Used strictly to read and store per-device operational preferences (such as onboarding completion and Apple Health sync on/off toggles) within the shared App Group (`group.es.opinasdeque.halfunit`).
