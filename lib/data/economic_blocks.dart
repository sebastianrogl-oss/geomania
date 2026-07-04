// Primary economic block assignment per country (for quiz purposes)
// When a country belongs to multiple blocks, we assign the most specific/notable one.
const Map<String, String> economicBlockPrimary = {
  // ── EU (27 members) ────────────────────────────────────────────────────────
  'AT': 'EU', 'BE': 'EU', 'BG': 'EU', 'HR': 'EU', 'CY': 'EU',
  'CZ': 'EU', 'DK': 'EU', 'EE': 'EU', 'FI': 'EU', 'FR': 'EU',
  'DE': 'EU', 'GR': 'EU', 'HU': 'EU', 'IE': 'EU', 'IT': 'EU',
  'LV': 'EU', 'LT': 'EU', 'LU': 'EU', 'MT': 'EU', 'NL': 'EU',
  'PL': 'EU', 'PT': 'EU', 'RO': 'EU', 'SK': 'EU', 'SI': 'EU',
  'ES': 'EU', 'SE': 'EU',

  // ── G7 (non-EU members) ────────────────────────────────────────────────────
  'US': 'G7', 'CA': 'G7', 'JP': 'G7', 'GB': 'G7',

  // ── OPEC ───────────────────────────────────────────────────────────────────
  'SA': 'OPEC', 'IR': 'OPEC', 'IQ': 'OPEC', 'KW': 'OPEC',
  'AE': 'OPEC', 'LY': 'OPEC', 'NG': 'OPEC', 'GA': 'OPEC',
  'CG': 'OPEC', 'GQ': 'OPEC', 'VE': 'OPEC', 'DZ': 'OPEC',

  // ── BRICS (original 5) ────────────────────────────────────────────────────
  'BR': 'BRICS', 'RU': 'BRICS', 'IN': 'BRICS', 'CN': 'BRICS', 'ZA': 'BRICS',

  // ── ASEAN (10 members) ────────────────────────────────────────────────────
  'BN': 'ASEAN', 'KH': 'ASEAN', 'ID': 'ASEAN', 'LA': 'ASEAN',
  'MY': 'ASEAN', 'MM': 'ASEAN', 'PH': 'ASEAN', 'SG': 'ASEAN',
  'TH': 'ASEAN', 'VN': 'ASEAN',

  // ── G20 (notable non-EU / non-G7 / non-OPEC / non-BRICS / non-ASEAN) ──────
  'AU': 'G20', 'KR': 'G20', 'MX': 'G20', 'AR': 'G20', 'TR': 'G20',
};

const List<String> allBlocks = ['EU', 'G7', 'G20', 'OPEC', 'BRICS', 'ASEAN', 'Keiner davon'];

String primaryBlockFor(String iso2) =>
    economicBlockPrimary[iso2] ?? 'Keiner davon';

// ── Währungen pro Land (Deutsch) ─────────────────────────────────────────────
const Map<String, String> countryCurrencies = {
  // Europa
  'DE': 'Euro', 'FR': 'Euro', 'IT': 'Euro', 'ES': 'Euro', 'PT': 'Euro',
  'NL': 'Euro', 'BE': 'Euro', 'AT': 'Euro', 'GR': 'Euro', 'FI': 'Euro',
  'IE': 'Euro', 'LU': 'Euro', 'CY': 'Euro', 'EE': 'Euro', 'LV': 'Euro',
  'LT': 'Euro', 'MT': 'Euro', 'SI': 'Euro', 'SK': 'Euro', 'HR': 'Euro',
  'AD': 'Euro', 'MC': 'Euro', 'SM': 'Euro', 'VA': 'Euro',
  'ME': 'Euro', 'XK': 'Euro',
  'CH': 'Schweizer Franken',
  'GB': 'Britisches Pfund',
  'SE': 'Schwedische Krone',
  'NO': 'Norwegische Krone',
  'DK': 'Dänische Krone',
  'IS': 'Isländische Krone',
  'CZ': 'Tschechische Krone',
  'HU': 'Ungarischer Forint',
  'PL': 'Polnischer Zloty',
  'RO': 'Rumänischer Leu',
  'BG': 'Bulgarischer Lew',
  'RS': 'Serbischer Dinar',
  'UA': 'Ukrainische Hrywnja',
  'RU': 'Russischer Rubel',
  'TR': 'Türkische Lira',
  'AL': 'Albanischer Lek',
  'BA': 'Konvertible Mark',
  'BY': 'Belarussischer Rubel',
  'MK': 'Mazedonischer Denar',
  'MD': 'Moldauischer Leu',
  'LI': 'Schweizer Franken',

  // Nordamerika
  'US': 'US-Dollar',
  'CA': 'Kanadischer Dollar',
  'MX': 'Mexikanischer Peso',
  'CU': 'Kubanischer Peso',
  'DO': 'Dominikanischer Peso',
  'JM': 'Jamaikanischer Dollar',
  'TT': 'Trinidad-Dollar',
  'HT': 'Haitianische Gourde',
  'GT': 'Guatemaltekischer Quetzal',
  'HN': 'Honduranische Lempira',
  'SV': 'US-Dollar',
  'NI': 'Nicaraguanischer Córdoba',
  'CR': 'Costa-Ricanischer Colón',
  'PA': 'Panamaischer Balboa',
  'BZ': 'Belize-Dollar',
  'BB': 'Barbadischer Dollar',

  // Südamerika
  'BR': 'Brasilianischer Real',
  'AR': 'Argentinischer Peso',
  'CO': 'Kolumbianischer Peso',
  'CL': 'Chilenischer Peso',
  'PE': 'Peruanischer Sol',
  'VE': 'Venezolanischer Bolívar',
  'EC': 'US-Dollar',
  'BO': 'Bolivianischer Boliviano',
  'UY': 'Uruguayischer Peso',
  'PY': 'Paraguayischer Guaraní',
  'GY': 'Guyanischer Dollar',
  'SR': 'Surinamischer Dollar',

  // Asien
  'CN': 'Chinesischer Renminbi (Yuan)',
  'JP': 'Japanischer Yen',
  'IN': 'Indische Rupie',
  'KR': 'Südkoreanischer Won',
  'ID': 'Indonesische Rupiah',
  'TH': 'Thailändischer Baht',
  'VN': 'Vietnamesischer Dong',
  'PH': 'Philippinischer Peso',
  'MY': 'Malaysischer Ringgit',
  'SG': 'Singapur-Dollar',
  'PK': 'Pakistanische Rupie',
  'BD': 'Bangladeschischer Taka',
  'NP': 'Nepalesische Rupie',
  'LK': 'Sri-Lankische Rupie',
  'BT': 'Bhutanischer Ngultrum',
  'MV': 'Maledivische Rufiyaa',
  'KZ': 'Kasachischer Tenge',
  'UZ': 'Usbekischer Sum',
  'MN': 'Mongolischer Tögrög',
  'KH': 'Kambodschanischer Riel',
  'MM': 'Myanmarischer Kyat',
  'LA': 'Laotischer Kip',
  'BN': 'Brunei-Dollar',
  'KG': 'Kirgisischer Som',
  'TJ': 'Tadschikischer Somoni',
  'TM': 'Turkmenischer Manat',
  'AF': 'Afghani',
  'GE': 'Georgischer Lari',
  'AM': 'Armenischer Dram',
  'AZ': 'Aserbaidschanischer Manat',

  // Naher Osten
  'SA': 'Saudi-Riyal',
  'AE': 'Dirham der VAE',
  'IR': 'Iranischer Rial',
  'IQ': 'Irakischer Dinar',
  'IL': 'Neuer Israelischer Schekel',
  'JO': 'Jordanischer Dinar',
  'KW': 'Kuwaitischer Dinar',
  'QA': 'Katarischer Riyal',
  'OM': 'Omanischer Rial',
  'BH': 'Bahrain-Dinar',
  'YE': 'Jemenitischer Rial',
  'LB': 'Libanesisches Pfund',
  'SY': 'Syrisches Pfund',

  // Afrika
  'NG': 'Nigerianische Naira',
  'EG': 'Ägyptisches Pfund',
  'ZA': 'Südafrikanischer Rand',
  'ET': 'Äthiopischer Birr',
  'KE': 'Kenianischer Schilling',
  'GH': 'Ghanaischer Cedi',
  'TZ': 'Tansanischer Schilling',
  'MA': 'Marokkanischer Dirham',
  'DZ': 'Algerischer Dinar',
  'TN': 'Tunesischer Dinar',
  'LY': 'Libyscher Dinar',
  'SN': 'CFA-Franc (BCEAO)',
  'CM': 'CFA-Franc (BEAC)',
  'CI': 'CFA-Franc (BCEAO)',
  'AO': 'Angolanischer Kwanza',
  'CD': 'Kongolesischer Franc',
  'CG': 'CFA-Franc (BEAC)',
  'GA': 'CFA-Franc (BEAC)',
  'BJ': 'CFA-Franc (BCEAO)',
  'BF': 'CFA-Franc (BCEAO)',
  'ML': 'CFA-Franc (BCEAO)',
  'ZW': 'US-Dollar',
  'MZ': 'Mosambikanischer Metical',
  'NA': 'Namibischer Dollar',
  'BW': 'Botswanischer Pula',
  'ZM': 'Sambischer Kwacha',
  'RW': 'Ruandischer Franc',
  'UG': 'Ugandischer Schilling',
  'LS': 'Lesothischer Loti',
  'GQ': 'CFA-Franc (BEAC)',
  'SD': 'Sudanesisches Pfund',
  'SO': 'Somalischer Schilling',

  // Ozeanien
  'AU': 'Australischer Dollar',
  'NZ': 'Neuseeländischer Dollar',
  'FJ': 'Fidschi-Dollar',
  'PG': 'Papua-Neuguineisches Kina',
  'SB': 'Salomonischer Dollar',
  'WS': 'Samoanischer Tālā',
  'TO': 'Tongaisches Paʻanga',
  'FM': 'US-Dollar',
  'MH': 'US-Dollar',
  'PW': 'US-Dollar',
  'KI': 'Australischer Dollar',
  'TV': 'Australischer Dollar',
  'NR': 'Australischer Dollar',
};

// Countries with well-known currencies for easy mode
const Set<String> currencyEasyCountries = {
  'US', 'CA', 'GB', 'AU', 'NZ',
  'DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'GR', 'IE', 'FI', 'SE', 'NO', 'DK',
  'CH', 'PL', 'CZ', 'HU', 'RO', 'RU', 'UA', 'TR',
  'JP', 'CN', 'KR', 'IN', 'ID', 'TH', 'MY', 'SG', 'VN', 'PH', 'PK', 'BD',
  'BR', 'MX', 'AR', 'CL', 'CO', 'PE',
  'SA', 'AE', 'IL', 'KW', 'QA', 'OM', 'IR', 'IQ',
  'EG', 'NG', 'ZA', 'KE', 'GH', 'MA', 'ET', 'TN', 'DZ',
};
