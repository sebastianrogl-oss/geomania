import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';
import '../services/auth_service.dart';
import '../widgets/maskottchen_animation.dart';

class AnzeigenameScreen extends StatefulWidget {
  final VoidCallback onFertig;
  const AnzeigenameScreen({super.key, required this.onFertig});

  @override
  State<AnzeigenameScreen> createState() => _AnzeigenameScreenState();
}

class _AnzeigenameScreenState extends State<AnzeigenameScreen> {
  final _controller = TextEditingController();
  bool _speichert = false;
  String? _fehlerText;

  bool get _gueltig => _controller.text.trim().length >= 2;

  Future<void> _weiter() async {
    if (!_gueltig || _speichert) return;
    setState(() {
      _speichert = true;
      _fehlerText = null;
    });
    final ergebnis = await AuthService.setzeAnzeigenameEindeutig(
      _controller.text.trim(),
    );
    if (ergebnis != AnzeigenameErgebnis.erfolgreich) {
      if (mounted) {
        setState(() {
          _speichert = false;
          _fehlerText = ergebnis == AnzeigenameErgebnis.bereitsVergeben
              ? t('Dieser Name ist schon vergeben — bitte wähle einen anderen.')
              : t('Etwas ist schiefgelaufen — bitte versuch es erneut.');
        });
      }
      return;
    }
    if (mounted) widget.onFertig();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MaskottchenAnimation(groesse: 200),
                    const SizedBox(height: 24),
                    Text(
                      t('Willkommen bei GeoMania!'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1a1a1a),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('Wie sollen dich andere in der Rangliste sehen?'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF888888),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF1a1a1a),
                          width: 2.5,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLength: 16,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() => _fehlerText = null),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: t('Dein Name'),
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    if (_fehlerText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _fehlerText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFCC0000),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _gueltig ? _weiter : null,
                      child: AnimatedOpacity(
                        opacity: _gueltig ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A9E4A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF1a1a1a),
                              width: 2.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF1a1a1a),
                                offset: Offset(0, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: _speichert
                              ? const Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  t('Los geht\'s →'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
