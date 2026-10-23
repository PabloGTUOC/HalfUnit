# TestFlight Beta Notes — Half Unit

Welcome to the Half Unit beta testing program! Thank you for helping us test Half Unit on iPhone and Apple Watch.

Below are testing guides and focus areas in English and German.

---

# English (en-US / en-GB)

## Welcome to the Half Unit Beta
Half Unit is a native iPhone and Apple Watch app designed for quick, 1-tap drink logging and honest awareness of your alcohol-free days. Everything is private by design: no user accounts, no ads, no trackers, and all data lives on your devices and in your private iCloud.

Please test the following key features and let us know if anything behaves unexpectedly.

## What to Test

### 1. One-Tap Logging & 5-Second Undo
- Tap any of the 6 preset buttons on the **Today** screen (Beer, Wine, Shot, etc.).
- Verify the tactile haptic response feels immediate.
- Check that a 5-second **Undo** banner appears at the bottom. Tap **Undo** to verify the drink is immediately removed from the counter and list.
- Long-press any preset button to test logging a drink for an earlier time or earlier date.

### 2. Standalone Apple Watch App
- Open Half Unit on your Apple Watch.
- Test logging drinks directly from the 2 × 3 grid on your wrist.
- Try logging while your iPhone is in Airplane Mode or turned off. Verify the watch logs immediately, and check that entries sync to your iPhone once reconnected.

### 3. Day-Boundary Behavior (07:00 AM)
- Half Unit uses a 07:00 AM day boundary.
- If you log a drink late at night (e.g., at 01:30 AM or 02:00 AM), verify that it is recorded under the *previous evening's* date, rather than counting as a new drinking day.
- Test changing the boundary hour in Settings → Day Boundary.

### 4. Alcohol-Free Days & Streaks
- Check the headline counter on the **Today** screen.
- On days where no drinks have been logged, verify that today counts as alcohol-free.
- When you log a drink, verify that the counter switches to "Today" and displays your previous streak length.
- Review your longest streak ever and longest streak this year on the **Insights** screen.

### 5. Apple Health Synchronization
- In Settings → Apple Health, ensure Health sync is enabled (write permission granted for "Alcoholic Beverages").
- Open Apple's Health app and inspect the `Alcoholic Beverages` category:
  - Verify that each drink appears as a standard drink count (`pure alcohol grams / 10`).
  - Edit or delete a drink in Half Unit and verify that the corresponding sample in Apple Health updates or disappears.
  - Test using the app with Health permissions turned off to confirm that the app functions normally without sync.

### 6. Widgets & Watch Complications
- Add the Half Unit widget to your iPhone Home Screen (Small or Medium). Test the interactive preset buttons on the Medium widget.
- Add the Half Unit streak complication to your Apple Watch face and confirm the streak number matches the app.

### 7. Insights & History
- Explore the **Insights** tab across different periods: 7 days, 30 days, 3 months, 12 months, and 2 years.
- Verify the calendar heatmap and weekly bar chart render smoothly in both Light Mode and Dark Mode.
- On the **History** tab, test searching for drinks by name or notes, editing drink properties, and swiping to delete.

### 8. Data Export and Restore
- Open Settings → Data and tap **Export CSV**. Open the exported file in Apple Numbers or Microsoft Excel to verify column headers, dates, and values.
- Tap **Export JSON** to export your full dataset, and verify that the restore workflow functions as expected.

## Submitting Beta Reports
- Use the standard TestFlight beta reporting feature (take a screenshot and tap "Share Feedback").
- Or email us directly at: [{{CONTACT_EMAIL}}](mailto:{{CONTACT_EMAIL}}) with your device model and iOS/watchOS version.

---

# Deutsch (de-DE)

## Willkommen beim Half Unit Betatest
Vielen Dank, dass Sie Half Unit auf Ihrem iPhone und Ihrer Apple Watch testen! Half Unit wurde für schnelles Protokollieren mit einem Fingertipp und ehrliche Transparenz über alkoholfreie Tage entwickelt. Datenschutz steht an erster Stelle: keine Benutzerkonten, keine Werbung, kein Tracking und alle Daten verbleiben auf Ihren Geräten und in Ihrer privaten iCloud.

Bitte testen Sie die folgenden Kernbereiche und teilen Sie uns Auffälligkeiten oder Verbesserungsvorschläge mit.

## Was Sie testen sollten

### 1. Schnelles Protokollieren mit 1 Fingertipp & 5-Sekunden-Rückgängig
- Tippen Sie auf der Ansicht **Heute** auf eine der 6 Vorlagen (Bier, Wein, Schnaps usw.).
- Prüfen Sie, ob die haptische Bestätigung unmittelbar erfolgt.
- Achten Sie auf das 5-Sekunden-Banner **Rückgängig**. Ein Fingertipp darauf sollte den Eintrag sofort wieder aus der Liste und dem Zähler entfernen.
- Halten Sie eine Vorlage gedrückt, um ein Getränk für einen früheren Zeitpunkt des Abends oder Vortags einzutragen.

### 2. Eigenständige Apple Watch-App
- Öffnen Sie Half Unit auf der Apple Watch.
- Protokollieren Sie Getränke direkt über das 2 × 3 Raster am Handgelenk.
- Testen Sie das Eintragen im Flugmodus oder wenn das iPhone ausgeschaltet ist. Der Eintrag sollte lokal auf der Watch gespeichert werden und automatisch mit dem iPhone synchronisieren, sobald wieder eine Verbindung besteht.

### 3. Tagesgrenze (07:00 Uhr morgens)
- Standardmäßig endet ein logischer Tag um 07:00 Uhr morgens.
- Wenn Sie nachts (z. B. um 01:30 Uhr) ein Getränk eintragen, prüfen Sie, ob es dem *Vorabend* zugeordnet wird, damit eine Ausgehnacht nicht als zwei Trinktage gewertet wird.
- Testen Sie das Anpassen der Tagesgrenze unter Einstellungen → Tagesgrenze.

### 4. Alkoholfreie Tage & Serien
- Überprüfen Sie den Zähler für alkoholfreie Tage auf der Ansicht **Heute**.
- An Tagen ohne Einträge zählt der heutige Tag als alkoholfrei.
- Sobald Sie ein Getränk erfassen, wechselt die Anzeige auf „Heute“ und zeigt die vorherige Serie an.
- Prüfen Sie unter **Trends** Ihre längste Serie aller Zeiten und die längste Serie dieses Jahres.

### 5. Synchronisation mit Apple Health
- Aktivieren Sie unter Einstellungen → Apple Health die Synchronisation (Schreibberechtigung für „Alkoholische Getränke“).
- Öffnen Sie Apples Health-App und prüfen Sie die Kategorie `Alkoholische Getränke`:
  - Jeder Eintrag sollte als Standardglas erfasst werden (`Gramm reiner Alkohol / 10`).
  - Bearbeiten oder löschen Sie einen Eintrag in Half Unit und prüfen Sie, ob der Eintrag in Apple Health aktualisiert oder gelöscht wird.
  - Prüfen Sie die App auch mit deaktivierter Health-Berechtigung: Alle übrigen Funktionen müssen fehlerfrei weiterlaufen.

### 6. Widgets & Apple Watch-Komplikationen
- Fügen Sie das Half Unit-Widget zu Ihrem iPhone Home-Bildschirm hinzu (Klein oder Mittel). Testen Sie die interaktiven Tasten auf dem mittleren Widget.
- Fügen Sie die Half Unit-Komplikation zu Ihrem Apple Watch-Zifferblatt hinzu und prüfen Sie, ob die Zahl der alkoholfreien Tage übereinstimmt.

### 7. Trends & Verlauf
- Wechseln Sie zum Reiter **Trends** und testen Sie die Zeiträume: 7 Tage, 30 Tage, 3 Monate, 12 Monate und 2 Jahre.
- Überprüfen Sie die Darstellung der Kalender-Heatmap und des wöchentlichen Balkendiagramms im Hell- und Dunkelmodus.
- Testen Sie im Reiter **Verlauf** das Suchen, Bearbeiten und Löschen per Wischgeste.

### 8. Datenexport und Wiederherstellung
- Gehen Sie zu Einstellungen → Daten und wählen Sie **CSV exportieren**. Öffnen Sie die Datei in Apple Numbers oder Microsoft Excel, um Spalten und Werte zu kontrollieren.
- Testen Sie **JSON-Export**, um Ihre Daten zu sichern oder wiederherzustellen.

## Rückmeldungen einreichen
- Nutzen Sie die TestFlight-Funktion für Beta-Berichte (Screenshot erstellen und auf „Beta-Feedback teilen“ tippen).
- Oder schreiben Sie uns direkt per E-Mail an: [{{CONTACT_EMAIL}}](mailto:{{CONTACT_EMAIL}}) unter Angabe Ihres Gerätemodells und Ihrer Betriebssystemversion.
