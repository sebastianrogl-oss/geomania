// HINWEIS: Dieser Screen wird aktuell NICHT verwendet — main.dart bindet für
// den Home-Tab home_screen.dart ein (der den Lernpfad als Zickzack-Pfad mit
// Maskottchen rendert), nicht LernpfadScreen. Diese Datei ist die einzige
// verbleibende Referenz auf LernpfadScreen im Code (siehe grep). Übersetzte
// Strings hier landen dadurch nirgends sichtbar — die eigentlichen
// UI-Übersetzungen für den Lernpfad liegen in home_screen.dart.
import 'package:flutter/material.dart';
import '../data/lernpfad_data.dart';
import '../l10n/uebersetzungen.dart';
import '../services/fortschritt_service.dart';
import '../widgets/kontinent_hintergrund.dart';
import '../widgets/station_emoji.dart';
import 'station_quiz_screen.dart';
import '../theme/app_theme.dart';

class LernpfadScreen extends StatefulWidget {
  const LernpfadScreen({super.key});

  @override
  State<LernpfadScreen> createState() => _LernpfadScreenState();
}

class _LernpfadScreenState extends State<LernpfadScreen> {
  LernpfadSnapshot? _snap;
  LernWelt _aktivWelt = lernwelten.first;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FortschrittService.ladeSnapshot();
    if (!mounted) return;
    setState(() => _snap = snap);
  }

  Future<void> _stationTippen(LernStation station) async {
    final details = _snap?.detailsFor(station.id);
    final istUmriss = station.modus == LernModus.umrissBild ||
        station.modus == LernModus.umrissMultiple;
    if (details == null || (!details.istFreigeschaltet && !istUmriss)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StationQuizScreen(station: station)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    return Scaffold(
      backgroundColor: kHintergrund,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(t('Lernpfad'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: snap == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _WeltLeiste(
                  snap: snap,
                  aktiv: _aktivWelt,
                  onWahl: (w) => setState(() {
                    _aktivWelt = w;
                    _expanded.clear();
                  }),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: KontinentHintergrund(
                      key: ValueKey(_aktivWelt.id),
                      kontinentId: _aktivWelt.id,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final a in _aktivWelt.abschnitte)
                            _AbschnittKarte(
                              abschnitt: a,
                              snap: snap,
                              expanded: _expanded.contains(a.id),
                              onToggle: () => setState(() => _expanded.contains(a.id)
                                  ? _expanded.remove(a.id)
                                  : _expanded.add(a.id)),
                              onStationTap: _stationTippen,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Welt-Leiste ───────────────────────────────────────────────────────────────

class _WeltLeiste extends StatelessWidget {
  final LernpfadSnapshot snap;
  final LernWelt aktiv;
  final void Function(LernWelt) onWahl;

  const _WeltLeiste(
      {required this.snap, required this.aktiv, required this.onWahl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B3A2D),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: lernwelten.map((w) {
            final frei    = snap.istWeltFrei(w.id);
            final istAktiv = aktiv.id == w.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: frei ? () => onWahl(w) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: istAktiv
                        ? const Color(0xFF4A9E4A)
                        : frei
                            ? const Color(0xFF2A4A3A)
                            : const Color(0xFF1E3529),
                    borderRadius: BorderRadius.circular(20),
                    border: istAktiv
                        ? Border.all(color: Colors.white24, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(w.emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        w.name,
                        style: TextStyle(
                          color: istAktiv
                              ? Colors.white
                              : frei
                                  ? const Color(0xFF8BC8A0)
                                  : const Color(0xFF4A6A5A),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (!frei) ...[
                        const SizedBox(width: 4),
                        const Text('🔒', style: TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Abschnitt-Karte ───────────────────────────────────────────────────────────

class _AbschnittKarte extends StatelessWidget {
  final LernAbschnitt abschnitt;
  final LernpfadSnapshot snap;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(LernStation) onStationTap;

  const _AbschnittKarte({
    required this.abschnitt,
    required this.snap,
    required this.expanded,
    required this.onToggle,
    required this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    final frei = snap.istAbschnittFrei(abschnitt.id);
    final abgeschlossen = snap.istAbschnittAbgeschlossen(abschnitt.id);
    final doneCount = abschnitt.stationen
        .where((s) => snap.detailsFor(s.id).istAbgeschlossen)
        .length;
    final progress = snap.abschnittFortschritt(abschnitt.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: frei ? const Color(0xFFEAEAE5) : const Color(0xFFEEEDE9),
        borderRadius: BorderRadius.circular(16),
        border: abgeschlossen
            ? Border.all(color: const Color(0xFF4A9E4A), width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          InkWell(
            onTap: frei ? onToggle : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('Abschnitt {n}', {'n': '${abschnitt.stufe}'}),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: frei
                                    ? const Color(0xFF1a1a1a)
                                    : const Color(0xFF999999),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t(abschnitt.untertitel),
                              style: TextStyle(
                                fontSize: 12,
                                color: frei
                                    ? const Color(0xFF666666)
                                    : const Color(0xFFBBBBBB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!frei)
                        const Text('🔒', style: TextStyle(fontSize: 18))
                      else if (abgeschlossen)
                        const Text('✅', style: TextStyle(fontSize: 18))
                      else ...[
                        Text(
                          '$doneCount/${abschnitt.stationen.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A9E4A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFF666666),
                          size: 20,
                        ),
                      ],
                      if (abschnitt.hatTimer) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: t('15-Sekunden-Timer pro Frage'),
                          child: const Text('⏱️', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ],
                  ),
                  if (frei) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFCCCCC6),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4A9E4A)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── Stationen ───────────────────────────────────────────────────────
          if (frei && expanded) ...[
            const Divider(height: 1, color: Color(0xFFD4D4CC)),
            ...abschnitt.stationen.map((s) => _StationZeile(
                  station: s,
                  details: snap.detailsFor(s.id),
                  abschnittFrei: frei,
                  onTap: () => onStationTap(s),
                )),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

// ── Station-Zeile ─────────────────────────────────────────────────────────────

class _StationZeile extends StatelessWidget {
  final LernStation station;
  final StationDetails details;
  final bool abschnittFrei;
  final VoidCallback onTap;

  const _StationZeile({
    required this.station,
    required this.details,
    required this.abschnittFrei,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String untertitel = details.istGestartet
        ? t('Fortsetzen ({a}/{b})', {
            'a': '${details.aktuellerFragenIndex}',
            'b': '${station.fragenAnzahl}',
          })
        : lernModusFragenLabel(station);

    final StationStatus status;
    if (details.istAbgeschlossen) {
      status = StationStatus.erledigt;
    } else if (details.istFreigeschaltet) {
      status = StationStatus.aktuell;
    } else {
      status = StationStatus.gesperrt;
    }

    return InkWell(
      onTap: details.istFreigeschaltet ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            StationButton(modus: station.modus, status: status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lernModusLabel(station.modus),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: abschnittFrei
                          ? const Color(0xFF1a1a1a)
                          : const Color(0xFFBBBBBB),
                    ),
                  ),
                  Text(
                    untertitel,
                    style: TextStyle(
                      fontSize: 11,
                      color: details.istGestartet
                          ? const Color(0xFF4A9E4A)
                          : const Color(0xFF888888),
                      fontWeight: details.istGestartet
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (details.istFreigeschaltet && !details.istAbgeschlossen)
              const Icon(Icons.chevron_right,
                  color: Color(0xFFCCCCCC), size: 18),
          ],
        ),
      ),
    );
  }
}
