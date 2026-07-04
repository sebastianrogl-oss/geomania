class Land {
  final String iso;
  final String name;
  final String kontinent;
  final String region;
  final int schwierigkeit;

  const Land({
    required this.iso,
    required this.name,
    required this.kontinent,
    required this.region,
    required this.schwierigkeit,
  });
}

const List<Land> alleLaender = [
  // ── EUROPA (44) ───────────────────────────────────────────────────────────────
  Land(iso: 'DE', name: 'Deutschland',        kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 1),
  Land(iso: 'FR', name: 'Frankreich',         kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 1),
  Land(iso: 'IT', name: 'Italien',            kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 1),
  Land(iso: 'ES', name: 'Spanien',            kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 1),
  Land(iso: 'PT', name: 'Portugal',           kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 1),
  Land(iso: 'GB', name: 'Großbritannien',     kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 1),
  Land(iso: 'NL', name: 'Niederlande',        kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 2),
  Land(iso: 'BE', name: 'Belgien',            kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 2),
  Land(iso: 'CH', name: 'Schweiz',            kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 2),
  Land(iso: 'AT', name: 'Österreich',         kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 2),
  Land(iso: 'IE', name: 'Irland',             kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 2),
  Land(iso: 'LU', name: 'Luxemburg',          kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 3),
  Land(iso: 'MC', name: 'Monaco',             kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 3),
  Land(iso: 'AD', name: 'Andorra',            kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 3),
  Land(iso: 'LI', name: 'Liechtenstein',      kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 3),
  Land(iso: 'SM', name: 'San Marino',         kontinent: 'europa', region: 'westeuropa',  schwierigkeit: 3),
  Land(iso: 'SE', name: 'Schweden',           kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 1),
  Land(iso: 'NO', name: 'Norwegen',           kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 1),
  Land(iso: 'DK', name: 'Dänemark',           kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 2),
  Land(iso: 'FI', name: 'Finnland',           kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 2),
  Land(iso: 'IS', name: 'Island',             kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 2),
  Land(iso: 'EE', name: 'Estland',            kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 3),
  Land(iso: 'LV', name: 'Lettland',           kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 3),
  Land(iso: 'LT', name: 'Litauen',            kontinent: 'europa', region: 'nordeuropa',  schwierigkeit: 3),
  Land(iso: 'PL', name: 'Polen',              kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 1),
  Land(iso: 'CZ', name: 'Tschechien',         kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'SK', name: 'Slowakei',           kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'HU', name: 'Ungarn',             kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'RO', name: 'Rumänien',           kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'BG', name: 'Bulgarien',          kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'HR', name: 'Kroatien',           kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'GR', name: 'Griechenland',       kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'UA', name: 'Ukraine',            kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 2),
  Land(iso: 'SI', name: 'Slowenien',          kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'RS', name: 'Serbien',            kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'BA', name: 'Bosnien',            kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'ME', name: 'Montenegro',         kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'MK', name: 'Nordmazedonien',     kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'AL', name: 'Albanien',           kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'MD', name: 'Moldau',             kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'BY', name: 'Belarus',            kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),
  Land(iso: 'RU', name: 'Russland',           kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 1),
  Land(iso: 'XK', name: 'Kosovo',             kontinent: 'europa', region: 'osteuropa',   schwierigkeit: 3),

  // ── SÜDAMERIKA (12) ──────────────────────────────────────────────────────────
  Land(iso: 'BR', name: 'Brasilien',          kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 1),
  Land(iso: 'AR', name: 'Argentinien',        kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 1),
  Land(iso: 'CL', name: 'Chile',              kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 1),
  Land(iso: 'CO', name: 'Kolumbien',          kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 2),
  Land(iso: 'PE', name: 'Peru',               kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 2),
  Land(iso: 'VE', name: 'Venezuela',          kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 2),
  Land(iso: 'EC', name: 'Ecuador',            kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 2),
  Land(iso: 'BO', name: 'Bolivien',           kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 2),
  Land(iso: 'PY', name: 'Paraguay',           kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 3),
  Land(iso: 'UY', name: 'Uruguay',            kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 3),
  Land(iso: 'GY', name: 'Guyana',             kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 3),
  Land(iso: 'SR', name: 'Suriname',           kontinent: 'suedamerika', region: 'suedamerika', schwierigkeit: 3),

  // ── NORDAMERIKA (23) ─────────────────────────────────────────────────────────
  Land(iso: 'US', name: 'USA',                kontinent: 'nordamerika', region: 'nordamerika',  schwierigkeit: 1),
  Land(iso: 'CA', name: 'Kanada',             kontinent: 'nordamerika', region: 'nordamerika',  schwierigkeit: 1),
  Land(iso: 'MX', name: 'Mexiko',             kontinent: 'nordamerika', region: 'nordamerika',  schwierigkeit: 1),
  Land(iso: 'CU', name: 'Kuba',               kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 2),
  Land(iso: 'GT', name: 'Guatemala',          kontinent: 'nordamerika', region: 'mittelamerika', schwierigkeit: 3),
  Land(iso: 'BZ', name: 'Belize',             kontinent: 'nordamerika', region: 'mittelamerika', schwierigkeit: 3),
  Land(iso: 'HN', name: 'Honduras',           kontinent: 'nordamerika', region: 'mittelamerika', schwierigkeit: 3),
  Land(iso: 'SV', name: 'El Salvador',        kontinent: 'nordamerika', region: 'mittelamerika', schwierigkeit: 3),
  Land(iso: 'NI', name: 'Nicaragua',          kontinent: 'nordamerika', region: 'mittelamerika', schwierigkeit: 3),
  Land(iso: 'CR', name: 'Costa Rica',         kontinent: 'nordamerika', region: 'mittelamerika', schwierigkeit: 3),
  Land(iso: 'PA', name: 'Panama',             kontinent: 'nordamerika', region: 'mittelamerika', schwierigkeit: 3),
  Land(iso: 'JM', name: 'Jamaika',            kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'HT', name: 'Haiti',              kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'DO', name: 'Dom. Republik',      kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'TT', name: 'Trinidad und Tobago', kontinent: 'nordamerika', region: 'karibik',     schwierigkeit: 3),
  Land(iso: 'BB', name: 'Barbados',           kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'LC', name: 'St. Lucia',          kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'VC', name: 'St. Vincent',        kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'GD', name: 'Grenada',            kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'AG', name: 'Antigua',            kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'DM', name: 'Dominica',           kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'KN', name: 'St. Kitts',          kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),
  Land(iso: 'BS', name: 'Bahamas',            kontinent: 'nordamerika', region: 'karibik',      schwierigkeit: 3),

  // ── AFRIKA (54) ──────────────────────────────────────────────────────────────
  Land(iso: 'NG', name: 'Nigeria',            kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 1),
  Land(iso: 'EG', name: 'Ägypten',            kontinent: 'afrika', region: 'nordafrika',     schwierigkeit: 1),
  Land(iso: 'ZA', name: 'Südafrika',          kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 1),
  Land(iso: 'MA', name: 'Marokko',            kontinent: 'afrika', region: 'nordafrika',     schwierigkeit: 1),
  Land(iso: 'DZ', name: 'Algerien',           kontinent: 'afrika', region: 'nordafrika',     schwierigkeit: 2),
  Land(iso: 'TN', name: 'Tunesien',           kontinent: 'afrika', region: 'nordafrika',     schwierigkeit: 2),
  Land(iso: 'LY', name: 'Libyen',             kontinent: 'afrika', region: 'nordafrika',     schwierigkeit: 2),
  Land(iso: 'SD', name: 'Sudan',              kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 2),
  Land(iso: 'ET', name: 'Äthiopien',          kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 2),
  Land(iso: 'KE', name: 'Kenia',              kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 2),
  Land(iso: 'TZ', name: 'Tansania',           kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 2),
  Land(iso: 'GH', name: 'Ghana',              kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 2),
  Land(iso: 'CD', name: 'DR Kongo',           kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 2),
  Land(iso: 'AO', name: 'Angola',             kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 2),
  Land(iso: 'MG', name: 'Madagaskar',         kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 2),
  Land(iso: 'SS', name: 'Südsudan',           kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'CG', name: 'Kongo',              kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 3),
  Land(iso: 'MZ', name: 'Mosambik',           kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'CM', name: 'Kamerun',            kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 3),
  Land(iso: 'CI', name: 'Elfenbeinküste',     kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'NE', name: 'Niger',              kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'ML', name: 'Mali',               kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'BF', name: 'Burkina Faso',       kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'SN', name: 'Senegal',            kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'ZM', name: 'Sambia',             kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'ZW', name: 'Simbabwe',           kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'UG', name: 'Uganda',             kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'RW', name: 'Ruanda',             kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'BI', name: 'Burundi',            kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'SO', name: 'Somalia',            kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'ER', name: 'Eritrea',            kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'DJ', name: 'Dschibuti',          kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'MW', name: 'Malawi',             kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'BW', name: 'Botswana',           kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'NA', name: 'Namibia',            kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'LS', name: 'Lesotho',            kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'SZ', name: 'Eswatini',           kontinent: 'afrika', region: 'suedafrika',     schwierigkeit: 3),
  Land(iso: 'GA', name: 'Gabun',              kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 3),
  Land(iso: 'GQ', name: 'Äquatorialguinea',   kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 3),
  Land(iso: 'CF', name: 'Zentralafrik. Rep.', kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 3),
  Land(iso: 'TD', name: 'Tschad',             kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 3),
  Land(iso: 'MR', name: 'Mauretanien',        kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'GM', name: 'Gambia',             kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'GW', name: 'Guinea-Bissau',      kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'GN', name: 'Guinea',             kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'SL', name: 'Sierra Leone',       kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'LR', name: 'Liberia',            kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'TG', name: 'Togo',               kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'BJ', name: 'Benin',              kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'CV', name: 'Kap Verde',          kontinent: 'afrika', region: 'westafrika',     schwierigkeit: 3),
  Land(iso: 'ST', name: 'São Tomé',           kontinent: 'afrika', region: 'zentralafrika',  schwierigkeit: 3),
  Land(iso: 'KM', name: 'Komoren',            kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'SC', name: 'Seychellen',         kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),
  Land(iso: 'MU', name: 'Mauritius',          kontinent: 'afrika', region: 'ostafrika',      schwierigkeit: 3),

  // ── ASIEN (48) ───────────────────────────────────────────────────────────────
  Land(iso: 'CN', name: 'China',              kontinent: 'asien', region: 'ostasien',       schwierigkeit: 1),
  Land(iso: 'JP', name: 'Japan',              kontinent: 'asien', region: 'ostasien',       schwierigkeit: 1),
  Land(iso: 'IN', name: 'Indien',             kontinent: 'asien', region: 'suedasien',      schwierigkeit: 1),
  Land(iso: 'SA', name: 'Saudi-Arabien',      kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 1),
  Land(iso: 'TR', name: 'Türkei',             kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 1),
  Land(iso: 'ID', name: 'Indonesien',         kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 1),
  Land(iso: 'KR', name: 'Südkorea',           kontinent: 'asien', region: 'ostasien',       schwierigkeit: 2),
  Land(iso: 'TH', name: 'Thailand',           kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 2),
  Land(iso: 'VN', name: 'Vietnam',            kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 2),
  Land(iso: 'PK', name: 'Pakistan',           kontinent: 'asien', region: 'suedasien',      schwierigkeit: 2),
  Land(iso: 'BD', name: 'Bangladesch',        kontinent: 'asien', region: 'suedasien',      schwierigkeit: 2),
  Land(iso: 'PH', name: 'Philippinen',        kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 2),
  Land(iso: 'MY', name: 'Malaysia',           kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 2),
  Land(iso: 'NP', name: 'Nepal',              kontinent: 'asien', region: 'suedasien',      schwierigkeit: 2),
  Land(iso: 'AE', name: 'Emirate',            kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 2),
  Land(iso: 'IL', name: 'Israel',             kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 2),
  Land(iso: 'IQ', name: 'Irak',               kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 2),
  Land(iso: 'IR', name: 'Iran',               kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 2),
  Land(iso: 'AF', name: 'Afghanistan',        kontinent: 'asien', region: 'zentralasien',   schwierigkeit: 2),
  Land(iso: 'KZ', name: 'Kasachstan',         kontinent: 'asien', region: 'zentralasien',   schwierigkeit: 2),
  Land(iso: 'MN', name: 'Mongolei',           kontinent: 'asien', region: 'ostasien',       schwierigkeit: 2),
  Land(iso: 'SG', name: 'Singapur',           kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 3),
  Land(iso: 'MM', name: 'Myanmar',            kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 3),
  Land(iso: 'KH', name: 'Kambodscha',         kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 3),
  Land(iso: 'LA', name: 'Laos',               kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 3),
  Land(iso: 'LK', name: 'Sri Lanka',          kontinent: 'asien', region: 'suedasien',      schwierigkeit: 3),
  Land(iso: 'SY', name: 'Syrien',             kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'JO', name: 'Jordanien',          kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'LB', name: 'Libanon',            kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'KW', name: 'Kuwait',             kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'QA', name: 'Katar',              kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'BH', name: 'Bahrain',            kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'OM', name: 'Oman',               kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'YE', name: 'Jemen',              kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),
  Land(iso: 'UZ', name: 'Usbekistan',         kontinent: 'asien', region: 'zentralasien',   schwierigkeit: 3),
  Land(iso: 'TM', name: 'Turkmenistan',       kontinent: 'asien', region: 'zentralasien',   schwierigkeit: 3),
  Land(iso: 'AZ', name: 'Aserbaidschan',      kontinent: 'asien', region: 'kaukasus',       schwierigkeit: 3),
  Land(iso: 'GE', name: 'Georgien',           kontinent: 'asien', region: 'kaukasus',       schwierigkeit: 3),
  Land(iso: 'AM', name: 'Armenien',           kontinent: 'asien', region: 'kaukasus',       schwierigkeit: 3),
  Land(iso: 'TJ', name: 'Tadschikistan',      kontinent: 'asien', region: 'zentralasien',   schwierigkeit: 3),
  Land(iso: 'KG', name: 'Kirgistan',          kontinent: 'asien', region: 'zentralasien',   schwierigkeit: 3),
  Land(iso: 'KP', name: 'Nordkorea',          kontinent: 'asien', region: 'ostasien',       schwierigkeit: 3),
  Land(iso: 'TW', name: 'Taiwan',             kontinent: 'asien', region: 'ostasien',       schwierigkeit: 3),
  Land(iso: 'BT', name: 'Bhutan',             kontinent: 'asien', region: 'suedasien',      schwierigkeit: 3),
  Land(iso: 'MV', name: 'Malediven',          kontinent: 'asien', region: 'suedasien',      schwierigkeit: 3),
  Land(iso: 'BN', name: 'Brunei',             kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 3),
  Land(iso: 'TL', name: 'Timor-Leste',        kontinent: 'asien', region: 'suedostasien',   schwierigkeit: 3),
  Land(iso: 'PS', name: 'Palästina',          kontinent: 'asien', region: 'naherOsten',     schwierigkeit: 3),

  // ── OZEANIEN (14) ────────────────────────────────────────────────────────────
  Land(iso: 'AU', name: 'Australien',         kontinent: 'ozeanien', region: 'australien',  schwierigkeit: 1),
  Land(iso: 'NZ', name: 'Neuseeland',         kontinent: 'ozeanien', region: 'australien',  schwierigkeit: 1),
  Land(iso: 'FJ', name: 'Fidschi',            kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 2),
  Land(iso: 'PG', name: 'Papua-Neuguinea',    kontinent: 'ozeanien', region: 'melanesien',  schwierigkeit: 2),
  Land(iso: 'WS', name: 'Samoa',              kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
  Land(iso: 'TO', name: 'Tonga',              kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
  Land(iso: 'VU', name: 'Vanuatu',            kontinent: 'ozeanien', region: 'melanesien',  schwierigkeit: 3),
  Land(iso: 'SB', name: 'Salomonen',          kontinent: 'ozeanien', region: 'melanesien',  schwierigkeit: 3),
  Land(iso: 'KI', name: 'Kiribati',           kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
  Land(iso: 'FM', name: 'Mikronesien',        kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
  Land(iso: 'PW', name: 'Palau',              kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
  Land(iso: 'MH', name: 'Marshallinseln',     kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
  Land(iso: 'NR', name: 'Nauru',              kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
  Land(iso: 'TV', name: 'Tuvalu',             kontinent: 'ozeanien', region: 'pazifik',     schwierigkeit: 3),
];

/// Lookup: ISO2 → Land
final Map<String, Land> landByIso = {
  for (final l in alleLaender) l.iso: l,
};

/// Alle Länder eines Kontinents
List<Land> laenderDesKontinents(String kontinent) =>
    alleLaender.where((l) => l.kontinent == kontinent).toList();

/// 3 falsche Optionen aus gleichem Kontinent, ähnlicher Schwierigkeit
List<String> generiereUmrissOptionen(String richtigesIso, String kontinent) {
  final richtig = landByIso[richtigesIso];
  final schw = richtig?.schwierigkeit ?? 2;

  // Kandidaten: gleicher Kontinent, Schwierigkeit ±1, nicht das richtige Land
  var kandidaten = alleLaender
      .where((l) =>
          l.iso != richtigesIso &&
          l.kontinent == kontinent &&
          (l.schwierigkeit - schw).abs() <= 1)
      .toList()
    ..shuffle();

  // Fallback: ganzer Kontinent ohne Schwierigkeits-Filter
  if (kandidaten.length < 3) {
    kandidaten = alleLaender
        .where((l) => l.iso != richtigesIso && l.kontinent == kontinent)
        .toList()
      ..shuffle();
  }

  // Letzter Fallback: weltweit
  if (kandidaten.length < 3) {
    kandidaten = alleLaender.where((l) => l.iso != richtigesIso).toList()
      ..shuffle();
  }

  final optionen = kandidaten.take(3).map((l) => l.iso).toList()
    ..add(richtigesIso)
    ..shuffle();
  return optionen;
}
