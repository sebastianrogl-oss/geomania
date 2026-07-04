import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class RanglisteService {
  static final _db = FirebaseFirestore.instance;

  static String get _heutigerTag {
    final n = DateTime.now();
    return '${n.year}'
        '${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // Tages-Ergebnis einer Challenge speichern.
  // Überschreibt NUR wenn besser als der bereits gespeicherte Wert
  // (ein Versuch pro Tag, aber kein Downgrade bei Mehrfach-Trigger).
  static Future<void> ergebnisSpeichern({
    required String challengeId,
    required num wert,
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
      final alt = snap.exists ? (snap.data()?['punkte'] as num? ?? 0) : null;
      if (alt == null || wert > alt) {
        await ref.set({
          'uid': uid,
          'anzeigename': name ?? 'Spieler',
          'punkte': wert,
          'erstelltAm': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Rangliste speichern Fehler: $e');
    }
  }

  // Top 100 der heutigen Tages-Rangliste
  static Future<List<RanglistenEintrag>> ladeTagesRangliste(
      String challengeId) async {
    try {
      final q = await _db
          .collection('ranglisten')
          .doc(challengeId)
          .collection(_heutigerTag)
          .orderBy('punkte', descending: true)
          .limit(100)
          .get();
      return q.docs.asMap().entries.map((e) => RanglistenEintrag(
            rang: e.key + 1,
            uid: e.value['uid'] ?? '',
            name: e.value['anzeigename'] ?? 'Spieler',
            wert: e.value['punkte'] ?? 0,
            istIch: e.value['uid'] == AuthService.uid,
          )).toList();
    } catch (e) {
      print('Rangliste laden Fehler: $e');
      return [];
    }
  }

  // Portfolio Alltime (Gesamtkapital)
  static Future<void> portfolioKapitalSpeichern(num kapital) async {
    final uid = AuthService.uid;
    final name = AuthService.anzeigename;
    if (uid == null) return;
    try {
      await _db.collection('portfolio_alltime').doc(uid).set({
        'uid': uid,
        'anzeigename': name ?? 'Spieler',
        'kapital': kapital,
        'aktualisiertAm': FieldValue.serverTimestamp(),
      });
      // Auch im Spieler-Dokument
      await _db.collection('spieler').doc(uid).update({
        'portfolioKapital': kapital,
      });
    } catch (e) {
      print('Portfolio Kapital speichern Fehler: $e');
    }
  }

  static Future<List<RanglistenEintrag>> ladePortfolioAlltime() async {
    try {
      final q = await _db
          .collection('portfolio_alltime')
          .orderBy('kapital', descending: true)
          .limit(100)
          .get();
      return q.docs.asMap().entries.map((e) => RanglistenEintrag(
            rang: e.key + 1,
            uid: e.value['uid'] ?? '',
            name: e.value['anzeigename'] ?? 'Spieler',
            wert: e.value['kapital'] ?? 0,
            istIch: e.value['uid'] == AuthService.uid,
          )).toList();
    } catch (e) {
      print('Portfolio Alltime Fehler: $e');
      return [];
    }
  }
}

class RanglistenEintrag {
  final int rang;
  final String uid;
  final String name;
  final num wert;
  final bool istIch;
  RanglistenEintrag({
    required this.rang,
    required this.uid,
    required this.name,
    required this.wert,
    required this.istIch,
  });
}
