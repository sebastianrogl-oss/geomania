// Wirtschaftssektoren-Daten für GeoMania
// mainSector: einer der 8 definierten Sektoren

const Map<String, String> sektorEmojis = {
  'Öl & Gas':               '🛢️',
  'Technologie':             '💻',
  'Landwirtschaft':          '🌾',
  'Tourismus':               '🏖️',
  'Industrie & Produktion':  '🏭',
  'Bergbau & Rohstoffe':     '⛏️',
  'Finanzdienstleistungen':  '💰',
  'Handel & Logistik':       '🚢',
};

class SektorData {
  final String countryName;
  final String flagEmoji;
  final String mainSector;
  final List<String> topExports;
  final String sectorDescription;
  final String funFact;

  const SektorData({
    required this.countryName,
    required this.flagEmoji,
    required this.mainSector,
    required this.topExports,
    required this.sectorDescription,
    this.funFact = '',
  });

  String get sektorEmoji => sektorEmojis[mainSector] ?? '🌐';
}

const List<SektorData> wirtschaftssektoren = [

  // ── Öl & Gas ──────────────────────────────────────────────────────────────
  SektorData(
    countryName: 'Saudi-Arabien', flagEmoji: '🇸🇦', mainSector: 'Öl & Gas',
    topExports: ['Rohöl', 'Raffinerieprodukte', 'Petrochemie'],
    sectorDescription: 'Saudi-Arabien ist der größte Ölexporteur der Welt. Aramco, das staatliche Ölunternehmen, ist das wertvollste Unternehmen der Welt.',
    funFact: 'Saudi-Arabien besitzt ca. 17 % der weltweiten Erdölreserven.',
  ),
  SektorData(
    countryName: 'Russland', flagEmoji: '🇷🇺', mainSector: 'Öl & Gas',
    topExports: ['Erdgas', 'Rohöl', 'Kohle'],
    sectorDescription: 'Russland ist der größte Erdgasexporteur der Welt und zweitgrößter Ölexporteur.',
    funFact: 'Die Gaspipeline Nord Stream 2 war mit 1.224 km eine der längsten Unterwasserpipelines der Welt.',
  ),
  SektorData(
    countryName: 'Norwegen', flagEmoji: '🇳🇴', mainSector: 'Öl & Gas',
    topExports: ['Erdöl', 'Erdgas', 'Fisch'],
    sectorDescription: 'Norwegen ist Westeuropas größter Ölproduzent. Die Öleinnahmen fließen in den weltgrößten Staatsfonds (1,7 Billionen USD).',
    funFact: 'Obwohl Öl-Exporteur, fährt Norwegen dank Ölreichtum den höchsten Anteil an Elektroautos weltweit.',
  ),
  SektorData(
    countryName: 'Nigeria', flagEmoji: '🇳🇬', mainSector: 'Öl & Gas',
    topExports: ['Rohöl', 'Gas', 'Kakao'],
    sectorDescription: 'Nigeria ist der größte Ölproduzent Afrikas. Öl macht über 90 % der Exporteinnahmen aus.',
    funFact: 'Das Niger-Delta ist eine der artenreichsten Flussdeltas der Welt, leidet aber stark unter Ölverschmutzung.',
  ),
  SektorData(
    countryName: 'Kuwait', flagEmoji: '🇰🇼', mainSector: 'Öl & Gas',
    topExports: ['Rohöl', 'Raffinerieprodukte', 'Düngemittel'],
    sectorDescription: 'Kuwaits Wirtschaft wird fast vollständig von Öl dominiert, das über 90 % der Staatseinnahmen ausmacht.',
    funFact: 'Kuwait besitzt ca. 6 % der weltweiten Erdölreserven auf einem Gebiet kleiner als Bayern.',
  ),
  SektorData(
    countryName: 'Katar', flagEmoji: '🇶🇦', mainSector: 'Öl & Gas',
    topExports: ['Flüssiggas (LNG)', 'Rohöl', 'Petrochemie'],
    sectorDescription: 'Katar ist der weltgrößte LNG-Exporteur und hat das höchste Pro-Kopf-Einkommen der Welt.',
    funFact: 'Katars North Dome ist das größte Einzelgasfeld der Welt, geteilt mit dem iranischen South Pars.',
  ),
  SektorData(
    countryName: 'Irak', flagEmoji: '🇮🇶', mainSector: 'Öl & Gas',
    topExports: ['Rohöl', 'Erdgas', 'Datteln'],
    sectorDescription: 'Irak hat die fünftgrößten Ölreserven der Welt. Öl macht über 95 % der Exporteinnahmen aus.',
    funFact: '',
  ),
  SektorData(
    countryName: 'Kasachstan', flagEmoji: '🇰🇿', mainSector: 'Öl & Gas',
    topExports: ['Rohöl', 'Gas', 'Eisenerz'],
    sectorDescription: 'Kasachstan ist der größte Ölproduzent Zentralasiens und liegt unter den Top 15 weltweit.',
    funFact: '',
  ),
  SektorData(
    countryName: 'Aserbaidschan', flagEmoji: '🇦🇿', mainSector: 'Öl & Gas',
    topExports: ['Rohöl', 'Erdgas', 'Petrochemie'],
    sectorDescription: 'Aserbaidschan war eines der ersten Länder, das Öl kommerziell förderte – bereits 1846 in Baku.',
    funFact: 'Baku wird „Stadt der Winde" genannt und liegt am Kaspischen Meer.',
  ),

  // ── Technologie ───────────────────────────────────────────────────────────
  SektorData(
    countryName: 'USA', flagEmoji: '🇺🇸', mainSector: 'Technologie',
    topExports: ['Halbleiter', 'Flugzeuge', 'Software'],
    sectorDescription: 'Das Silicon Valley in Kalifornien beherbergt die wertvollsten Technologieunternehmen der Welt: Apple, Google, Meta, Microsoft.',
    funFact: 'Die USA geben jährlich mehr für F&E aus als jedes andere Land – über 700 Milliarden Dollar.',
  ),
  SektorData(
    countryName: 'Südkorea', flagEmoji: '🇰🇷', mainSector: 'Technologie',
    topExports: ['Halbleiter', 'Mobiltelefone', 'Autos'],
    sectorDescription: 'Südkorea ist Weltmarktführer bei Speicherchips (Samsung, SK Hynix) und Displays (OLED). "Koreanische Welle" (K-Pop) auch als Softpower.',
    funFact: 'Samsung allein macht ca. 20 % des südkoreanischen BIP aus.',
  ),
  SektorData(
    countryName: 'Taiwan', flagEmoji: '🇹🇼', mainSector: 'Technologie',
    topExports: ['Halbleiter', 'Elektronik', 'Maschinen'],
    sectorDescription: 'TSMC (Taiwan Semiconductor Manufacturing Company) produziert über 90 % der weltweit fortschrittlichsten Chips.',
    funFact: 'Taiwan wird als „Silicon Island" bezeichnet – ohne TSMC würde die globale Elektronikproduktion kollabieren.',
  ),
  SektorData(
    countryName: 'Israel', flagEmoji: '🇮🇱', mainSector: 'Technologie',
    topExports: ['Diamanten', 'Software', 'Militärtechnik'],
    sectorDescription: 'Israel hat mehr Start-ups pro Einwohner als jedes andere Land und wird „Start-Up Nation" genannt.',
    funFact: 'Intel, Microsoft und Google betreiben einige ihrer wichtigsten F&E-Zentren außerhalb der USA in Israel.',
  ),
  SektorData(
    countryName: 'Finnland', flagEmoji: '🇫🇮', mainSector: 'Technologie',
    topExports: ['Elektronik', 'Maschinen', 'Holz'],
    sectorDescription: 'Finnland ist Heimat von Nokia (einstmals weltweit größter Handyhersteller) und einer der führenden Gaming-Nationen (Angry Birds, Clash of Clans).',
    funFact: 'Finnland hat die höchste Dichte an Ingenieuren pro Einwohner in Europa.',
  ),
  SektorData(
    countryName: 'Schweden', flagEmoji: '🇸🇪', mainSector: 'Technologie',
    topExports: ['Maschinen', 'Fahrzeuge', 'Pharmaka'],
    sectorDescription: 'Schweden ist Heimat von Spotify, IKEA, H&M und Ericsson – mehr Unicorn-Start-ups pro Einwohner als fast überall auf der Welt.',
    funFact: 'Stockholm hat nach Silicon Valley und NYC die drittmeisten Technologie-Einhörner pro Einwohner.',
  ),

  // ── Industrie & Produktion ────────────────────────────────────────────────
  SektorData(
    countryName: 'Deutschland', flagEmoji: '🇩🇪', mainSector: 'Industrie & Produktion',
    topExports: ['Autos', 'Maschinen', 'Chemikalien'],
    sectorDescription: 'Deutschland ist Europas größte Wirtschaft, getrieben von Automobilindustrie (VW, BMW, Mercedes) und Maschinenbau.',
    funFact: 'Made in Germany war ursprünglich ein britisches Warnlabel – es wurde zum weltweiten Qualitätssymbol.',
  ),
  SektorData(
    countryName: 'China', flagEmoji: '🇨🇳', mainSector: 'Industrie & Produktion',
    topExports: ['Elektronik', 'Maschinen', 'Textilien'],
    sectorDescription: 'China ist die „Werkstatt der Welt" – verantwortlich für ca. 29 % der weltweiten Industrieproduktion.',
    funFact: 'China produziert mehr Stahl als alle anderen Länder zusammen.',
  ),
  SektorData(
    countryName: 'Japan', flagEmoji: '🇯🇵', mainSector: 'Industrie & Produktion',
    topExports: ['Autos', 'Elektronik', 'Maschinen'],
    sectorDescription: 'Japan ist weltbekannt für Qualitätsfertigung: Toyota, Sony, Panasonic. Das „Kaizen"-Prinzip (kontinuierliche Verbesserung) stammt aus Japan.',
    funFact: 'Toyota ist das meistverkaufte Autohaus der Welt und Pionier der Hybridtechnologie (Prius, 1997).',
  ),
  SektorData(
    countryName: 'Türkei', flagEmoji: '🇹🇷', mainSector: 'Industrie & Produktion',
    topExports: ['Fahrzeuge', 'Textilien', 'Maschinen'],
    sectorDescription: 'Die Türkei ist eine der größten Textil- und Bekleidungsproduktionsstätten der Welt und ein wachsender Automobil-Hub.',
    funFact: 'Istanbul ist die einzige Metropole der Welt, die auf zwei Kontinenten liegt.',
  ),
  SektorData(
    countryName: 'Vietnam', flagEmoji: '🇻🇳', mainSector: 'Industrie & Produktion',
    topExports: ['Elektronik', 'Textilien', 'Schuhe'],
    sectorDescription: 'Vietnam hat sich zur wichtigsten Fertigungsbasis für Elektronikunternehmen (Samsung, Apple) nach China entwickelt.',
    funFact: 'Samsung produziert fast die Hälfte seiner Smartphones in Vietnam.',
  ),
  SektorData(
    countryName: 'Bangladesch', flagEmoji: '🇧🇩', mainSector: 'Industrie & Produktion',
    topExports: ['Bekleidung', 'Textilien', 'Schuhe'],
    sectorDescription: 'Bangladesch ist nach China der zweitgrößte Bekleidungsexporteur der Welt.',
    funFact: 'Die Bekleidungsindustrie beschäftigt über 4 Millionen Menschen, davon 80 % Frauen.',
  ),
  SektorData(
    countryName: 'Polen', flagEmoji: '🇵🇱', mainSector: 'Industrie & Produktion',
    topExports: ['Maschinen', 'Fahrzeuge', 'Elektronik'],
    sectorDescription: 'Polen ist einer der größten Automobilproduzenten Europas – viele deutsche Hersteller betreiben Werke in Polen.',
    funFact: 'Polen ist der größte Möbelproduzent Europas.',
  ),
  SektorData(
    countryName: 'Tschechien', flagEmoji: '🇨🇿', mainSector: 'Industrie & Produktion',
    topExports: ['Fahrzeuge', 'Maschinen', 'Elektronik'],
    sectorDescription: 'Tschechien hat die höchste Automobilproduktion pro Einwohner in Europa. Škoda (VW-Gruppe) ist das Herzstück.',
    funFact: 'Škoda Auto wurde bereits 1895 gegründet und ist damit einer der ältesten Autohersteller der Welt.',
  ),
  SektorData(
    countryName: 'Mexiko', flagEmoji: '🇲🇽', mainSector: 'Industrie & Produktion',
    topExports: ['Fahrzeuge', 'Elektronik', 'Öl'],
    sectorDescription: 'Mexiko ist dank des USMCA-Handelsabkommens einer der wichtigsten Fertigungsstandorte Nordamerikas.',
    funFact: 'Mexiko ist der weltweit größte Exporteur von Flachbildschirmen.',
  ),
  SektorData(
    countryName: 'Kambodscha', flagEmoji: '🇰🇭', mainSector: 'Industrie & Produktion',
    topExports: ['Bekleidung', 'Schuhe', 'Reismaschinen'],
    sectorDescription: 'Kambodschas Wirtschaft hängt stark von der Textilproduktion für westliche Modemarken ab.',
    funFact: '',
  ),

  // ── Landwirtschaft ────────────────────────────────────────────────────────
  SektorData(
    countryName: 'Brasilien', flagEmoji: '🇧🇷', mainSector: 'Landwirtschaft',
    topExports: ['Sojabohnen', 'Rindfleisch', 'Kaffee'],
    sectorDescription: 'Brasilien ist Weltmarktführer bei Soja, Kaffee, Zucker und Rindfleisch – der „Supermarkt der Welt".',
    funFact: 'Brasilien produziert ca. 40 % des weltweiten Kaffeeverbrauchs.',
  ),
  SektorData(
    countryName: 'Argentinien', flagEmoji: '🇦🇷', mainSector: 'Landwirtschaft',
    topExports: ['Sojabohnen', 'Getreide', 'Rindfleisch'],
    sectorDescription: 'Die argentinische Pampa ist eine der fruchtbarsten Agrarregionen der Welt.',
    funFact: 'Argentinien isst mehr Rindfleisch pro Kopf als fast jedes andere Land.',
  ),
  SektorData(
    countryName: 'Äthiopien', flagEmoji: '🇪🇹', mainSector: 'Landwirtschaft',
    topExports: ['Kaffee', 'Schnittblumen', 'Sesam'],
    sectorDescription: 'Äthiopien ist die Heimat des Kaffees – der Name „Kaffee" leitet sich von der Provinz Kaffa ab.',
    funFact: 'Äthiopien ist Afrikas größter Kaffeeexporteur und globaler Top-5-Produzent.',
  ),
  SektorData(
    countryName: 'Kenia', flagEmoji: '🇰🇪', mainSector: 'Landwirtschaft',
    topExports: ['Tee', 'Kaffee', 'Schnittblumen'],
    sectorDescription: 'Kenia ist der weltgrößte Exporteur von Schnittblumen – die meisten Rosen aus europäischen Blumenläden kommen aus dem Rift Valley.',
    funFact: 'Kenias Tee wird in London versteigert und gilt als einer der besten der Welt.',
  ),
  SektorData(
    countryName: 'Indonesien', flagEmoji: '🇮🇩', mainSector: 'Landwirtschaft',
    topExports: ['Palmöl', 'Kohle', 'Textilien'],
    sectorDescription: 'Indonesien ist der weltgrößte Produzent von Palmöl, das in der Hälfte aller Supermarktprodukte steckt.',
    funFact: 'Indonesien besteht aus über 17.000 Inseln – es ist der größte Inselstaat der Welt.',
  ),
  SektorData(
    countryName: 'Neuseeland', flagEmoji: '🇳🇿', mainSector: 'Landwirtschaft',
    topExports: ['Milchprodukte', 'Fleisch', 'Holz'],
    sectorDescription: 'Neuseelands Landwirtschaft ist hochentwickelt und exportorientiert – das Land hat mehr Schafe als Menschen.',
    funFact: 'In Neuseeland leben ca. 6 Schafe pro Einwohner.',
  ),
  SektorData(
    countryName: 'Elfenbeinküste', flagEmoji: '🇨🇮', mainSector: 'Landwirtschaft',
    topExports: ['Kakao', 'Cashew', 'Kaffee'],
    sectorDescription: 'Die Elfenbeinküste ist der weltweit größte Kakaoproduzent – über 40 % der globalen Ernte stammt von dort.',
    funFact: 'Fast alle Schokolade der Welt hängt von Kakao aus Westafrika ab.',
  ),
  SektorData(
    countryName: 'Pakistan', flagEmoji: '🇵🇰', mainSector: 'Landwirtschaft',
    topExports: ['Textilien', 'Baumwolle', 'Reis'],
    sectorDescription: 'Pakistan ist einer der größten Baumwollproduzenten der Welt und globaler Textilexporteur.',
    funFact: 'Pakistan ist der viertgrößte Baumwollerzeuger der Welt.',
  ),
  SektorData(
    countryName: 'Myanmar', flagEmoji: '🇲🇲', mainSector: 'Landwirtschaft',
    topExports: ['Edelsteine', 'Reis', 'Gas'],
    sectorDescription: 'Myanmar ist einer der größten Reisexporteure Südostasiens.',
    funFact: '',
  ),

  // ── Tourismus ────────────────────────────────────────────────────────────
  SektorData(
    countryName: 'Frankreich', flagEmoji: '🇫🇷', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Luxusgüter', 'Aerospace'],
    sectorDescription: 'Frankreich ist das meistbesuchte Land der Welt – über 90 Millionen Touristen jährlich.',
    funFact: 'Der Eiffelturm sollte ursprünglich nach 20 Jahren abgerissen werden – er steht seit 1889.',
  ),
  SektorData(
    countryName: 'Spanien', flagEmoji: '🇪🇸', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Fahrzeuge', 'Maschinen'],
    sectorDescription: 'Spanien ist das zweitmeistbesuchte Land Europas. Tourismus macht ca. 12 % des BIP aus.',
    funFact: 'Spanien hat die zweitgrößte Anzahl an UNESCO-Welterbestätten in Europa.',
  ),
  SektorData(
    countryName: 'Italien', flagEmoji: '🇮🇹', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Maschinen', 'Mode'],
    sectorDescription: 'Italien verbindet Kultur, Geschichte und Küche einzigartig. Es hat mehr UNESCO-Welterbestätten als jedes andere Land.',
    funFact: 'Italien hat mit 58 UNESCO-Welterbestätten die höchste Dichte weltweit.',
  ),
  SektorData(
    countryName: 'Griechenland', flagEmoji: '🇬🇷', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Schifffahrt', 'Olivenöl'],
    sectorDescription: 'Tourismus ist mit über 20 % BIP-Anteil einer der wichtigsten Wirtschaftszweige Griechenlands.',
    funFact: 'Griechenland besitzt mehr Inseln als offiziell gezählt werden – schätzungsweise 3.000 bis 6.000.',
  ),
  SektorData(
    countryName: 'Thailand', flagEmoji: '🇹🇭', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Elektronik', 'Fahrzeuge'],
    sectorDescription: 'Thailand ist Südostasias beliebtestes Reiseziel. Tourismus macht ca. 15 % des BIP aus.',
    funFact: 'Bangkok ist die meistbesuchte Stadt der Welt nach Übernachtungstouristen.',
  ),
  SektorData(
    countryName: 'Kroatien', flagEmoji: '🇭🇷', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Schiffe', 'Pharma'],
    sectorDescription: 'Die Adriaküste und die zahlreichen Inseln machen Kroatien zu einem der beliebtesten Sommerziele Europas.',
    funFact: 'Teile von Game of Thrones wurden in Kroatien gedreht (Dubrovnik = Königsmund).',
  ),
  SektorData(
    countryName: 'Portugal', flagEmoji: '🇵🇹', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Fahrzeuge', 'Textilien'],
    sectorDescription: 'Lissabon und der Algarve sind Hotspots für Touristen. Tourismus ist Portugals wichtigster Devisenbringer.',
    funFact: 'Portugal ist die älteste Nation Europas mit unveränderten Grenzen seit 1139.',
  ),
  SektorData(
    countryName: 'Marokko', flagEmoji: '🇲🇦', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Phosphate', 'Textilien'],
    sectorDescription: 'Marrakesch, Fes und die Sahara machen Marokko zum meistbesuchten Land Afrikas.',
    funFact: 'Marokko besitzt über 70 % der weltweiten Phosphatvorkommen.',
  ),
  SektorData(
    countryName: 'Ägypten', flagEmoji: '🇪🇬', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Erdgas', 'Textilien'],
    sectorDescription: 'Die Pyramiden von Gizeh, der Nil und das Rote Meer ziehen jährlich Millionen Touristen an.',
    funFact: 'Durch den Suezkanal passieren ca. 12 % des weltweiten Seehandels.',
  ),
  SektorData(
    countryName: 'Nepal', flagEmoji: '🇳🇵', mainSector: 'Tourismus',
    topExports: ['Tourismus', 'Teppiche', 'Textilien'],
    sectorDescription: 'Nepal ist das Zentrum des Bergsteigtourismus – 8 der 14 höchsten Berge der Welt liegen hier.',
    funFact: 'Der Mount Everest wächst jedes Jahr um etwa 4 mm durch tektonische Kräfte.',
  ),

  // ── Bergbau & Rohstoffe ───────────────────────────────────────────────────
  SektorData(
    countryName: 'Australien', flagEmoji: '🇦🇺', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Eisenerz', 'Kohle', 'Gold'],
    sectorDescription: 'Australien ist der weltgrößte Exporteur von Eisenerz und Kohle. China kauft fast 90 % davon auf.',
    funFact: 'Australien enthält das größte bekannte Goldfeld der Welt im Goldfields-Esperance-Gebiet.',
  ),
  SektorData(
    countryName: 'Südafrika', flagEmoji: '🇿🇦', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Gold', 'Platin', 'Kohle'],
    sectorDescription: 'Südafrika ist der weltgrößte Platinproduzent und einer der wichtigsten Goldproduzenten.',
    funFact: 'Südafrika besitzt ca. 80 % der weltweiten Platinvorkommen.',
  ),
  SektorData(
    countryName: 'Chile', flagEmoji: '🇨🇱', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Kupfer', 'Lithium', 'Wein'],
    sectorDescription: 'Chile ist der weltweit größte Kupferproduzent – Kupfer macht über 50 % der Exporteinnahmen aus.',
    funFact: 'Chile besitzt zusammen mit Bolivien und Argentinien über 60 % der weltweiten Lithiumreserven.',
  ),
  SektorData(
    countryName: 'Peru', flagEmoji: '🇵🇪', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Kupfer', 'Gold', 'Zink'],
    sectorDescription: 'Peru ist einer der weltweit wichtigsten Produzenten von Silber, Kupfer, Zink und Gold.',
    funFact: 'Die Anden in Peru enthalten einige der reichsten Metallvorkommen der Welt.',
  ),
  SektorData(
    countryName: 'Demokratische Republik Kongo', flagEmoji: '🇨🇩', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Kobalt', 'Kupfer', 'Coltan'],
    sectorDescription: 'Der Kongo besitzt ca. 70 % der weltweiten Kobaltvorkommen – unverzichtbar für Elektroautobatterien.',
    funFact: 'Ohne kongolesisches Kobalt wäre die globale Elektromobilität kaum möglich.',
  ),
  SektorData(
    countryName: 'Botswana', flagEmoji: '🇧🇼', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Diamanten', 'Kupfer', 'Nickel'],
    sectorDescription: 'Botswana ist einer der weltgrößten Diamantenproduzenten und hat dies genutzt, um sich zur Mitteleinkommensklasse zu entwickeln.',
    funFact: 'Botswana war 1966 eines der ärmsten Länder der Welt – Diamanten machten es zum Musterstaat Afrikas.',
  ),
  SektorData(
    countryName: 'Sambia', flagEmoji: '🇿🇲', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Kupfer', 'Kobalt', 'Gold'],
    sectorDescription: 'Der sogenannte „Kupfergürtel" erstreckt sich über Nordsambia und ist einer der reichsten Kupferabbaugebiete weltweit.',
    funFact: '',
  ),
  SektorData(
    countryName: 'Bolivien', flagEmoji: '🇧🇴', mainSector: 'Bergbau & Rohstoffe',
    topExports: ['Lithium', 'Zinn', 'Erdgas'],
    sectorDescription: 'Bolivien besitzt die weltweit größten Lithiumreserven im Salar de Uyuni.',
    funFact: 'Der Salar de Uyuni in Bolivien ist die größte Salzwüste der Welt und atemberaubend schön.',
  ),

  // ── Finanzdienstleistungen ────────────────────────────────────────────────
  SektorData(
    countryName: 'Schweiz', flagEmoji: '🇨🇭', mainSector: 'Finanzdienstleistungen',
    topExports: ['Uhren', 'Pharma', 'Finanzdienstleistungen'],
    sectorDescription: 'Zürich und Genf gehören zu den wichtigsten Finanzzentren der Welt. Über 7.000 Milliarden USD Auslandsvermögen werden in der Schweiz verwaltet.',
    funFact: 'Die Schweiz verwaltet ca. 25 % des weltweiten grenzüberschreitend verwalteten Privatvermögens.',
  ),
  SektorData(
    countryName: 'Vereinigtes Königreich', flagEmoji: '🇬🇧', mainSector: 'Finanzdienstleistungen',
    topExports: ['Finanzdienstleistungen', 'Maschinen', 'Pharmaka'],
    sectorDescription: 'Londons City ist das wichtigste Finanzzentrum Europas und eines der drei globalen Finanzzentren neben New York und Singapur.',
    funFact: 'Die Londoner Börse (LSE) wurde 1801 gegründet und ist eine der ältesten der Welt.',
  ),
  SektorData(
    countryName: 'Singapur', flagEmoji: '🇸🇬', mainSector: 'Handel & Logistik',
    topExports: ['Elektronik', 'Chemie', 'Maschinen'],
    sectorDescription: 'Singapur ist eines der wichtigsten Finanzzentren Asiens und der weltgrößte Containerhafenumschlagplatz.',
    funFact: 'Singapur ist der einzige Stadtstaat Südostasiens und hat das dritthöchste Pro-Kopf-BIP der Welt.',
  ),
  SektorData(
    countryName: 'Luxemburg', flagEmoji: '🇱🇺', mainSector: 'Finanzdienstleistungen',
    topExports: ['Finanzprodukte', 'Stahl', 'Chemie'],
    sectorDescription: 'Luxemburg ist das größte Investmentfondszentrum Europas und zweites weltweit nach den USA.',
    funFact: 'Luxemburg hat das höchste Pro-Kopf-BIP in Europa.',
  ),
  SektorData(
    countryName: 'Bahrain', flagEmoji: '🇧🇭', mainSector: 'Finanzdienstleistungen',
    topExports: ['Finanzdienstleistungen', 'Erdöl', 'Aluminium'],
    sectorDescription: 'Bahrain ist das islamische Bankenzentrum des Nahen Ostens.',
    funFact: '',
  ),

  // ── Handel & Logistik ─────────────────────────────────────────────────────
  SektorData(
    countryName: 'Ver. Arab. Emirate', flagEmoji: '🇦🇪', mainSector: 'Handel & Logistik',
    topExports: ['Öl', 'Gold', 'Logistikdienstleistungen'],
    sectorDescription: 'Dubai ist eines der wichtigsten Handels- und Logistikzentren der Welt. Jebel Ali ist der größte Hafen des Nahen Ostens.',
    funFact: 'Dubai hat sich von einem Fischereihafen (1960er) zu einer globalen Metropole mit dem höchsten Gebäude der Welt entwickelt.',
  ),
  SektorData(
    countryName: 'Niederlande', flagEmoji: '🇳🇱', mainSector: 'Handel & Logistik',
    topExports: ['Maschinen', 'Chemie', 'Logistik'],
    sectorDescription: 'Rotterdam ist mit Abstand der größte Hafen Europas. Die Niederlande sind das Eingangstor zum europäischen Markt.',
    funFact: 'Der Hafen Rotterdam schlägt mehr als 450 Millionen Tonnen Güter pro Jahr um.',
  ),
  SektorData(
    countryName: 'Belgien', flagEmoji: '🇧🇪', mainSector: 'Handel & Logistik',
    topExports: ['Chemie', 'Maschinen', 'Diamanten'],
    sectorDescription: 'Antwerpen ist nach Rotterdam der zweitgrößte Hafen Europas und weltgrößtes Diamantenzentrum.',
    funFact: 'Antwerpen ist für mehr als 80 % des weltweiten Diamantenhandels verantwortlich.',
  ),
  SektorData(
    countryName: 'Panama', flagEmoji: '🇵🇦', mainSector: 'Handel & Logistik',
    topExports: ['Kanalgebühren', 'Gold', 'Früchte'],
    sectorDescription: 'Der Panamakanal verbindet Atlantik und Pazifik und ist eine der wichtigsten Wasserstraßen der Welt.',
    funFact: 'Pro Jahr passieren über 14.000 Schiffe den Panamakanal – ca. 5 % des weltweiten Seehandels.',
  ),
];
