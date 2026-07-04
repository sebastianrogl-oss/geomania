import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AnzeigenameScreen extends StatefulWidget {
  final VoidCallback onFertig;
  const AnzeigenameScreen({super.key, required this.onFertig});

  @override
  State<AnzeigenameScreen> createState() => _AnzeigenameScreenState();
}

class _AnzeigenameScreenState extends State<AnzeigenameScreen> {
  final _controller = TextEditingController();
  bool _speichert = false;

  bool get _gueltig => _controller.text.trim().length >= 2;

  Future<void> _weiter() async {
    if (!_gueltig || _speichert) return;
    setState(() => _speichert = true);
    await AuthService.setzeAnzeigename(_controller.text.trim());
    await AuthService.spielerAnlegen();
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/deko/coin_winken.png',
                width: 100,
                height: 100,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Willkommen bei GeoMania!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1a1a1a),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Wie sollen dich andere in der Rangliste sehen?',
                style: TextStyle(
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
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Dein Name',
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
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
                        : const Text(
                            'Los geht\'s →',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
      ),
    );
  }
}
