# Ich zähl bis drei / Count to Three

iOS-/iPadOS-App, mit der ein Elternteil das Familien-iPad vom eigenen iPhone aus „pausiert“.

## Ziel

- Auf Knopfdruck am Eltern-iPhone erscheint auf dem iPad bei jeder App ein großer, nicht wegklickbarer Hinweis („Ich zähl bis drei – Spielzeit ist vorbei“).
- Ein weiterer Knopfdruck hebt die Sperre auf („Spielzeit!“).
- Das Eltern-iPhone sieht, ob die Sperre angekommen ist (Quittung) und ob die App auf dem iPad umgangen wurde (Lebenszeichen und Autorisierungsstatus).

Es ist eine **sanfte Sperre mit Nachweis**, keine unüberwindbare Sperre. Alle leben im selben Haushalt: Wird die Sperre umgangen, reicht es, davon zu erfahren.

## Rahmenbedingungen

- Das iPad nutzt einen gemeinsamen Familien-Apple-Account, keinen Kinder-Account. Deshalb `.individual`-Autorisierung, nicht `.child`.
- Das Eltern-iPhone nutzt einen anderen Apple-Account als das iPad.
- Keine Drittanbieter-Apps, keine eigene Server-Infrastruktur, keine Kosten für Pushes. Möglichst wenig Daten verlassen die Geräte.
- Kein MDM und kein Zurücksetzen des iPads.
- Swift 6, SwiftUI. Die App braucht keine Funktion, die erst mit iOS 27 kommt; die Xcode-Version richtet sich nach dem, was auf dem Mac verfügbar ist.
- Keine externen Abhängigkeiten ohne Rückfrage.

## Aktueller Stand

Phase: Repo angelegt, Xcode-Projekt noch nicht.

- **Auf dem Mac ist kein Xcode installiert**, nur die Command Line Tools (Swift 6.2.3). macOS ist 26.2.
- Xcode 26.5 und 26.6 laufen auf macOS 26.2. Xcode 27.x verlangt macOS 26.6 oder neuer ([Systemanforderungen](https://developer.apple.com/xcode/system-requirements)).
- Apple nennt für Xcode 26.6 On-Device-Debugging bis iOS 26.5. Laufen iPhone oder iPad schon mit iOS 27, ist vor den Spikes zu klären, ob sich das Projekt damit auf die Geräte bringen lässt; sonst wird Xcode 27 samt macOS-Update gebraucht.
- Vorschlag, noch nicht bestätigt: Bundle-ID `de.haushoppe.countto3`, App Group `group.de.haushoppe.countto3`, Container `iCloud.de.haushoppe.countto3`. Vor dem Anlegen des Projekts Johannes fragen.

## Vorgehen

1. Xcode-Projekt anlegen: App-Target, Shield Configuration Extension, Shield Action Extension, DeviceActivityMonitor Extension, Notification Service Extension, gemeinsame App Group, CloudKit-Container. Capabilities: Family Controls, iCloud (CloudKit), Push Notifications, Background Modes → Remote notifications.
2. Gemeinsames Swift-Package für das CloudKit-Datenmodell (`LockState`, `Heartbeat`), den Shield-Manager und die Heartbeat-Erzeugung.
3. Spikes 1 bis 6 in dieser Reihenfolge, jeweils als minimaler Wegwerf-Prototyp ohne UI und mit Testanleitung für echte Geräte (iPhone als Eltern-Gerät, iPad als Kind-Gerät). Johannes trägt die Ergebnisse in `SPIKES.md` ein. **Danach anhalten und gemeinsam auswerten.**
4. Erst danach: UI, Onboarding (Autorisierung, Pairing, Hinweis zu „Immer erlaubt“) und Auswertungslogik in der Eltern-App.

## Architektur

**Eine App mit zwei Rollen**, gewählt beim ersten Start (Eltern oder Kind-Gerät). Begründung: Ein Store-Eintrag und ein Kauf decken beide Geräte ab, und beide Rollen teilen Container, Datenmodell und Pairing. Zwei Apps würden das Pairing für Nutzer und Review umständlicher machen.

Die Geräte sprechen über CloudKit-Sharing miteinander. Apple ist der einzige Zusteller.

- **Steuerkanal (Eltern → iPad):** Zone `Control` in der privaten Datenbank der Eltern, Datensatz `LockState`, Felder in `encryptedValues`: `locked` (Int 0/1), `commandId` (String, UUID), `issuedAt` (Date). Daraus ein `CKShare`, Teilnehmerrecht nur lesen. Die Einladung per AirDrop oder Nachricht ans iPad ist das Pairing.
- **Statuskanal (iPad → Eltern):** Spiegelbildlich Zone `Status` in der privaten Datenbank des Familien-Accounts, Datensatz `Heartbeat`, nur lesend mit dem Eltern-Account geteilt.
- **Pushes:** Beide Seiten abonnieren ihre `sharedCloudDatabase` per `CKDatabaseSubscription`, mit `shouldSendContentAvailable = true`, einem sichtbaren Text als Fallback und `shouldSendMutableContent = true`, damit die Notification Service Extension überhaupt läuft.
- **Fail-closed:** Verliert das iPad die Freigabe (Share entfernt oder nicht lesbar), bleibt es gesperrt oder wird gesperrt.
- **Sperren:** Benannter `ManagedSettingsStore` setzt `shield.applicationCategories = .all()` und `shield.webDomainCategories = .all()`. Entsperren leert den Store.
- **Shield Configuration Extension:** Titel, Untertitel, Farben und Icon im Stil „Ich zähl bis drei“.
- **Shield Action Extension:** Der Primärbutton antwortet mit `.close`.

### Heartbeat und Quittung

Felder von `Heartbeat`: `ackCommandId`, `shieldActive`, `authStatus`, `bootTime` (siehe Spike 4), `lowPowerMode` (`ProcessInfo.processInfo.isLowPowerModeEnabled`), `protectedDataAvailable` (`UIApplication.shared.isProtectedDataAvailable`), `sentAt`.

Auswertung in der Eltern-App:

- **Quittung ist der Kern:** Nach „Sperren“ wird innerhalb weniger Minuten `ackCommandId == commandId` mit `shieldActive == true` erwartet. Bleibt das aus: „Nicht bestätigt – bitte nachsehen“.
- **Eindeutige Umgehung:** `authStatus` ist nicht `.approved`.
- **Lücke mit neuer Bootzeit:** Das Gerät war aus. Kein Alarm.
- **Lücke mit gleicher Bootzeit:** Nur ein Hinweis zum Nachsehen, kein Alarm. Ursache können Standby, Drosselung, Force-Quit oder Stromsparmodus sein.
- Der Dauer-Heartbeat läuft nur grob mit und hat eine großzügige Schwelle, weil starre Intervalle auf iOS Fehlalarme erzeugen.
- Nach einem Neustart sind vor dem ersten Entsperren keine verschlüsselten Daten verfügbar. Das ist erwartetes Verhalten.

## Wissensstand zur Plattform

Immer kennzeichnen, woher eine Aussage stammt. Die Screen-Time-API ist voller undokumentierter Eigenheiten; bei Unsicherheit in der aktuellen Apple-Dokumentation und im Developer Forum nachsehen, nicht aus dem Gedächtnis antworten.

**Von Apple dokumentiert**

- `shouldSendMutableContent` setzt `mutable-content` im Payload ([Doku](https://developer.apple.com/documentation/cloudkit/cksubscription/notificationinfo-swift.class/shouldsendmutablecontent)).
- `encryptedValues` ist mit CloudKit-Sharing kompatibel; nur Nutzer auf dem `CKShare` können die Felder entschlüsseln ([WWDC21](https://developer.apple.com/videos/play/wwdc2021/10086/)).
- Für Bootzeit-Zugriffe gilt: Die Kategorie `NSPrivacyAccessedAPICategorySystemBootTime` führt `systemUptime` und `mach_absolute_time()` auf. Nach den Gründen 35F9.1 und 8FFB.1 darf weder die Bootzeit noch daraus Abgeleitetes das Gerät verlassen; 3D61.1 erlaubt das nur für einen vom Nutzer abgesendeten Fehlerbericht ([Doku](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)).

**Aussagen von Apple-Mitarbeitern im Forum, nicht in der Doku**

- Shield-Extensions: „For privacy reasons you cannot make API calls from your Shield Extension.“ ([Frameworks Engineer, Jan. 2025](https://developer.apple.com/forums/thread/772282))
- DeviceActivityMonitor: Die Laufzeit endet, sobald die synchronen Callbacks zurückkehren. Als Workaround nennt Apple, den Callback mit `DispatchGroup.wait` kurz offen zu halten ([Frameworks Engineer, Feb. 2023](https://developer.apple.com/forums/thread/724649)).
- Notification Service Extension: Beliebiger Code darin „may or may not work“ ([Apple Engineer, Aug. 2024](https://developer.apple.com/forums/thread/761212)).
- Das Distribution-Entitlement für Family Controls wird team-weit vergeben und gilt dann für alle Bundle-IDs des Teams ([DTS Engineer, Mai 2026](https://developer.apple.com/forums/thread/828085)). Den Status jeder Extension trotzdem unter „Certificates, Identifiers & Profiles“ prüfen.

**Berichte anderer Entwickler und Recherche-Annahmen, ungeprüft**

- Ein Entwickler berichtet, dass `ManagedSettings` und das Anlegen von `DeviceActivity`-Zeitplänen aus der Notification Service Extension nicht funktionierten; Schreiben in `UserDefaults` schon. Keine Antwort im Thread, Stand Aug. 2024 ([Forum](https://developer.apple.com/forums/thread/761212)).
- `AuthorizationCenter.shared.authorizationStatus` liefert nach einem Widerruf oft weiter `.approved`, bis die App neu startet, danach `.notDetermined`.
- Bei `.individual` lässt sich die Berechtigung mit Gerätecode oder Face ID widerrufen, ohne den Bildschirmzeit-Code. Damit fallen alle Schilde weg.
- Stille Pushes wecken eine weggewischte App nicht und können gedrosselt werden. Kritisch ist deshalb die Zustellung des Sperrbefehls.
- Ein gesetzter Schild übersteht Force-Quit und Neustart. Die eigene App ist ausgenommen. Apps unter „Immer erlaubt“ erfasst `.all()` nicht. Die Einstellungs-App bleibt erreichbar.
- Für die DeviceActivityMonitor Extension werden 5 bis 6 MB Speichergrenze genannt, höchstens 20 gleichzeitig überwachte Aktivitäten und mindestens 15 Minuten je Zeitfenster.

## Spikes

| # | Frage | Vorwissen |
|---|---|---|
| 1 | Läuft die Notification Service Extension bei `mutable-content` auch, wenn die App weggewischt wurde, und darf sie den benannten `ManagedSettingsStore` setzen? | Wichtigster Test. Ein Bericht spricht dagegen. |
| 2 | Wecken wiederkehrende Zeitfenster die DeviceActivityMonitor Extension zuverlässig, und kann sie `LockState` lesen und `Heartbeat` schreiben? | Netzwerk kommt laut Forum teils an, die Laufzeit ist knapp. Zwei CloudKit-Operationen in einem Callback sind das Risiko. |
| 3 | Kann die Shield Action Extension CloudKit abfragen („Freigabe prüfen“)? | Apple-Mitarbeiter verneint das. Der Sekundärbutton ist deshalb nur eingeplant, falls der Spike das widerlegt. |
| 4 | Ist `kern.boottime` auf iPadOS auslesbar und stabil? | `kern.boottime` steht nicht in Apples Liste, die Regel zur Bootzeit verbietet aber das Versenden. Vor dem Store klären, ob das Feld `bootTime` bleiben darf. |
| 5 | Funktionieren Einladung, Annahme, `CKDatabaseSubscription` auf der geteilten Datenbank und `encryptedValues` im geteilten Datensatz zwischen zwei Accounts? | Teilweise dokumentiert, das Zusammenspiel ist offen. |
| 6 | Was meldet die App nach einem Widerruf und nach einem Neustart der App wirklich? | Siehe `authorizationStatus` oben. |

## Name und Store

- Deutsch: **„Ich zähl bis drei“**, Untertitel „Der Familien-Pausenknopf“. Englisch: **„Count to Three“**.
- Anzeigename über `CFBundleDisplayName` in `InfoPlist.xcstrings` lokalisiert.
- Geplanter Preis: rund 1 €. Ziel für das Datenschutz-Label: „Keine Daten erfasst“.
- Die Store-Beschreibung sagt ehrlich, dass es eine sanfte Sperre mit Nachweis ist und kein Schutz gegen jemanden, der den Gerätecode kennt.
- Begründung für das Distribution-Entitlement: „Familien-Pausenknopf für gemeinsam genutzte Geräte“ mit `.individual`-Autorisierung, ohne Datenerhebung. Das Development-Entitlement reicht für Builds per Xcode, TestFlight und App Store brauchen das Distribution-Entitlement.
- Johannes erledigt selbst: Namensreservierung in App Store Connect und den Antrag auf das Distribution-Entitlement.

## Bekannte Schwächen

Diese Schwächen gehören zum Konzept und werden offen benannt:

- Wer den Gerätecode kennt, kann die Berechtigung widerrufen. Dann bleibt nur der Nachweis.
- Apps unter „Immer erlaubt“ bleiben nutzbar, bis sie jemand manuell aus der Liste entfernt. Das Onboarding weist darauf hin.
