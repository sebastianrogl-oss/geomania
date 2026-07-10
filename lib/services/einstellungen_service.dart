import 'package:shared_preferences/shared_preferences.dart';

/// App-Einstellungen (Ton/Haptik) — rein lokal, kein Konto-Bezug.
class EinstellungenService {
  static const _kSound = 'einstellung_sound';
  static const _kVibration = 'einstellung_vibration';

  static Future<bool> get soundAktiv async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSound) ?? true;
  }

  static Future<void> setzeSoundAktiv(bool aktiv) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSound, aktiv);
  }

  static Future<bool> get vibrationAktiv async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kVibration) ?? true;
  }

  static Future<void> setzeVibrationAktiv(bool aktiv) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibration, aktiv);
  }
}
