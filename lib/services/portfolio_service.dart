import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/portfolio_daten.dart';
import 'challenge_rekord_service.dart';
import 'daily_challenge.dart';
import 'tages_seed_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Persistenz (Phase 2)
// Kapital, Streak, Verlauf und Makro-Trend bleiben über Tage hinweg gespeichert.
// ══════════════════════════════════════════════════════════════════════════════

class PortfolioStatus {
  final double kapital;
  final double rekordKapital;
  final int streak;
  final List<double> verlauf; // älteste zuerst, max. 30 Einträge
  final MakroTrend trend;
  final bool heuteGespielt;
  final String heute; // yyyy-MM-dd

  const PortfolioStatus({
    required this.kapital,
    required this.rekordKapital,
    required this.streak,
    required this.verlauf,
    required this.trend,
    required this.heuteGespielt,
    required this.heute,
  });
}

class PortfolioSpielstilRohdaten {
  final int tage;
  final int auswahlen;        // Summe gewählter Länder über alle Tage
  final double risikoSumme;   // Summe (gewichtetes Ø-Risiko pro Tag)
  final double effektivSumme; // Summe (effektive Länderzahl / Diversifikation pro Tag)
  final int newsTreffer;      // Anzahl gewählter Länder, die an dem Tag in den News waren
  final int trendTreffer;     // Anzahl gewählter Länder, die vom Makro-Trend profitierten

  const PortfolioSpielstilRohdaten({
    required this.tage,
    required this.auswahlen,
    required this.risikoSumme,
    required this.effektivSumme,
    required this.newsTreffer,
    required this.trendTreffer,
  });
}

class PortfolioService {
  static const double kStartKapital = 1000.0;
  static const double kFloor = 100.0;

  static const _kKapital         = 'pf_kapital';
  static const _kRekord          = 'pf_rekord_kapital';
  static const _kStreak          = 'pf_streak';
  static const _kLetzterSpieltag = 'pf_letzter_spieltag';
  static const _kVerlauf         = 'pf_verlauf';

  static const _kStilTage         = 'pf_stil_tage';
  static const _kStilAuswahlen    = 'pf_stil_auswahlen';
  static const _kStilRisikoSumme  = 'pf_stil_risiko_summe';
  static const _kStilEffektivSumme = 'pf_stil_effektiv_summe';
  static const _kStilNewsTreffer  = 'pf_stil_news_treffer';
  static const _kStilTrendTreffer = 'pf_stil_trend_treffer';

  // ── Datum-Helfer ─────────────────────────────────────────────────────────────

  static String _formatDatum(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseDatum(String s) {
    final teile = s.split('-');
    return DateTime(int.parse(teile[0]), int.parse(teile[1]), int.parse(teile[2]));
  }

  static DateTime _heuteDatum() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // ── Makro-Trend (täglich neu, seed-basiert, für alle Spieler gleich) ────────
  // Kein mehrtägiger Zustand mehr — jeder Tag zieht unabhängig einen neuen
  // Trend, daher keine Persistenz (kein "Tag X von Y"-Zähler) nötig.

  static MakroTrend _heutigerTrend(DateTime heute) {
    final seed = TagesSeedService.seedFuer('portfolio_trend') +
        heute.year * 10000 + heute.month * 100 + heute.day;
    return trendPool[Random(seed).nextInt(trendPool.length)];
  }

  // ── Laden ─────────────────────────────────────────────────────────────────

  static Future<PortfolioStatus> ladeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final heute = _heuteDatum();
    final heuteStr = _formatDatum(heute);

    final letzterSpieltag = prefs.getString(_kLetzterSpieltag);

    // Streak bricht sanft, wenn ein Tag verpasst wurde (Kapital bleibt unberührt).
    var streak = prefs.getInt(_kStreak) ?? 0;
    if (letzterSpieltag != null && letzterSpieltag != heuteStr) {
      final gestern = heute.subtract(const Duration(days: 1));
      if (_parseDatum(letzterSpieltag).isBefore(gestern)) {
        streak = 0;
        await prefs.setInt(_kStreak, 0);
      }
    }

    final kapital = prefs.getDouble(_kKapital) ?? kStartKapital;
    final rekord  = prefs.getDouble(_kRekord) ?? kapital;
    final verlaufRoh = prefs.getStringList(_kVerlauf) ?? [];
    final verlauf = verlaufRoh.map(double.parse).toList();

    final trend = _heutigerTrend(heute);

    return PortfolioStatus(
      kapital: kapital,
      rekordKapital: rekord,
      streak: streak,
      verlauf: verlauf,
      trend: trend,
      heuteGespielt: letzterSpieltag == heuteStr,
      heute: heuteStr,
    );
  }

  // ── Tag abschließen ──────────────────────────────────────────────────────────

  static Future<PortfolioStatus> schliesseTagAb({
    required double neuesKapital,
    required double gewichtetesRisiko,
    required double effektiveLaenderzahl,
    required int newsTrefferAnzahl,
    required int trendTrefferAnzahl,
    required int anzahlLaender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final heute = _heuteDatum();
    final heuteStr = _formatDatum(heute);

    final kapitalGeklemmt = neuesKapital.clamp(kFloor, double.infinity).toDouble();
    final rekordBisher = prefs.getDouble(_kRekord) ?? kStartKapital;
    final rekordNeu = max(rekordBisher, kapitalGeklemmt);

    // Tages-Rendite in % ggü. dem Kapital VOR diesem Abschluss — Basis für
    // die "Ø Rendite"-Anzeige im Profil (analog zur Punkte-Summe der anderen
    // drei Challenges).
    final kapitalVorher = prefs.getDouble(_kKapital) ?? kStartKapital;
    final renditeHeute = (kapitalGeklemmt - kapitalVorher) / kapitalVorher * 100;

    final letzterSpieltag = prefs.getString(_kLetzterSpieltag);
    final streakBisher = prefs.getInt(_kStreak) ?? 0;
    final gestern = _formatDatum(heute.subtract(const Duration(days: 1)));
    final streakNeu = (letzterSpieltag == gestern) ? streakBisher + 1 : 1;

    final verlaufRoh = prefs.getStringList(_kVerlauf) ?? [];
    final verlaufNeu = [...verlaufRoh, kapitalGeklemmt.toString()];
    if (verlaufNeu.length > 30) {
      verlaufNeu.removeRange(0, verlaufNeu.length - 30);
    }

    await prefs.setDouble(_kKapital, kapitalGeklemmt);
    await prefs.setDouble(_kRekord, rekordNeu);
    await prefs.setInt(_kStreak, streakNeu);
    await prefs.setString(_kLetzterSpieltag, heuteStr);
    await prefs.setStringList(_kVerlauf, verlaufNeu);

    await prefs.setInt(_kStilTage, (prefs.getInt(_kStilTage) ?? 0) + 1);
    await prefs.setInt(_kStilAuswahlen,
        (prefs.getInt(_kStilAuswahlen) ?? 0) + anzahlLaender);
    await prefs.setDouble(_kStilRisikoSumme,
        (prefs.getDouble(_kStilRisikoSumme) ?? 0) + gewichtetesRisiko);
    await prefs.setDouble(_kStilEffektivSumme,
        (prefs.getDouble(_kStilEffektivSumme) ?? 0) + effektiveLaenderzahl);
    await prefs.setInt(_kStilNewsTreffer,
        (prefs.getInt(_kStilNewsTreffer) ?? 0) + newsTrefferAnzahl);
    await prefs.setInt(_kStilTrendTreffer,
        (prefs.getInt(_kStilTrendTreffer) ?? 0) + trendTrefferAnzahl);

    await ChallengeRekordService.summeErhoehen('portfolio', renditeHeute);
    await DailyChallenge.markDone('portfolio');

    return ladeStatus();
  }

  /// DEBUG: Nimmt den heutigen Portfolio-Tag zurück.
  ///
  /// Anders als die drei Punkte-Challenges hinterlässt das Portfolio mehr als
  /// eine Erledigt-Marke: Es schreibt ein neues Kapital und hängt es an den
  /// Verlauf. Beides wird hier rückgängig gemacht, sonst spielte man beim
  /// zweiten Durchgang des Tages auf einem Kapital weiter, das die erste
  /// Runde schon verändert hat — und der Verlauf bekäme zwei Punkte für
  /// denselben Tag.
  ///
  /// Das Kapital kommt aus dem Verlauf selbst: Sein vorletzter Eintrag ist
  /// der Stand vor dem heutigen Abschluss. Gibt es keinen, war heute der
  /// erste Tag überhaupt — dann gilt wieder das Startkapital.
  ///
  /// NICHT zurückgerechnet werden Rekord, Serie und die Spielstil-Summen: Für
  /// die fehlen die Vorwerte, sie liessen sich nur raten.
  static Future<void> debugHeuteZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    final verlauf = prefs.getStringList(_kVerlauf) ?? [];
    if (verlauf.isNotEmpty) {
      verlauf.removeLast();
      await prefs.setStringList(_kVerlauf, verlauf);
    }
    final vorher = verlauf.isEmpty
        ? kStartKapital
        : double.tryParse(verlauf.last) ?? kStartKapital;
    await prefs.setDouble(_kKapital, vorher);
    await prefs.remove(_kLetzterSpieltag);
  }

  // ── Spielstil-Rohdaten (für Phase 8) ─────────────────────────────────────────

  static Future<PortfolioSpielstilRohdaten> ladeSpielstilRohdaten() async {
    final prefs = await SharedPreferences.getInstance();
    return PortfolioSpielstilRohdaten(
      tage: prefs.getInt(_kStilTage) ?? 0,
      auswahlen: prefs.getInt(_kStilAuswahlen) ?? 0,
      risikoSumme: prefs.getDouble(_kStilRisikoSumme) ?? 0,
      effektivSumme: prefs.getDouble(_kStilEffektivSumme) ?? 0,
      newsTreffer: prefs.getInt(_kStilNewsTreffer) ?? 0,
      trendTreffer: prefs.getInt(_kStilTrendTreffer) ?? 0,
    );
  }
}
