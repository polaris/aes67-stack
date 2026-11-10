# AES67 in C – Empfangen und Senden

Nov 4, 2026 · @Jan Deinhard

Dieser Plan führt vom laufenden PTP-Aufbau (BeagleBone Black, Dante AVIO, Cisco SG250) zu einem AES67-Empfänger und -Sender in C. Es ist ein **Lern- und Vorzeigeprojekt**, keine Produktentwicklung: Das Repository ist von Anfang an öffentlich, und nachvollziehbarer Code, gute Dokumentation und messbare Ergebnisse zählen mehr als vollständiger Funktionsumfang. Der Code ist trotzdem so gebaut, dass er auf Mikrocontrollern laufen kann.

## Überblick

**Ziel 1, Empfangen:** Das Board findet einen AES67-Strom des AVIO, empfängt ihn, schreibt das Audio in eine WAV-Datei und misst, wie pünktlich die Pakete relativ zur PTP-Zeit ankommen.

**Ziel 2, Senden:** Das Board erzeugt einen 1-kHz-Sinuston, sendet ihn als AES67-Strom und kündigt ihn per SAP an. Der AVIO empfängt ihn, und du hörst den Ton am PC über USB.

**Lernziele:**

- Modernes, portables C (C11) für Mikrocontroller und Linux
- Die Protokolle hinter AES67: SAP, SDP, RTP, das Audioformat L24 und der Zeitbezug zu PTP
- Embedded-Werkzeuge: CMake, Cross-Compiler, Unit-Tests, Fuzzing, statische Analyse
- Arbeiten mit Claude Code, ohne das Verständnis abzugeben
- Ein technisches Projekt öffentlich so aufbereiten, dass andere es verstehen und nachbauen können

**Umfang:** sechs Phasen plus Vorbereitung. Jede Phase endet mit einem prüfbaren Ergebnis. Bei zwei Abenden pro Woche sind etwa vier bis sechs Wochen realistisch.

## Grundsätze für den Code

Diese Regeln kommen auch in die Datei `CLAUDE.md` im Repository. Claude Code liest sie bei jeder Sitzung.

**Sprache und Standard**

- **C11**, kompiliert mit `-std=c11`. C11 bringt `_Static_assert`, `stdint.h`-Typen und `stdbool.h` und wird von allen relevanten Toolchains unterstützt: GCC, Clang, Arm GNU Toolchain, Zephyr. C17 ändert nur Fehler in C11, C23 ist auf Mikrocontroller-Toolchains noch nicht verlässlich.
- Code, Kommentare, Bezeichner und Commit-Nachrichten auf Englisch.

**Zwei Schichten**

- **Kern** (`src/core`): Parser, Paketaufbau, Zeitrechnung. Kein `malloc`, keine Betriebssystem-Aufrufe, kein `printf`, keine globalen Variablen. Nur Puffer fester Größe, die der Aufrufer bereitstellt. Dieser Teil läuft später unverändert auf dem NUCLEO-H753ZI.
- **Portierung** (`port/`): Sockets, Uhrzeit, Dateien. Zuerst POSIX für das BeagleBone, später Zephyr. Der Kern kennt nur eine kleine Schnittstelle in `include/aes67/platform.h`.

**Regeln im Kern**

- Alle öffentlichen Namen beginnen mit `aes67_`, Makros mit `AES67_`. Schreibweise `snake_case`.
- Ganzzahltypen mit fester Breite (`uint8_t`, `int32_t`, `uint64_t`). Kein `int` für Daten aus dem Netz.
- Fehler als Enum-Rückgabewert `aes67_err` (`AES67_OK`, `AES67_ERR_TRUNCATED`, `AES67_ERR_INVALID` …). Ergebnisse über Ausgabeparameter.
- Netzdaten nie über Casts auf Structs lesen. Jedes Feld byteweise mit Hilfsfunktionen wie `aes67_read_be16()` lesen. Das vermeidet Probleme mit Byte-Reihenfolge und unausgerichteten Zugriffen auf Mikrocontrollern.
- Jede Funktion, die Netzdaten liest, bekommt Zeiger **und** Länge und prüft jede Länge vor dem Zugriff.
- Zustände stecken in Kontext-Structs, die der Aufrufer anlegt (`aes67_rx_ctx`). Damit ist der Code ohne globale Daten mehrfach verwendbar.
- Keine VLAs, keine Rekursion, kein Gleitkomma in zeitkritischen Pfaden.

Das ist bewusst kein vollständiges MISRA C, sondern ein leichter Satz von Regeln in dessen Geist.

## Tooling

| Zweck | Werkzeug | Warum |
| --- | --- | --- |
| Build-System | CMake ≥ 3.25 mit `CMakePresets.json`, Ninja | Standard für C, Zephyr baut ebenfalls mit CMake. Presets halten alle Build-Varianten in einer Datei. |
| Compiler Host | GCC und Clang unter WSL2 | Zwei Compiler finden mehr Fehler als einer. |
| Compiler BeagleBone | Yocto-SDK aus deinem Build | Passt exakt zu Kernel und Bibliotheken im Image. |
| Compiler Mikrocontroller | Arm GNU Toolchain (`arm-none-eabi-gcc`) | Prüft ab Tag 1, dass der Kern für Cortex-M7 (STM32H753) baut, auch ohne Board. |
| Unit-Tests | Unity (ThrowTheSwitch) mit CTest | Kleines Test-Framework in reinem C, läuft auch auf Mikrocontrollern. |
| Laufzeitprüfung | AddressSanitizer und UndefinedBehaviorSanitizer | Findet Speicherfehler und undefiniertes Verhalten in Tests. |
| Fuzzing | libFuzzer (Clang) | Wirft zufällige Daten auf die Parser. Pflicht für Code, der Netzdaten liest. |
| Statische Analyse | clang-tidy, cppcheck | Findet Fehler ohne Ausführung. |
| Formatierung | clang-format | Einheitlicher Stil ohne Diskussion. |
| Testabdeckung | gcovr (optional) | Zeigt ungetestete Pfade. |
| CI | GitHub Actions | Jeder Push baut und testet alle Varianten. |
| Netzanalyse | Wireshark am PC, Port Mirroring am Switch | Mitschnitte (pcap-Dateien) dienen zugleich als Testdaten. |
| Debuggen am Board | gdbserver im Image, `gdb-multiarch` unter WSL | Schrittweises Debuggen auf dem BeagleBone. |
| Audioprüfung | Audacity | WAV-Dateien ansehen und anhören, Frequenz prüfen. |

**Compiler-Warnungen** für alle Varianten, im CI als Fehler (`-Werror`):

```text
-Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow
-Wcast-align -Wstrict-prototypes -Wmissing-prototypes -Wvla
-Wdouble-promotion -Wformat=2 -Wundef -Wnull-dereference
```

**Build-Varianten** in `CMakePresets.json`:

| Preset | Inhalt |
| --- | --- |
| `host-debug` | GCC, Debug, alle Tests |
| `host-asan` | Clang, Sanitizer an, alle Tests |
| `host-fuzz` | Clang, Fuzz-Ziele für die Parser |
| `bbb` | Yocto-SDK, Apps für das BeagleBone |
| `mcu-check` | `arm-none-eabi-gcc`, nur der Kern, für Cortex-M7 |

## Verzeichnisstruktur

Öffentliches Repository `aes67-stack` unter der Lizenz MIT (Entscheidung in `docs/adr/0003-license-mit.md`). Das ebenfalls öffentliche `bbb-aes67-lab` bleibt für Yocto und Testaufbau zuständig. Vor dem ersten Push den Arbeitsvertrag auf Regeln zu Rechten an privat entwickeltem Code prüfen.

```text
aes67-stack/
├── CMakeLists.txt
├── CMakePresets.json
├── CLAUDE.md                 # rules for Claude Code
├── README.md                 # goal, setup, results, how to build
├── LICENSE                   # MIT (ADR 0003)
├── .clang-format
├── .clang-tidy
├── .gitignore
├── .github/workflows/ci.yml
├── cmake/
│   ├── warnings.cmake
│   ├── sanitizers.cmake
│   └── toolchain-arm-none-eabi.cmake
├── include/aes67/            # public headers of the core
│   ├── aes67.h               # umbrella header
│   ├── err.h
│   ├── bytes.h               # big-endian read/write helpers
│   ├── sap.h
│   ├── sdp.h
│   ├── rtp.h
│   ├── pcm.h                 # L24 <-> int32
│   ├── mediaclock.h          # PTP time <-> RTP timestamp
│   └── platform.h            # interface the port must implement
├── src/core/                 # portable, no OS, no malloc
│   ├── bytes.c
│   ├── sap.c
│   ├── sdp_parse.c
│   ├── sdp_write.c
│   ├── rtp.c
│   ├── rtp_stats.c
│   ├── pcm.c
│   └── mediaclock.c
├── port/
│   ├── posix/                # BeagleBone / Linux
│   │   ├── net_posix.c
│   │   └── clock_phc.c       # reads /dev/ptp0
│   └── zephyr/               # later
├── apps/                     # command-line programs (POSIX)
│   ├── sapdump/
│   ├── rx/
│   └── tx/
├── tests/
│   ├── unit/                 # test_sdp.c, test_rtp.c, ...
│   ├── fuzz/                 # fuzz_sdp.c, fuzz_rtp.c, fuzz_sap.c
│   └── data/                 # SDP samples, pcap captures from the AVIO
├── tools/                    # Python helpers: pcap extract, WAV analysis, plots
└── docs/
    ├── plan.md               # this plan
    ├── api-design.md         # conventions and module overview
    ├── adr/                  # architecture decision records
    └── results/              # one write-up per phase with measurements and plots
```

In `docs/adr/` hältst du Architekturentscheidungen kurz fest (ADR, Architecture Decision Record), z. B. „C11 statt C17“ oder „Unity statt CMocka“. Das hilft dir später und zeigt Lesern, wie du entscheidest.

## Arbeitsweise mit Claude Code

Ziel ist schnelles Vorankommen **und** Lernen. Pro Modul gilt diese Aufteilung:

1. **Claude Code entwirft das gesamte API einmalig in Phase 1** (Design-Dokument, alle Header, Testvorschläge), damit alles aus einem Guss ist. **Du prüfst und gibst frei.** Achte besonders auf Puffer und Längen, Fehlerfälle und Speicherbesitz. Die Header prägen den ganzen Code, und spätere Änderungen ziehen sich durch alle Module und Tests. Zu Beginn jeder späteren Phase schaut Claude Code die Header dieser Phase noch einmal mit dir durch.
2. **Du schreibst Tests und Implementierung.** Am besten die Tests zuerst, dann prüfst du gegen die Spezifikation statt gegen deinen eigenen Code.
3. **Claude Code reviewt Tests und Implementierung** gegen die Regeln aus `CLAUDE.md` und `docs/api-design.md` und lässt Tests, Sanitizer und clang-tidy laufen. Erst danach commitest du und gehst zum nächsten Modul.

Ausnahmen: CMake-Gerüst, Python-Skripte in `tools/` und die Kommandozeilen-Apps darf Claude Code weitgehend selbst schreiben. Dort liegt nicht der Lernschwerpunkt.

**Pro Phase eine neue Sitzung.** Startprompt-Muster:

```text
Read CLAUDE.md, docs/plan.md and docs/api-design.md.
We are working on phase N, module <name>.
First, review the header of this module with me. Do not write tests or
implementation. After I have written both, review them against CLAUDE.md
and docs/api-design.md and run all presets. Explain C details I may not know.
```

Abweichungen vom Plan hältst du als ADR fest, nicht nur im Chat.

## Dokumentation und Sichtbarkeit

Da das Projekt vor allem zeigen soll, wie du arbeitest, gehört die Dokumentation zu jeder Phase dazu, nicht ans Ende.

- **README** als Einstieg: Ziel in zwei Sätzen, Aufbau mit Hardware-Liste, aktueller Stand, wichtigste Messergebnisse, Bauanleitung. Oben ein CI-Badge, das zeigt, dass alles grün ist. Die README wächst mit jeder Phase mit.
- **Ergebnisbericht pro Phase** in `docs/results/phase-N.md`: was gebaut wurde, was gemessen wurde, eine Grafik, was überrascht hat. Eine Seite reicht. Die Grafiken erzeugen Skripte in `tools/` aus CSV-Daten der Apps.
- **ADRs** für jede Entscheidung, die jemand anders hinterfragen könnte.
- **Saubere Commit-Historie:** ein Modul pro Commit, aussagekräftige Nachrichten. Die Historie ist für Leser ein Teil der Geschichte.
- **Optional, aber wirksam: Artikel.** Zwei, drei Beiträge zu Themen mit Aha-Effekt, etwa die Rechnung zwischen PTP-Zeit und RTP-Zeitstempel oder die fehlende CPTS-Option im Yocto-Kernel. Veröffentlicht z. B. auf LinkedIn oder einem eigenen Blog und verlinkt aus README und Profil. Auf potenzielle Kunden wirkt das oft stärker als der Code allein.

Zu jedem „Fertig, wenn“ einer Phase gehört deshalb auch: Ergebnisbericht geschrieben, README aktualisiert.

## Phase 0: Testumgebung vorbereiten

**Ziel:** Programme schnell aufs Board bringen und debuggen. Der AVIO sendet einen AES67-Strom, und du hast Mitschnitte davon als Testdaten.

**Was du lernst:** Wie ein AES67-Strom im Netz aussieht, bevor du eine Zeile Code schreibst.

**Aufgaben**

1. **Image erweitern** (im Repository `bbb-aes67-lab`). SSH-Server und Debug-Werkzeuge in `conf/local.inc`, die `local.conf` per `require` einbindet:

   ```bash
   EXTRA_IMAGE_FEATURES += "ssh-server-dropbear tools-debug"
   ```

   Später sauberer: ein eigenes Image-Rezept `meta-bbb/recipes-core/images/bbb-aes67-image.bb`. Dann steht in `local.conf` nur noch, was vom Build-Rechner abhängt.

   **Netz:** Der Laborswitch hängt am Heimnetz, das Board holt sich seine Adresse per DHCP. Damit sie gleich bleibt, im Router eine DHCP-Reservierung für die MAC-Adresse des Boards anlegen.
2. **SDK bauen und installieren.** Das SDK enthält Cross-Compiler und Bibliotheken passend zum Image:

   ```bash
   bitbake core-image-minimal core-image-minimal:do_populate_sdk
   tmp/deploy/sdk/poky-*-toolchain-*.sh      # installs to /opt/poky/...
   ```
3. **Multicast eindämmen.** Bevor die AVIOs Ströme senden, am SG250 IGMP Snooping und IGMP Querier einschalten. Sonst läuft der Multicast durchs ganze Heimnetz und belastet vor allem das WLAN. Danach prüfen, dass Dante Controller die Geräte weiter findet.

   Test: `ssh root@<adresse-des-boards>` aus WSL. Im Heimnetz klappt das auch ohne besondere WSL-Einstellungen.
4. **AES67-Flow im Dante Controller anlegen.** Geräteansicht des ersten AVIO, Symbol „Multicast-Flow erstellen“, Option **AES67** anhaken, beide Kanäle auswählen.
5. **Testton einspielen.** Den AVIO in Windows als Ausgabegerät wählen und in Audacity einen 1-kHz-Sinuston erzeugen und abspielen (Erzeugen → Ton).
6. **Mitschneiden.** Einmal aufzeichnen, dann Teile exportieren. Wireshark läuft am PC, der dazu direkt am SG250 hängt. Solange die Multicast-Filterung am Switch aus ist, sieht der PC alle Ströme. Ist sie an, für den Mitschnitt kurz ausschalten oder Port Mirroring nutzen.
   1. Etwa 90 Sekunden aufzeichnen, während der Testton läuft. 90 Sekunden, weil SAP nur etwa alle 30 Sekunden ankündigt.
   2. Zum Ansehen den Display-Filter `sap || ptp || udp.port == 5004` nutzen. RTP erkennt Wireshark erst nach „Analyze → Enabled Protocols → rtp\_udp“ oder „Decode As → RTP“.
   3. Getrennt nach Protokoll exportieren, jeweils Filter eingeben und „Datei → Angegebene Pakete exportieren“ → nur angezeigte Pakete:
      - Filter `sap` → `tests/data/avio-sap.pcapng` (mindestens zwei Ankündigungen)
      - Filter `udp.port == 5004` → `tests/data/avio-rtp-1khz.pcapng` (etwa 10 Sekunden, Bereich vorher markieren)
      - optional Filter `ptp` → `tests/data/avio-ptp.pcapng` (nützlich in Phase 5)

   **Dazu eine Textdatei, kein Mitschnitt:** `tests/data/avio.sdp` enthält die SDP-Beschreibung des Stroms als reinen Text. Die Unit-Tests für den SDP-Parser lesen sie direkt ein, ohne eine pcap-Datei zerlegen zu müssen. Am einfachsten aus Dante Controller: Geräteansicht → Senden → Info-Symbol beim Multicast-Flow → „In Zwischenablage kopieren“.

**Fertig, wenn:** Du per SSH aufs Board kommst, das SDK einen Testcompile schafft und die drei Testdateien vorliegen. Du kannst im SDP Multicast-Adresse, Port, Format und `ptime` benennen.

## Phase 1: Projektgerüst

**Ziel:** Ein vollständiges Projektgerüst mit dem gesamten API aus einem Guss. Jede Build-Variante ist grün, alle Funktionen existieren als Stubs.

**Was du lernst:** API-Entwurf in C, modernes CMake (Targets statt globaler Variablen), Presets, Cross-Compiling, Test-Einbindung.

### Teil A: Gerüst

1. Repository `aes67-stack` öffentlich auf GitHub anlegen, mit `LICENSE` (MIT oder Apache-2.0) und einer ersten README. Verzeichnisstruktur wie oben.
2. `CLAUDE.md` mit den Grundsätzen aus diesem Plan schreiben. Diesen Plan als `docs/plan.md` ablegen.
3. CMake:
   - Bibliothek `aes67_core` aus `src/core`, öffentliche Header aus `include/`.
   - `C_STANDARD 11`, `C_STANDARD_REQUIRED ON`, `C_EXTENSIONS OFF`.
   - Warnungen aus `cmake/warnings.cmake` per Funktion an jedes Target hängen.
   - Optionen `AES67_BUILD_TESTS`, `AES67_BUILD_APPS`, `AES67_BUILD_FUZZ`.
4. Unity per `FetchContent` einbinden, Tests mit `add_test` registrieren.
5. Die fünf Presets aus dem Abschnitt Tooling anlegen. Für `bbb` das SDK-Environment vorher sourcen. Für `mcu-check` eine Toolchain-Datei mit `-mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-d16` (passend zum STM32H753 auf dem NUCLEO-H753ZI).
6. `.clang-format` und `.clang-tidy` anlegen.
7. GitHub-Actions-Workflow: `host-debug`, `host-asan` und `mcu-check` bei jedem Push.

### Teil B: API-Entwurf in einer Sitzung

Eine einzige Claude-Code-Sitzung entwirft das gesamte API. So sind Namen, Fehlerbehandlung und Pufferregeln überall gleich.

1. **Design-Dokument** `docs/api-design.md`:
   - Konventionen: Präfixe, Namensschema, Fehler-Enum, Ausgabeparameter.
   - Pufferregeln: Wer stellt Speicher bereit, wie werden Längen übergeben und geprüft, wer besitzt welche Daten, wie lange gelten Zeiger in Empfangspuffer.
   - Kontext-Structs: Anlegen, Initialisieren, keine versteckten Zustände.
   - Schnittstelle zur Plattform (`platform.h`).
   - Übersicht aller Module mit Abhängigkeiten und der Phase, in der sie implementiert werden.
2. **Alle Header** in `include/aes67/` nach diesem Dokument, mit Doxygen-Kommentaren pro Funktion: Zweck, Parameter, Rückgabewerte, Fehlerfälle.
3. **Testvorschläge** pro Modul als Liste in `docs/api-design.md`, noch kein Testcode.
4. **Freigabe:**
   - Header für Phase 2 bis 4 (`bytes`, `sap`, `sdp`, `rtp`, `pcm`) gibst du fest frei.
   - Header für Phase 5 und 6 (`mediaclock`, Schreibfunktionen) gelten als Entwurf. Zu Beginn ihrer Phase prüfst du sie erneut, mit dem, was du bis dahin gelernt hast.
   - Änderungen an freigegebenen Headern nur mit ADR.

### Teil C: Stubs und erstes Modul

1. **Stubs:** Jede Funktion aus den Headern bekommt eine leere Implementierung in `src/core`, die `AES67_ERR_NOT_IMPLEMENTED` zurückgibt. So bauen und linken alle Presets von Anfang an, auch `mcu-check`.
2. **Erstes echtes Modul:** `bytes.c` mit `aes67_read_be16/24/32` und `aes67_write_be16/24/32`, dazu Tests. Damit probst du den kompletten Ablauf aus Header, Tests, Implementierung und Review an einem kleinen Beispiel.

### Regeln für inkrementelles Arbeiten ab hier

- Jeder Commit ist grün in allen Presets. Lokal darfst du mit roten Tests arbeiten, das ist der normale Weg: erst der Test, dann der Code.
- Wer Tests vor der Implementierung committen will, markiert sie mit `TEST_IGNORE()`.
- Ein Modul ist ein Schritt: Tests, Implementierung, Review, Commit. Danach das nächste.

**Fertig, wenn:**

```bash
cmake --workflow --preset host-debug   # configure, build, test
cmake --preset mcu-check && cmake --build --preset mcu-check
```

beide ohne Warnung durchlaufen, der CI-Lauf auf GitHub grün ist und du `docs/api-design.md` sowie die Header für Phase 2 bis 4 freigegeben hast.

## Phase 2: Ströme finden mit SAP und SDP

**Ziel:** Das Programm `aes67-sapdump` zeigt auf dem Board alle AES67-Ströme im Netz mit Adresse, Port und Format.

**Was du lernst:** Binärprotokolle sicher parsen (SAP), Textprotokolle sicher parsen (SDP), Multicast-Empfang unter Linux, CMake für Programme statt Bibliotheken.

**Hintergrund**

- **SAP** (Session Announcement Protocol, RFC 2974): AES67-Geräte senden etwa alle 30 Sekunden eine Ankündigung an `239.255.255.255`, Port `9875`. Aufbau: 8 Byte Kopf (Version, Flags, Länge der Authentifizierung, Message-ID-Hash, IPv4-Adresse des Absenders), optional die Authentifizierung, optional der Typ `application/sdp` mit Null-Byte, danach die SDP-Beschreibung. Das Flag T=1 bedeutet: Strom wird abgekündigt.
- **SDP** (Session Description Protocol, RFC 8866): Text, eine Angabe pro Zeile im Format `x=wert`. Für AES67 wichtig:

```text
c=IN IP4 239.69.x.y/32                         multicast address
m=audio 5004 RTP/AVP 97                        port and payload type
a=rtpmap:97 L24/48000/2                        format: 24 bit, 48 kHz, 2 ch
a=ptime:1                                      packet duration in ms
a=ts-refclk:ptp=IEEE1588-2008:<gmid>:0         PTP grandmaster and domain
a=mediaclk:direct=<offset>                     RTP timestamp offset
```

**Aufgaben**

1. Header `sap.h` entwerfen: `aes67_sap_msg` mit Flags, Hash, Absender und Zeiger plus Länge auf das SDP. Kein Kopieren, nur Zeiger in den Empfangspuffer.
2. Header `sdp.h` entwerfen: `aes67_sdp` mit festen Feldern (Adresse als `uint32_t`, Port, Payload-Typ, Abtastrate, Kanäle, Bittiefe, `ptime` in Mikrosekunden, Grandmaster-ID als 8 Byte, Domäne, Offset) und einem Namensfeld fester Länge. Unbekannte Zeilen überspringen, nicht als Fehler werten.
3. Tests: echtes SDP aus `tests/data/avio.sdp`, dazu Randfälle wie fehlende Zeilen, `\n` statt `\r\n`, zu lange Werte, abgeschnittene SAP-Köpfe.
4. Implementierung `sap.c` und `sdp_parse.c`.
5. Fuzz-Ziele `fuzz_sap.c` und `fuzz_sdp.c`, jeweils mindestens 10 Minuten ohne Fund laufen lassen.
6. Plattform: `net_posix.c` mit Funktionen zum Öffnen eines UDP-Sockets und Beitreten einer Multicast-Gruppe (`IP_ADD_MEMBERSHIP` an `eth0`).
7. App `apps/sapdump`: Ankündigungen empfangen, Ströme in einer Tabelle halten, bei Änderung ausgeben. Abgekündigte Ströme entfernen.

   **CMake für die erste App** (Übung E aus dem CMake-Lernplan): Den C-Code der App darf Claude Code schreiben, die CMake-Einbindung schreibst du, Claude Code reviewt. Eigenes Target mit Warnungen und Sanitizern, `_POSIX_C_SOURCE` nur für App und Portierung (nie für den Kern), `install()`-Regel für das Programm, baut auch im Preset `bbb`.

**Fertig, wenn:** `aes67-sapdump` auf dem Board den Flow des AVIO mit denselben Werten zeigt wie Wireshark, alle Tests grün sind und die Fuzzer nichts finden.

## Phase 3: RTP empfangen

**Ziel:** Das Programm `aes67-rx` tritt dem Strom bei und meldet jede Sekunde: Pakete, Verluste, vertauschte Pakete, Jitter.

**Was du lernst:** RTP-Kopf, Sequenznummern mit Überlauf, Jitter-Messung nach RFC 3550.

**Hintergrund:** Ein RTP-Paket (RFC 3550) beginnt mit 12 Byte Kopf: Version (immer 2), Padding, Extension, Anzahl CSRC, Marker, Payload-Typ, 16-Bit-Sequenznummer, 32-Bit-Zeitstempel, 32-Bit-SSRC (Kennung der Quelle). Danach optional CSRC-Liste und Erweiterung, dann die Audiodaten. Bei `ptime` 1 ms und 48 kHz trägt jedes Paket 48 Samples pro Kanal, der Zeitstempel steigt pro Paket um 48.

**Aufgaben**

1. Header `rtp.h` entwerfen: `aes67_rtp_hdr` und `aes67_rtp_parse(buf, len, &hdr, &payload, &payload_len)`. CSRC und Erweiterung korrekt überspringen.
2. Header für Statistik entwerfen: `aes67_rtp_stats` mit `update(stats, seq, ts, arrival)`. Sequenzdifferenz über `(int16_t)(seq - last_seq)` berechnen, das löst den Überlauf bei 65535 → 0.
3. Tests: echte Pakete aus dem Mitschnitt. Ein kleines Python-Skript in `tools/` zieht die RTP-Nutzdaten aus `avio-rtp-1khz.pcapng` und legt sie als Binärdatei in `tests/data/` ab. Dazu künstliche Fälle: Verlust, Duplikat, Vertauschung, Überlauf.
4. Implementierung `rtp.c` und `rtp_stats.c` (selbst schreiben).
5. Fuzz-Ziel `fuzz_rtp.c`.
6. App `apps/rx`: Strom per Kommandozeile oder aus der SAP-Tabelle wählen, Multicast beitreten, Statistik pro Sekunde ausgeben. Empfangszeit per `SO_TIMESTAMPNS` vom Kernel holen statt nach dem Lesen zu messen.

**Fertig, wenn:** `aes67-rx` über 10 Minuten 1000 Pakete pro Sekunde zeigt, ohne Verluste.

## Phase 4: Audio auswerten

**Ziel:** `aes67-rx --wav out.wav` schreibt den empfangenen Strom in eine WAV-Datei. In Audacity siehst und hörst du den 1-kHz-Ton ohne Knackser.

**Was du lernst:** Das Format L24, Vorzeichen-Erweiterung in portablem C, Lücken im Strom behandeln.

**Hintergrund:** L24 bedeutet 24 Bit pro Sample, vorzeichenbehaftet, größtes Byte zuerst (Big Endian). Die Kanäle wechseln sich ab: Links, Rechts, Links, Rechts. Ein Stereo-Paket mit 1 ms hat also 48 × 2 × 3 = 288 Byte Nutzdaten.

Eine typische C-Falle: Zwei naheliegende Wege, das Vorzeichen eines 24-Bit-Werts zu erweitern, sind in C11 implementierungsabhängig. Das Rechtsschieben einer negativen Zahl und die Umwandlung eines `uint32_t` über `INT32_MAX` in `int32_t`. Die gängigen Compiler verhalten sich zwar gleich, garantiert ist es aber nicht. Vollständig definiert ist reine Arithmetik im positiven Bereich:

```c
int32_t v = (int32_t)(((uint32_t)b[0] << 16) | ((uint32_t)b[1] << 8) | b[2]); /* 0 .. 0xFFFFFF */
v -= (v & 0x800000) * 2;  /* two's complement of 24 bit -> -8388608 .. 8388607 */
int32_t s = v * 256;      /* left-justify to the usual 32-bit audio format */
```

**Aufgaben**

1. Header `pcm.h`: `aes67_pcm_l24_to_s32(src, src_len, dst, dst_frames, channels)` und die Gegenrichtung `aes67_pcm_s32_to_l24(...)` (für Phase 6).
2. Tests: bekannte Werte (0, größter positiver, kleinster negativer Wert, −1), Hin- und Rückumwandlung, zu kurze Puffer.
3. Implementierung `pcm.c` (selbst schreiben).
4. WAV-Schreiber in der App, nicht im Kern, weil er Dateien braucht. 24 Bit, 48 kHz, Stereo, Little Endian.
5. Lücken: Springt der RTP-Zeitstempel um mehr als 48, die fehlenden Samples als Stille einfügen. So bleibt die Datei zeitrichtig.
6. Skript `tools/wav_check.py` (Python mit NumPy): Grundfrequenz per FFT bestimmen, Sprünge im Signal finden.

**Fertig, wenn:** Eine 60-Sekunden-Aufnahme in Audacity sauber 1000 Hz zeigt und `wav_check.py` keine Sprünge findet.

## Phase 5: Zeitbezug zu PTP

**Ziel:** `aes67-rx` misst für jedes Paket, wie lange nach seinem Audio-Zeitpunkt es ankommt, und zeigt Minimum, Mittel und Maximum. Daraus ergibt sich, wann ein Empfänger abspielen darf.

**Was du lernst:** Wie AES67 Audio und Uhrzeit verknüpft. Das ist der Kern jedes AES67-Geräts.

### Die Rechnung, Schritt für Schritt

AES67 legt fest: Der RTP-Zeitstempel ist die Zahl der Samples seit dem PTP-Nullpunkt (1.1.1970, Zeitskala TAI), plus dem Offset aus `a=mediaclk:direct`, abgeschnitten auf 32 Bit.

**Schritt 1, Grundformel.** Mit PTP-Zeit t in Sekunden, Abtastrate f\_s = 48 000 und Offset o:

```latex
ts = \left( \lfloor t \cdot f_s \rfloor + o \right) \bmod 2^{32}
```

**Schritt 2, das Überlaufproblem.** Die PTP-Uhr liefert Sekunden s und Nanosekunden n. Rechnet man zuerst alles in Nanosekunden um, ist t etwa 1,8 · 10¹⁸ ns. Mal 48 000 ergibt etwa 8,5 · 10²². Ein `uint64_t` fasst aber nur etwa 1,8 · 10¹⁹. Die Multiplikation läuft also über.

**Schritt 3, aufteilen.** Wegen t = s + n / 10⁹ gilt:

```latex
t \cdot f_s = s \cdot f_s + \frac{n \cdot f_s}{10^9}
```

Der erste Teil ist höchstens etwa 1,8 · 10⁹ · 48 000 ≈ 8,5 · 10¹³, der Zähler des zweiten höchstens 10⁹ · 48 000 = 4,8 · 10¹³. Beides passt bequem in 64 Bit. Da s · f\_s ganzzahlig ist, genügt es, nur den zweiten Teil abzurunden:

```latex
\lfloor t \cdot f_s \rfloor = s \cdot f_s + \left\lfloor \frac{n \cdot f_s}{10^9} \right\rfloor
```

In C ist das ganzzahlige Division mit `uint64_t`, sie rundet bei positiven Werten ab.

**Schritt 4, auf 32 Bit abschneiden.** Die Umwandlung eines vorzeichenlosen Werts in `uint32_t` ist in C genau modulo 2³². Ein Cast genügt.

**Schritt 5, Laufzeit eines Pakets.** Kommt ein Paket mit Zeitstempel ts\_p an, berechnest du für den Empfangszeitpunkt den Zeitstempel ts\_a nach Schritt 1 bis 4. Die Differenz d = ts\_a − ts\_p, gerechnet in `uint32_t`, ist die Verspätung in Samples. Ist d ≥ 2³¹, liegt das Paket in der Zukunft, und der Wert ist als negativ zu deuten: −(2³² − d). Geteilt durch 48 ergibt sich die Zeit in Millisekunden.

Zu erwarten ist mindestens 1 ms, denn der Sender verschickt ein Paket erst, wenn dessen 48 Samples vollständig sind. Dazu kommen Netzlaufzeit und Schwankungen.

### Woher die PTP-Zeit beim Empfang kommt

Die CPTS-Einheit stempelt nur PTP-Pakete in Hardware, keine RTP-Pakete. Deshalb dieser Weg:

1. `ptp4l` synchronisiert `/dev/ptp0` mit dem AVIO.
2. `phc2sys -s eth0 -c CLOCK_REALTIME -w` stellt die Systemuhr danach, als UTC.
3. Der Kernel stempelt jedes RTP-Paket beim Empfang mit der Systemuhr (`SO_TIMESTAMPNS`).
4. PTP-Zeit = Systemzeit + UTC-Offset (derzeit 37 s, `ptp4l` kennt den Wert aus den Announce-Nachrichten).

Prüfstein: Liegt die gemessene Laufzeit bei etwa 37 Sekunden statt Millisekunden, stimmt die Zeitskala nicht. Das ist ein häufiger Fehler und ein guter erster Test.

**Aufgaben**

1. Header `mediaclock.h`: `aes67_mediaclock_ts_from_ptp(sec, nsec, rate, offset)` und `aes67_mediaclock_diff(ts_a, ts_b)` mit Ergebnis als vorzeichenbehafteter Wert in Samples.
2. Tests mit von Hand gerechneten Werten, Überlauf des 32-Bit-Zeitstempels, Werten kurz vor und nach einer vollen Sekunde.
3. Implementierung `mediaclock.c` (selbst schreiben).
4. Plattformfunktion in `platform.h`: `aes67_platform_ptp_now()`. Den UTC-Offset übergibt die App als Konfiguration.
5. `aes67-rx` um die Laufzeitmessung erweitern: Minimum, Mittel, Maximum pro Sekunde, optional als CSV für eine Grafik.

**Fertig, wenn:** Die gemessene Laufzeit stabil bei wenigen Millisekunden liegt und du erklären kannst, woraus sie sich zusammensetzt.

## Phase 6: AES67-Strom senden

**Ziel:** `aes67-tx` sendet einen 1-kHz-Sinuston als AES67-Strom und kündigt ihn per SAP an. Der AVIO empfängt ihn, und du hörst ihn am PC über USB. Das ist der direkte Funktionsnachweis.

**Was du lernst:** Pakete bauen statt lesen, SDP erzeugen, zeitgenaues Senden unter Linux, Interoperabilität mit einem fremden Gerät.

**Hintergrund**

- **Sinus ohne Gleitkomma:** Bei 48 kHz hat ein 1-kHz-Ton genau 48 Samples pro Periode. Das ist exakt ein Paket. Eine Tabelle mit 48 Werten reicht, jedes Paket ist identisch. Pegel −20 dBFS (ein Zehntel des Maximums), damit es am PC nicht zu laut wird. Die Tabelle erzeugt ein Python-Skript als `const int32_t`-Array.
- **Zeitstempel:** Paket k trägt ts = ts₀ + 48 · k. ts₀ berechnest du mit `mediaclock` aus der aktuellen PTP-Zeit. Gesendet wird Paket k, sobald seine 48 Samples „vorbei“ sind, also zur PTP-Zeit seines letzten Samples.
- **Zeitgenau senden:** `clock_nanosleep()` mit `TIMER_ABSTIME` auf die Sendezeit, Thread mit `SCHED_FIFO`. Ein Standard-Linux-Kernel schwankt dabei um einige zehn bis hundert Mikrosekunden. Das ist für einen Empfänger mit mehreren Millisekunden Puffer unkritisch. Miss es trotzdem.
- **SDP für den eigenen Strom:**

```text
v=0
o=- <session-id> <version> IN IP4 169.254.10.10
s=BBB sine 1kHz
c=IN IP4 239.69.10.10/32
t=0 0
m=audio 5004 RTP/AVP 98
a=rtpmap:98 L24/48000/2
a=ptime:1
a=ts-refclk:ptp=IEEE1588-2008:<grandmaster-id>:0
a=mediaclk:direct=0
a=sendonly
```

Die Grandmaster-ID liefert `pmc -u -b 0 'GET PARENT_DATA_SET'` aus linuxptp. Die Adresse im Bereich 239.69.x.x entspricht dem Standardpräfix der Dante-Geräte.

**Aufgaben**

1. Header-Erweiterungen: `aes67_rtp_write()`, `aes67_sdp_write()`, `aes67_sap_write()`. Alle schreiben in einen Puffer des Aufrufers und geben die Länge zurück.
2. Tests: Was geschrieben wird, muss der eigene Parser wieder lesen können (Round-Trip). Dazu Vergleich mit dem SDP des AVIO auf gleiche Struktur.
3. Implementierung `sdp_write.c`, Schreibfunktionen in `rtp.c` und `sap.c`.
4. App `apps/tx`: Sinus-Tabelle, Sendeschleife, SAP-Ankündigung alle 30 Sekunden, Abkündigung (T=1) beim Beenden mit Strg+C.
5. **Erst gegen sich selbst testen:** `aes67-rx` auf dem Board empfängt `aes67-tx`, Phase-4-Prüfung mit `wav_check.py`.
6. **Dann gegen den AVIO:** Im Dante Controller erscheint der Strom unter dem Namen aus der `s=`-Zeile. In der Routing-Matrix die Empfangskanäle des AVIO darauf abonnieren. Den AVIO in Windows als Eingabegerät wählen und in Audacity aufnehmen.
7. Sendezeitpunkte messen: Abweichung vom Soll pro Paket, Minimum, Mittel, Maximum.

**Fertig, wenn:** Der Ton 10 Minuten lang ohne Aussetzer am PC ankommt, Dante Controller keine Fehler für das Abonnement zeigt und die Aufnahme `wav_check.py` besteht.

**Fehlerbilder und erste Verdächtige**

| Symptom | Wahrscheinliche Ursache |
| --- | --- |
| Strom erscheint nicht im Dante Controller | SAP-Paket fehlerhaft, Wireshark zeigt es |
| Abonnement schlägt fehl | Format oder `ptime` passt nicht, falsche Grandmaster-ID |
| Ton knackt regelmäßig | Zeitstempel falsch fortgezählt oder Sendeschleife zu spät |
| Ton ist zu hoch oder tief | Abtastrate oder Kanalzahl im SDP passt nicht zu den Daten |
| Nur Rauschen | Byte-Reihenfolge der L24-Samples vertauscht |

## Ausblick: der Weg zum Mikrocontroller

Nach Phase 6 hast du Kern, Tests und eine Linux-Portierung. Der Kern baut bereits seit Phase 1 für Cortex-M7. Wenn du das Projekt weiterführen willst, wären das die nächsten Schritte, als eigener Plan:

1. **Zephyr-Modul:** Das Repository mit `zephyr/module.yml` als Zephyr-Modul einbindbar machen. Der Kern ändert sich dabei nicht.
2. **Portierung `port/zephyr`:** Sockets über die Zephyr-Netzwerk-API, PTP-Zeit über die Hardware-Zeitstempel des STM32-Ethernet-Controllers, Audio über den I2S-Treiber auf Basis der SAI-Einheit.
3. **Board:** NUCLEO-H753ZI (Cortex-M7, 480 MHz, Ethernet mit IEEE-1588-Zeitstempeln) mit dem Pmod I2S2 von Digilent als Audio-Ein- und -Ausgang. Zuerst SAP und RTP empfangen wie in Phase 2 und 3, dann PTP, dann Audio per SAI und I2S an den Pmod I2S2. Ziel: Der AVIO sendet, das Nucleo-Board spielt den Ton hörbar über Kopfhörer ab.
4. **Gemeinsame Tests:** Unity läuft auch auf dem Board. Dieselben Unit-Tests einmal auf dem Host und einmal auf dem Ziel ausführen.

Das BeagleBone bleibt dabei die Referenz: Was dort läuft, ist das Soll für den Mikrocontroller.
