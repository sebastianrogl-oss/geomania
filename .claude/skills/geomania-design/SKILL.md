---
name: geomania-design
description: Das Design-System der GeoMania-App — Farbpalette und wo welche Farbe gilt, Typografie (Poppins), das 3D-Button-Muster mit Rand und hartem Schatten, die Karten-Optik sowie die Regel, Maße relativ statt absolut zu berechnen. Nutze diesen Skill, wenn du in diesem Projekt Oberfläche baust oder änderst: neue Screens, Buttons, Karten, Dialoge, Overlays, Animationen — oder wenn du eine Farbe, Schriftgröße oder ein Abstandsmaß wählen musst.
---

# GeoMania Design-System

Verbindliche Regeln für alle Oberflächen dieser App. Wenn eine Vorgabe im
Auftrag von diesem Dokument abweicht, gilt der Auftrag — weise aber auf die
Abweichung hin.

## Schrift: Poppins (nicht Nunito)

Die App verwendet durchgehend **Poppins**. Gesetzt wird sie global in
`lib/theme/app_theme.dart:22` über `fontFamily: 'Poppins'`; als Assets liegen
in `pubspec.yaml` nur **Regular (400)** und **Bold (700)**.

> Nunito kommt im Projekt nirgends vor. Ein `fontFamily: 'Nunito'` würde
> stillschweigend auf die System-Schrift zurückfallen und damit *anders*
> aussehen als der Rest der App. Wenn in einem Auftrag „Nunito" steht, ist
> die App-Schrift gemeint — also Poppins.

### Gewichte

Nur zwei Schnitte existieren, alles ab w500 landet auf der Bold-Datei. `w700`
und `w800` sehen daher identisch aus — die Unterscheidung im Code ist
Absichtserklärung, kein optischer Unterschied.

| Gewicht | Verwendung |
|---|---|
| `w900` | Sehr große Zahlen in Feier-Momenten (Streak-Zahl) |
| `w800` | Button-Beschriftungen, Überschriften, Abzeichen-Namen |
| `w700` | Standard für Hervorhebungen, Titel in Karten |
| `w600` | Antworttexte, Listeneinträge |
| `w500` | Selten, für zurückgenommene Nebeninformation |

### Größen

Übliche Staffelung: 9–11 für Hinweise und Fußnoten, 12–13 für Sekundärtext
(häufigste Werte), 14–16 für Fließtext und Buttons, 17–22 für Überschriften.
Darüber nur in Feier-Momenten.

### Texte außerhalb von Material

In `showGeneralDialog`/`showDialog` ohne Material-Vorfahr greift
`DefaultTextStyle.fallback()` statt des Themes. Dort **müssen**
`fontFamily: 'Poppins'` und `decoration: TextDecoration.none` explizit gesetzt
werden, sonst erscheint System-Schrift mit gelben Unterstreichungen.
Alternativ das ganze Overlay in `Material(type: MaterialType.transparency)`
wickeln — das ist bei Vollbild-Overlays der sauberere Weg.

## Farben

Definiert in `lib/theme/app_theme.dart`. Werte, die dort fehlen, stehen im
Code als Literal — die Zählungen unten geben an, wie etabliert ein Wert ist.

### Grundpalette

| Farbe | Wert | Verwendung |
|---|---|---|
| `textDark` | `0xFF1A1A1A` | Textfarbe auf hellem Grund; **zugleich Rand- und Schattenfarbe des 3D-Musters** (häufigster Wert der App) |
| `accentGreen` | `0xFF4A9E4A` | Primäraktion: Weiter-/Fertig-Buttons, richtige Antwort, Fortschrittsbalken, Header |
| `textMid` | `0xFF888888` | Sekundärtext, deaktivierte Zustände |
| `card` | `0xFFEAEAE5` | Antwort-Buttons im Ruhezustand, Kartenflächen |
| `gold` | `0xFFF9A825` | Abzeichen, Aufprallwelle, Auszeichnungen |
| `bg` | `0xFFF5F4F0` | Bildschirmhintergrund (Variante `0xFFF5F5F0` in Quiz-Screens) |
| `blue` | `0xFF4A90D9` | Sekundäre Akzente |
| `purple` | `0xFF7C3AED` | Selten, eigene Spielmodi |

### Zustandsfarben

| Zweck | Wert |
|---|---|
| Falsche Antwort (Fläche) | `0xFFE53935` |
| Falsche Antwort (Rand/Umriss) | `0xFFD94040` |
| Erfolg dunkel (Umrisse, Sekundärgrün) | `0xFF2E7D32` |
| Erfolg hell (Flächenhinterlegung) | `0xFFE8F5E9` |
| Fehler hell (Flächenhinterlegung) | `0xFFFFEBEE` |
| Dunkler Header/AppBar | `0xFF1B3A2D` |
| Fortschrittsbalken-Grund | `0xFF2A4A3A` |
| Debug-Bereich (Einstellungen) | `0xFFB8570A` |

### Overlays

Vollbild-Momente (Streak-Feier, Abzeichen) dunkeln mit
`Colors.black.withValues(alpha: 0.7)` bzw. `0.75` ab. Dezente Hinweise darauf:
weiß mit `alpha: 0.5`.

Benutze `withValues(alpha:)`, nicht das veraltete `withOpacity()`.

## 3D-Button-Muster

Das prägende Element der App: farbige Fläche, **dunkler Rand**, **harter
Schatten ohne Weichzeichnung** nach unten versetzt. Nie ein weicher
Material-Schatten.

```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(vertical: 16),
  decoration: BoxDecoration(
    color: const Color(0xFF4A9E4A),
    borderRadius: BorderRadius.circular(50),
    border: Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
    boxShadow: const [
      BoxShadow(
        color: Color(0xFF1A1A1A),
        offset: Offset(0, 4),
        blurRadius: 0,          // hart, nie weichgezeichnet
      ),
    ],
  ),
  child: Text(
    t('Fertig'),
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    ),
  ),
)
```

Referenz: `lib/widgets/challenge_fertig_button.dart`. **Neue Buttons dieser Art
von dort übernehmen, nicht neu erfinden** — Farbe, Radius, Rand, Schattenversatz
und Schriftgröße sind bewusst überall gleich.

Kennwerte: Radius `50` (Pillenform) für Hauptaktionen, `12–14` für flächige
Buttons · Rand `2` bis `2.5` · Schattenversatz `Offset(0, 3)` bis `Offset(0, 4)`
· `blurRadius: 0` immer.

Zurückgenommene Aktionen (z. B. Skip-Level) bewusst **ohne** 3D-Schatten und in
Grau statt Grün — der Kontrast trägt die Hierarchie.

## Karten-Optik

Dieselbe Sprache wie die Buttons, nur weiße Fläche und kleinerer Radius:

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
    boxShadow: const [
      BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
    ],
  ),
  child: Column(children: children),
)
```

Referenz: `_Card` in `lib/screens/settings_screen.dart`.

Für flächige Listenelemente ohne Rahmen genügt `card` (`0xFFEAEAE5`) mit
Radius `12` und einem sehr dezenten weichen Schatten
(`Colors.black.withAlpha(20)`, `blurRadius: 4`).

## Maße relativ berechnen

**Absolute Pixelwerte für zusammengehörige Elemente sind ein Fehler.** Wenn
mehrere Elemente eine Komposition bilden — eine Figur mit Effekten, ein
Overlay mit Text darunter — leite alle Maße aus **einer** Leitgröße ab.

Grund: Wird später die Leitgröße geändert (und das passiert), müssten sonst
jedes Mal Schatten, Ringe, Abstände und Schriftgrößen einzeln nachgezogen
werden. Genau dabei verschieben sich Proportionen unbemerkt.

```dart
// Leitgröße: der einzige Hebel für die Gesamtgröße.
const _kGesamtSkalierung = 0.54;
double _muenzGroesse(Size schirm) =>
    (schirm.height * 0.42 * _kGesamtSkalierung).clamp(186.3, 283.5);

// Alles andere als VERHÄLTNIS dazu, nie in Pixeln:
const _kWellenStart = 0.75;        // × Münzgröße
const _kWellenEnde = 1.45;
const _kNameGroesse = 0.108;
const _kAbstandMuenzeName = 0.042;
```

Vorbild: `lib/widgets/abzeichen_popup.dart` (Konstantenblock am Dateikopf).

Regeln dazu:

- **Bildschirmabhängige Leitgrößen** mit `MediaQuery.of(context).size` und
  `.clamp(min, max)` versehen, damit sie auf Handy und Tablet funktionieren.
- **Positionen aus der Geometrie berechnen**, nicht schätzen. Beispiel: Der
  Fuß eines zentrierten Objekts in einer Bühne liegt bei
  `(buehneZuObjekt - 1) / 2 * objektGroesse` über dem Bühnenboden.
- **Konstanten gebündelt am Dateikopf** ablegen, mit Kommentar, welche davon
  die Leitgröße ist.
- **Timings von Größen trennen** — beide Blöcke getrennt halten, damit eine
  Größenänderung nie versehentlich das Timing verschiebt.
- Ausgenommen bleibt Bildschirm-Chrome (Seitenränder, Hinweistexte,
  Zähler-Overlays): das ist an den Bildschirm gebunden, nicht an die Figur,
  und darf absolut bleiben.

### Überlauf und Abschneiden

Wenn Effekte über ihren Layout-Platz hinausragen sollen (Wellen, Glow):
`Stack(clipBehavior: Clip.none)` plus `OverflowBox`. Ein `FittedBox(fit:
BoxFit.scaleDown)` um eine Komposition mit *konstanter* Layout-Größe fängt
kleine Displays ab, ohne dass der Skalierungsfaktor während der Animation
zappelt.

## Weitere Konventionen

- **Sprache im Code**: Bezeichner, Kommentare und Commit-Nachrichten sind
  deutsch. Nutzertexte laufen durch `t('…')`, Übersetzungen liegen in
  `lib/l10n/uebersetzungen_*.dart`.
- **Haptik**: das `vibration`-Paket statt `HapticFeedback`, wenn abgestufte
  oder längere Muster nötig sind. Immer `EinstellungenService.vibrationAktiv`
  vorschalten und den Wert **vorab** laden, damit zwischen Auslöser und
  Vibration kein `await` liegt.
- **Overlays** schließen per Tap auf den ganzen Screen
  (`HitTestBehavior.opaque`) mit dem Hinweis `t('Tippen für weiter')`
  (fontSize 13, weiß α 0.5, 40 px vom unteren Rand) — kein Auto-Dismiss.
