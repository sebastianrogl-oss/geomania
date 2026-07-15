// Englische Kurz-Währungsnamen (ohne Länder-Adjektiv), nach ISO-Währungscode
// — Gegenstück zu _waehrungsKuerzel in station_session_service.dart. Eigene
// Map statt Übersetzung der deutschen Kurzform, weil Deutsch mehrere
// unterschiedliche Währungen unter demselben Wort zusammenfasst (z.B.
// "Krone" für SEK/NOK/DKK/CZK), während Englisch eigene Wörter je Währung
// hat (Krona/Krone/Koruna) — eine reine Text-Übersetzung der deutschen Werte
// würde diese Unterscheidung verlieren.
const Map<String, String> waehrungsKuerzelEn = {
  // Europa
  'GBP': 'Pound', 'CHF': 'Franc', 'SEK': 'Krona',
  'NOK': 'Krone', 'DKK': 'Krone', 'PLN': 'Złoty',
  'CZK': 'Koruna', 'HUF': 'Forint', 'RON': 'Leu',
  'RUB': 'Ruble', 'TRY': 'Lira', 'UAH': 'Hryvnia',
  'BGN': 'Lev', 'RSD': 'Dinar',
  // Nordamerika
  'USD': 'Dollar', 'CAD': 'Dollar', 'MXN': 'Peso',
  // Südamerika
  'BRL': 'Real', 'ARS': 'Peso', 'COP': 'Peso',
  'CLP': 'Peso', 'PEN': 'Sol', 'VES': 'Bolívar',
  // Asien – Ostasien
  'JPY': 'Yen', 'CNY': 'Yuan', 'KRW': 'Won',
  'SGD': 'Dollar', 'TWD': 'Dollar', 'MNT': 'Tögrög',
  // Asien – Südostasien
  'IDR': 'Rupiah', 'THB': 'Baht', 'MYR': 'Ringgit',
  'PHP': 'Peso', 'VND': 'Dong', 'MMK': 'Kyat',
  'KHR': 'Riel', 'LAK': 'Kip',
  // Asien – Südasien / Zentralasien
  'INR': 'Rupee', 'PKR': 'Rupee', 'BDT': 'Taka',
  'LKR': 'Rupee', 'NPR': 'Rupee', 'KZT': 'Tenge',
  'UZS': 'Som', 'GEL': 'Lari', 'AMD': 'Dram',
  'AZN': 'Manat',
  // Naher Osten
  'SAR': 'Riyal', 'AED': 'Dirham', 'ILS': 'Shekel',
  'QAR': 'Riyal', 'KWD': 'Dinar', 'BHD': 'Dinar',
  'OMR': 'Rial', 'JOD': 'Dinar', 'IQD': 'Dinar',
  'IRR': 'Rial',
  // Afrika
  'ZAR': 'Rand', 'NGN': 'Naira', 'EGP': 'Pound',
  'MAD': 'Dirham', 'KES': 'Shilling', 'GHS': 'Cedi',
  'ETB': 'Birr', 'TZS': 'Shilling', 'DZD': 'Dinar',
  'TND': 'Dinar',
  // Ozeanien
  'AUD': 'Dollar', 'NZD': 'Dollar',
};
