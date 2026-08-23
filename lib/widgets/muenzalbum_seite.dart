import 'dart:math';
import 'package:flutter/material.dart';
import '../data/abzeichen_data.dart';
import 'muenze_widget.dart';

const _kategorien = [
  (AbzeichenKategorie.serien, 'Serien'),
  (AbzeichenKategorie.kontinente, 'Kontinente'),
  (AbzeichenKategorie.meilensteine, 'Meilensteine'),
  (AbzeichenKategorie.challenges, 'Challenges'),
];

/// Die Abzeichen-Galerie im "Münzalbum"-Design — zweite Seite des
/// Profilbild-Dialogs, per Wischen erreichbar. Lederartiger Hintergrund,
/// 4 Kategorie-Seiten (Reiter + intern per Wischen navigierbar), Abzeichen
/// als metallische Münzen (freigeschaltet) bzw. gestrichelte Umrisse
/// (gesperrt).
class MuenzalbumSeite extends StatefulWidget {
  final Set<String> freigeschaltete;
  /// Wird ausgelöst, wenn auf der ersten Kategorie-Seite noch weiter nach
  /// rechts gewischt wird (Overscroll) — signalisiert dem äußeren PageView
  /// (Profilbild <-> Münzalbum), dass die Geste zu ihm gehört, da das innere
  /// Kategorie-PageView sonst jeden Wisch auf derselben Achse zuerst
  /// abfängt.
  final VoidCallback? onSwipeZurueckZuProfilbild;

  const MuenzalbumSeite({
    super.key,
    required this.freigeschaltete,
    this.onSwipeZurueckZuProfilbild,
  });

  @override
  State<MuenzalbumSeite> createState() => _MuenzalbumSeiteState();
}

class _MuenzalbumSeiteState extends State<MuenzalbumSeite> {
  late final PageController _kategorieController;
  int _kategorieIndex = 0;
  bool _rueckwaertsAusgeloest = false;

  @override
  void initState() {
    super.initState();
    _kategorieController = PageController();
  }

  @override
  void dispose() {
    _kategorieController.dispose();
    super.dispose();
  }

  void _gehZu(int i) {
    _kategorieController.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  /// Erkennt, ob auf der ersten Kategorie-Seite über den Anfang hinaus
  /// gewischt wird (negativer Overscroll bei Index 0) und reicht das dann
  /// EINMAL pro Geste an das äußere PageView weiter, statt dass das innere
  /// Kategorie-PageView den Wisch stillschweigend verschluckt.
  bool _aufScrollNotification(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll < 0 && _kategorieIndex == 0) {
      if (!_rueckwaertsAusgeloest) {
        _rueckwaertsAusgeloest = true;
        widget.onSwipeZurueckZuProfilbild?.call();
      }
    } else if (n is ScrollEndNotification) {
      _rueckwaertsAusgeloest = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Nur die erspielbaren mitzählen — passend zum Nenner unten. Eine
    // verliehene Ehrenmünze darf den Zähler nicht über sein Maximum treiben.
    final anzahlErreicht = sammelbareAbzeichen
        .where((a) => widget.freigeschaltete.contains(a.id))
        .length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8D6E52), Color(0xFF6F5540)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            // Gezählt wird über die ERSPIELBAREN Münzen. Die Ehrenmünzen
            // stehen bewusst nicht im Nenner — sonst bliebe für jeden, der
            // keine hat, für immer eine Lücke stehen, obwohl er alles
            // Erreichbare gesammelt hat.
            '$anzahlErreicht / ${sammelbareAbzeichen.length} Münzen gesammelt',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          _KategorieReiter(
            index: _kategorieIndex,
            titel: [for (final k in _kategorien) k.$2],
            onTap: _gehZu,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _aufScrollNotification,
              child: PageView(
                controller: _kategorieController,
                onPageChanged: (i) => setState(() => _kategorieIndex = i),
                children: [
                  for (final k in _kategorien)
                    _KategorieSeite(
                      kategorie: k.$1,
                      freigeschaltete: widget.freigeschaltete,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kategorie-Reiter ────────────────────────────────────────────────────────

class _KategorieReiter extends StatelessWidget {
  final int index;
  final List<String> titel;
  final ValueChanged<int> onTap;
  const _KategorieReiter({
    required this.index,
    required this.titel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < titel.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: i == index
                          ? const Color(0xFFEFE1C8)
                          : const Color(0xFFEFE1C8).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      titel[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: i == index
                            ? const Color(0xFF6F5540)
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Kategorie-Seite (Grid) ────────────────────────────────────────────────────

class _KategorieSeite extends StatelessWidget {
  final AbzeichenKategorie kategorie;
  final Set<String> freigeschaltete;
  const _KategorieSeite({required this.kategorie, required this.freigeschaltete});

  static const _challengeGruppen = [
    ('preis', 'Das große Schätzen'),
    ('higher_lower', 'Higher or Lower'),
    ('ranking_game', 'Ranking Game'),
    ('portfolio', 'Portfolio'),
  ];

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: 12,
    mainAxisSpacing: 16,
    childAspectRatio: 0.8,
  );

  @override
  Widget build(BuildContext context) {
    final abzeichenDieserKategorie =
        alleAbzeichen.where((a) => a.kategorie == kategorie).toList();

    if (kategorie != AbzeichenKategorie.challenges) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        gridDelegate: _gridDelegate,
        itemCount: abzeichenDieserKategorie.length,
        itemBuilder: (_, i) => _MuenzSlot(
          abzeichen: abzeichenDieserKategorie[i],
          freigeschaltet: freigeschaltete.contains(abzeichenDieserKategorie[i].id),
        ),
      );
    }

    // Tages-Challenges: 12 Abzeichen in 4 Untergruppen (je Challenge) mit
    // kleinen Zwischen-Überschriften statt einem einzigen 12er-Grid.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final gruppe in _challengeGruppen) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              gruppe.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          GridView(
            gridDelegate: _gridDelegate,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final a in abzeichenDieserKategorie
                  .where((a) => a.id.startsWith('punkte_${gruppe.$1}_')))
                _MuenzSlot(
                  abzeichen: a,
                  freigeschaltet: freigeschaltete.contains(a.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // ── Ehrenmünzen ───────────────────────────────────────────────────
        //
        // Hängen unten an der LETZTEN Album-Seite, nicht an einem eigenen
        // Reiter: fünf Reiter schneiden auf 320 und 360 px schon bei
        // normaler Schriftgrösse "Meilensteine" und "Challenges" ab. Damit
        // stehen sie zugleich ganz am Ende der Mappe, was zu einer Ehrung
        // besser passt als ein eigener Abschnitt mittendrin.
        if (ehrenAbzeichen.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              'Ehrung',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          GridView(
            gridDelegate: _gridDelegate,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final a in ehrenAbzeichen)
                _MuenzSlot(
                  abzeichen: a,
                  freigeschaltet: freigeschaltete.contains(a.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Münz-Slot (Album-Fach) ────────────────────────────────────────────────────

class _MuenzSlot extends StatefulWidget {
  final Abzeichen abzeichen;
  final bool freigeschaltet;
  const _MuenzSlot({required this.abzeichen, required this.freigeschaltet});

  @override
  State<_MuenzSlot> createState() => _MuenzSlotState();
}

class _MuenzSlotState extends State<_MuenzSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;

  @override
  void initState() {
    super.initState();
    _flipCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _tippen() async {
    if (!widget.freigeschaltet) {
      // Gesperrte Münze: keine Animation, Beschreibung erscheint sofort in
      // gedämpfter Farbe — der Unterschied zu "besessen" soll auch haptisch
      // spürbar sein.
      _zeigeInfo(gesperrt: true);
      return;
    }
    await _flipCtrl.forward(from: 0);
    if (!mounted) return;
    _zeigeInfo(gesperrt: false);
  }

  void _zeigeInfo({required bool gesperrt}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AbzeichenInfoSheet(abzeichen: widget.abzeichen, gesperrt: gesperrt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tippen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF5A4433),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              // OverflowBox, da die Münze (114.24px) bewusst größer als ihr
              // Fach (76px) sein soll -> ohne das würde der Fach-Container
              // die Münze auf 76px zusammenstauchen (das Icon "überquillt"
              // dabei sichtbar, weil Text/Icon-Glyphen nicht wie ein Bild
              // an die Layout-Box geklemmt werden, das Bild selbst aber
              // schon -> ohne OverflowBox wächst nur das Icon, nicht die
              // Münze selbst).
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: AnimatedBuilder(
                  animation: _flipCtrl,
                  builder: (_, child) {
                    final winkel = _flipCtrl.value * 2 * pi;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(winkel),
                      child: child,
                    );
                  },
                  child: MuenzenWidget(
                    abzeichen: widget.abzeichen,
                    // Gesperrte Münze (gestrichelter Umriss) bleibt bei der
                    // ursprünglichen Fach-Größe -> nur die freigeschaltete
                    // Münze selbst ist bewusst größer als ihr Fach.
                    groesse: widget.freigeschaltet ? 95 : 68,
                    erreicht: widget.freigeschaltet,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.abzeichen.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: widget.freigeschaltet
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info-Bottom-Sheet ─────────────────────────────────────────────────────────

class _AbzeichenInfoSheet extends StatelessWidget {
  final Abzeichen abzeichen;
  final bool gesperrt;
  const _AbzeichenInfoSheet({required this.abzeichen, required this.gesperrt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: gesperrt ? const Color(0xFFEAEAE5) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD0CEC8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          MuenzenWidget(abzeichen: abzeichen, groesse: 94.08, erreicht: !gesperrt),
          const SizedBox(height: 14),
          Text(
            abzeichen.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: gesperrt ? const Color(0xFF888888) : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gesperrt ? 'Noch nicht erreicht: ${abzeichen.beschreibung}' : abzeichen.beschreibung,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: gesperrt ? const Color(0xFFAAAAAA) : const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}
