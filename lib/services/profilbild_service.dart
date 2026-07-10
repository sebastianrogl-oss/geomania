import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verwaltet das auswählbare Profilbild — nutzt die bereits vorhandenen
/// Kontinent-Deko-/Maskottchen-Icons aus assets/icons/deko/ statt neuer Assets.
class ProfilbildService {
  static const _key = 'profilbild_pfad';

  /// Wird hochgezählt, sobald sich das Profilbild ändert — damit andere,
  /// dauerhaft lebende Screens (z.B. HomeScreen, per IndexedStack nie neu
  /// aufgebaut) es ohne kompletten Reload nachziehen können.
  static final geaendert = ValueNotifier<int>(0);

  static const List<String> verfuegbareBilder = [
    'assets/icons/deko/globus_normal.png',
    'assets/icons/deko/globus_winken.png',
    'assets/icons/deko/globus_denken.png',
    'assets/icons/deko/globus_ueberrascht.png',
    'assets/icons/deko/coin_normal.png',
    'assets/icons/deko/coin_winken.png',
    'assets/icons/deko/coin_denken.png',
    'assets/icons/deko/coin_ueberrascht.png',
    'assets/icons/deko/afrika_elefant.png',
    'assets/icons/deko/afrika_giraffe.png',
    'assets/icons/deko/afrika_nashorn.png',
    'assets/icons/deko/asien_panda.png',
    'assets/icons/deko/nordamerika_adler.png',
    'assets/icons/deko/nordamerika_baer.png',
    'assets/icons/deko/ozeanien_kaenguru.png',
    'assets/icons/deko/ozeanien_koala.png',
    'assets/icons/deko/ozeanien_shark.png',
    'assets/icons/deko/suedamerika_jaguar.png',
    'assets/icons/deko/suedamerika_lama.png',
    'assets/icons/deko/suedamerika_tukan.png',
    'assets/icons/deko/welt_rakete.png',
    'assets/icons/deko/welt_kompass.png',
  ];

  static const String standard = 'assets/icons/deko/globus_normal.png';

  static Future<String> getProfilbild() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? standard;
  }

  static Future<void> setProfilbild(String pfad) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pfad);
    geaendert.value++;
  }

  // Globus-/Coin-Assets sind breite 677x369-Bilder (statt quadratisch wie die
  // übrigen Deko-Icons) -> unter BoxFit.contain in einem quadratischen Kreis
  // werden sie oben/unten stark gestaucht und wirken viel kleiner als die
  // anderen Profilbild-Optionen. BoxFit.cover füllt den Kreis stattdessen voll.
  static bool istWeitformat(String pfad) =>
      pfad.contains('/globus_') || pfad.contains('/coin_');
}
