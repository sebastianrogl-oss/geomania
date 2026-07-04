import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

/// Zeigt die echte Flagge eines Landes via country_flags-Paket.
/// Fallback auf Unicode-Flaggen-Emoji wenn der Code ungültig ist.
///
/// countryCode: ISO 3166-1 alpha-2, z.B. "DE", "FR", "US"
class FlaggenWidget extends StatelessWidget {
  final String countryCode;
  final double width;
  final double height;
  final double borderRadius;

  const FlaggenWidget({
    super.key,
    required this.countryCode,
    this.width = 60,
    this.height = 40,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final code = countryCode.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      return _EmojiFlag(code: code, width: width, height: height, borderRadius: borderRadius);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CountryFlag.fromCountryCode(
        code,
        height: height,
        width: width,
      ),
    );
  }
}

/// Fallback: Unicode-Regionalindikator-Emoji (deckt alle ISO-Codes ab)
class _EmojiFlag extends StatelessWidget {
  final String code;
  final double width;
  final double height;
  final double borderRadius;

  const _EmojiFlag({
    required this.code,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  String _toEmoji(String code) {
    if (code.length != 2) return '🏳️';
    // Regional Indicator Symbols: A=0x1F1E6, B=0x1F1E7, ...
    final a = code.codeUnitAt(0) - 65 + 0x1F1E6;
    final b = code.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes([a, b]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        color: Colors.grey.shade100,
      ),
      alignment: Alignment.center,
      child: Text(
        _toEmoji(code),
        style: TextStyle(fontSize: height * 0.55),
      ),
    );
  }
}

/// Challenge-Icon aus assets/icons/ (SVG).
/// Fällt auf ein Text-Emoji zurück wenn die Datei noch nicht existiert.
///
/// Verwendung:
///   ChallengeIconWidget(name: 'challenge_preis', fallback: '🏷️')
///
/// So eigene PNGs einbinden:
///   1. PNG-Datei in assets/icons/ ablegen (z.B. challenge_preis.png)
///   2. In pubspec.yaml ist assets/icons/ bereits registriert
///   3. Unten den path auf '.png' ändern und SvgPicture durch Image.asset() ersetzen
class ChallengeIconWidget extends StatelessWidget {
  final String name;      // Dateiname ohne Extension, z.B. 'challenge_preis'
  final String fallback;  // Emoji-Fallback
  final double size;

  const ChallengeIconWidget({
    super.key,
    required this.name,
    required this.fallback,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    // Aktuell: SVG-Placeholder. Für echte PNGs:
    //   Image.asset('assets/icons/$name.png', width: size, height: size)
    return Image.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      errorBuilder: (_, e, s) => Text(
        fallback,
        style: TextStyle(fontSize: size * 0.7),
      ),
    );
  }
}
