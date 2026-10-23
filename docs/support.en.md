# Support & FAQ — Half Unit

Welcome to the Half Unit support page. Half Unit is a native iPhone and Apple Watch app designed for quick, one-tap drink logging and honest awareness of your alcohol-free days.

If you have questions, encounter an issue, or want to share suggestions, we are here to help.

---

## Contact & Support

- **Developer:** {{OWNER_NAME}}
- **Email Support:** [{{CONTACT_EMAIL}}](mailto:{{CONTACT_EMAIL}})
- **Support Website:** {{SUPPORT_URL}}
- **Privacy Policy:** [{{PRIVACY_URL}}]({{PRIVACY_URL}})
- **Postal Address:** {{POSTAL_ADDRESS}}

When emailing for support, please include your device model, iOS/watchOS version, and the Half Unit version (found in Settings → About).

---

## Frequently Asked Questions

### 1. What is a "Half Unit" (HU)?
Half Unit uses a straightforward scale in steps of 0.5 HU:
- **0.5 HU** is approximately 10 grams of pure alcohol (equivalent to a standard drink in Germany and WHO guidelines).
- **1.0 HU** is approximately 20 grams of pure alcohol (such as a standard 0.5 l beer at 5% ABV).

Behind every entry, Half Unit calculates and stores the exact grams of pure alcohol based on volume and alcohol by volume (`volume in ml × ABV% × 0.8`). You can change your preferred display unit anytime in Settings to HU, pure grams, German standard drinks (10 g), or UK units (8 g).

### 2. What are the default presets?
Half Unit launches with 6 ready-to-use presets:
1. **Small beer** (0.25–0.33 l, 5% ABV) = 0.5 HU
2. **Small wine** (0.1–0.125 l, 12% ABV) = 0.5 HU
3. **Beer** (0.5 l, 5% ABV) = 1 HU
4. **Wine glass** (0.2 l, 12% ABV) = 1 HU
5. **Shot** (4 cl, 40% ABV) = 1 HU
6. **Long drink / double** (8 cl spirit, 40% ABV) = 2 HU

You can reorder, hide, edit, or add custom presets in Settings.

### 3. How does the day boundary (07:00) work?
In Half Unit, a "logical day" starts at 07:00 and ends at 06:59 the following morning. If you log a drink at 01:30 AM during a social evening, it is counted as part of the previous evening's drinking day. This ensures a late night out is never erroneously counted as two separate drinking days. You can adjust the boundary hour in Settings.

### 4. How are "days without alcohol" calculated?
Your headline counter shows consecutive alcohol-free logical days. For example, if your last drink was on Saturday evening and today is Monday, the app displays 2 days without alcohol. Today counts as alcohol-free until a drink is logged. If you log a drink today, the counter displays "Today" alongside your previous streak.

### 5. Does the Apple Watch app work without my iPhone?
Yes. The Apple Watch app operates completely standalone. You can log drinks on your wrist with a single tap even when your phone is turned off or not nearby. When the devices reconnect, your entries synchronize automatically through your private iCloud database and WatchConnectivity.

### 6. How does Apple Health integration work?
On iPhone, Half Unit can mirror your logged drinks to Apple Health as `Alcoholic Beverages` samples. Entries are converted to standard drink counts (`grams / 10`). When you edit or delete a drink in Half Unit, the corresponding Apple Health entry is updated or removed when the iPhone app next syncs (immediately if the iPhone app is open, or when it is next opened if changes were made on Apple Watch, widgets, or Siri). Apple Health integration is optional and write-only; Half Unit does not read personal records or data from other apps.

### 7. Can I export my data?
Yes. In Settings → Data, you can export your entire drink history as a CSV spreadsheet (compatible with Apple Numbers, Microsoft Excel, and Google Sheets) or generate a JSON data file for data restore.

### 8. Is my data private?
Completely. Half Unit requires no account registration, runs no developer servers, and includes no third-party analytics or advertising SDKs. Your data resides on your devices and syncs through your personal, private Apple iCloud account (CloudKit), encrypted in transit and at rest (and end-to-end encrypted with Advanced Data Protection). Optional security features, including Face ID / passcode lock and an evening reminder, are available in Settings (both optional and off by default).

---

## Health and Medical Disclaimer

Half Unit is a personal logging tool for your own use. It is an informational tool for tracking personal consumption and mindful awareness.

- Half Unit is **not a medical device** and does not provide medical advice, diagnosis or treatment. It is not designed to diagnose, treat, cure, or prevent any illness or alcohol use disorder.
- If you are worried about your drinking, talk to a doctor or a counselling service.
- The app does not measure blood alcohol concentration (BAC) and does not provide intoxication or safe to drive estimates. Never use the app to decide whether it is safe to operate a vehicle.
- Official guidelines for low-risk alcohol consumption vary by country. For health advice and official resources, please visit:
  - Germany: [Kenn dein Limit](https://www.kenn-dein-limit.de)
  - United Kingdom: [NHS Alcohol Advice](https://www.nhs.uk/live-well/alcohol-advice/)
