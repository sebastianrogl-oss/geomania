import 'package:flutter/material.dart';
import '../../data/portfolio_daten.dart';
import '../../services/challenge_ergebnis_service.dart';
import '../../services/portfolio_engine.dart';
import '../../services/portfolio_service.dart';
import 'portfolio_aufloesung_screen.dart';

/// Lädt das heute bereits erzielte Portfolio-Ergebnis aus der lokalen
/// Speicherung und zeigt es über die bestehende PortfolioAufloesungScreen
/// erneut an — startet KEINE neue Investitionsrunde (für "Ergebnisse" im
/// Start-Screen).
class PortfolioErgebnisAnsichtScreen extends StatefulWidget {
  const PortfolioErgebnisAnsichtScreen({super.key});

  @override
  State<PortfolioErgebnisAnsichtScreen> createState() =>
      _PortfolioErgebnisAnsichtScreenState();
}

class _PortfolioErgebnisAnsichtScreenState
    extends State<PortfolioErgebnisAnsichtScreen> {
  PortfolioTagesErgebnis? _ergebnis;
  PortfolioStatus? _status;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final status = await PortfolioService.ladeStatus();
    final detail = await ChallengeErgebnisService.laden('portfolio');
    final roh = detail?['ergebnis'] as Map<String, dynamic>?;
    if (roh == null) {
      if (mounted) setState(() => _status = status);
      return;
    }

    final beitraege = (roh['beitraege'] as List<dynamic>).map((b) {
      final m = b as Map<String, dynamic>;
      return PortfolioLandBeitrag(
        iso: m['iso'] as String,
        anteilProzent: m['anteilProzent'] as int,
        basis: (m['basis'] as num).toDouble(),
        news: (m['news'] as num).toDouble(),
        newsNamen: (m['newsNamen'] as List<dynamic>).cast<String>(),
        trend: (m['trend'] as num).toDouble(),
        schwankung: (m['schwankung'] as num).toDouble(),
        tagesRendite: (m['tagesRendite'] as num).toDouble(),
        beitragProzent: (m['beitragProzent'] as num).toDouble(),
      );
    }).toList();

    final erfuellteAllianzenRoh =
        (roh['erfuellteAllianzen'] as List<dynamic>?) ?? [];
    final erfuellteAllianzen = erfuellteAllianzenRoh.map((a) {
      final m = a as Map<String, dynamic>;
      return MarktNews(
        typ: NewsTyp.kontinentsAllianz,
        titel: m['titel'] as String,
        klartext: '',
        gewinner: const [],
        verlierer: const [],
        allianzKontinente: (m['allianzKontinente'] as List<dynamic>).cast<String>(),
        allianzBonus: (m['allianzBonus'] as num).toDouble(),
      );
    }).toList();

    final erfuellteSektorKombosRoh =
        (roh['erfuellteSektorKombos'] as List<dynamic>?) ?? [];
    final erfuellteSektorKombos = erfuellteSektorKombosRoh.map((a) {
      final m = a as Map<String, dynamic>;
      return MarktNews(
        typ: NewsTyp.sektorKombination,
        titel: m['titel'] as String,
        klartext: '',
        gewinner: const [],
        verlierer: const [],
        sektorKombo: (m['sektorKombo'] as List<dynamic>).cast<String>(),
        sektorKomboBonus: (m['sektorKomboBonus'] as num).toDouble(),
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      _ergebnis = PortfolioTagesErgebnis(
        beitraege: beitraege,
        kontinentsBonus: roh['kontinentsBonus'] as int,
        allianzBonus: (roh['allianzBonus'] as num?)?.toDouble() ?? 0.0,
        erfuellteAllianzen: erfuellteAllianzen,
        sektorKomboBonus: (roh['sektorKomboBonus'] as num?)?.toDouble() ?? 0.0,
        erfuellteSektorKombos: erfuellteSektorKombos,
        depotRenditeGesamt: (roh['depotRenditeGesamt'] as num).toDouble(),
        altesKapital: (roh['altesKapital'] as num).toDouble(),
        neuesKapital: (roh['neuesKapital'] as num).toDouble(),
        gewichtetesRisiko: (roh['gewichtetesRisiko'] as num).toDouble(),
        effektiveLaenderzahl: (roh['effektiveLaenderzahl'] as num).toDouble(),
        newsTrefferAnzahl: roh['newsTrefferAnzahl'] as int,
        trendTrefferAnzahl: roh['trendTrefferAnzahl'] as int,
      );
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ergebnis = _ergebnis;
    final status = _status;
    if (ergebnis == null || status == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F0E8),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF4A9E4A))),
      );
    }
    return PortfolioAufloesungScreen(
        ergebnis: ergebnis, status: status, nurAnsicht: true);
  }
}
