// BACKUP - lernpfad_screen.dart - Stand: 2026-06-17
// Originalort: lib/screens/lernpfad_screen.dart
// Beschreibung: Lernpfad-Platzhalter-Screen ("Kommt bald!") — war nirgendwo
//               in der Navigation eingebunden, daher orphan.
// Wiederherstellen: zurückkopieren nach lib/screens/lernpfad_screen.dart

import 'package:flutter/material.dart';

class LernpfadScreen extends StatelessWidget {
  final String title;
  final String emoji;
  const LernpfadScreen({super.key, required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F4F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 12),
              const Text('Kommt bald!',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
              const SizedBox(height: 8),
              const Text(
                  'Dieser Lernpfad wird gerade aufgebaut.\nSchau bald wieder vorbei.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB))),
            ],
          ),
        ),
      ),
    );
  }
}
