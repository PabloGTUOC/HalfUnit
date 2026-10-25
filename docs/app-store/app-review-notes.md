# App Review Notes — Half Unit

Thank you for reviewing Half Unit! Below is essential information to help you review and test the application quickly and thoroughly.

---

## 1. Authentication & Account Requirements

- **No login or account required:** Half Unit does not require registration, login credentials, or third-party sign-in.
- **Immediate access:** Launching the app presents a brief 3-screen onboarding sequence explaining the unit system and offering optional HealthKit setup, after which all app features are immediately accessible.
- **Medical & personal-use disclaimer:** A clear "Not medical advice" disclaimer stating that the app is for personal use only and provides no medical advice or treatment is shown on the first onboarding screen and in Settings → About.

---

## 2. HealthKit Permission & Usage Explanation

### Purpose of HealthKit Write Permission
Half Unit requests write access for `HKQuantityTypeIdentifier.numberOfAlcoholicBeverages`.
- **Why access is needed:** When the user logs an alcoholic drink in Half Unit, the app can mirror the entry to Apple Health as a sample of `Alcoholic Beverages`, converted into standard drinks (`pure alcohol grams / 10`). This allows the user's Health database to stay up to date with their logging.
- **Write-only in version 1:** Half Unit requests write access only (`NSHealthUpdateUsageDescription`). It does not read health records or drinks logged by third-party applications.
- **Strictly optional:** HealthKit integration is 100% optional. If the user taps "Not Now" in onboarding or denies permission in the iOS system prompt, all other features of Half Unit (drink logging, streak counting, period analytics, presets customization, and CSV export) continue to work normally without restriction or error banners.
- **Sync timing:** The iPhone app is the sole writer to Apple Health. Changes made in the open iPhone app reach HealthKit immediately; changes originating from the Apple Watch, widgets, or Siri are written to HealthKit when the iPhone app is next opened or brought to the foreground.

---

## 3. Step-by-Step Testing Guide (Testing Without Pre-existing Data)

### A. First Launch & Onboarding
1. Install and open the app on iPhone.
2. Step through the 3 onboarding screens:
   - Screen 1: Explanation of Half Units (HU) and pure alcohol grams.
   - Screen 2: Review or hide default drink presets.
   - Screen 3: Optional Apple Health setup. You can either tap "Allow Apple Health" to test HealthKit writing or tap "Not Now" to test full functionality without Health permissions.

### B. Quick Logging & 5-Second Undo
1. On the **Today** tab, tap any preset button (e.g., "Beer, 1 HU").
2. Notice the immediate tactile haptic response and the appearance of a 5-second **Undo** banner at the bottom of the screen.
3. If you tap **Undo**, the drink is removed immediately from the local database, and removed from Apple Health when the iPhone app next syncs (immediately while the iPhone app is open).
4. Tap a preset again to record a drink. Notice the headline counter updates to show today's consumption.

### C. History & Editing
1. Switch to the **History** tab.
2. The logged drink is listed under today's logical date.
3. Tap the entry to edit details (timestamp, preset, volume, ABV, or note), or swipe left to delete the entry.
4. If Apple Health permission was granted, changes synchronize to the Apple Health app (immediately while the iPhone app is open, or upon next opening if logged via Watch, widgets, or Siri).

### D. Insights & Analytics
1. Switch to the **Insights** tab.
2. Test the period selectors: **7 d**, **30 d**, **3 m**, **12 m**, and **2 y**.
3. View the drinking-days count (e.g., "1 of 1 tracked days"), calendar heatmap, and weekly charts.

### E. Settings & Data Export
1. Tap the gear icon in the top right corner of the **Today** tab to open **Settings**.
2. Customize preset details, change the day-boundary hour, or switch the display unit (HU, grams, German standard drinks, UK units). Optional Face ID lock and optional evening reminder can also be configured here (both off by default).
3. Under the **Data** section, tap **Export CSV** to open the system share sheet and review the exported spreadsheet file.

### F. Standalone Apple Watch App
1. Open Half Unit on Apple Watch.
2. The watch app functions completely standalone. Tap any preset button on the 2 × 3 grid to log a drink with tactile confirmation.
3. If the companion iPhone is offline or unreachable, the entry is saved to the local watch store and syncs automatically via CloudKit and WatchConnectivity once connected.

### G. Widgets & Complications
1. Add the **Half Unit** widget to the iOS Home Screen (available in Small and Medium sizes).
2. The Medium widget includes interactive preset buttons allowing 1-tap logging directly from the Home Screen.
3. Add the Half Unit streak complication to an Apple Watch face to view current alcohol-free days.

### H. Siri & App Shortcuts
1. Activate Siri and say:
   - *"Log a beer in Half Unit"*
   - *"Days without alcohol in Half Unit"*

---

## 4. Reviewer Contact Information

If you have any questions or require additional details during review, please contact:

- **Contact Person:** Pablo Gonzalez Torres
- **Email:** [pbsitio@gmail.com](mailto:pbsitio@gmail.com)
