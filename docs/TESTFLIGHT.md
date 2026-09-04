# TestFlight

Wie ein Build auf die Geräte der Tester kommt. Stand 2026-08-21; die
Repo-Seite ist vorbereitet, die mit **(Maurice)** markierten Schritte brauchen
den Apple-Account und passieren genau einmal.

## Einmalige Einrichtung

1. **(Maurice)** Apple Developer Program aktiv? Der Account hinter
   `de.mauricejobst` muss zahlendes Mitglied sein (99 €/Jahr), sonst gibt es
   kein App Store Connect.
2. **(Maurice)** Xcode → Settings → Accounts: mit der Apple-ID anmelden. Ohne
   das gibt es keine Signing-Identität auf dieser Maschine
   (`security find-identity -v -p codesigning` listet aktuell **0**).
3. **(Maurice)** Team-ID (10 Zeichen, unter developer.apple.com → Membership)
   in `Config/Secrets.xcconfig` eintragen:
   `BEMBEL_TEAM_ID = XXXXXXXXXX`. Die Datei ist gitignored; die Team-ID am
   besten zusätzlich als 1Password-Item ablegen (sie ist nicht geheim, aber
   so übersteht sie den nächsten Mac-Reset).
4. **(Maurice)** In App Store Connect → Apps → „+“ eine neue App anlegen:
   - Bundle ID `de.mauricejobst.bembel` (explicit; Xcode legt die App-ID
     beim ersten signierten Archiv per `-allowProvisioningUpdates` selbst an,
     sonst vorher unter Identifiers registrieren — inklusive der
     App-Group `group.de.mauricejobst.bembel` und der Widget-Extension-ID
     `de.mauricejobst.bembel.widgets`).
   - Name „BEMBEL“, Primärsprache Deutsch.
5. **(Maurice)** App Privacy in App Store Connect: **Data Not Collected** —
   kein Tracking, keine Analytics, kein Backend, Standort verlässt das Gerät
   nicht (gedeckt durch die Architektur, siehe AGENTS.md). Export Compliance
   ist im Code beantwortet: `ITSAppUsesNonExemptEncryption = false` in
   `App/Info.plist` — nur HTTPS, keine eigene Krypto; die Frage kommt beim
   Upload nicht mehr.

## Jeder Build

```
make testflight
```

archiviert Release für `generic/platform=iOS` und lädt direkt zu App Store
Connect hoch (`Config/ExportOptions.plist`, `destination = upload`,
`manageAppVersionAndBuildNumber` nummeriert die Builds durch). Danach in
App Store Connect → TestFlight:

- Erster Build: Beta-App-Beschreibung + Feedback-E-Mail ausfüllen.
- Interne Tester (bis 100, sofort): Maurice, @cybeerboy, @jaypikay,
  @monsdroid als App-Store-Connect-Nutzer einladen.
- Externe Tester brauchen einmalig Beta App Review (~1 Tag).

## Versionierung

`MARKETING_VERSION` lebt in `Config/Shared.xcconfig` (aktuell 0.2.0) und wird
pro TestFlight-Welle von Hand erhöht; die Build-Nummer je Version verwaltet
der Upload selbst. Das App-Icon ist generiert — `make icon` zeichnet es neu,
nie von Hand in den Asset-Katalog malen.

## Bekannte Lücken vor dem ersten externen Beta

- RMV-Abfahrten laufen noch auf Sample-Daten (#11, API-Key ausstehend) —
  für interne Tester okay, in der Beta-Beschreibung erwähnen.
- Kiosk-Stempel feuern nur im Vordergrund (When-In-Use). Das ist keine Lücke
  mehr, sondern entschieden (#105): Always-Auth wurde bewusst nicht
  eingeführt, der Settings-Text nennt die Reichweite jetzt korrekt.
