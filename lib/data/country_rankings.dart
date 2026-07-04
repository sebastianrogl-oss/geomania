// Data sources: World Bank 2022-2024, UN, CIA World Factbook,
//   Wikipedia (coastline, minimum wage), The Economist Big Mac Index Jan-2021
// null = no reliable data available for this indicator
// coastlineKm = 0 for landlocked countries (valid value, filtered in quiz)

import 'laender_daten.dart';

class CountryRanking {
  final String iso2;
  final String iso3;
  final String name;
  final String flagEmoji;
  final double? area;             // km²
  final int? population;
  final double? gdpPerCapita;     // USD (current)
  final double? lifeExpectancy;   // years
  final double? co2PerCapita;     // metric tons per person
  final double? coastlineKm;      // km (0 = landlocked)
  final double? minimumWageUsd;   // monthly USD equivalent; null = no national min wage
  final double? bigMacIndexUsd;   // USD price Jan-2021 (The Economist)

  const CountryRanking({
    required this.iso2,
    required this.iso3,
    required this.name,
    required this.flagEmoji,
    this.area,
    this.population,
    this.gdpPerCapita,
    this.lifeExpectancy,
    this.co2PerCapita,
    this.coastlineKm,
    this.minimumWageUsd,
    this.bigMacIndexUsd,
  });
}

const List<CountryRanking> countryRankings = [
  // ── Europa ─────────────────────────────────────────────────────────────────
  CountryRanking(iso2:'DE', iso3:'DEU', name:'Deutschland',            flagEmoji:'🇩🇪', area:357114,    population:83516593,  gdpPerCapita:56104,  lifeExpectancy:81.1, co2PerCapita:8.1,  coastlineKm:2389,  minimumWageUsd:1204,  bigMacIndexUsd:4.16),
  CountryRanking(iso2:'FR', iso3:'FRA', name:'Frankreich',             flagEmoji:'🇫🇷', area:551695,    population:68551653,  gdpPerCapita:46103,  lifeExpectancy:82.5, co2PerCapita:4.5,  coastlineKm:4853,  minimumWageUsd:1801,  bigMacIndexUsd:4.24),
  CountryRanking(iso2:'GB', iso3:'GBR', name:'Vereinigtes Königreich', flagEmoji:'🇬🇧', area:243610,    population:69226000,  gdpPerCapita:53246,  lifeExpectancy:81.3, co2PerCapita:5.3,  coastlineKm:12429, minimumWageUsd:1394,  bigMacIndexUsd:3.39),
  CountryRanking(iso2:'IT', iso3:'ITA', name:'Italien',                flagEmoji:'🇮🇹', area:301340,    population:58952704,  gdpPerCapita:40385,  lifeExpectancy:83.6, co2PerCapita:5.6,  coastlineKm:7600,  minimumWageUsd:null,  bigMacIndexUsd:4.32),
  CountryRanking(iso2:'ES', iso3:'ESP', name:'Spanien',                flagEmoji:'🇪🇸', area:505990,    population:48848840,  gdpPerCapita:35327,  lifeExpectancy:84.0, co2PerCapita:5.7,  coastlineKm:4964,  minimumWageUsd:1455,  bigMacIndexUsd:4.24),
  CountryRanking(iso2:'PT', iso3:'PRT', name:'Portugal',               flagEmoji:'🇵🇹', area:92212,     population:10694681,  gdpPerCapita:25690,  lifeExpectancy:82.1, co2PerCapita:5.2,  coastlineKm:1793,  minimumWageUsd:828,   bigMacIndexUsd:3.25),
  CountryRanking(iso2:'NL', iso3:'NLD', name:'Niederlande',            flagEmoji:'🇳🇱', area:41543,     population:17993485,  gdpPerCapita:63140,  lifeExpectancy:82.3, co2PerCapita:9.3,  coastlineKm:451,   minimumWageUsd:3016,  bigMacIndexUsd:4.12),
  CountryRanking(iso2:'BE', iso3:'BEL', name:'Belgien',                flagEmoji:'🇧🇪', area:30528,     population:11858610,  gdpPerCapita:53210,  lifeExpectancy:82.0, co2PerCapita:8.1,  coastlineKm:67,    minimumWageUsd:2401,  bigMacIndexUsd:4.37),
  CountryRanking(iso2:'CH', iso3:'CHE', name:'Schweiz',                flagEmoji:'🇨🇭', area:41285,     population:9005582,   gdpPerCapita:100000, lifeExpectancy:84.0, co2PerCapita:4.0,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:6.50),
  CountryRanking(iso2:'AT', iso3:'AUT', name:'Österreich',             flagEmoji:'🇦🇹', area:83871,     population:9177982,   gdpPerCapita:55170,  lifeExpectancy:81.8, co2PerCapita:7.5,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:3.84),
  CountryRanking(iso2:'SE', iso3:'SWE', name:'Schweden',               flagEmoji:'🇸🇪', area:450295,    population:10569709,  gdpPerCapita:62930,  lifeExpectancy:83.3, co2PerCapita:3.5,  coastlineKm:3218,  minimumWageUsd:null,  bigMacIndexUsd:5.76),
  CountryRanking(iso2:'NO', iso3:'NOR', name:'Norwegen',               flagEmoji:'🇳🇴', area:323802,    population:5572279,   gdpPerCapita:100570, lifeExpectancy:83.7, co2PerCapita:8.3,  coastlineKm:83281, minimumWageUsd:null,  bigMacIndexUsd:5.54),
  CountryRanking(iso2:'DK', iso3:'DNK', name:'Dänemark',               flagEmoji:'🇩🇰', area:43094,     population:5976992,   gdpPerCapita:69420,  lifeExpectancy:81.4, co2PerCapita:5.8,  coastlineKm:7314,  minimumWageUsd:null,  bigMacIndexUsd:4.51),
  CountryRanking(iso2:'FI', iso3:'FIN', name:'Finnland',               flagEmoji:'🇫🇮', area:338424,    population:5619911,   gdpPerCapita:55830,  lifeExpectancy:81.8, co2PerCapita:8.0,  coastlineKm:1250,  minimumWageUsd:null,  bigMacIndexUsd:4.88),
  CountryRanking(iso2:'PL', iso3:'POL', name:'Polen',                  flagEmoji:'🇵🇱', area:312679,    population:36559233,  gdpPerCapita:22090,  lifeExpectancy:77.8, co2PerCapita:9.5,  coastlineKm:440,   minimumWageUsd:1245,  bigMacIndexUsd:3.36),
  CountryRanking(iso2:'CZ', iso3:'CZE', name:'Tschechien',             flagEmoji:'🇨🇿', area:78866,     population:10905028,  gdpPerCapita:30420,  lifeExpectancy:79.1, co2PerCapita:10.2, coastlineKm:0,     minimumWageUsd:850,   bigMacIndexUsd:4.25),
  CountryRanking(iso2:'HU', iso3:'HUN', name:'Ungarn',                 flagEmoji:'🇭🇺', area:93028,     population:9562065,   gdpPerCapita:22560,  lifeExpectancy:76.2, co2PerCapita:5.6,  coastlineKm:0,     minimumWageUsd:765,   bigMacIndexUsd:3.57),
  CountryRanking(iso2:'GR', iso3:'GRC', name:'Griechenland',           flagEmoji:'🇬🇷', area:131957,    population:10405134,  gdpPerCapita:22330,  lifeExpectancy:81.9, co2PerCapita:6.4,  coastlineKm:13676, minimumWageUsd:1215,  bigMacIndexUsd:3.31),
  CountryRanking(iso2:'RO', iso3:'ROU', name:'Rumänien',               flagEmoji:'🇷🇴', area:238397,    population:19051804,  gdpPerCapita:18290,  lifeExpectancy:75.6, co2PerCapita:4.7,  coastlineKm:225,   minimumWageUsd:915,   bigMacIndexUsd:2.33),
  CountryRanking(iso2:'HR', iso3:'HRV', name:'Kroatien',               flagEmoji:'🇭🇷', area:56594,     population:3866200,   gdpPerCapita:20460,  lifeExpectancy:78.6, co2PerCapita:4.5,  coastlineKm:5835,  minimumWageUsd:900,   bigMacIndexUsd:3.53),
  CountryRanking(iso2:'RS', iso3:'SRB', name:'Serbien',                flagEmoji:'🇷🇸', area:77474,     population:6586476,   gdpPerCapita:10260,  lifeExpectancy:75.9, co2PerCapita:6.8,  coastlineKm:0,     minimumWageUsd:510,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BG', iso3:'BGR', name:'Bulgarien',              flagEmoji:'🇧🇬', area:110879,    population:6441421,   gdpPerCapita:14420,  lifeExpectancy:75.2, co2PerCapita:7.6,  coastlineKm:354,   minimumWageUsd:550,   bigMacIndexUsd:null),
  CountryRanking(iso2:'UA', iso3:'UKR', name:'Ukraine',                flagEmoji:'🇺🇦', area:603550,    population:37860221,  gdpPerCapita:4530,   lifeExpectancy:72.1, co2PerCapita:5.0,  coastlineKm:2782,  minimumWageUsd:204,   bigMacIndexUsd:2.17),
  CountryRanking(iso2:'RU', iso3:'RUS', name:'Russland',               flagEmoji:'🇷🇺', area:17098242,  population:143533851, gdpPerCapita:14250,  lifeExpectancy:72.4, co2PerCapita:12.3, coastlineKm:37653, minimumWageUsd:346,   bigMacIndexUsd:2.19),
  CountryRanking(iso2:'TR', iso3:'TUR', name:'Türkei',                 flagEmoji:'🇹🇷', area:783562,    population:85518661,  gdpPerCapita:13000,  lifeExpectancy:78.0, co2PerCapita:5.8,  coastlineKm:7200,  minimumWageUsd:770,   bigMacIndexUsd:2.04),
  CountryRanking(iso2:'AL', iso3:'ALB', name:'Albanien',               flagEmoji:'🇦🇱', area:28748,     population:2786748,   gdpPerCapita:6920,   lifeExpectancy:78.7, co2PerCapita:2.5,  coastlineKm:362,   minimumWageUsd:471,   bigMacIndexUsd:null),
  CountryRanking(iso2:'AD', iso3:'AND', name:'Andorra',                flagEmoji:'🇦🇩', area:468,       population:79824,     gdpPerCapita:41000,  lifeExpectancy:83.0, co2PerCapita:5.5,  coastlineKm:0,     minimumWageUsd:400,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BA', iso3:'BIH', name:'Bosnien und Herzegowina',flagEmoji:'🇧🇦', area:51209,     population:3210847,   gdpPerCapita:7800,   lifeExpectancy:77.6, co2PerCapita:7.1,  coastlineKm:20,    minimumWageUsd:269,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BY', iso3:'BLR', name:'Belarus',                flagEmoji:'🇧🇾', area:207600,    population:9498238,   gdpPerCapita:7700,   lifeExpectancy:74.2, co2PerCapita:6.1,  coastlineKm:0,     minimumWageUsd:122,   bigMacIndexUsd:null),
  CountryRanking(iso2:'CY', iso3:'CYP', name:'Zypern',                 flagEmoji:'🇨🇾', area:9251,      population:1260138,   gdpPerCapita:30800,  lifeExpectancy:81.5, co2PerCapita:6.6,  coastlineKm:648,   minimumWageUsd:1006,  bigMacIndexUsd:null),
  CountryRanking(iso2:'EE', iso3:'EST', name:'Estland',                flagEmoji:'🇪🇪', area:45228,     population:1365884,   gdpPerCapita:29200,  lifeExpectancy:77.8, co2PerCapita:9.8,  coastlineKm:3794,  minimumWageUsd:857,   bigMacIndexUsd:3.21),
  CountryRanking(iso2:'IE', iso3:'IRL', name:'Irland',                 flagEmoji:'🇮🇪', area:70273,     population:5123536,   gdpPerCapita:99200,  lifeExpectancy:82.9, co2PerCapita:8.3,  coastlineKm:1448,  minimumWageUsd:1576,  bigMacIndexUsd:4.33),
  CountryRanking(iso2:'IS', iso3:'ISL', name:'Island',                 flagEmoji:'🇮🇸', area:102775,    population:376248,    gdpPerCapita:72000,  lifeExpectancy:83.1, co2PerCapita:12.0, coastlineKm:4970,  minimumWageUsd:1198,  bigMacIndexUsd:null),
  CountryRanking(iso2:'LI', iso3:'LIE', name:'Liechtenstein',          flagEmoji:'🇱🇮', area:160,       population:39584,     gdpPerCapita:170000, lifeExpectancy:83.0, co2PerCapita:4.5,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'LT', iso3:'LTU', name:'Litauen',                flagEmoji:'🇱🇹', area:65300,     population:2831462,   gdpPerCapita:24300,  lifeExpectancy:75.9, co2PerCapita:5.3,  coastlineKm:90,    minimumWageUsd:1364,  bigMacIndexUsd:2.85),
  CountryRanking(iso2:'LU', iso3:'LUX', name:'Luxemburg',              flagEmoji:'🇱🇺', area:2586,      population:672050,    gdpPerCapita:130000, lifeExpectancy:82.8, co2PerCapita:14.5, coastlineKm:0,     minimumWageUsd:2966,  bigMacIndexUsd:null),
  CountryRanking(iso2:'LV', iso3:'LVA', name:'Lettland',               flagEmoji:'🇱🇻', area:64589,     population:1850651,   gdpPerCapita:22200,  lifeExpectancy:75.1, co2PerCapita:3.9,  coastlineKm:498,   minimumWageUsd:999,   bigMacIndexUsd:2.85),
  CountryRanking(iso2:'MC', iso3:'MCO', name:'Monaco',                 flagEmoji:'🇲🇨', area:2,         population:39050,     gdpPerCapita:185000, lifeExpectancy:86.0, co2PerCapita:2.5,  coastlineKm:4,     minimumWageUsd:2105,  bigMacIndexUsd:null),
  CountryRanking(iso2:'MD', iso3:'MDA', name:'Moldau',                 flagEmoji:'🇲🇩', area:33846,     population:2512000,   gdpPerCapita:5800,   lifeExpectancy:70.6, co2PerCapita:2.6,  coastlineKm:0,     minimumWageUsd:222,   bigMacIndexUsd:2.76),
  CountryRanking(iso2:'ME', iso3:'MNE', name:'Montenegro',             flagEmoji:'🇲🇪', area:13812,     population:620739,    gdpPerCapita:10300,  lifeExpectancy:77.8, co2PerCapita:4.8,  coastlineKm:294,   minimumWageUsd:511,   bigMacIndexUsd:null),
  CountryRanking(iso2:'MK', iso3:'MKD', name:'Nordmazedonien',         flagEmoji:'🇲🇰', area:25713,     population:2082958,   gdpPerCapita:7400,   lifeExpectancy:75.7, co2PerCapita:4.3,  coastlineKm:0,     minimumWageUsd:406,   bigMacIndexUsd:null),
  CountryRanking(iso2:'MT', iso3:'MLT', name:'Malta',                  flagEmoji:'🇲🇹', area:316,       population:535064,    gdpPerCapita:34800,  lifeExpectancy:82.8, co2PerCapita:4.7,  coastlineKm:253,   minimumWageUsd:767,   bigMacIndexUsd:null),
  CountryRanking(iso2:'SI', iso3:'SVN', name:'Slowenien',              flagEmoji:'🇸🇮', area:20273,     population:2119844,   gdpPerCapita:32400,  lifeExpectancy:81.3, co2PerCapita:7.1,  coastlineKm:47,    minimumWageUsd:1423,  bigMacIndexUsd:2.84),
  CountryRanking(iso2:'SK', iso3:'SVK', name:'Slowakei',               flagEmoji:'🇸🇰', area:49035,     population:5460185,   gdpPerCapita:21900,  lifeExpectancy:77.3, co2PerCapita:6.9,  coastlineKm:0,     minimumWageUsd:828,   bigMacIndexUsd:3.40),
  CountryRanking(iso2:'SM', iso3:'SMR', name:'San Marino',             flagEmoji:'🇸🇲', area:61,        population:33660,     gdpPerCapita:50000,  lifeExpectancy:85.0, co2PerCapita:null, coastlineKm:0,     minimumWageUsd:1735,  bigMacIndexUsd:null),
  CountryRanking(iso2:'VA', iso3:'VAT', name:'Vatikanstadt',           flagEmoji:'🇻🇦', area:1,         population:800,       gdpPerCapita:null,   lifeExpectancy:null, co2PerCapita:null, coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'XK', iso3:'XKX', name:'Kosovo',                 flagEmoji:'🇽🇰', area:10887,     population:1775378,   gdpPerCapita:5300,   lifeExpectancy:73.8, co2PerCapita:5.8,  coastlineKm:0,     minimumWageUsd:224,   bigMacIndexUsd:null),

  // ── Amerika ────────────────────────────────────────────────────────────────
  CountryRanking(iso2:'US', iso3:'USA', name:'Vereinigte Staaten',    flagEmoji:'🇺🇸', area:9833517,   population:340110988, gdpPerCapita:84534,  lifeExpectancy:78.5, co2PerCapita:15.1, coastlineKm:19924, minimumWageUsd:1256,  bigMacIndexUsd:4.82),
  CountryRanking(iso2:'CA', iso3:'CAN', name:'Kanada',                flagEmoji:'🇨🇦', area:9984670,   population:41288599,  gdpPerCapita:54340,  lifeExpectancy:82.2, co2PerCapita:15.3, coastlineKm:202080,minimumWageUsd:1008,  bigMacIndexUsd:6.52),
  CountryRanking(iso2:'MX', iso3:'MEX', name:'Mexiko',                flagEmoji:'🇲🇽', area:1964375,   population:130861007, gdpPerCapita:13800,  lifeExpectancy:74.9, co2PerCapita:3.9,  coastlineKm:9330,  minimumWageUsd:278,   bigMacIndexUsd:2.64),
  CountryRanking(iso2:'BR', iso3:'BRA', name:'Brasilien',             flagEmoji:'🇧🇷', area:8515767,   population:211998573, gdpPerCapita:10311,  lifeExpectancy:74.0, co2PerCapita:2.3,  coastlineKm:7491,  minimumWageUsd:292,   bigMacIndexUsd:5.15),
  CountryRanking(iso2:'AR', iso3:'ARG', name:'Argentinien',           flagEmoji:'🇦🇷', area:2780400,   population:45696159,  gdpPerCapita:13700,  lifeExpectancy:76.9, co2PerCapita:4.4,  coastlineKm:4989,  minimumWageUsd:null,  bigMacIndexUsd:4.65),
  CountryRanking(iso2:'CO', iso3:'COL', name:'Kolumbien',             flagEmoji:'🇨🇴', area:1141748,   population:52886363,  gdpPerCapita:7200,   lifeExpectancy:77.0, co2PerCapita:1.8,  coastlineKm:3208,  minimumWageUsd:350,   bigMacIndexUsd:4.73),
  CountryRanking(iso2:'CL', iso3:'CHL', name:'Chile',                 flagEmoji:'🇨🇱', area:756102,    population:19764771,  gdpPerCapita:16800,  lifeExpectancy:80.0, co2PerCapita:4.8,  coastlineKm:6435,  minimumWageUsd:553,   bigMacIndexUsd:2.70),
  CountryRanking(iso2:'PE', iso3:'PER', name:'Peru',                  flagEmoji:'🇵🇪', area:1285216,   population:34217848,  gdpPerCapita:8100,   lifeExpectancy:73.4, co2PerCapita:1.8,  coastlineKm:2414,  minimumWageUsd:318,   bigMacIndexUsd:3.51),
  CountryRanking(iso2:'VE', iso3:'VEN', name:'Venezuela',             flagEmoji:'🇻🇪', area:912050,    population:28405543,  gdpPerCapita:5100,   lifeExpectancy:72.8, co2PerCapita:3.8,  coastlineKm:2800,  minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'EC', iso3:'ECU', name:'Ecuador',               flagEmoji:'🇪🇨', area:283561,    population:18135478,  gdpPerCapita:6300,   lifeExpectancy:74.2, co2PerCapita:2.6,  coastlineKm:2237,  minimumWageUsd:594,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BO', iso3:'BOL', name:'Bolivien',              flagEmoji:'🇧🇴', area:1098581,   population:12413315,  gdpPerCapita:4000,   lifeExpectancy:64.1, co2PerCapita:1.8,  coastlineKm:0,     minimumWageUsd:362,   bigMacIndexUsd:null),
  CountryRanking(iso2:'UY', iso3:'URY', name:'Uruguay',               flagEmoji:'🇺🇾', area:176215,    population:3386588,   gdpPerCapita:23400,  lifeExpectancy:78.8, co2PerCapita:2.1,  coastlineKm:660,   minimumWageUsd:507,   bigMacIndexUsd:4.33),
  CountryRanking(iso2:'PY', iso3:'PRY', name:'Paraguay',              flagEmoji:'🇵🇾', area:406752,    population:7356409,   gdpPerCapita:6000,   lifeExpectancy:74.3, co2PerCapita:1.4,  coastlineKm:0,     minimumWageUsd:363,   bigMacIndexUsd:null),
  CountryRanking(iso2:'GY', iso3:'GUY', name:'Guyana',                flagEmoji:'🇬🇾', area:214969,    population:804567,    gdpPerCapita:15000,  lifeExpectancy:70.4, co2PerCapita:2.8,  coastlineKm:459,   minimumWageUsd:168,   bigMacIndexUsd:null),
  CountryRanking(iso2:'SR', iso3:'SUR', name:'Suriname',              flagEmoji:'🇸🇷', area:163820,    population:618040,    gdpPerCapita:5200,   lifeExpectancy:72.0, co2PerCapita:3.2,  coastlineKm:386,   minimumWageUsd:289,   bigMacIndexUsd:null),
  CountryRanking(iso2:'CU', iso3:'CUB', name:'Kuba',                  flagEmoji:'🇨🇺', area:109884,    population:10979783,  gdpPerCapita:null,   lifeExpectancy:78.8, co2PerCapita:2.5,  coastlineKm:3735,  minimumWageUsd:7,     bigMacIndexUsd:null),
  CountryRanking(iso2:'DO', iso3:'DOM', name:'Dominikanische Republik',flagEmoji:'🇩🇴', area:48671,     population:11427557,  gdpPerCapita:10100,  lifeExpectancy:74.2, co2PerCapita:2.4,  coastlineKm:1288,  minimumWageUsd:166,   bigMacIndexUsd:null),
  CountryRanking(iso2:'HT', iso3:'HTI', name:'Haiti',                 flagEmoji:'🇭🇹', area:27750,     population:11724763,  gdpPerCapita:1500,   lifeExpectancy:64.0, co2PerCapita:0.3,  coastlineKm:1771,  minimumWageUsd:155,   bigMacIndexUsd:null),
  CountryRanking(iso2:'GT', iso3:'GTM', name:'Guatemala',             flagEmoji:'🇬🇹', area:108889,    population:18406359,  gdpPerCapita:5400,   lifeExpectancy:73.0, co2PerCapita:1.0,  coastlineKm:400,   minimumWageUsd:null,  bigMacIndexUsd:3.25),
  CountryRanking(iso2:'HN', iso3:'HND', name:'Honduras',              flagEmoji:'🇭🇳', area:112492,    population:10593798,  gdpPerCapita:3100,   lifeExpectancy:74.8, co2PerCapita:1.2,  coastlineKm:832,   minimumWageUsd:371,   bigMacIndexUsd:3.53),
  CountryRanking(iso2:'SV', iso3:'SLV', name:'El Salvador',           flagEmoji:'🇸🇻', area:21041,     population:6364943,   gdpPerCapita:4900,   lifeExpectancy:72.0, co2PerCapita:1.0,  coastlineKm:307,   minimumWageUsd:304,   bigMacIndexUsd:null),
  CountryRanking(iso2:'NI', iso3:'NIC', name:'Nicaragua',             flagEmoji:'🇳🇮', area:130373,    population:7046310,   gdpPerCapita:2400,   lifeExpectancy:74.5, co2PerCapita:0.9,  coastlineKm:910,   minimumWageUsd:155,   bigMacIndexUsd:3.49),
  CountryRanking(iso2:'CR', iso3:'CRI', name:'Costa Rica',            flagEmoji:'🇨🇷', area:51100,     population:5129910,   gdpPerCapita:14800,  lifeExpectancy:80.0, co2PerCapita:1.4,  coastlineKm:1290,  minimumWageUsd:696,   bigMacIndexUsd:4.36),
  CountryRanking(iso2:'PA', iso3:'PAN', name:'Panama',                flagEmoji:'🇵🇦', area:75417,     population:4515577,   gdpPerCapita:16300,  lifeExpectancy:79.1, co2PerCapita:2.4,  coastlineKm:2490,  minimumWageUsd:153,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BZ', iso3:'BLZ', name:'Belize',                flagEmoji:'🇧🇿', area:22966,     population:441471,    gdpPerCapita:6000,   lifeExpectancy:74.2, co2PerCapita:1.4,  coastlineKm:386,   minimumWageUsd:248,   bigMacIndexUsd:null),
  CountryRanking(iso2:'JM', iso3:'JAM', name:'Jamaika',               flagEmoji:'🇯🇲', area:10991,     population:2839175,   gdpPerCapita:6000,   lifeExpectancy:72.6, co2PerCapita:2.7,  coastlineKm:1022,  minimumWageUsd:343,   bigMacIndexUsd:null),
  CountryRanking(iso2:'TT', iso3:'TTO', name:'Trinidad und Tobago',   flagEmoji:'🇹🇹', area:5130,      population:1534937,   gdpPerCapita:18200,  lifeExpectancy:71.5, co2PerCapita:25.4, coastlineKm:362,   minimumWageUsd:222,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BB', iso3:'BRB', name:'Barbados',              flagEmoji:'🇧🇧', area:430,       population:281635,    gdpPerCapita:18900,  lifeExpectancy:79.0, co2PerCapita:4.5,  coastlineKm:97,    minimumWageUsd:455,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BS', iso3:'BHS', name:'Bahamas',               flagEmoji:'🇧🇸', area:13943,     population:410862,    gdpPerCapita:34400,  lifeExpectancy:74.1, co2PerCapita:5.8,  coastlineKm:3542,  minimumWageUsd:910,   bigMacIndexUsd:null),
  CountryRanking(iso2:'AG', iso3:'ATG', name:'Antigua und Barbuda',   flagEmoji:'🇦🇬', area:442,       population:93763,     gdpPerCapita:20500,  lifeExpectancy:78.2, co2PerCapita:5.5,  coastlineKm:153,   minimumWageUsd:263,   bigMacIndexUsd:null),
  CountryRanking(iso2:'DM', iso3:'DMA', name:'Dominica',              flagEmoji:'🇩🇲', area:751,       population:72737,     gdpPerCapita:9800,   lifeExpectancy:77.2, co2PerCapita:1.9,  coastlineKm:148,   minimumWageUsd:130,   bigMacIndexUsd:null),
  CountryRanking(iso2:'GD', iso3:'GRD', name:'Grenada',               flagEmoji:'🇬🇩', area:344,       population:124610,    gdpPerCapita:12800,  lifeExpectancy:73.2, co2PerCapita:2.3,  coastlineKm:121,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'KN', iso3:'KNA', name:'St. Kitts und Nevis',   flagEmoji:'🇰🇳', area:261,       population:47755,     gdpPerCapita:22200,  lifeExpectancy:76.2, co2PerCapita:4.5,  coastlineKm:135,   minimumWageUsd:375,   bigMacIndexUsd:null),
  CountryRanking(iso2:'LC', iso3:'LCA', name:'St. Lucia',             flagEmoji:'🇱🇨', area:616,       population:179237,    gdpPerCapita:13000,  lifeExpectancy:76.2, co2PerCapita:2.3,  coastlineKm:158,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'VC', iso3:'VCT', name:'St. Vincent',           flagEmoji:'🇻🇨', area:389,       population:103698,    gdpPerCapita:9400,   lifeExpectancy:73.0, co2PerCapita:1.8,  coastlineKm:84,    minimumWageUsd:null,  bigMacIndexUsd:null),

  // ── Asien ──────────────────────────────────────────────────────────────────
  CountryRanking(iso2:'CN', iso3:'CHN', name:'China',               flagEmoji:'🇨🇳', area:9596960,  population:1408975000, gdpPerCapita:13303,  lifeExpectancy:78.6, co2PerCapita:8.0,  coastlineKm:14500, minimumWageUsd:223,   bigMacIndexUsd:3.17),
  CountryRanking(iso2:'JP', iso3:'JPN', name:'Japan',               flagEmoji:'🇯🇵', area:377930,   population:123975371,  gdpPerCapita:32487,  lifeExpectancy:84.3, co2PerCapita:9.0,  coastlineKm:29751, minimumWageUsd:809,   bigMacIndexUsd:3.71),
  CountryRanking(iso2:'IN', iso3:'IND', name:'Indien',              flagEmoji:'🇮🇳', area:3287263,  population:1450935791, gdpPerCapita:2695,   lifeExpectancy:70.2, co2PerCapita:1.9,  coastlineKm:11098, minimumWageUsd:72,    bigMacIndexUsd:2.74),
  CountryRanking(iso2:'KR', iso3:'KOR', name:'Südkorea',            flagEmoji:'🇰🇷', area:100210,   population:51751065,   gdpPerCapita:34200,  lifeExpectancy:83.6, co2PerCapita:12.8, coastlineKm:2413,  minimumWageUsd:609,   bigMacIndexUsd:4.19),
  CountryRanking(iso2:'ID', iso3:'IDN', name:'Indonesien',          flagEmoji:'🇮🇩', area:1904569,  population:283487931,  gdpPerCapita:5000,   lifeExpectancy:68.3, co2PerCapita:2.2,  coastlineKm:54716, minimumWageUsd:194,   bigMacIndexUsd:2.32),
  CountryRanking(iso2:'TH', iso3:'THA', name:'Thailand',            flagEmoji:'🇹🇭', area:513120,   population:71668011,   gdpPerCapita:8100,   lifeExpectancy:78.1, co2PerCapita:3.8,  coastlineKm:3219,  minimumWageUsd:273,   bigMacIndexUsd:4.08),
  CountryRanking(iso2:'VN', iso3:'VNM', name:'Vietnam',             flagEmoji:'🇻🇳', area:331212,   population:100987686,  gdpPerCapita:4300,   lifeExpectancy:74.8, co2PerCapita:3.0,  coastlineKm:3444,  minimumWageUsd:265,   bigMacIndexUsd:1.59),
  CountryRanking(iso2:'PH', iso3:'PHL', name:'Philippinen',         flagEmoji:'🇵🇭', area:300000,   population:115843670,  gdpPerCapita:4000,   lifeExpectancy:71.8, co2PerCapita:1.4,  coastlineKm:36289, minimumWageUsd:289,   bigMacIndexUsd:2.87),
  CountryRanking(iso2:'MY', iso3:'MYS', name:'Malaysia',            flagEmoji:'🇲🇾', area:329847,   population:35557673,   gdpPerCapita:13200,  lifeExpectancy:76.0, co2PerCapita:8.3,  coastlineKm:4675,  minimumWageUsd:336,   bigMacIndexUsd:2.35),
  CountryRanking(iso2:'SG', iso3:'SGP', name:'Singapur',            flagEmoji:'🇸🇬', area:728,      population:6036860,    gdpPerCapita:88000,  lifeExpectancy:83.9, co2PerCapita:7.9,  coastlineKm:193,   minimumWageUsd:null,  bigMacIndexUsd:4.26),
  CountryRanking(iso2:'PK', iso3:'PAK', name:'Pakistan',            flagEmoji:'🇵🇰', area:881913,   population:251269164,  gdpPerCapita:1500,   lifeExpectancy:67.8, co2PerCapita:1.0,  coastlineKm:1046,  minimumWageUsd:107,   bigMacIndexUsd:3.30),
  CountryRanking(iso2:'BD', iso3:'BGD', name:'Bangladesch',         flagEmoji:'🇧🇩', area:147570,   population:173562364,  gdpPerCapita:2800,   lifeExpectancy:73.0, co2PerCapita:0.6,  coastlineKm:580,   minimumWageUsd:13,    bigMacIndexUsd:null),
  CountryRanking(iso2:'NP', iso3:'NPL', name:'Nepal',               flagEmoji:'🇳🇵', area:147181,   population:29651054,   gdpPerCapita:1400,   lifeExpectancy:70.3, co2PerCapita:0.5,  coastlineKm:0,     minimumWageUsd:166,   bigMacIndexUsd:null),
  CountryRanking(iso2:'MM', iso3:'MMR', name:'Myanmar',             flagEmoji:'🇲🇲', area:676578,   population:54500091,   gdpPerCapita:1200,   lifeExpectancy:66.2, co2PerCapita:0.7,  coastlineKm:1930,  minimumWageUsd:138,   bigMacIndexUsd:null),
  CountryRanking(iso2:'KZ', iso3:'KAZ', name:'Kasachstan',          flagEmoji:'🇰🇿', area:2724900,  population:20592571,   gdpPerCapita:12000,  lifeExpectancy:73.0, co2PerCapita:16.8, coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'UZ', iso3:'UZB', name:'Usbekistan',          flagEmoji:'🇺🇿', area:448978,   population:36361859,   gdpPerCapita:2800,   lifeExpectancy:70.6, co2PerCapita:3.8,  coastlineKm:0,     minimumWageUsd:71,    bigMacIndexUsd:null),
  CountryRanking(iso2:'GE', iso3:'GEO', name:'Georgien',            flagEmoji:'🇬🇪', area:69700,    population:3699557,    gdpPerCapita:7200,   lifeExpectancy:74.6, co2PerCapita:3.0,  coastlineKm:310,   minimumWageUsd:8,     bigMacIndexUsd:null),
  CountryRanking(iso2:'AM', iso3:'ARM', name:'Armenien',            flagEmoji:'🇦🇲', area:29743,    population:3033500,    gdpPerCapita:7600,   lifeExpectancy:74.9, co2PerCapita:3.3,  coastlineKm:0,     minimumWageUsd:190,   bigMacIndexUsd:null),
  CountryRanking(iso2:'AZ', iso3:'AZE', name:'Aserbaidschan',       flagEmoji:'🇦🇿', area:86600,    population:10202830,   gdpPerCapita:8200,   lifeExpectancy:72.6, co2PerCapita:4.1,  coastlineKm:0,     minimumWageUsd:203,   bigMacIndexUsd:3.95),
  CountryRanking(iso2:'AF', iso3:'AFG', name:'Afghanistan',         flagEmoji:'🇦🇫', area:652230,   population:42647492,   gdpPerCapita:450,    lifeExpectancy:63.1, co2PerCapita:0.3,  coastlineKm:0,     minimumWageUsd:70,    bigMacIndexUsd:null),
  CountryRanking(iso2:'KG', iso3:'KGZ', name:'Kirgisistan',         flagEmoji:'🇰🇬', area:199951,   population:7000000,    gdpPerCapita:1700,   lifeExpectancy:72.1, co2PerCapita:1.8,  coastlineKm:0,     minimumWageUsd:28,    bigMacIndexUsd:null),
  CountryRanking(iso2:'TJ', iso3:'TJK', name:'Tadschikistan',       flagEmoji:'🇹🇯', area:143100,   population:10143543,   gdpPerCapita:1200,   lifeExpectancy:72.0, co2PerCapita:1.0,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'TM', iso3:'TKM', name:'Turkmenistan',        flagEmoji:'🇹🇲', area:488100,   population:6341855,    gdpPerCapita:8100,   lifeExpectancy:67.8, co2PerCapita:12.5, coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'MN', iso3:'MNG', name:'Mongolei',            flagEmoji:'🇲🇳', area:1564116,  population:3447157,    gdpPerCapita:5500,   lifeExpectancy:70.9, co2PerCapita:8.5,  coastlineKm:0,     minimumWageUsd:229,   bigMacIndexUsd:null),
  CountryRanking(iso2:'KP', iso3:'PRK', name:'Nordkorea',           flagEmoji:'🇰🇵', area:120538,   population:25971909,   gdpPerCapita:null,   lifeExpectancy:72.3, co2PerCapita:3.0,  coastlineKm:2495,  minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'LA', iso3:'LAO', name:'Laos',                flagEmoji:'🇱🇦', area:236800,   population:7595062,    gdpPerCapita:2200,   lifeExpectancy:68.1, co2PerCapita:2.4,  coastlineKm:0,     minimumWageUsd:100,   bigMacIndexUsd:null),
  CountryRanking(iso2:'KH', iso3:'KHM', name:'Kambodscha',          flagEmoji:'🇰🇭', area:181035,   population:17218682,   gdpPerCapita:1800,   lifeExpectancy:70.0, co2PerCapita:0.8,  coastlineKm:443,   minimumWageUsd:200,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BT', iso3:'BTN', name:'Bhutan',              flagEmoji:'🇧🇹', area:38394,    population:782455,     gdpPerCapita:3600,   lifeExpectancy:71.8, co2PerCapita:1.3,  coastlineKm:0,     minimumWageUsd:46,    bigMacIndexUsd:null),
  CountryRanking(iso2:'LK', iso3:'LKA', name:'Sri Lanka',           flagEmoji:'🇱🇰', area:65610,    population:22156000,   gdpPerCapita:3500,   lifeExpectancy:77.1, co2PerCapita:1.1,  coastlineKm:1340,  minimumWageUsd:90,    bigMacIndexUsd:3.13),
  CountryRanking(iso2:'MV', iso3:'MDV', name:'Malediven',           flagEmoji:'🇲🇻', area:298,      population:521021,     gdpPerCapita:12000,  lifeExpectancy:80.1, co2PerCapita:3.6,  coastlineKm:644,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'TL', iso3:'TLS', name:'Timor-Leste',         flagEmoji:'🇹🇱', area:14874,    population:1341296,    gdpPerCapita:2100,   lifeExpectancy:68.0, co2PerCapita:0.8,  coastlineKm:706,   minimumWageUsd:115,   bigMacIndexUsd:null),
  CountryRanking(iso2:'BN', iso3:'BRN', name:'Brunei',              flagEmoji:'🇧🇳', area:5765,     population:449002,     gdpPerCapita:37000,  lifeExpectancy:76.8, co2PerCapita:24.1, coastlineKm:161,   minimumWageUsd:null,  bigMacIndexUsd:null),

  // ── Naher Osten ────────────────────────────────────────────────────────────
  CountryRanking(iso2:'SA', iso3:'SAU', name:'Saudi-Arabien',                  flagEmoji:'🇸🇦', area:2149690, population:35300280, gdpPerCapita:27000, lifeExpectancy:74.9, co2PerCapita:19.3, coastlineKm:2640,  minimumWageUsd:null,  bigMacIndexUsd:3.73),
  CountryRanking(iso2:'AE', iso3:'ARE', name:'Vereinigte Arabische Emirate',   flagEmoji:'🇦🇪', area:83600,   population:10986400,  gdpPerCapita:50000, lifeExpectancy:79.0, co2PerCapita:22.5, coastlineKm:1318,  minimumWageUsd:null,  bigMacIndexUsd:4.82),
  CountryRanking(iso2:'IR', iso3:'IRN', name:'Iran',                           flagEmoji:'🇮🇷', area:1648195, population:91567738,  gdpPerCapita:4000,  lifeExpectancy:76.8, co2PerCapita:8.1,  coastlineKm:2440,  minimumWageUsd:145,   bigMacIndexUsd:null),
  CountryRanking(iso2:'IQ', iso3:'IRQ', name:'Irak',                           flagEmoji:'🇮🇶', area:438317,  population:46042015,  gdpPerCapita:5600,  lifeExpectancy:72.6, co2PerCapita:4.2,  coastlineKm:58,    minimumWageUsd:214,   bigMacIndexUsd:null),
  CountryRanking(iso2:'IL', iso3:'ISR', name:'Israel',                         flagEmoji:'🇮🇱', area:20770,   population:9974400,   gdpPerCapita:55000, lifeExpectancy:83.0, co2PerCapita:6.0,  coastlineKm:273,   minimumWageUsd:1995,  bigMacIndexUsd:5.27),
  CountryRanking(iso2:'JO', iso3:'JOR', name:'Jordanien',                      flagEmoji:'🇯🇴', area:89342,   population:11552876,  gdpPerCapita:4400,  lifeExpectancy:75.1, co2PerCapita:2.3,  coastlineKm:26,    minimumWageUsd:409,   bigMacIndexUsd:3.24),
  CountryRanking(iso2:'LB', iso3:'LBN', name:'Libanon',                        flagEmoji:'🇱🇧', area:10452,   population:5805962,   gdpPerCapita:4200,  lifeExpectancy:79.1, co2PerCapita:4.4,  coastlineKm:225,   minimumWageUsd:200,   bigMacIndexUsd:1.49),
  CountryRanking(iso2:'QA', iso3:'QAT', name:'Katar',                          flagEmoji:'🇶🇦', area:11586,   population:2857822,   gdpPerCapita:82000, lifeExpectancy:80.2, co2PerCapita:38.6, coastlineKm:563,   minimumWageUsd:274,   bigMacIndexUsd:3.57),
  CountryRanking(iso2:'KW', iso3:'KWT', name:'Kuwait',                         flagEmoji:'🇰🇼', area:17818,   population:4897263,   gdpPerCapita:35000, lifeExpectancy:77.8, co2PerCapita:24.0, coastlineKm:499,   minimumWageUsd:216,   bigMacIndexUsd:3.59),
  CountryRanking(iso2:'OM', iso3:'OMN', name:'Oman',                           flagEmoji:'🇴🇲', area:309500,  population:5281538,   gdpPerCapita:19000, lifeExpectancy:77.0, co2PerCapita:16.7, coastlineKm:2092,  minimumWageUsd:592,   bigMacIndexUsd:2.86),
  CountryRanking(iso2:'YE', iso3:'YEM', name:'Jemen',                          flagEmoji:'🇾🇪', area:527968,  population:40583164,  gdpPerCapita:600,   lifeExpectancy:65.1, co2PerCapita:0.5,  coastlineKm:1906,  minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'BH', iso3:'BHR', name:'Bahrain',                        flagEmoji:'🇧🇭', area:765,     population:1472233,   gdpPerCapita:28000, lifeExpectancy:79.1, co2PerCapita:23.5, coastlineKm:161,   minimumWageUsd:null,  bigMacIndexUsd:1.40),
  CountryRanking(iso2:'SY', iso3:'SYR', name:'Syrien',                         flagEmoji:'🇸🇾', area:185180,  population:21324000,  gdpPerCapita:null,  lifeExpectancy:73.1, co2PerCapita:1.7,  coastlineKm:193,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'PS', iso3:'PSE', name:'Palästina',                      flagEmoji:'🇵🇸', area:6020,    population:5483450,   gdpPerCapita:4000,  lifeExpectancy:74.1, co2PerCapita:0.6,  coastlineKm:40,    minimumWageUsd:null,  bigMacIndexUsd:null),

  // ── Afrika ─────────────────────────────────────────────────────────────────
  CountryRanking(iso2:'NG', iso3:'NGA', name:'Nigeria',                      flagEmoji:'🇳🇬', area:923768,  population:232679478, gdpPerCapita:2000,  lifeExpectancy:54.3, co2PerCapita:0.7,  coastlineKm:853,   minimumWageUsd:176,   bigMacIndexUsd:null),
  CountryRanking(iso2:'ET', iso3:'ETH', name:'Äthiopien',                    flagEmoji:'🇪🇹', area:1104300, population:132059767, gdpPerCapita:1000,  lifeExpectancy:67.8, co2PerCapita:0.2,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'EG', iso3:'EGY', name:'Ägypten',                      flagEmoji:'🇪🇬', area:1001450, population:116538258, gdpPerCapita:3500,  lifeExpectancy:72.1, co2PerCapita:2.5,  coastlineKm:2450,  minimumWageUsd:118,   bigMacIndexUsd:2.64),
  CountryRanking(iso2:'ZA', iso3:'ZAF', name:'Südafrika',                    flagEmoji:'🇿🇦', area:1219090, population:64007187,  gdpPerCapita:6700,  lifeExpectancy:64.0, co2PerCapita:8.5,  coastlineKm:2798,  minimumWageUsd:355,   bigMacIndexUsd:4.71),
  CountryRanking(iso2:'KE', iso3:'KEN', name:'Kenia',                        flagEmoji:'🇰🇪', area:580367,  population:56432944,  gdpPerCapita:2200,  lifeExpectancy:66.3, co2PerCapita:0.4,  coastlineKm:536,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'GH', iso3:'GHA', name:'Ghana',                        flagEmoji:'🇬🇭', area:238533,  population:34427414,  gdpPerCapita:2500,  lifeExpectancy:64.2, co2PerCapita:0.6,  coastlineKm:539,   minimumWageUsd:102,   bigMacIndexUsd:null),
  CountryRanking(iso2:'TZ', iso3:'TZA', name:'Tansania',                     flagEmoji:'🇹🇿', area:945087,  population:68560157,  gdpPerCapita:1200,  lifeExpectancy:67.3, co2PerCapita:0.3,  coastlineKm:1424,  minimumWageUsd:73,    bigMacIndexUsd:null),
  CountryRanking(iso2:'MA', iso3:'MAR', name:'Marokko',                      flagEmoji:'🇲🇦', area:446550,  population:38081173,  gdpPerCapita:3800,  lifeExpectancy:75.9, co2PerCapita:1.9,  coastlineKm:2945,  minimumWageUsd:349,   bigMacIndexUsd:null),
  CountryRanking(iso2:'DZ', iso3:'DZA', name:'Algerien',                     flagEmoji:'🇩🇿', area:2381741, population:46814308,  gdpPerCapita:4200,  lifeExpectancy:77.1, co2PerCapita:4.0,  coastlineKm:998,   minimumWageUsd:185,   bigMacIndexUsd:null),
  CountryRanking(iso2:'TN', iso3:'TUN', name:'Tunesien',                     flagEmoji:'🇹🇳', area:163610,  population:12277109,  gdpPerCapita:4200,  lifeExpectancy:75.7, co2PerCapita:2.8,  coastlineKm:1148,  minimumWageUsd:166,   bigMacIndexUsd:null),
  CountryRanking(iso2:'SN', iso3:'SEN', name:'Senegal',                      flagEmoji:'🇸🇳', area:196722,  population:18501984,  gdpPerCapita:1700,  lifeExpectancy:68.3, co2PerCapita:0.6,  coastlineKm:531,   minimumWageUsd:34,    bigMacIndexUsd:null),
  CountryRanking(iso2:'CM', iso3:'CMR', name:'Kamerun',                      flagEmoji:'🇨🇲', area:475442,  population:29123744,  gdpPerCapita:1700,  lifeExpectancy:59.8, co2PerCapita:0.4,  coastlineKm:402,   minimumWageUsd:62,    bigMacIndexUsd:null),
  CountryRanking(iso2:'CI', iso3:'CIV', name:'Elfenbeinküste',               flagEmoji:'🇨🇮', area:322463,  population:31934230,  gdpPerCapita:2800,  lifeExpectancy:59.0, co2PerCapita:0.5,  coastlineKm:515,   minimumWageUsd:120,   bigMacIndexUsd:null),
  CountryRanking(iso2:'MG', iso3:'MDG', name:'Madagaskar',                   flagEmoji:'🇲🇬', area:587041,  population:31964956,  gdpPerCapita:600,   lifeExpectancy:67.4, co2PerCapita:0.2,  coastlineKm:4828,  minimumWageUsd:31,    bigMacIndexUsd:null),
  CountryRanking(iso2:'AO', iso3:'AGO', name:'Angola',                       flagEmoji:'🇦🇴', area:1246700, population:37202061,  gdpPerCapita:3400,  lifeExpectancy:62.7, co2PerCapita:1.2,  coastlineKm:1600,  minimumWageUsd:61,    bigMacIndexUsd:null),
  CountryRanking(iso2:'BF', iso3:'BFA', name:'Burkina Faso',                 flagEmoji:'🇧🇫', area:274222,  population:23251485,  gdpPerCapita:900,   lifeExpectancy:61.8, co2PerCapita:0.2,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'BI', iso3:'BDI', name:'Burundi',                      flagEmoji:'🇧🇮', area:27834,   population:13238559,  gdpPerCapita:250,   lifeExpectancy:61.8, co2PerCapita:0.1,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'BJ', iso3:'BEN', name:'Benin',                        flagEmoji:'🇧🇯', area:112622,  population:13754688,  gdpPerCapita:1400,  lifeExpectancy:60.0, co2PerCapita:0.5,  coastlineKm:121,   minimumWageUsd:86,    bigMacIndexUsd:null),
  CountryRanking(iso2:'BW', iso3:'BWA', name:'Botswana',                     flagEmoji:'🇧🇼', area:581730,  population:2756202,   gdpPerCapita:7500,  lifeExpectancy:65.0, co2PerCapita:3.0,  coastlineKm:0,     minimumWageUsd:152,   bigMacIndexUsd:null),
  CountryRanking(iso2:'CD', iso3:'COD', name:'Dem. Republik Kongo',          flagEmoji:'🇨🇩', area:2344858, population:102262808, gdpPerCapita:600,   lifeExpectancy:61.2, co2PerCapita:0.1,  coastlineKm:37,    minimumWageUsd:55,    bigMacIndexUsd:null),
  CountryRanking(iso2:'CF', iso3:'CAF', name:'Zentralafrikanische Republik', flagEmoji:'🇨🇫', area:622984,  population:5742315,   gdpPerCapita:500,   lifeExpectancy:54.4, co2PerCapita:0.1,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'CG', iso3:'COG', name:'Republik Kongo',               flagEmoji:'🇨🇬', area:342000,  population:6142179,   gdpPerCapita:2300,  lifeExpectancy:64.9, co2PerCapita:0.7,  coastlineKm:169,   minimumWageUsd:170,   bigMacIndexUsd:null),
  CountryRanking(iso2:'CV', iso3:'CPV', name:'Kap Verde',                    flagEmoji:'🇨🇻', area:4033,    population:593149,    gdpPerCapita:4000,  lifeExpectancy:73.7, co2PerCapita:0.9,  coastlineKm:965,   minimumWageUsd:141,   bigMacIndexUsd:null),
  CountryRanking(iso2:'DJ', iso3:'DJI', name:'Dschibuti',                    flagEmoji:'🇩🇯', area:23200,   population:1136455,   gdpPerCapita:2400,  lifeExpectancy:65.3, co2PerCapita:0.7,  coastlineKm:314,   minimumWageUsd:198,   bigMacIndexUsd:null),
  CountryRanking(iso2:'ER', iso3:'ERI', name:'Eritrea',                      flagEmoji:'🇪🇷', area:117600,  population:3748901,   gdpPerCapita:null,  lifeExpectancy:67.8, co2PerCapita:0.2,  coastlineKm:2234,  minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'GA', iso3:'GAB', name:'Gabun',                        flagEmoji:'🇬🇦', area:267668,  population:2397368,   gdpPerCapita:7100,  lifeExpectancy:67.4, co2PerCapita:2.0,  coastlineKm:885,   minimumWageUsd:255,   bigMacIndexUsd:null),
  CountryRanking(iso2:'GM', iso3:'GMB', name:'Gambia',                       flagEmoji:'🇬🇲', area:11295,   population:2773168,   gdpPerCapita:800,   lifeExpectancy:62.0, co2PerCapita:0.3,  coastlineKm:80,    minimumWageUsd:60,    bigMacIndexUsd:null),
  CountryRanking(iso2:'GN', iso3:'GIN', name:'Guinea',                       flagEmoji:'🇬🇳', area:245857,  population:14190612,  gdpPerCapita:1100,  lifeExpectancy:59.1, co2PerCapita:0.3,  coastlineKm:320,   minimumWageUsd:62,    bigMacIndexUsd:null),
  CountryRanking(iso2:'GQ', iso3:'GNQ', name:'Äquatorialguinea',             flagEmoji:'🇬🇶', area:28051,   population:1714671,   gdpPerCapita:7000,  lifeExpectancy:60.4, co2PerCapita:4.5,  coastlineKm:296,   minimumWageUsd:224,   bigMacIndexUsd:null),
  CountryRanking(iso2:'GW', iso3:'GNB', name:'Guinea-Bissau',                flagEmoji:'🇬🇼', area:36125,   population:2150842,   gdpPerCapita:800,   lifeExpectancy:59.0, co2PerCapita:0.3,  coastlineKm:350,   minimumWageUsd:30,    bigMacIndexUsd:null),
  CountryRanking(iso2:'KM', iso3:'COM', name:'Komoren',                      flagEmoji:'🇰🇲', area:2235,    population:879360,    gdpPerCapita:1700,  lifeExpectancy:65.0, co2PerCapita:0.4,  coastlineKm:340,   minimumWageUsd:129,   bigMacIndexUsd:null),
  CountryRanking(iso2:'LR', iso3:'LBR', name:'Liberia',                      flagEmoji:'🇱🇷', area:111369,  population:5418377,   gdpPerCapita:700,   lifeExpectancy:63.7, co2PerCapita:0.3,  coastlineKm:579,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'LS', iso3:'LSO', name:'Lesotho',                      flagEmoji:'🇱🇸', area:30355,   population:2330318,   gdpPerCapita:1100,  lifeExpectancy:57.1, co2PerCapita:1.0,  coastlineKm:0,     minimumWageUsd:102,   bigMacIndexUsd:null),
  CountryRanking(iso2:'LY', iso3:'LBY', name:'Libyen',                       flagEmoji:'🇱🇾', area:1759540, population:7252573,   gdpPerCapita:6500,  lifeExpectancy:72.9, co2PerCapita:9.0,  coastlineKm:1770,  minimumWageUsd:325,   bigMacIndexUsd:null),
  CountryRanking(iso2:'ML', iso3:'MLI', name:'Mali',                         flagEmoji:'🇲🇱', area:1240192, population:24478595,  gdpPerCapita:900,   lifeExpectancy:59.3, co2PerCapita:0.2,  coastlineKm:0,     minimumWageUsd:57,    bigMacIndexUsd:null),
  CountryRanking(iso2:'MR', iso3:'MRT', name:'Mauretanien',                  flagEmoji:'🇲🇷', area:1030700, population:4736139,   gdpPerCapita:1900,  lifeExpectancy:65.4, co2PerCapita:0.8,  coastlineKm:754,   minimumWageUsd:72,    bigMacIndexUsd:null),
  CountryRanking(iso2:'MU', iso3:'MUS', name:'Mauritius',                    flagEmoji:'🇲🇺', area:2040,    population:1266334,   gdpPerCapita:10800, lifeExpectancy:74.7, co2PerCapita:3.2,  coastlineKm:177,   minimumWageUsd:251,   bigMacIndexUsd:null),
  CountryRanking(iso2:'MW', iso3:'MWI', name:'Malawi',                       flagEmoji:'🇲🇼', area:118484,  population:21906168,  gdpPerCapita:600,   lifeExpectancy:63.3, co2PerCapita:0.1,  coastlineKm:0,     minimumWageUsd:20,    bigMacIndexUsd:null),
  CountryRanking(iso2:'MZ', iso3:'MOZ', name:'Mosambik',                     flagEmoji:'🇲🇿', area:801590,  population:33897354,  gdpPerCapita:600,   lifeExpectancy:59.9, co2PerCapita:0.3,  coastlineKm:2470,  minimumWageUsd:78,    bigMacIndexUsd:null),
  CountryRanking(iso2:'NA', iso3:'NAM', name:'Namibia',                      flagEmoji:'🇳🇦', area:824292,  population:2604172,   gdpPerCapita:5500,  lifeExpectancy:65.1, co2PerCapita:1.6,  coastlineKm:1572,  minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'NE', iso3:'NER', name:'Niger',                        flagEmoji:'🇳🇪', area:1267000, population:26207977,  gdpPerCapita:600,   lifeExpectancy:62.6, co2PerCapita:0.1,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'RW', iso3:'RWA', name:'Ruanda',                       flagEmoji:'🇷🇼', area:26338,   population:14094683,  gdpPerCapita:1000,  lifeExpectancy:69.6, co2PerCapita:0.1,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'SC', iso3:'SYC', name:'Seychellen',                   flagEmoji:'🇸🇨', area:455,     population:107118,    gdpPerCapita:17000, lifeExpectancy:74.8, co2PerCapita:5.2,  coastlineKm:491,   minimumWageUsd:152,   bigMacIndexUsd:null),
  CountryRanking(iso2:'SD', iso3:'SDN', name:'Sudan',                        flagEmoji:'🇸🇩', area:1886068, population:47958087,  gdpPerCapita:600,   lifeExpectancy:66.0, co2PerCapita:0.5,  coastlineKm:853,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'SL', iso3:'SLE', name:'Sierra Leone',                 flagEmoji:'🇸🇱', area:71740,   population:8791092,   gdpPerCapita:500,   lifeExpectancy:54.6, co2PerCapita:0.2,  coastlineKm:402,   minimumWageUsd:57,    bigMacIndexUsd:null),
  CountryRanking(iso2:'SO', iso3:'SOM', name:'Somalia',                      flagEmoji:'🇸🇴', area:637657,  population:18143378,  gdpPerCapita:400,   lifeExpectancy:57.4, co2PerCapita:0.1,  coastlineKm:3333,  minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'SS', iso3:'SSD', name:'Südsudan',                     flagEmoji:'🇸🇸', area:619745,  population:10748272,  gdpPerCapita:500,   lifeExpectancy:57.0, co2PerCapita:0.2,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'ST', iso3:'STP', name:'São Tomé und Príncipe',        flagEmoji:'🇸🇹', area:964,     population:231856,    gdpPerCapita:2200,  lifeExpectancy:70.3, co2PerCapita:0.6,  coastlineKm:209,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'SZ', iso3:'SWZ', name:'Eswatini',                     flagEmoji:'🇸🇿', area:17364,   population:1210822,   gdpPerCapita:4500,  lifeExpectancy:60.1, co2PerCapita:1.2,  coastlineKm:0,     minimumWageUsd:76,    bigMacIndexUsd:null),
  CountryRanking(iso2:'TD', iso3:'TCD', name:'Tschad',                       flagEmoji:'🇹🇩', area:1284000, population:18278568,  gdpPerCapita:700,   lifeExpectancy:55.1, co2PerCapita:0.1,  coastlineKm:0,     minimumWageUsd:110,   bigMacIndexUsd:null),
  CountryRanking(iso2:'TG', iso3:'TGO', name:'Togo',                         flagEmoji:'🇹🇬', area:56785,   population:8848699,   gdpPerCapita:1000,  lifeExpectancy:60.8, co2PerCapita:0.4,  coastlineKm:56,    minimumWageUsd:70,    bigMacIndexUsd:null),
  CountryRanking(iso2:'UG', iso3:'UGA', name:'Uganda',                       flagEmoji:'🇺🇬', area:241038,  population:48582334,  gdpPerCapita:900,   lifeExpectancy:62.6, co2PerCapita:0.1,  coastlineKm:0,     minimumWageUsd:35,    bigMacIndexUsd:null),
  CountryRanking(iso2:'ZM', iso3:'ZMB', name:'Sambia',                       flagEmoji:'🇿🇲', area:752618,  population:20569737,  gdpPerCapita:1400,  lifeExpectancy:64.4, co2PerCapita:0.4,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'ZW', iso3:'ZWE', name:'Simbabwe',                     flagEmoji:'🇿🇼', area:390757,  population:16665409,  gdpPerCapita:1600,  lifeExpectancy:60.6, co2PerCapita:1.0,  coastlineKm:0,     minimumWageUsd:null,  bigMacIndexUsd:null),

  // ── Ozeanien ───────────────────────────────────────────────────────────────
  CountryRanking(iso2:'AU', iso3:'AUS', name:'Australien',    flagEmoji:'🇦🇺', area:7692024, population:27196812, gdpPerCapita:64604, lifeExpectancy:83.9, co2PerCapita:15.2, coastlineKm:25760, minimumWageUsd:2707,  bigMacIndexUsd:5.15),
  CountryRanking(iso2:'NZ', iso3:'NZL', name:'Neuseeland',    flagEmoji:'🇳🇿', area:270467,  population:5287500,  gdpPerCapita:48000, lifeExpectancy:82.5, co2PerCapita:7.4,  coastlineKm:15134, minimumWageUsd:1580,  bigMacIndexUsd:4.36),
  CountryRanking(iso2:'PG', iso3:'PNG', name:'Papua-Neuguinea',flagEmoji:'🇵🇬', area:462840,  population:10576502, gdpPerCapita:2800,  lifeExpectancy:64.7, co2PerCapita:0.9,  coastlineKm:5152,  minimumWageUsd:43,    bigMacIndexUsd:null),
  CountryRanking(iso2:'FJ', iso3:'FJI', name:'Fidschi',       flagEmoji:'🇫🇯', area:18274,   population:929766,   gdpPerCapita:5800,  lifeExpectancy:70.4, co2PerCapita:1.7,  coastlineKm:1129,  minimumWageUsd:464,   bigMacIndexUsd:null),
  CountryRanking(iso2:'SB', iso3:'SLB', name:'Salomonen',     flagEmoji:'🇸🇧', area:28896,   population:740424,   gdpPerCapita:2800,  lifeExpectancy:73.1, co2PerCapita:0.6,  coastlineKm:5313,  minimumWageUsd:59,    bigMacIndexUsd:null),
  CountryRanking(iso2:'VU', iso3:'VUT', name:'Vanuatu',       flagEmoji:'🇻🇺', area:12189,   population:336000,   gdpPerCapita:3600,  lifeExpectancy:70.3, co2PerCapita:0.8,  coastlineKm:2528,  minimumWageUsd:323,   bigMacIndexUsd:null),
  CountryRanking(iso2:'WS', iso3:'WSM', name:'Samoa',         flagEmoji:'🇼🇸', area:2842,    population:222382,   gdpPerCapita:4400,  lifeExpectancy:75.1, co2PerCapita:1.5,  coastlineKm:403,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'TO', iso3:'TON', name:'Tonga',         flagEmoji:'🇹🇴', area:747,     population:100651,   gdpPerCapita:5000,  lifeExpectancy:72.0, co2PerCapita:2.3,  coastlineKm:419,   minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'FM', iso3:'FSM', name:'Mikronesien',   flagEmoji:'🇫🇲', area:702,     population:114164,   gdpPerCapita:3000,  lifeExpectancy:70.8, co2PerCapita:2.3,  coastlineKm:6112,  minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'PW', iso3:'PLW', name:'Palau',         flagEmoji:'🇵🇼', area:459,     population:18058,    gdpPerCapita:14000, lifeExpectancy:74.2, co2PerCapita:3.0,  coastlineKm:1519,  minimumWageUsd:120,   bigMacIndexUsd:null),
  CountryRanking(iso2:'MH', iso3:'MHL', name:'Marshallinseln',flagEmoji:'🇲🇭', area:181,     population:42050,    gdpPerCapita:5000,  lifeExpectancy:70.3, co2PerCapita:2.0,  coastlineKm:370,   minimumWageUsd:173,   bigMacIndexUsd:null),
  CountryRanking(iso2:'KI', iso3:'KIR', name:'Kiribati',      flagEmoji:'🇰🇮', area:811,     population:121388,   gdpPerCapita:1800,  lifeExpectancy:68.4, co2PerCapita:0.6,  coastlineKm:1143,  minimumWageUsd:86,    bigMacIndexUsd:null),
  CountryRanking(iso2:'TV', iso3:'TUV', name:'Tuvalu',        flagEmoji:'🇹🇻', area:26,      population:11792,    gdpPerCapita:3500,  lifeExpectancy:67.7, co2PerCapita:1.2,  coastlineKm:24,    minimumWageUsd:null,  bigMacIndexUsd:null),
  CountryRanking(iso2:'NR', iso3:'NRU', name:'Nauru',         flagEmoji:'🇳🇷', area:21,      population:10834,    gdpPerCapita:12000, lifeExpectancy:64.7, co2PerCapita:4.0,  coastlineKm:30,    minimumWageUsd:null,  bigMacIndexUsd:null),
];

// Available ranking categories for the quiz
class RankingCategory {
  final String id;
  final String label;
  final String emoji;
  final String unit;
  final bool higherIsBetter;
  final double? Function(CountryRanking) getValue;

  const RankingCategory({
    required this.id,
    required this.label,
    required this.emoji,
    required this.unit,
    required this.higherIsBetter,
    required this.getValue,
  });
}

final List<RankingCategory> rankingCategories = [
  RankingCategory(
    id: 'gdpPerCapita', label: 'BIP pro Kopf', emoji: '💵',
    unit: 'USD', higherIsBetter: true,
    getValue: (c) => c.gdpPerCapita,
  ),
  RankingCategory(
    id: 'population', label: 'Bevölkerung', emoji: '👥',
    unit: 'Einwohner', higherIsBetter: true,
    getValue: (c) => c.population?.toDouble(),
  ),
  RankingCategory(
    id: 'area', label: 'Fläche', emoji: '🗺️',
    unit: 'km²', higherIsBetter: true,
    getValue: (c) => c.area,
  ),
  RankingCategory(
    id: 'lifeExpectancy', label: 'Lebenserwartung', emoji: '❤️',
    unit: 'Jahre', higherIsBetter: true,
    getValue: (c) => c.lifeExpectancy,
  ),
  RankingCategory(
    id: 'minimumWage', label: 'Mindestlohn', emoji: '💼',
    unit: 'USD/Monat', higherIsBetter: true,
    getValue: (c) => c.minimumWageUsd,
  ),
  RankingCategory(
    id: 'coastline', label: 'Küstenlinie', emoji: '🌊',
    unit: 'km', higherIsBetter: true,
    getValue: (c) => (c.coastlineKm != null && c.coastlineKm! > 0) ? c.coastlineKm : null,
  ),
  RankingCategory(
    id: 'gdpTotal', label: 'BIP gesamt', emoji: '🏦',
    unit: 'USD', higherIsBetter: true,
    getValue: (c) => (c.gdpPerCapita != null && c.population != null)
        ? c.gdpPerCapita! * c.population! : null,
  ),
  RankingCategory(
    id: 'internet', label: 'Internetgeschwindigkeit', emoji: '🌐',
    unit: 'Mbps', higherIsBetter: true,
    getValue: (c) => internetGeschwindigkeit[c.iso2],
  ),
  RankingCategory(
    id: 'corruption', label: 'Korruptionsindex', emoji: '🏅',
    unit: '/ 100', higherIsBetter: true,
    getValue: (c) => korruptionsIndex[c.iso2],
  ),
  RankingCategory(
    id: 'press_freedom', label: 'Pressefreiheitsindex', emoji: '📰',
    unit: '/ 100', higherIsBetter: true,
    getValue: (c) => pressefreiheit[c.iso2],
  ),
  RankingCategory(
    id: 'happiness', label: 'Glücksindex', emoji: '😊',
    unit: '/ 10', higherIsBetter: true,
    getValue: (c) => gluecksIndex[c.iso2],
  ),
  RankingCategory(
    id: 'tourism', label: 'Tourismuseinnahmen', emoji: '✈️',
    unit: 'Mrd. USD', higherIsBetter: true,
    getValue: (c) => tourismusEinnahmen[c.iso2],
  ),
  RankingCategory(
    id: 'military', label: 'Militärausgaben', emoji: '🛡️',
    unit: 'Mrd. USD', higherIsBetter: true,
    getValue: (c) => militaerAusgaben[c.iso2],
  ),
  RankingCategory(
    id: 'birth_rate', label: 'Geburtenrate', emoji: '👶',
    unit: 'Kinder/Frau', higherIsBetter: true,
    getValue: (c) => geburtenrate[c.iso2],
  ),
  RankingCategory(
    id: 'forest', label: 'Waldanteil', emoji: '🌲',
    unit: '%', higherIsBetter: true,
    getValue: (c) => waldanteil[c.iso2],
  ),
  RankingCategory(
    id: 'alcohol', label: 'Alkoholkonsum', emoji: '🍺',
    unit: 'L/Kopf', higherIsBetter: true,
    getValue: (c) => alkoholkonsum[c.iso2],
  ),
  RankingCategory(
    id: 'olympics', label: 'Olympia-Medaillen', emoji: '🥇',
    unit: 'Medaillen', higherIsBetter: true,
    getValue: (c) => olympiaMedaillen[c.iso2],
  ),
  RankingCategory(
    id: 'highest_point', label: 'Höchster Punkt', emoji: '⛰️',
    unit: 'm', higherIsBetter: true,
    getValue: (c) => hoechsterPunkt[c.iso2],
  ),
  RankingCategory(
    id: 'inflation', label: 'Inflationsrate', emoji: '📈',
    unit: '%', higherIsBetter: true,
    getValue: (c) => inflationsrate[c.iso2],
  ),
  RankingCategory(
    id: 'debt', label: 'Staatsschulden', emoji: '💳',
    unit: '% BIP', higherIsBetter: true,
    getValue: (c) => staatsschulden[c.iso2],
  ),
];

// GDP real growth rates 2023 (World Bank / IMF estimates, %)
const Map<String, double> gdpGrowthRates = {
  // Europa
  'DE': -0.3, 'FR':  0.9, 'GB':  0.1, 'IT':  0.9, 'ES':  2.5,
  'PT':  2.3, 'NL':  0.1, 'BE':  1.4, 'CH':  1.3, 'AT': -0.8,
  'SE': -0.2, 'NO':  0.5, 'DK':  1.8, 'FI': -1.0, 'PL':  0.2,
  'CZ': -0.4, 'HU': -0.9, 'GR':  2.0, 'RO':  2.1, 'HR':  2.8,
  'RS':  2.5, 'BG':  1.8, 'UA': -4.5, 'RU':  3.6, 'TR':  4.5,
  'SK':  1.1, 'SI':  1.6, 'LT':  0.3, 'LV': -0.6, 'EE': -3.0,
  // Nordamerika & Karibik
  'US':  2.5, 'CA':  1.2, 'MX':  3.2,
  // Südamerika
  'BR':  2.9, 'AR': -1.6, 'CO':  0.6, 'CL':  0.2, 'PE': -0.6,
  'UY':  0.4, 'VE':  4.0, 'BO':  2.5, 'PY':  4.7,
  // Asien & Ozeanien
  'JP':  1.9, 'CN':  5.2, 'KR':  1.4, 'IN':  8.2, 'ID':  5.0,
  'TH':  1.9, 'MY':  3.6, 'SG':  1.1, 'PH':  5.6, 'VN':  5.1,
  'PK':  2.4, 'LK': -2.3, 'BD':  5.8, 'MM':  2.5, 'NP':  3.9,
  'AU':  2.0, 'NZ':  0.6,
  // Naher Osten & Zentralasien
  'SA': -0.8, 'AE':  3.4, 'IL':  2.0, 'IR':  5.0, 'IQ':  1.3,
  'KZ':  5.1, 'UZ':  6.0,
  // Afrika
  'EG':  3.8, 'ZA':  0.6, 'NG':  2.9, 'KE':  5.0, 'ET':  7.2,
  'GH':  2.2, 'MA':  3.4, 'DZ':  4.1, 'TN':  0.8, 'TZ':  5.0,
};
