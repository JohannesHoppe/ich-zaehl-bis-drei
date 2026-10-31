# Ich zähl bis drei / Count to Three

iPadOS-App, mit der ein Elternteil ein geteiltes Familien-iPad vom eigenen Android-Smartphone oder Mac aus „pausiert“.

## Ziel

- Auf Knopfdruck am Eltern-Gerät erscheint auf dem iPad bei jeder App ein großer, nicht wegklickbarer Hinweis („Ich zähl bis drei – Spielzeit ist vorbei“).
- Ein weiterer Knopfdruck hebt die Sperre auf („Spielzeit!“).
- Das Eltern-Gerät zeigt, ob die Sperre angekommen ist (Quittung) und ob die App auf dem iPad umgangen wurde (Lebenszeichen und Autorisierungsstatus).

Es ist eine **sanfte Sperre mit Nachweis**, keine unüberwindbare Sperre. Alle leben im selben Haushalt: Wird die Sperre umgangen, reicht es, davon zu erfahren.

## Rahmenbedingungen

- Das iPad nutzt einen gemeinsamen Familien-Apple-Account, keinen Kinder-Account. Deshalb `.individual`-Autorisierung, nicht `.child`.
- Gesperrt werden ausschließlich geteilte iPads.
- Die Eltern nutzen Android-Smartphones und Macs. Es gibt kein iPhone als Eltern-Gerät.
- Das iPad zeigt beim Start einen QR-Code; die Eltern scannen ihn und steuern das iPad dann. Die Eltern-Seite darf eine PWA, eine statische Webseite oder eine native App sein.
- Keine Drittanbieter-Apps, keine eigene Server-Infrastruktur, keine Kosten für Pushes. Möglichst wenig Daten verlassen die Geräte.
- Kein MDM und kein Zurücksetzen des iPads.
- Swift 6, SwiftUI. Die App braucht keine Funktion, die erst mit iOS 27 kommt; die Xcode-Version richtet sich nach dem, was auf dem Mac verfügbar ist.
- Keine externen Abhängigkeiten ohne Rückfrage.

## Aktueller Stand

Phase: Repo angelegt, Xcode-Projekt noch nicht.

- **Auf dem Mac ist kein Xcode installiert**, nur die Command Line Tools (Swift 6.2.3). macOS ist 26.2.
- Entscheidung: **aktuelles macOS und aktuelles Xcode 27.x.** Xcode 27.x verlangt macOS 26.6 oder neuer und unterstützt On-Device-Debugging bis iOS 27 ([Systemanforderungen](https://developer.apple.com/xcode/system-requirements)). App-Store-Uploads verlangen ab April 2027 ohnehin das iOS-27-SDK ([Apple](https://developer.apple.com/news/?id=k1mtkt1k)).
- Das macOS-Update plant Johannes selbst, weil auf dem Mac weitere Agenten laufen. Das Xcode-Projekt und die Spikes warten darauf.
- Firma: Haushoppe-ITS. Kennungen: Bundle-ID `de.haushoppe-its.countto3`, App Group `group.de.haushoppe-its.countto3`, Container `iCloud.de.haushoppe-its.countto3`.

## Offene Entscheidung: Eltern-Seite und Zustellung

Diese Frage wird separat geklärt. Von ihr hängen Steuerkanal, Statuskanal und Spike 5 ab.

- **CloudKit im Browser:** PWA nutzt CloudKit JS oder CloudKit Web Services. Es läuft ohne eigenen Server, die Eltern brauchen aber ein Apple-Konto und melden sich damit im Browser an. Ob das auf Android-Browsern reibungslos klappt, ist ungeprüft. `encryptedValues` sind laut einem Forenbeitrag im Web nicht zugänglich ([Forum](https://developer.apple.com/forums/thread/772640), ungeprüft); die Nutzdaten wären dann mit einem Schlüssel aus dem QR-Code selbst zu verschlüsseln.
- **Kleines Relay:** PWA spricht mit einem eigenen Dienst, der über APNs und FCM zustellt. Der QR-Code reicht als Pairing, Eltern brauchen kein Konto und Web Push wird möglich. Es widerspricht aber „kein eigener Server“ und gefährdet womöglich das Label „Keine Daten erfasst“.
- **Offen bei beiden:** Wie erfahren die Eltern von einer ausbleibenden Quittung, wenn die PWA gerade nicht offen ist?

## Vorgehen

1. Xcode-Projekt anlegen: App-Target, Shield Configuration Extension, Shield Action Extension, DeviceActivityMonitor Extension, Notification Service Extension, gemeinsame App Group, CloudKit-Container. Capabilities: Family Controls, iCloud (CloudKit), Push Notifications, Background Modes → Remote notifications.
2. Gemeinsames Swift-Package für das CloudKit-Datenmodell (`LockState`, `Heartbeat`), den Shield-Manager und die Heartbeat-Erzeugung.
3. Spikes 1 bis 6 in dieser Reihenfolge, jeweils als minimaler Wegwerf-Prototyp ohne UI und mit Testanleitung für das echte iPad. Spike 5 wartet auf die offene Entscheidung; die übrigen Spikes hängen nicht von ihr ab. Johannes trägt die Ergebnisse in `SPIKES.md` ein. **Danach anhalten und gemeinsam auswerten.**
4. Erst danach: UI, Onboarding (Autorisierung, QR-Pairing, Hinweis zu „Immer erlaubt“) und Auswertungslogik auf der Eltern-Seite.

## Architektur

**Eine native App nur fürs iPad, die Eltern-Seite läuft im Browser.** Begründung: FamilyControls wird nur auf dem iPad gebraucht, und die Eltern-Geräte sind Android-Smartphones und Macs. Eine PWA deckt beide ab.

- **Steuerdaten (Eltern → iPad):** `LockState` mit `locked` (Int 0/1), `commandId` (String, UUID), `issuedAt` (Date).
- **Statusdaten (iPad → Eltern):** `Heartbeat`, siehe unten.
- **Pairing:** Das iPad zeigt einen QR-Code. Ein Schlüssel im Fragment der URL (`#…`) bleibt beim Abruf der Seite auf dem Gerät.
- **Pushes:** Damit die Notification Service Extension läuft, braucht der Push einen sichtbaren Text und `mutable-content`. Für den stillen Weckversuch kommt `content-available` dazu.
- **Fail-closed:** Verliert das iPad die Verbindung zur Eltern-Seite dauerhaft oder wird die Kopplung ungültig, bleibt es gesperrt oder wird gesperrt.
- **Sperren:** Benannter `ManagedSettingsStore` setzt `shield.applicationCategories = .all()` und `shield.webDomainCategories = .all()`. Entsperren leert den Store.
- **Shield Configuration Extension:** Titel, Untertitel, Farben und Icon im Stil „Ich zähl bis drei“.
- **Shield Action Extension:** Der Primärbutton antwortet mit `.close`.

### Heartbeat und Quittung

Felder von `Heartbeat`: `ackCommandId`, `shieldActive`, `authStatus`, `bootTime` (siehe Spike 4), `lowPowerMode` (`ProcessInfo.processInfo.isLowPowerModeEnabled`), `protectedDataAvailable` (`UIApplication.shared.isProtectedDataAvailable`), `sentAt`.

Auswertung auf der Eltern-Seite:

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
| 5 | Trägt der gewählte Weg von der PWA zum iPad, einschließlich Android-Browser und Rückkanal? | Hängt an der offenen Entscheidung zur Zustellung. |
| 6 | Was meldet die App nach einem Widerruf und nach einem Neustart der App wirklich? | Siehe `authorizationStatus` oben. |

## Repo und Lizenz

- Das Repo ist öffentlich lesbar und steht unter der PolyForm Strict License 1.0.0. Weil das Projekt nicht Open Source ist, heißt es in allen Texten „Quelltext einsehbar“.
- Geheimnisse wie Schlüssel oder Tokens kommen nie ins Repo, auch nicht in die Commit-Historie.
- Lesbarer Quelltext zeigt nicht, dass die Store-Version genau daraus gebaut wurde. Texte versprechen das deshalb nicht.

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
