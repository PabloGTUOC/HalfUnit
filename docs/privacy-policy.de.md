# Datenschutzerklärung — Half Unit

Stand: Oktober 2026

Der Schutz Ihrer Privatsphäre ist für Half Unit ein zentrales Leitprinzip. Wir sind davon überzeugt, dass persönliche Konsum- und Gesundheitsdaten ausschließlich Ihnen gehören. Half Unit verzichtet vollständig auf Benutzerkonten, unterhält keine eigenen Server, bindet keine Software-Entwicklungskits (SDKs) von Drittanbietern ein, nutzt keine Werbenetzwerke und führt keinerlei Nutzer-Tracking oder Telemetrieerfassung durch.

Diese Datenschutzerklärung erläutert, wie Half Unit Daten auf Ihren Geräten sowie in Ihrem persönlichen iCloud-Konto verarbeitet und schützt.

---

## 1. Übersicht der Datenschutzpraktiken

| Bereich | Umsetzung in Half Unit |
|---|---|
| **Benutzerkonten** | Keine Registrierung und kein Konto erforderlich. |
| **Entwicklerserver** | Keine vorhanden. Wir betreiben keine Server und haben keinen Zugriff auf Ihre Einträge. |
| **Analyse & Telemetrie** | Keine Drittanbieter-Analyse oder Absturzmelder integriert. |
| **Werbung & Tracking** | Keine Werbung, kein Tracking. Im App Store eingestuft als **Data Not Collected** (Keine Datenerfassung). |
| **Lokale Speicherung** | Gespeichert auf dem Gerät via Apple SwiftData in einem sicheren App-Group-Container. |
| **Cloud-Synchronisation** | Über Ihre private Apple iCloud-Datenbank (CloudKit); verschlüsselt bei der Übertragung und auf den Servern. |
| **Apple Health** | Optional auf iOS: schreibt protokollierte Getränke als „Alkoholische Getränke“. |
| **App-Sperre** | Optional (standardmäßig aus): Schutz per Face ID, Touch ID oder Gerätecode. |
| **Lokale Erinnerungen** | Optional (standardmäßig aus): auf dem Gerät gesteuerte Abenderinnerung; keine externen Push-Dienste. |
| **Datenexport** | Durch Sie initiierter CSV- und JSON-Export über das iOS-Freigabemenü. |

---

## 2. Speicherung auf Ihren Geräten und iCloud-Synchronisation

### Lokale Speicherung
Wenn Sie Getränke eintragen oder Einstellungen anpassen, werden diese Daten direkt auf Ihrem Gerät mit Apples SwiftData-Framework gespeichert. Die Datenbank befindet sich in einem gemeinsamen App-Group-Container (`group.es.opinasdeque.halfunit`), wodurch die iOS-App, die Apple Watch-App, interaktive Widgets und Siri-Kurzbefehle sicher auf dieselben lokalen Daten zugreifen können.

Gerätespezifische Voreinstellungen (wie der Abschluss des Einführungsvorgangs oder der Status der Apple Health-Synchronisation) werden lokal im App-Group-`UserDefaults`-Speicher unter der API-Kategorie `NSPrivacyAccessedAPICategoryUserDefaults` (Grund `1C8F.1`) hinterlegt.

### Private iCloud-Synchronisation (CloudKit)
Sofern iCloud auf Ihren Apple-Geräten aktiviert ist, synchronisiert Half Unit Ihre Einträge und Voreinstellungen zwischen Ihrem iPhone und Ihrer Apple Watch über die private CloudKit-Datenbank Ihres persönlichen Apple-Accounts (`iCloud.es.opinasdeque.halfunit`).

- Ihre Daten werden über Ihre private iCloud-Datenbank synchronisiert. Apple verschlüsselt die Daten bei der Übertragung und auf den Servern (in transit und at rest).
- Bei aktiviertem Erweiterten Datenschutz (Advanced Data Protection) in Ihrem Apple-Konto sind diese Daten Ende-zu-Ende verschlüsselt.
- Der Entwickler hat zu keinem Zeitpunkt Zugriff auf Ihre private CloudKit-Datenbank, Ihre Schlüssel oder Ihre Einträge.
- Die Synchronisation erfolgt ausschließlich über die offizielle Infrastruktur von Apple.

---

## 3. Integration von Apple Health (HealthKit)

Auf iOS-Geräten bietet Half Unit eine freiwillige Anbindung an Apple HealthKit.

### Schreibzugriff durch Half Unit
- Wenn Sie die Synchronisation aktivieren, überträgt Half Unit protokollierte Getränke als Datenpunkte der Kategorie `Alkoholische Getränke` (`HKQuantityTypeIdentifier.numberOfAlcoholicBeverages`) an Apple Health.
- Die Speicherung erfolgt in Standardgetränken, berechnet aus Gramm reinem Alkohol geteilt durch 10 (`Gramm / 10`), passend zur Konvention von Apple Health.
- Jeder Datenpunkt enthält eine eindeutige Kennung, sodass nachträgliche Bearbeitungen oder Löschungen in Half Unit den Eintrag in Apple Health aktualisieren oder entfernen, sobald die iPhone-App das nächste Mal synchronisiert (sofort, wenn die Änderung in der geöffneten iPhone-App vorgenommen wird; Einträge, Änderungen oder Löschungen von der Apple Watch, über Widgets oder Siri werden übertragen, sobald die iPhone-App das nächste Mal geöffnet oder in den Vordergrund gebracht wird).
- Ausschließlich die iPhone-App führt Schreibvorgänge in Apple Health durch.

### Schutz Ihrer Gesundheitsdaten
- In Version 1 führt Half Unit **ausschließlich Schreibvorgänge** in Apple Health durch. Es werden keine Daten aus Apple Health oder von Drittanbieter-Apps ausgelesen.
- Gesundheitsdaten werden niemals für Marketing, Werbezwecke oder Profilbildung verwendet.
- Gesundheitsdaten werden niemals an Dritte oder externe Empfänger weitergegeben.
- Die Anbindung an Apple Health ist vollständig optional. Falls Sie die Berechtigung verweigern oder widerrufen, bleiben alle übrigen Funktionen der App vollständig nutzbar.

---

## 4. Mitteilungen und Gerätesicherheit

- **Abenderinnerung:** Sie können eine tägliche Erinnerung aktivieren („Heute etwas zu protokollieren?“). Diese Funktion ist optional, standardmäßig ausgeschaltet und wird ausschließlich lokal über das UserNotifications-Framework Ihres Betriebssystems geplant. Es erfolgt keine Verbindung zu externen Servern.
- **Biometrische App-Sperre:** Sie können die App mit Face ID, Touch ID oder Ihrem Gerätecode absichern. Diese Funktion ist optional, standardmäßig ausgeschaltet und erfolgt vollständig über das iOS-System (`LocalAuthentication`). Half Unit erhält zu keinem Zeitpunkt Zugriff auf biometrische Merkmale.

---

## 5. Datenexport und Löschung

- **Export:** Sie können Ihre Daten jederzeit als CSV-Datei oder JSON-Datei über das Freigabemenü exportieren.
- **Löschen von Einträgen:** Löschen Sie einen Eintrag in Half Unit, wird dieser sofort aus den aktiven Ansichten und Statistiken ausgeblendet. Er wird bei der nächsten Synchronisation der iPhone-App aus Apple Health entfernt (sofort, wenn das Löschen in der geöffneten iPhone-App vorgenommen wird, oder beim nächsten Öffnen der iPhone-App, falls die Änderung von einem anderen Gerät stammte). Nach 30 Tagen werden gelöschte Datensätze endgültig bereinigt.
- **Löschen der App:** Durch das Entfernen von Half Unit von Ihren Geräten werden alle lokalen Daten gelöscht. Ihre CloudKit-Daten können Sie jederzeit in den Einstellungen Ihres Apple-Geräts unter `Einstellungen > [Ihr Name] > iCloud > Speicher verwalten` löschen.

---

## 6. Gesundheitshinweis und Haftungsausschluss

Half Unit ist ein Werkzeug zum Protokollieren, nur für Ihren persönlichen Gebrauch. Die App ist ein Dokumentationswerkzeug zur Förderung der persönlichen Achtsamkeit und zum Protokollieren von Gewohnheiten.

- Half Unit ist **kein Medizinprodukt** und bietet keine medizinische Beratung, Diagnose oder Behandlung. Die App ist nicht dafür bestimmt und eignet sich nicht dafür, Krankheiten oder Alkoholabhängigkeit zu diagnostizieren, zu behandeln, zu lindern oder zu heilen (does not diagnose, treat, or cure).
- Wenn Sie sich Sorgen um Ihren Alkoholkonsum machen, sprechen Sie mit einer Ärztin, einem Arzt oder einer Beratungsstelle.
- Die App ermittelt keine Blutalkoholkonzentration (BAK / blood alcohol concentration) und gibt keine Einschätzungen zur Fahrtüchtigkeit (safe to drive) ab. Verlassen Sie sich niemals auf die App, um Ihre Fahrtüchtigkeit oder die Eignung zum Bedienen von Maschinen zu beurteilen.
- Offizielle Empfehlungen für risikoarmen Alkoholkonsum variieren je nach Land. Für fundierte Gesundheitsinformationen und Beratungsangebote verweisen wir auf öffentliche Stellen:
  - Deutschland: [Kenn dein Limit (BZgA)](https://www.kenn-dein-limit.de)
  - Vereinigtes Königreich: [NHS Alcohol Advice](https://www.nhs.uk/live-well/alcohol-advice/)

---

## 7. Kontakt und Impressum

Bei Fragen zu dieser Datenschutzerklärung oder zu Half Unit wenden Sie sich bitte an:

- **Verantwortlicher:** {{OWNER_NAME}}
- **E-Mail:** {{CONTACT_EMAIL}}
- **Postanschrift:** {{POSTAL_ADDRESS}}
- **Support-Website:** {{SUPPORT_URL}}
- **Datenschutz-URL:** {{PRIVACY_URL}}
