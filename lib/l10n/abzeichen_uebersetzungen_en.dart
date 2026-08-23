// Englische Namen/Beschreibungen für alle 30 Abzeichen, nach Abzeichen.id.
// Wird vom computed Getter in abzeichen_data.dart genutzt (siehe dortiges
// `String get name` / `String get beschreibung`), damit ALLE
// `.name`/`.beschreibung`-Aufrufstellen automatisch lokalisiert sind.
const Map<String, String> abzeichenNamenEn = {
  'streak_3': 'Three Days Strong',
  'streak_7': 'One Week In',
  'streak_30': 'One Month Steady',
  'perfekt': 'Full Score',
  'neuer_rekord': 'Personal Best',
  'alle_challenges': 'Complete Day',
  'streak_app_30': 'Loyal Player',
  'kontinent_europa': 'Europe Master',
  'kontinent_suedamerika': 'South America Master',
  'kontinent_nordamerika': 'North America Master',
  'kontinent_afrika': 'Africa Master',
  'kontinent_asien': 'Asia Master',
  'kontinent_ozeanien': 'Oceania Master',
  'kontinent_welt': 'World Champion',
  'stationen_25': 'First Steps',
  'stationen_50': 'On a Roll',
  'stationen_100': 'Cartographer',
  'stationen_alle': 'Learning Path Champion',
  'punkte_preis_bronze': 'Guessing Talent',
  'punkte_preis_silber': 'Guessing Pro',
  'punkte_preis_gold': 'Guessing Master',
  'punkte_higher_lower_bronze': 'Streak Talent',
  'punkte_higher_lower_silber': 'Streak Pro',
  'punkte_higher_lower_gold': 'Streak Master',
  'punkte_ranking_game_bronze': 'Ranking Talent',
  'punkte_ranking_game_silber': 'Ranking Pro',
  'punkte_ranking_game_gold': 'Ranking Master',
  'punkte_portfolio_bronze': 'Investment Talent',
  'punkte_portfolio_silber': 'Investment Pro',
  'punkte_portfolio_gold': 'Investment Master',
};

const Map<String, String> abzeichenBeschreibungenEn = {
  'streak_3': 'You played a daily challenge 3 days in a row',
  'streak_7': 'You played a daily challenge 7 days in a row',
  'streak_30': 'You played a daily challenge 30 days in a row',
  'perfekt': 'You reached the maximum score in a daily challenge on one day',
  'neuer_rekord': 'You set a personal best in one of the daily challenges',
  'alle_challenges': 'You played all 4 daily challenges on one day',
  'streak_app_30': 'You used the app 30 days in a row',
  'kontinent_europa': 'You completed all stations in Europe',
  'kontinent_suedamerika': 'You completed all stations in South America',
  'kontinent_nordamerika': 'You completed all stations in North America',
  'kontinent_afrika': 'You completed all stations in Africa',
  'kontinent_asien': 'You completed all stations in Asia',
  'kontinent_ozeanien': 'You completed all stations in Oceania',
  'kontinent_welt': 'You fully mastered the final world "The World"',
  'stationen_25': 'You completed 25 stations on the learning path',
  'stationen_50': 'You completed 50 stations on the learning path',
  'stationen_100': 'You completed 100 stations on the learning path',
  'stationen_alle': 'You completed ALL stations on the learning path',
  'punkte_preis_bronze':
      'You reached at least 250 points in a round of "The Big Guess"',
  'punkte_preis_silber':
      'You reached at least 375 points in a round of "The Big Guess"',
  'punkte_preis_gold':
      'You reached at least 488 points in a round of "The Big Guess"',
  'punkte_higher_lower_bronze':
      'You got at least 10 correct in a row in "Higher or Lower"',
  'punkte_higher_lower_silber':
      'You got at least 20 correct in a row in "Higher or Lower"',
  'punkte_higher_lower_gold':
      'You got at least 35 correct in a row in "Higher or Lower"',
  'punkte_ranking_game_bronze':
      'You reached at least 400 points in a round of Ranking Game',
  'punkte_ranking_game_silber':
      'You reached at least 600 points in a round of Ranking Game',
  'punkte_ranking_game_gold':
      'You reached at least 780 points in a round of Ranking Game',
  'punkte_portfolio_bronze':
      'You reached at least \$50 profit in the Portfolio in one day',
  'punkte_portfolio_silber':
      'You reached at least \$150 profit in the Portfolio in one day',
  'punkte_portfolio_gold':
      'You reached at least \$300 profit in the Portfolio in one day',
};
