import 'package:flutter/material.dart';
import '../data/portfolio_daten.dart';
import '../l10n/uebersetzungen.dart';
import '../services/portfolio_engine.dart';
import '../utils/portfolio_format.dart';
import 'portfolio_flagge.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Länder-Aufschlüsselungskarte
// Gemeinsam genutzt von Screen 3 (Auflösung) und dem Beispiel-Screen, damit
// Begriffe und Formatierung garantiert übereinstimmen.
// ══════════════════════════════════════════════════════════════════════════════

class PortfolioLandKarte extends StatelessWidget {
  final PortfolioLandBeitrag beitrag;

  /// Ohne eigenen Rahmen — für den Fall, dass die Karte schon in einem
  /// Rahmen steckt.
  ///
  /// In der Auflösung liegt sie seit dem Umbau auf wischbare Karten in einer
  /// [WischKarte], und die bringt Fläche, Rand und Rundung selbst mit. Zwei
  /// Rahmen ineinander sahen aus wie ein Fehler, nicht wie Absicht.
  ///
  /// Der Beispiel-Screen zeigt sie weiterhin frei auf dem Hintergrund und
  /// braucht den Rahmen — deshalb ein Schalter und kein Entfernen.
  final bool ohneRahmen;

  const PortfolioLandKarte({
    super.key,
    required this.beitrag,
    this.ohneRahmen = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = beitrag;
    final positiv = b.beitragProzent >= 0;
    return Container(
      margin: EdgeInsets.only(bottom: ohneRahmen ? 0 : 10),
      padding: ohneRahmen
          ? const EdgeInsets.symmetric(vertical: 6)
          : const EdgeInsets.all(14),
      decoration: ohneRahmen
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEAEAE5)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFF1A1A1A),
                    offset: Offset(0, 3),
                    blurRadius: 0),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PortfolioFlagge(iso: b.iso, width: 28, height: 19, radius: 3),
              const SizedBox(width: 8),
              Expanded(
                child: Text(landName(b.iso),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text(t('{n}% Gewicht', {'n': '${b.anteilProzent}'}),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 10),
          PortfolioKomponenteZeile(label: t('Basis'), wert: b.basis),
          if (b.news.abs() > 0.05)
            PortfolioKomponenteZeile(
                label: b.newsNamen.isEmpty
                    ? t('News')
                    : t('News ({n})', {'n': b.newsNamen.join(", ")}),
                wert: b.news),
          if (b.trend.abs() > 0.05) PortfolioKomponenteZeile(label: t('Trend'), wert: b.trend),
          PortfolioKomponenteZeile(label: t('Schwankung 🎲'), wert: b.schwankung),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('Tagesrendite'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(fmtProzent(b.tagesRendite),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('Beitrag (×{n}%)', {'n': '${b.anteilProzent}'}),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              Text(fmtProzent(b.beitragProzent),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: positiv
                          ? const Color(0xFF4A9E4A)
                          : const Color(0xFFE53935))),
            ],
          ),
        ],
      ),
    );
  }
}

class PortfolioKomponenteZeile extends StatelessWidget {
  final String label;
  final double wert;
  const PortfolioKomponenteZeile({super.key, required this.label, required this.wert});

  @override
  Widget build(BuildContext context) {
    final positiv = wert >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          ),
          Text(fmtProzent(wert),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: positiv
                      ? const Color(0xFF4A9E4A)
                      : const Color(0xFFE53935))),
        ],
      ),
    );
  }
}
