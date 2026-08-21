/// Englische Fassungen für die täglichen Erinnerungen, die Streak-Warnung, den
/// Erlaubnis-Dialog und den Einstellungs-Bereich.
///
/// Die Benachrichtigungstexte sind sinngemäß übersetzt, nicht wörtlich: der
/// Ton (kurz, freundlich, kein Druck) wiegt schwerer als die genaue Wortwahl.
/// "Die Weltkarte ruft" wird deshalb "The world map is calling" und nicht
/// "The world map calls".
///
/// Die Platzhalter {tage}, {zeit} und {n} müssen in beiden Sprachen
/// vorkommen — t() ersetzt sie erst NACH dem Nachschlagen.
const Map<String, String> uebersetzungenErinnerungen = {
  // ── Tägliche Erinnerung ────────────────────────────────────────────────────
  'Coiny wartet': 'Coiny is waiting',
  'Eine Station gefällig?': 'Fancy a station?',
  'Zeit für ein paar Länder': 'Time for a few countries',
  'Ein paar Minuten reichen.': 'A couple of minutes will do.',
  'Kurze Runde?': 'Quick round?',
  'Die Welt ist groß genug für heute.': 'The world is big enough for today.',
  'Eine Station passt noch rein': 'There is room for one station',
  'Such dir eine aus.': 'Take your pick.',
  'Die Weltkarte ruft': 'The world map is calling',
  'Schaust du vorbei?': 'Coming by?',

  // ── Streak-Warnung ─────────────────────────────────────────────────────────
  'Deine {tage}-Tage-Serie läuft ab': 'Your {tage}-day streak is running out',
  'Noch eine Station?': 'One more station?',
  '{tage} Tage am Stück': '{tage} days in a row',
  'Heute fehlt noch einer.': 'Today is still missing one.',
  'Serie in Gefahr': 'Streak at risk',
  '{tage} Tage wären schade drum.': '{tage} days would be a shame to lose.',
  'Noch ist der Tag nicht rum': 'The day is not over yet',
  'Deine {tage}-Tage-Serie wartet.': 'Your {tage}-day streak is waiting.',
  '{tage} Tage — weiter so?': '{tage} days — keep it going?',
  'Eine Station genügt.': 'One station is enough.',

  // ── Erlaubnis-Dialog ───────────────────────────────────────────────────────
  'Sollen wir dich erinnern?': 'Shall we remind you?',
  'Dann bleibt deine Serie am Leben.': 'That keeps your streak alive.',
  'Ja, gerne': 'Yes, please',
  'Später': 'Later',

  // ── Einstellungen ──────────────────────────────────────────────────────────
  'ERINNERUNGEN': 'REMINDERS',
  'Erinnerungen': 'Reminders',
  'Erinnerungszeit': 'Reminder time',
  'Wieder automatisch ermitteln': 'Work it out automatically again',
  'Streak-Warnung': 'Streak warning',
  '{zeit} · von dir gesetzt': '{zeit} · set by you',
  '{zeit} · Vorgabe, noch zu wenige Spieltage':
      '{zeit} · default, not enough days played yet',
  '{zeit} · aus deinen letzten {n} Spieltagen':
      '{zeit} · from your last {n} days played',
  'Benachrichtigungen sind für GeoMania im System ausgeschaltet. Zum Einschalten hier tippen.':
      'Notifications for GeoMania are switched off in your system settings. '
          'Tap here to turn them on.',

  // ── Debug-Bereich ──────────────────────────────────────────────────────────
  'Benachrichtigung sofort senden (Debug)': 'Send notification now (debug)',
  'Erlaubnis-Dialog zurücksetzen (Debug)': 'Reset permission dialog (debug)',
  'Geplante Benachrichtigungen (Debug)': 'Scheduled notifications (debug)',
};
