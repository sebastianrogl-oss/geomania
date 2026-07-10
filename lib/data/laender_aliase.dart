// Gängige alternative Schreibweisen für Ländernamen, die bei den
// Eingabe-Modi (flaggenQuizEingabe, umrissEingabe, hauptstaedteEingabe)
// zusätzlich zum offiziellen Namen als richtig akzeptiert werden.
// Werte hier bereits ohne Umlaute/Akzente und in Kleinbuchstaben, damit sie
// direkt mit dem normalisierten Nutzer-Text verglichen werden können
// (siehe normalisiereEingabe() in station_quiz_screen.dart).
const Map<String, List<String>> laenderAliase = {
  'US': ['usa', 'vereinigte staaten von amerika', 'amerika'],
  'GB': ['uk', 'grossbritannien', 'england', 'vereinigtes koenigreich'],
  'CZ': ['tschechische republik', 'tschechei'],
  'NL': ['holland'],
  'RU': ['russische foederation', 'russland'],
  'KR': ['suedkorea', 'republik korea'],
  'KP': ['nordkorea'],
  'CD': ['kongo kinshasa', 'demokratische republik kongo', 'dr kongo'],
  'CG': ['kongo brazzaville', 'republik kongo'],
  'CI': ['elfenbeinkueste'],
  'SZ': ['swasiland', 'eswatini'],
  'MK': ['mazedonien', 'nordmazedonien'],
  'TR': ['tuerkei', 'tuerkiye'],
  'AE': ['vae', 'vereinigte arabische emirate'],
  'MM': ['birma', 'burma'],
  'LK': ['ceylon'],
  'IR': ['persien'],
};
