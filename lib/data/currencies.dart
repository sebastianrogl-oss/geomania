// Currency data for Währungen-Quiz
// difficulty: 1=leicht, 2=mittel, 3=schwer

class CurrencyData {
  final String countryName;
  final String flagEmoji;
  final String currencyName;
  final String currencyCode;
  final String currencySymbol;
  final String funFact;
  final int difficulty;

  const CurrencyData({
    required this.countryName,
    required this.flagEmoji,
    required this.currencyName,
    required this.currencyCode,
    required this.currencySymbol,
    this.funFact = '',
    required this.difficulty,
  });
}

const List<CurrencyData> currencies = [
  // ── Europa – Euro-Zone ───────────────────────────────────────────────────────
  CurrencyData(countryName: 'Deutschland',   flagEmoji: '🇩🇪', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1,
    funFact: 'Der Euro ist Währung von 20 EU-Ländern und die zweitwichtigste Reservewährung der Welt.'),
  CurrencyData(countryName: 'Frankreich',    flagEmoji: '🇫🇷', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1),
  CurrencyData(countryName: 'Italien',       flagEmoji: '🇮🇹', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1),
  CurrencyData(countryName: 'Spanien',       flagEmoji: '🇪🇸', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1),
  CurrencyData(countryName: 'Portugal',      flagEmoji: '🇵🇹', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1),
  CurrencyData(countryName: 'Niederlande',   flagEmoji: '🇳🇱', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1),
  CurrencyData(countryName: 'Belgien',       flagEmoji: '🇧🇪', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1),
  CurrencyData(countryName: 'Österreich',    flagEmoji: '🇦🇹', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 1),
  CurrencyData(countryName: 'Finnland',      flagEmoji: '🇫🇮', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 2),
  CurrencyData(countryName: 'Griechenland',  flagEmoji: '🇬🇷', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 2),
  CurrencyData(countryName: 'Kroatien',      flagEmoji: '🇭🇷', currencyName: 'Euro',                    currencyCode: 'EUR', currencySymbol: '€',  difficulty: 2,
    funFact: 'Kroatien führte den Euro erst 2023 ein und war damit das bisher letzte Land, das der Eurozone beitrat.'),

  // ── Europa – Eigenwährungen ──────────────────────────────────────────────────
  CurrencyData(countryName: 'Vereinigtes Königreich', flagEmoji: '🇬🇧', currencyName: 'Britisches Pfund Sterling', currencyCode: 'GBP', currencySymbol: '£', difficulty: 1,
    funFact: 'Das Britische Pfund Sterling ist die älteste noch im Umlauf befindliche Währung der Welt – seit über 1.200 Jahren!'),
  CurrencyData(countryName: 'Schweiz',       flagEmoji: '🇨🇭', currencyName: 'Schweizer Franken',       currencyCode: 'CHF', currencySymbol: 'Fr', difficulty: 1,
    funFact: 'Der Schweizer Franken gilt als „sicherer Hafen" – in Krisenzeiten steigt sein Wert oft stark an.'),
  CurrencyData(countryName: 'Schweden',      flagEmoji: '🇸🇪', currencyName: 'Schwedische Krone',       currencyCode: 'SEK', currencySymbol: 'kr', difficulty: 2,
    funFact: 'Obwohl EU-Mitglied, hat Schweden den Euro nie eingeführt und hält an der Krone fest.'),
  CurrencyData(countryName: 'Norwegen',      flagEmoji: '🇳🇴', currencyName: 'Norwegische Krone',       currencyCode: 'NOK', currencySymbol: 'kr', difficulty: 2),
  CurrencyData(countryName: 'Dänemark',      flagEmoji: '🇩🇰', currencyName: 'Dänische Krone',          currencyCode: 'DKK', currencySymbol: 'kr', difficulty: 2),
  CurrencyData(countryName: 'Polen',         flagEmoji: '🇵🇱', currencyName: 'Polnischer Złoty',        currencyCode: 'PLN', currencySymbol: 'zł', difficulty: 2),
  CurrencyData(countryName: 'Tschechien',    flagEmoji: '🇨🇿', currencyName: 'Tschechische Krone',      currencyCode: 'CZK', currencySymbol: 'Kč', difficulty: 2),
  CurrencyData(countryName: 'Ungarn',        flagEmoji: '🇭🇺', currencyName: 'Ungarischer Forint',      currencyCode: 'HUF', currencySymbol: 'Ft', difficulty: 2),
  CurrencyData(countryName: 'Rumänien',      flagEmoji: '🇷🇴', currencyName: 'Rumänischer Leu',         currencyCode: 'RON', currencySymbol: 'lei',difficulty: 2),
  CurrencyData(countryName: 'Russland',      flagEmoji: '🇷🇺', currencyName: 'Russischer Rubel',        currencyCode: 'RUB', currencySymbol: '₽',  difficulty: 1),
  CurrencyData(countryName: 'Türkei',        flagEmoji: '🇹🇷', currencyName: 'Türkische Lira',          currencyCode: 'TRY', currencySymbol: '₺',  difficulty: 1,
    funFact: 'Die Türkische Lira verlor in den 2010er–2020er Jahren über 90 % ihres Wertes gegenüber dem Dollar.'),
  CurrencyData(countryName: 'Ukraine',       flagEmoji: '🇺🇦', currencyName: 'Ukrainische Hrywnja',     currencyCode: 'UAH', currencySymbol: '₴',  difficulty: 3),
  CurrencyData(countryName: 'Bulgarien',     flagEmoji: '🇧🇬', currencyName: 'Bulgarischer Lew',        currencyCode: 'BGN', currencySymbol: 'лв', difficulty: 3),
  CurrencyData(countryName: 'Serbien',       flagEmoji: '🇷🇸', currencyName: 'Serbischer Dinar',        currencyCode: 'RSD', currencySymbol: 'din',difficulty: 3),

  // ── Nordamerika ──────────────────────────────────────────────────────────────
  CurrencyData(countryName: 'USA',           flagEmoji: '🇺🇸', currencyName: 'US-Dollar',               currencyCode: 'USD', currencySymbol: '\$', difficulty: 1,
    funFact: 'Der US-Dollar ist die wichtigste Reservewährung der Welt – über 60 % der globalen Devisenreserven bestehen aus Dollars.'),
  CurrencyData(countryName: 'Kanada',        flagEmoji: '🇨🇦', currencyName: 'Kanadischer Dollar',      currencyCode: 'CAD', currencySymbol: '\$', difficulty: 1),
  CurrencyData(countryName: 'Mexiko',        flagEmoji: '🇲🇽', currencyName: 'Mexikanischer Peso',      currencyCode: 'MXN', currencySymbol: '\$', difficulty: 2),

  // ── Südamerika ───────────────────────────────────────────────────────────────
  CurrencyData(countryName: 'Brasilien',     flagEmoji: '🇧🇷', currencyName: 'Brasilianischer Real',    currencyCode: 'BRL', currencySymbol: 'R\$',difficulty: 2,
    funFact: 'Brasilien hat seit 1942 fünf verschiedene Währungen verwendet, bevor der Real 1994 eingeführt wurde.'),
  CurrencyData(countryName: 'Argentinien',   flagEmoji: '🇦🇷', currencyName: 'Argentinischer Peso',    currencyCode: 'ARS', currencySymbol: '\$', difficulty: 2),
  CurrencyData(countryName: 'Kolumbien',     flagEmoji: '🇨🇴', currencyName: 'Kolumbianischer Peso',   currencyCode: 'COP', currencySymbol: '\$', difficulty: 2),
  CurrencyData(countryName: 'Chile',         flagEmoji: '🇨🇱', currencyName: 'Chilenischer Peso',      currencyCode: 'CLP', currencySymbol: '\$', difficulty: 2),
  CurrencyData(countryName: 'Peru',          flagEmoji: '🇵🇪', currencyName: 'Peruanischer Sol',       currencyCode: 'PEN', currencySymbol: 'S/', difficulty: 3),
  CurrencyData(countryName: 'Venezuela',     flagEmoji: '🇻🇪', currencyName: 'Venezolanischer Bolívar',currencyCode: 'VES', currencySymbol: 'Bs.',difficulty: 3),

  // ── Asien – Ostasien ─────────────────────────────────────────────────────────
  CurrencyData(countryName: 'Japan',         flagEmoji: '🇯🇵', currencyName: 'Japanischer Yen',         currencyCode: 'JPY', currencySymbol: '¥',  difficulty: 1,
    funFact: 'Der Yen ist nach Dollar und Euro die am dritthäufigsten gehandelte Währung der Welt.'),
  CurrencyData(countryName: 'China',         flagEmoji: '🇨🇳', currencyName: 'Chinesischer Yuan',       currencyCode: 'CNY', currencySymbol: '¥',  difficulty: 1,
    funFact: 'China kontrolliert den Wechselkurs des Yuan streng – ein freier Devisenhandel ist nur eingeschränkt erlaubt.'),
  CurrencyData(countryName: 'Südkorea',      flagEmoji: '🇰🇷', currencyName: 'Südkoreanischer Won',     currencyCode: 'KRW', currencySymbol: '₩',  difficulty: 2),
  CurrencyData(countryName: 'Singapur',      flagEmoji: '🇸🇬', currencyName: 'Singapur-Dollar',         currencyCode: 'SGD', currencySymbol: '\$', difficulty: 2),
  CurrencyData(countryName: 'Taiwan',        flagEmoji: '🇹🇼', currencyName: 'Neuer Taiwan-Dollar',     currencyCode: 'TWD', currencySymbol: 'NT\$',difficulty: 3),
  CurrencyData(countryName: 'Mongolei',      flagEmoji: '🇲🇳', currencyName: 'Mongolischer Tögrög',     currencyCode: 'MNT', currencySymbol: '₮',  difficulty: 3),

  // ── Asien – Südostasien ──────────────────────────────────────────────────────
  CurrencyData(countryName: 'Indonesien',    flagEmoji: '🇮🇩', currencyName: 'Indonesische Rupiah',     currencyCode: 'IDR', currencySymbol: 'Rp', difficulty: 2),
  CurrencyData(countryName: 'Thailand',      flagEmoji: '🇹🇭', currencyName: 'Thailändischer Baht',     currencyCode: 'THB', currencySymbol: '฿',  difficulty: 2),
  CurrencyData(countryName: 'Malaysia',      flagEmoji: '🇲🇾', currencyName: 'Malaysischer Ringgit',    currencyCode: 'MYR', currencySymbol: 'RM', difficulty: 2),
  CurrencyData(countryName: 'Philippinen',   flagEmoji: '🇵🇭', currencyName: 'Philippinischer Peso',   currencyCode: 'PHP', currencySymbol: '₱',  difficulty: 2),
  CurrencyData(countryName: 'Vietnam',       flagEmoji: '🇻🇳', currencyName: 'Vietnamesischer Dong',    currencyCode: 'VND', currencySymbol: '₫',  difficulty: 2),
  CurrencyData(countryName: 'Myanmar',       flagEmoji: '🇲🇲', currencyName: 'Myanmarischer Kyat',      currencyCode: 'MMK', currencySymbol: 'K',  difficulty: 3),
  CurrencyData(countryName: 'Kambodscha',    flagEmoji: '🇰🇭', currencyName: 'Kambodschanischer Riel',  currencyCode: 'KHR', currencySymbol: '៛',  difficulty: 3),
  CurrencyData(countryName: 'Laos',          flagEmoji: '🇱🇦', currencyName: 'Laotischer Kip',          currencyCode: 'LAK', currencySymbol: '₭',  difficulty: 3),

  // ── Asien – Südasien ─────────────────────────────────────────────────────────
  CurrencyData(countryName: 'Indien',        flagEmoji: '🇮🇳', currencyName: 'Indische Rupie',          currencyCode: 'INR', currencySymbol: '₹',  difficulty: 1,
    funFact: 'Das offizielle Symbol der Indischen Rupie (₹) wurde erst 2010 eingeführt, um die Währung international erkennbar zu machen.'),
  CurrencyData(countryName: 'Pakistan',      flagEmoji: '🇵🇰', currencyName: 'Pakistanische Rupie',     currencyCode: 'PKR', currencySymbol: '₨',  difficulty: 2),
  CurrencyData(countryName: 'Bangladesch',   flagEmoji: '🇧🇩', currencyName: 'Bangladeschischer Taka',  currencyCode: 'BDT', currencySymbol: '৳',  difficulty: 3),
  CurrencyData(countryName: 'Sri Lanka',     flagEmoji: '🇱🇰', currencyName: 'Sri-lankische Rupie',     currencyCode: 'LKR', currencySymbol: 'Rs', difficulty: 3),
  CurrencyData(countryName: 'Nepal',         flagEmoji: '🇳🇵', currencyName: 'Nepalesische Rupie',      currencyCode: 'NPR', currencySymbol: 'Rs', difficulty: 3),

  // ── Asien – Zentralasien ─────────────────────────────────────────────────────
  CurrencyData(countryName: 'Kasachstan',    flagEmoji: '🇰🇿', currencyName: 'Kasachischer Tenge',      currencyCode: 'KZT', currencySymbol: '₸',  difficulty: 3),
  CurrencyData(countryName: 'Usbekistan',    flagEmoji: '🇺🇿', currencyName: 'Usbekischer Sum',          currencyCode: 'UZS', currencySymbol: 'сум',difficulty: 3),
  CurrencyData(countryName: 'Georgien',      flagEmoji: '🇬🇪', currencyName: 'Georgischer Lari',        currencyCode: 'GEL', currencySymbol: '₾',  difficulty: 3),
  CurrencyData(countryName: 'Armenien',      flagEmoji: '🇦🇲', currencyName: 'Armenischer Dram',        currencyCode: 'AMD', currencySymbol: '֏',  difficulty: 3),
  CurrencyData(countryName: 'Aserbaidschan', flagEmoji: '🇦🇿', currencyName: 'Aserbaidschanischer Manat',currencyCode: 'AZN', currencySymbol: '₼', difficulty: 3),

  // ── Naher Osten ──────────────────────────────────────────────────────────────
  CurrencyData(countryName: 'Saudi-Arabien', flagEmoji: '🇸🇦', currencyName: 'Saudi-Riyal',             currencyCode: 'SAR', currencySymbol: 'ر.س',difficulty: 1),
  CurrencyData(countryName: 'Ver. Arab. Emirate', flagEmoji: '🇦🇪', currencyName: 'UAE-Dirham',         currencyCode: 'AED', currencySymbol: 'د.إ',difficulty: 1),
  CurrencyData(countryName: 'Israel',        flagEmoji: '🇮🇱', currencyName: 'Neuer Israelischer Schekel', currencyCode: 'ILS', currencySymbol: '₪', difficulty: 2),
  CurrencyData(countryName: 'Katar',         flagEmoji: '🇶🇦', currencyName: 'Katar-Riyal',             currencyCode: 'QAR', currencySymbol: 'ر.ق',difficulty: 2),
  CurrencyData(countryName: 'Kuwait',        flagEmoji: '🇰🇼', currencyName: 'Kuwaitischer Dinar',      currencyCode: 'KWD', currencySymbol: 'د.ك',difficulty: 3,
    funFact: 'Der Kuwaitische Dinar ist die wertvollste Währungseinheit der Welt – 1 KWD entspricht über 3 US-Dollar.'),
  CurrencyData(countryName: 'Bahrain',       flagEmoji: '🇧🇭', currencyName: 'Bahrainischer Dinar',     currencyCode: 'BHD', currencySymbol: '.د.ب',difficulty: 3),
  CurrencyData(countryName: 'Oman',          flagEmoji: '🇴🇲', currencyName: 'Omanischer Rial',         currencyCode: 'OMR', currencySymbol: 'ر.ع.',difficulty: 3),
  CurrencyData(countryName: 'Jordanien',     flagEmoji: '🇯🇴', currencyName: 'Jordanischer Dinar',      currencyCode: 'JOD', currencySymbol: 'د.ا',difficulty: 3),
  CurrencyData(countryName: 'Irak',          flagEmoji: '🇮🇶', currencyName: 'Irakischer Dinar',        currencyCode: 'IQD', currencySymbol: 'ع.د',difficulty: 3),
  CurrencyData(countryName: 'Iran',          flagEmoji: '🇮🇷', currencyName: 'Iranischer Rial',         currencyCode: 'IRR', currencySymbol: '﷼',  difficulty: 3),

  // ── Afrika ───────────────────────────────────────────────────────────────────
  CurrencyData(countryName: 'Südafrika',     flagEmoji: '🇿🇦', currencyName: 'Südafrikanischer Rand',   currencyCode: 'ZAR', currencySymbol: 'R',  difficulty: 2,
    funFact: 'Der Name „Rand" leitet sich von „Witwatersrand" ab – der goldreichen Region um Johannesburg.'),
  CurrencyData(countryName: 'Nigeria',       flagEmoji: '🇳🇬', currencyName: 'Nigerianische Naira',     currencyCode: 'NGN', currencySymbol: '₦',  difficulty: 2),
  CurrencyData(countryName: 'Ägypten',       flagEmoji: '🇪🇬', currencyName: 'Ägyptisches Pfund',       currencyCode: 'EGP', currencySymbol: 'ج.م',difficulty: 2),
  CurrencyData(countryName: 'Marokko',       flagEmoji: '🇲🇦', currencyName: 'Marokkanischer Dirham',   currencyCode: 'MAD', currencySymbol: 'د.م.',difficulty: 2),
  CurrencyData(countryName: 'Kenia',         flagEmoji: '🇰🇪', currencyName: 'Kenianischer Schilling',  currencyCode: 'KES', currencySymbol: 'KSh', difficulty: 3),
  CurrencyData(countryName: 'Ghana',         flagEmoji: '🇬🇭', currencyName: 'Ghanaischer Cedi',        currencyCode: 'GHS', currencySymbol: '₵',  difficulty: 3),
  CurrencyData(countryName: 'Äthiopien',     flagEmoji: '🇪🇹', currencyName: 'Äthiopischer Birr',       currencyCode: 'ETB', currencySymbol: 'Br', difficulty: 3),
  CurrencyData(countryName: 'Tansania',      flagEmoji: '🇹🇿', currencyName: 'Tansanischer Schilling',  currencyCode: 'TZS', currencySymbol: 'TSh', difficulty: 3),
  CurrencyData(countryName: 'Algerien',      flagEmoji: '🇩🇿', currencyName: 'Algerischer Dinar',       currencyCode: 'DZD', currencySymbol: 'دج', difficulty: 3),
  CurrencyData(countryName: 'Tunesien',      flagEmoji: '🇹🇳', currencyName: 'Tunesischer Dinar',       currencyCode: 'TND', currencySymbol: 'د.ت',difficulty: 3),

  // ── Ozeanien ─────────────────────────────────────────────────────────────────
  CurrencyData(countryName: 'Australien',    flagEmoji: '🇦🇺', currencyName: 'Australischer Dollar',    currencyCode: 'AUD', currencySymbol: '\$', difficulty: 1,
    funFact: 'Australien war 1988 das erste Land der Welt, das Polymernoten aus Kunststoff einführte.'),
  CurrencyData(countryName: 'Neuseeland',    flagEmoji: '🇳🇿', currencyName: 'Neuseeländischer Dollar', currencyCode: 'NZD', currencySymbol: '\$', difficulty: 2),
];
