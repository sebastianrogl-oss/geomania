import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';

/// Überspringt eine GANZE Lernpfad-Station gegen eine Rewarded Ad — verwendet
/// an zwei Stellen: rechts in der Quiz-AppBar (station_quiz_screen.dart, weiß
/// auf dunkelgrünem Grund) UND auf dem Stations-Start-Screen (_StationSheet
/// in home_screen.dart, grau auf weißem Grund, [color] entsprechend gesetzt).
/// Bewusst schlicht als Text+Icon ohne Container/Rahmen/Hintergrund, damit er
/// sich dezent einfügt statt als eigenständiger Button abzustechen. Das
/// Filmklappen-Icon signalisiert eine Werbung (statt eines Skip-Symbols), da
/// das Überspringen an das Ansehen einer Rewarded Ad gekoppelt ist.
class LevelSkipButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final Color color;
  const LevelSkipButton({
    super.key,
    required this.loading,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(Icons.movie_creation_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(t('Level überspringen'),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
