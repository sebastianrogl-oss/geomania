import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/abzeichen_data.dart';
import 'abzeichen_service.dart';
import 'auth_service.dart';
import 'profilbild_service.dart';

class RanglisteService {
  static final _db = FirebaseFirestore.instance;

  // Standard-Competition-Ranking ("1224"-Methode): gleiche Werte bekommen
  // denselben Rang, der nächste abweichende Wert überspringt entsprechend
  // viele Ränge (z.B. 1000/900/900/800 -> Rang 1/2/2/4, nicht 1/2/2/3 oder
  // 1/2/3/4). [absteigendSortiert] muss bereits nach Wert absteigend
  // sortiert sein (z.B. via Firestore orderBy) — dann lässt sich der Rang
  // rein aus der Position der ERSTEN gleichwertigen Zeile ableiten, ohne für
  // jede Zeile die gesamte Liste erneut zu durchsuchen.
  static List<int> _berechneRaenge(List<num> absteigendSortiert) {
    final raenge = <int>[];
    for (var i = 0; i < absteigendSortiert.length; i++) {
      if (i > 0 && absteigendSortiert[i] == absteigendSortiert[i - 1]) {
        raenge.add(raenge[i - 1]);
      } else {
        raenge.add(i + 1);
      }
    }
    return raenge;
  }

  static String get _heutigerTag => tagString(DateTime.now());

  /// Firestore-Collection-Key im Format 'JJJJMMTT' für ein beliebiges Datum
  /// (nicht nur heute) — genutzt für die 14-Tage-Historie und die Bereinigung
  /// alter Tage. Absichtlich lexikografisch sortierbar (fest zweistellig
  /// gepaddet), auch wenn das hier nicht ausgenutzt wird.
  static String tagString(DateTime d) => '${d.year}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  /// Die ID des höchsten aktuell freigeschalteten Abzeichens dieses Spielers,
  /// oder null — wird beim Hochladen eines Tagesergebnisses mitgeschrieben
  /// (Teil 5), damit die Rangliste ein Icon dazu zeigen kann.
  static Future<String?> _topAbzeichen() async {
    final freigeschaltete = await AbzeichenService.getFreigeschaltete();
    return topAbzeichenId(freigeschaltete);
  }

  // Tages-Ergebnis einer Challenge speichern.
  // Überschreibt NUR wenn besser als der bereits gespeicherte Wert
  // (ein Versuch pro Tag, aber kein Downgrade bei Mehrfach-Trigger).
  static Future<void> ergebnisSpeichern({
    required String challengeId,
    required num wert,
    num? zusatzWert,
  }) async {
    final uid = AuthService.uid;
    final name = AuthService.anzeigename;
    if (uid == null) return;

    final ref = _db
        .collection('ranglisten')
        .doc(challengeId)
        .collection(_heutigerTag)
        .doc(uid);

    try {
      final snap = await ref.get();
      final altData = snap.data();
      final alt = snap.exists ? (altData?['punkte'] as num? ?? 0) : null;
      // Migrations-Fall: ein bereits gespeichertes Dokument, das VOR der
      // Umstellung von 'punkte' auf die Prozent-Rendite (Portfolio) erstellt
      // wurde, hat keinen 'zusatzWert' und trägt noch den alten, viel
      // größeren Dollar-Betrag als 'punkte'. Ein 'wert > alt'-Vergleich
      // (Prozent gegen Dollar) würde dann NIE zutreffen, sodass die
      // Rangliste dauerhaft auf dem alten, falsch skalierten Wert hängen
      // bliebe. Erkennbar daran, dass der neue Aufruf einen zusatzWert
      // mitliefert, das gespeicherte Dokument aber keinen hat — dann einmalig
      // unabhängig vom Wertevergleich überschreiben.
      final legacyOhneZusatzWert =
          snap.exists && zusatzWert != null && altData?['zusatzWert'] == null;
      if (alt == null || wert > alt || legacyOhneZusatzWert) {
        await ref.set({
          'uid': uid,
          'anzeigename': name ?? 'Spieler',
          'punkte': wert,
          if (zusatzWert != null) 'zusatzWert': zusatzWert,
          'profilbild': await ProfilbildService.getProfilbild(),
          'topAbzeichen': await _topAbzeichen(),
          'erstelltAm': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Rangliste speichern Fehler: $e');
    }
  }

  // ── 14-Tage-Rollfenster ──────────────────────────────────────────────────
  //
  // Speichert wie ergebnisSpeichern() und räumt zusätzlich den Tag GENAU
  // 15 Tage vor heute ab (1 Tag Sicherheitsabstand zum sichtbaren 14-Tage-
  // Fenster, siehe Abschluss-Check-Kommentar im Rangliste-Screen). Läuft bei
  // JEDEM Spieler mit, der ein Ergebnis speichert — reicht ohne eigene Cloud
  // Function, weil Firestore-Client-SDKs keine Subcollections auflisten
  // können, hier aber der exakte Tages-Key direkt berechnet statt gelistet
  // wird. Das Löschen fremder Einträge erlaubt firestore.rules NUR wenn deren
  // erstelltAm bereits > 14 Tage alt ist (siehe dortiger Kommentar).
  static Future<void> ergebnisSpeichernMitBereinigung({
    required String challengeId,
    required num wert,
    num? zusatzWert,
  }) async {
    await ergebnisSpeichern(
      challengeId: challengeId,
      wert: wert,
      zusatzWert: zusatzWert,
    );

    final vorFuenfzehnTagen = DateTime.now().subtract(const Duration(days: 15));
    final altTag = tagString(vorFuenfzehnTagen);

    try {
      final altCollection = _db
          .collection('ranglisten')
          .doc(challengeId)
          .collection(altTag);

      // Batch-weise löschen (nicht alle auf einmal) — Kosten-/Rate-Limit-
      // Schutz, reicht über mehrere Aufrufe verteilt trotzdem zeitnah aus.
      final altDocs = await altCollection.limit(50).get();
      for (final doc in altDocs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Einzelne Dokumente können hier per Regel abgelehnt werden (z.B. noch
      // keine 14 Tage alt durch Zeitzonen-Grenzfälle) — das darf das
      // eigentliche Speichern oben nicht beeinträchtigen, daher nur loggen.
      debugPrint('Rangliste-Bereinigung Fehler: $e');
    }
  }

  // Top 100 der Tages-Rangliste für [tag] (Standard: heute) — [tag] erlaubt
  // das Zurückblättern durch die 14-Tage-Historie im Rangliste-Screen.
  static Future<List<RanglistenEintrag>> ladeTagesRangliste(
      String challengeId, {
    DateTime? tag,
  }) async {
    try {
      final q = await _db
          .collection('ranglisten')
          .doc(challengeId)
          .collection(tag == null ? _heutigerTag : tagString(tag))
          .orderBy('punkte', descending: true)
          .limit(100)
          .get();
      final raenge = _berechneRaenge(
          q.docs.map((d) => d.data()['punkte'] as num? ?? 0).toList());
      return q.docs.asMap().entries.map((e) {
        // Über .data() (eine reguläre Map) statt über den []-Operator auf
        // dem QueryDocumentSnapshot selbst zugreifen: Firestore wirft bei
        // Snapshot[] einen StateError für fehlende Felder, eine Map gibt bei
        // einem fehlenden Key dagegen einfach null zurück — wichtig, da
        // ältere Einträge (vor Einführung von 'profilbild'/'zusatzWert')
        // diese Felder noch nicht haben.
        final d = e.value.data();
        return RanglistenEintrag(
          rang: raenge[e.key],
          uid: d['uid'] ?? '',
          name: d['anzeigename'] ?? 'Spieler',
          wert: d['punkte'] ?? 0,
          istIch: _istIch(d['uid']),
          topAbzeichen: d['topAbzeichen'] as String?,
          profilbildPfad: d['profilbild'] as String?,
          zusatzWert: d['zusatzWert'] as num?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Rangliste laden Fehler: $e');
      return [];
    }
  }

  // Eigener Platz + Teilnehmerzahl in der heutigen Tages-Rangliste einer
  // Challenge — für die "Platz X von Y Spielern heute"-Zeile im Ergebnis-
  // Screen. Nutzt Aggregations-Abfragen (.count()), damit NICHT alle
  // Dokumente geladen werden müssen (funktioniert auch jenseits von Top 100).
  // Gibt null zurück bei fehlendem Login, Fehler oder wenn heute noch niemand
  // gespielt hat.
  static Future<({int platz, int gesamt})?> ladeEigenenPlatzHeute(
      String challengeId, num eigenerWert) async {
    final uid = AuthService.uid;
    if (uid == null) return null;
    try {
      final coll = _db
          .collection('ranglisten')
          .doc(challengeId)
          .collection(_heutigerTag);

      final gesamtSnap = await coll.count().get();
      final gesamt = gesamtSnap.count ?? 0;
      if (gesamt == 0) return null;

      // Für den Vergleich den TATSÄCHLICH gespeicherten eigenen Wert nutzen,
      // nicht den frisch übergebenen Session-Wert: ergebnisSpeichern()
      // überschreibt nur bei einer Verbesserung, daher bleibt bei einem
      // schlechteren Wiederholungsversuch der alte (höhere) Firestore-Wert
      // stehen. Ohne diesen Abgleich würde das eigene, bessere gespeicherte
      // Ergebnis in der "besser als mich"-Zählung sich selbst mitzählen
      // (z.B. "#2 von 1" als einziger Spieler).
      final eigenesDoc = await coll.doc(uid).get();
      final gespeicherterWert =
          (eigenesDoc.data()?['punkte'] as num?) ?? eigenerWert;

      final besserSnap = await coll
          .where('punkte', isGreaterThan: gespeicherterWert)
          .count()
          .get();
      final platz = (besserSnap.count ?? 0) + 1;

      return (platz: platz, gesamt: gesamt);
    } catch (e) {
      debugPrint('Platz laden Fehler: $e');
      return null;
    }
  }

  // Aktualisiert das Profilbild sofort im Spieler-Dokument. Bereits
  // hochgeladene Ranglisten-/Alltime-Einträge werden erst beim nächsten
  // Ergebnis-Upload nachgezogen (ergebnisSpeichern / portfolioKapitalSpeichern
  // lesen das Profilbild bei jedem Aufruf frisch aus SharedPreferences).
  static Future<void> profilbildAktualisieren(String pfad) async {
    final uid = AuthService.uid;
    if (uid == null) return;
    try {
      await _db.collection('spieler').doc(uid).set({
        'profilbild': pfad,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Profilbild aktualisieren Fehler: $e');
    }
  }

  // Portfolio Alltime (Gesamtkapital)
  static Future<void> portfolioKapitalSpeichern(num kapital) async {
    final uid = AuthService.uid;
    final name = AuthService.anzeigename;
    if (uid == null) return;
    try {
      final profilbild = await ProfilbildService.getProfilbild();
      await _db.collection('portfolio_alltime').doc(uid).set({
        'uid': uid,
        'anzeigename': name ?? 'Spieler',
        'kapital': kapital,
        'profilbild': profilbild,
        'topAbzeichen': await _topAbzeichen(),
        'aktualisiertAm': FieldValue.serverTimestamp(),
      });
      // Auch im Spieler-Dokument
      await _db.collection('spieler').doc(uid).update({
        'portfolioKapital': kapital,
        'profilbild': profilbild,
      });
    } catch (e) {
      debugPrint('Portfolio Kapital speichern Fehler: $e');
    }
  }

  static Future<List<RanglistenEintrag>> ladePortfolioAlltime() async {
    try {
      final q = await _db
          .collection('portfolio_alltime')
          .orderBy('kapital', descending: true)
          .limit(100)
          .get();
      final raenge = _berechneRaenge(
          q.docs.map((d) => d.data()['kapital'] as num? ?? 0).toList());
      return q.docs.asMap().entries.map((e) {
        final d = e.value.data();
        return RanglistenEintrag(
          rang: raenge[e.key],
          uid: d['uid'] ?? '',
          name: d['anzeigename'] ?? 'Spieler',
          wert: d['kapital'] ?? 0,
          istIch: _istIch(d['uid']),
          topAbzeichen: d['topAbzeichen'] as String?,
          profilbildPfad: d['profilbild'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Portfolio Alltime Fehler: $e');
      return [];
    }
  }

  // Eigener Platz + Teilnehmerzahl im Portfolio-Gesamt-Ranking (All-Time) —
  // dasselbe Prinzip wie ladeEigenenPlatzHeute(), funktioniert also auch
  // außerhalb der angezeigten Top 100. Nutzt das im 'spieler'-Dokument
  // gepflegte portfolioKapital als aktuellen Wert (siehe
  // portfolioKapitalSpeichern), da dieser Aufruf unabhängig von einer
  // gerade laufenden Spielrunde funktionieren soll.
  static Future<({int platz, int gesamt})?> ladeEigenenPlatzPortfolio() async {
    final uid = AuthService.uid;
    if (uid == null) return null;
    try {
      final coll = _db.collection('portfolio_alltime');

      final gesamtSnap = await coll.count().get();
      final gesamt = gesamtSnap.count ?? 0;
      if (gesamt == 0) return null;

      final eigenesDoc = await coll.doc(uid).get();
      final gespeichertesKapital = eigenesDoc.data()?['kapital'] as num?;
      if (gespeichertesKapital == null) return null;

      final besserSnap = await coll
          .where('kapital', isGreaterThan: gespeichertesKapital)
          .count()
          .get();
      final platz = (besserSnap.count ?? 0) + 1;

      return (platz: platz, gesamt: gesamt);
    } catch (e) {
      debugPrint('Portfolio-Platz laden Fehler: $e');
      return null;
    }
  }

  /// Gehört dieser Ranglisten-Eintrag dem angemeldeten Spieler?
  ///
  /// Verglichen wird die uid, nicht der Anzeigename — Namen sind zwar
  /// reserviert (siehe anzeigenamen_reserviert), aber sie ändern sich, und
  /// ein alter Eintrag trägt dann noch den alten.
  ///
  /// DIE null-PRÜFUNG IST NICHT ÜBERFLÜSSIG: Ohne sie ergäbe `null == null`
  /// true. Wer nicht angemeldet ist ([AuthService.uid] ist null), hätte dann
  /// jeden Alt-Eintrag ohne uid-Feld als "seinen" markiert bekommen — grün
  /// hinterlegt, mit dem eigenen Profilbild daneben.
  static bool _istIch(Object? uidImEintrag) {
    final ich = AuthService.uid;
    return ich != null && uidImEintrag == ich;
  }
}

class RanglistenEintrag {
  final int rang;
  final String uid;
  final String name;
  final num wert;
  final bool istIch;
  final String? topAbzeichen;
  final String? profilbildPfad;
  final num? zusatzWert;
  RanglistenEintrag({
    required this.rang,
    required this.uid,
    required this.name,
    required this.wert,
    required this.istIch,
    this.topAbzeichen,
    this.profilbildPfad,
    this.zusatzWert,
  });
}
