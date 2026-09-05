import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'fortschritt_service.dart';
import 'spielstand.dart';
import 'spielstand_speicher.dart';
import 'update_neustart_service.dart';

/// Der Spielstand in der Cloud.
///
/// ══ DER GRUNDSATZ ═══════════════════════════════════════════════════════
///
/// Das Gerät ist die Wahrheit, die Cloud ist die Sicherung. Gespielt wird
/// immer gegen die SharedPreferences; die Cloud wird im Hintergrund
/// nachgezogen. Fällt sie aus — kein Netz, Zeitlimit, Regelfehler —, merkt
/// der Spieler nichts. Das ist Absicht: Eine Sicherung, die das Spielen
/// aufhalten kann, ist schlimmer als gar keine.
///
/// ══ WIE GESCHRIEBEN WIRD ════════════════════════════════════════════════
///
/// Als EINE JSON-Zeichenkette in einem Feld, nicht als Firestore-Map. Drei
/// Gründe:
///
///  1. JSON hält Ganzzahl und Kommazahl auseinander. Firestore rundet eine
///     Kommazahl ohne Nachkommastellen beim Rückweg gern zur Ganzzahl — und
///     eine Ganzzahl in `pf_kapital` würde jedes spätere `getDouble` mit
///     einer Typausnahme sprengen (siehe SpielstandSpeicher).
///  2. Unsere Schlüssel dürfen Zeichen enthalten, die Firestore in Feldnamen
///     nicht mag.
///  3. Ein Feld statt hunderter ist beim Schreiben deutlich billiger.
///
/// ══ WARUM JEDES SICHERN EINE TRANSAKTION IST ════════════════════════════
///
/// Zwei Geräte können gleichzeitig spielen. Ein blankes Überschreiben würde
/// dann den Fortschritt des jeweils anderen verwerfen. Die Transaktion liest
/// den Cloud-Stand und führt ihn mit dem eigenen zusammen — nach denselben
/// Regeln wie beim Anmelden. Das kostet einen Lesevorgang mehr, dafür kann
/// Sichern nie etwas kaputt machen.
class SpielstandSync {
  static final _db = FirebaseFirestore.instance;

  /// Wartezeit, bis nach der letzten Änderung gesichert wird.
  ///
  /// Eine Station löst ein Dutzend Schreibvorgänge in kurzer Folge aus. Ohne
  /// diese Sammelfrist wäre jeder davon eine eigene Transaktion.
  static const _sammelFrist = Duration(seconds: 5);

  /// Zeitlimit für jeden Cloud-Zugriff. Grosszügiger als bei
  /// [AuthService.hatEigenenNamen], weil hier nie eine Oberfläche wartet —
  /// aber vorhanden, damit ein Funkloch keinen Timer festhält.
  static const _zeitlimit = Duration(seconds: 10);

  static Timer? _timer;
  static bool _laeuft = false;

  /// NUR FÜR DEBUG-BUILDS: schaltet die Synchronisierung frei.
  ///
  /// Im Debug-Build ist sie sonst AUS. Der Grund ist unangenehm konkret: Am
  /// Entwicklungsgerät wird der Spielstand ständig künstlich verbogen —
  /// Streak setzen, alles freischalten, alles zurücksetzen. Liefe die
  /// Synchronisierung mit, landete dieser Unsinn im echten Konto und von dort
  /// auf dem Telefon, mit dem tatsächlich gespielt wird. Und weil die Regeln
  /// nur wachsen (ODER, Maximum, Vereinigung), liesse er sich nicht mehr
  /// herausbekommen.
  ///
  /// Zum bewussten Durchtesten am Gerät auf true setzen — am besten mit einem
  /// Konto, dessen Stand entbehrlich ist.
  static bool debugSyncErlaubt = false;

  /// Darf gerade synchronisiert werden?
  ///
  /// Anonyme Konten bleiben aussen vor: Das sind die Testkonten des
  /// Debug-Knopfes, sie werden wieder gelöscht. Ein Spielstand darin wäre
  /// eine Sicherung, die sich selbst wegwirft.
  static bool get aktiv {
    if (kDebugMode && !debugSyncErlaubt) return false;
    return AuthService.istAngemeldet && !AuthService.istTestkonto;
  }

  static DocumentReference<Map<String, dynamic>>? get _dok {
    final uid = AuthService.uid;
    if (uid == null) return null;
    return _db.collection('spieler').doc(uid).collection('stand').doc('aktuell');
  }

  // ── Anmelden ──────────────────────────────────────────────────────────────

  /// Führt beim Anmelden Gerät und Cloud zusammen.
  ///
  /// Der heikelste Moment der ganzen Funktion, und der Grund für die
  /// Zusammenführ-Regeln: Wer nach einem Update das erste Mal anmeldet, hat
  /// einen vollen Spielstand am Gerät und nichts in der Cloud. "Der Neuere
  /// gewinnt" hätte genau hier alles gelöscht.
  ///
  /// Liefert true, wenn sich am Gerät etwas geändert hat.
  static Future<bool> beimAnmelden() async {
    if (!aktiv) return false;
    final dok = _dok;
    if (dok == null) return false;

    try {
      // ZUERST die Notiz des Neustarts abarbeiten — VOR jedem Zusammenführen.
      //
      // Der Neustart beim Update auf 1.1.0 raeumt lokal ab, kann das
      // Cloud-Dokument aber nicht mitloeschen: Er laeuft in main() vor der
      // Anmeldung, es gibt dort noch keine uid. Ohne diesen Block holte der
      // Abgleich hier den alten Stand aus der Cloud zurueck — die
      // Zusammenfuehrung kennt nur Wachstum, "leer + voll" ergibt "voll".
      //
      // Genau das ist einem TestFlight-Tester passiert: Der Neustart lief,
      // und Sekundenbruchteile spaeter stand alles wieder da.
      //
      // Geloescht wird ueber [loescheCloudStand] — denselben Weg, den auch
      // "Fortschritt zuruecksetzen" in den Einstellungen nimmt. Wirft er,
      // bleibt die Notiz stehen und der naechste Anmeldeversuch holt es nach.
      if (await UpdateNeustartService.cloudLoeschenOffen()) {
        await loescheCloudStand();
        await UpdateNeustartService.cloudGeloescht();
        // Lokal ist bereits leer, es gibt nichts zurueckzuschreiben.
        return false;
      }

      final cloud = await _lies(dok);
      final lokal = await SpielstandSpeicher.lesen();
      final zusammen = spielstandZusammenfuehren(lokal, cloud);

      final geaendert = await SpielstandSpeicher.schreiben(zusammen);
      if (geaendert > 0) {
        // Die offenen Screens lesen ihren Stand aus den Prefs — ohne dieses
        // Signal zeigten sie bis zum nächsten Wechsel die alten Zahlen.
        FortschrittService.resetSignal.value++;
      }

      // Nur schreiben, wenn die Cloud tatsächlich hinterherhinkt.
      if (!_gleich(cloud, zusammen)) await _schreib(dok, zusammen);
      return geaendert > 0;
    } catch (e) {
      // Ohne Netz bleibt der lokale Stand, was er war. Nichts geht verloren.
      debugPrint('Spielstand: Anmelde-Abgleich fehlgeschlagen ($e)');
      return false;
    }
  }

  // ── Laufendes Sichern ─────────────────────────────────────────────────────

  /// Meldet, dass sich etwas geändert hat. Sichert nach [_sammelFrist].
  ///
  /// Absichtlich ohne `await` aufrufbar und absichtlich billig: Diese Methode
  /// steht in den heissen Pfaden (jede beantwortete Frage) und darf dort
  /// nichts kosten.
  static void merkeAenderung() {
    if (!aktiv) return;
    _timer?.cancel();
    _timer = Timer(_sammelFrist, () => jetztSichern());
  }

  /// Sichert sofort — beim Wegschalten der App und vor dem Abmelden.
  ///
  /// Der Moment des Wegschaltens ist der wichtigste überhaupt: Danach kann
  /// das Betriebssystem die App jederzeit beenden, ohne noch einmal zu
  /// fragen. Die Sammelfrist würde dann nie ablaufen.
  static Future<void> jetztSichern() async {
    _timer?.cancel();
    _timer = null;
    if (!aktiv || _laeuft) return;
    final dok = _dok;
    if (dok == null) return;

    _laeuft = true;
    try {
      final lokal = await SpielstandSpeicher.lesen();
      await _db.runTransaction((tx) async {
        final schnappschuss = await tx.get(dok);
        final cloud = _entpacke(schnappschuss.data());
        final zusammen = spielstandZusammenfuehren(lokal, cloud);
        if (_gleich(cloud, zusammen)) return;
        tx.set(dok, _packe(zusammen));
      }).timeout(_zeitlimit);
    } catch (e) {
      // Kein Netz, Zeitlimit, Regelfehler: Der lokale Stand bleibt gültig,
      // der nächste Versuch holt es nach.
      debugPrint('Spielstand: Sichern fehlgeschlagen ($e)');
    } finally {
      _laeuft = false;
    }
  }

  // ── Zurücksetzen ──────────────────────────────────────────────────────────

  /// Löscht den Cloud-Stand — für "Fortschritt zurücksetzen".
  ///
  /// OHNE DIESEN SCHRITT WÄRE DAS ZURÜCKSETZEN WIRKUNGSLOS. Die
  /// Zusammenführ-Regeln kennen nur Wachstum: Ein lokal gelöschtes
  /// `lp_s_done_...` steht in der Cloud weiter auf true, und der nächste
  /// Abgleich holt den ganzen Fortschritt zurück. Der Spieler sähe seinen
  /// Lernpfad wieder auftauchen und hielte die App zu Recht für kaputt.
  ///
  /// Deshalb erst löschen, dann lokal zurücksetzen — und der ausstehende
  /// Sicherungs-Timer muss weg, sonst schreibt er den alten Stand gleich
  /// wieder hin.
  static Future<void> loescheCloudStand() async {
    _timer?.cancel();
    _timer = null;
    if (!aktiv) return;
    final dok = _dok;
    if (dok == null) return;
    try {
      await dok.delete().timeout(_zeitlimit);
    } catch (e) {
      debugPrint('Spielstand: Cloud-Stand löschen fehlgeschlagen ($e)');
      rethrow; // Der Aufrufer muss wissen, dass der Reset unvollständig ist.
    }
  }

  // ── Lesen und Schreiben ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _lies(
      DocumentReference<Map<String, dynamic>> dok) async {
    final schnappschuss = await dok.get().timeout(_zeitlimit);
    return _entpacke(schnappschuss.data());
  }

  static Future<void> _schreib(DocumentReference<Map<String, dynamic>> dok,
          Map<String, dynamic> stand) =>
      dok.set(_packe(stand)).timeout(_zeitlimit);

  static Map<String, dynamic> _packe(Map<String, dynamic> stand) => {
        'version': kSpielstandVersion,
        'daten': jsonEncode(stand),
        'aktualisiert': FieldValue.serverTimestamp(),
      };

  /// Aus dem Dokument zurück in einen Spielstand.
  ///
  /// Ein fehlendes oder unlesbares Dokument ergibt einen LEEREN Stand, keinen
  /// Fehler — und ein leerer Stand kann beim Zusammenführen nichts löschen.
  /// Das ist die richtige Antwort auf "da steht noch nichts" und zugleich auf
  /// "da steht etwas, das ich nicht verstehe".
  static Map<String, dynamic> _entpacke(Map<String, dynamic>? daten) {
    if (daten == null) return {};
    final roh = daten['daten'];
    if (roh is! String) return {};
    try {
      final entschluesselt = jsonDecode(roh);
      if (entschluesselt is! Map) return {};
      return Map<String, dynamic>.from(entschluesselt);
    } catch (e) {
      debugPrint('Spielstand: Cloud-Dokument unlesbar ($e)');
      return {};
    }
  }

  /// Sind zwei Stände inhaltlich gleich? Spart den Schreibvorgang, wenn der
  /// Abgleich nichts Neues ergeben hat — der Normalfall.
  static bool _gleich(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final eintrag in a.entries) {
      final andere = b[eintrag.key];
      final eigen = eintrag.value;
      if (eigen is List && andere is List) {
        if (!listEquals(eigen.cast<Object?>(), andere.cast<Object?>())) {
          return false;
        }
      } else if (eigen != andere) {
        return false;
      }
    }
    return true;
  }

  /// Nur für Tests: setzt den Zustand zwischen zwei Fällen zurück.
  @visibleForTesting
  static void debugZuruecksetzen() {
    _timer?.cancel();
    _timer = null;
    _laeuft = false;
  }
}
