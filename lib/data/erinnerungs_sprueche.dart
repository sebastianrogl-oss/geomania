import 'dart:math';

/// Texte für die täglichen Erinnerungen und die Streak-Warnung.
///
/// Derselbe Ton wie die Halbzeit-Sprüche (data/halbzeit_sprueche.dart): kurz,
/// freundlich, Coiny spricht. Bewusst KEIN Druck und keine Schuldgefühle —
/// eine Benachrichtigung, die sich wie eine Mahnung liest, wird abgeschaltet.
///
/// Die deutschen Texte sind zugleich die Übersetzungsschlüssel; die englischen
/// Fassungen stehen in l10n/uebersetzungen_erinnerungen.dart und sind
/// sinngemäß übersetzt, nicht wörtlich.
///
/// Jeder Eintrag ist ein Paar aus Titel und Text: Android und iOS zeigen beide
/// Zeilen, der Titel fett. Ein Eintrag ohne Text sähe auf beiden Plattformen
/// unfertig aus.
class ErinnerungsSprueche {
  /// Tägliche Erinnerung — kein Bezug auf eine Serie, die kann fehlen.
  static const taeglich = <(String, String)>[
    ('Coiny wartet', 'Eine Station gefällig?'),
    ('Zeit für ein paar Länder', 'Ein paar Minuten reichen.'),
    ('Kurze Runde?', 'Die Welt ist groß genug für heute.'),
    ('Eine Station passt noch rein', 'Such dir eine aus.'),
    ('Die Weltkarte ruft', 'Schaust du vorbei?'),
  ];

  /// Streak-Warnung — {tage} wird durch die laufende Serie ersetzt.
  ///
  /// Die Zahl darf vorkommen und steht bewusst mal im Titel, mal im Text:
  /// stünde sie immer an derselben Stelle, fiele die Rotation kaum auf.
  static const streak = <(String, String)>[
    ('Deine {tage}-Tage-Serie läuft ab', 'Noch eine Station?'),
    ('{tage} Tage am Stück', 'Heute fehlt noch einer.'),
    ('Serie in Gefahr', '{tage} Tage wären schade drum.'),
    ('Noch ist der Tag nicht rum', 'Deine {tage}-Tage-Serie wartet.'),
    ('{tage} Tage — weiter so?', 'Eine Station genügt.'),
  ];

  static final _rng = Random();

  /// Zieht [anzahl] Indizes aus einem "Beutel", der jeden Eintrag genau einmal
  /// enthält, bevor er neu gemischt wird — echtes Rotieren ohne Wiederholung
  /// statt reinem Zufall, der denselben Spruch zweimal hintereinander liefern
  /// könnte.
  ///
  /// [rest] ist der noch nicht verbrauchte Beutel des letzten Aufrufs; die
  /// Methode gibt den neuen Reststand über [restNachher] zurück, damit er in
  /// den Prefs überdauert. Ohne dieses Weiterreichen begänne jede Neuplanung
  /// wieder bei demselben Spruch.
  ///
  /// Beim Nachfüllen wird der erste Eintrag des neuen Beutels vom zuletzt
  /// gezogenen weggetauscht — sonst käme an der Beutelgrenze doch eine
  /// Dopplung.
  ///
  /// Das greift nur INNERHALB eines Aufrufs: welcher Spruch beim vorigen
  /// Aufruf zuletzt dran war, wird nicht gespeichert. Leert sich der Beutel
  /// genau am Ende eines Aufrufs, kann sich der Spruch an dieser einen Stelle
  /// also doch wiederholen. Dafür einen zweiten Wert in den Prefs zu halten,
  /// wäre der Sache nicht angemessen — zumal der Spieler in aller Regel nur
  /// die erste Benachrichtigung jedes Vorrats zu sehen bekommt.
  static List<int> ziehe(
    int anzahl,
    int gesamt,
    List<int> rest, {
    void Function(List<int>)? restNachher,
  }) {
    final beutel = List<int>.of(rest);
    final gezogen = <int>[];
    int? zuletzt;

    for (int i = 0; i < anzahl; i++) {
      if (beutel.isEmpty) {
        final neu = List<int>.generate(gesamt, (j) => j)..shuffle(_rng);
        if (neu.length > 1 && neu.first == zuletzt) {
          final tausch = neu.removeAt(0);
          neu.insert(1 + _rng.nextInt(neu.length), tausch);
        }
        beutel.addAll(neu);
      }
      final index = beutel.removeAt(0);
      gezogen.add(index);
      zuletzt = index;
    }

    restNachher?.call(beutel);
    return gezogen;
  }
}
