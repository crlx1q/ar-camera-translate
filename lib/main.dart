import 'package:flutter/material.dart';

import 'ar_translator_page.dart';

void main() {
  runApp(const ARTranslateApp());
}

class ARTranslateApp extends StatelessWidget {
  const ARTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Camera Translate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5A0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F14), Color(0xFF10241D)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x1A00E5A0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.camera_rounded,
                      color: Color(0xFF00E5A0), size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AR Camera\nTranslate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Наведи камеру на текст — перевод появляется прямо поверх оригинала и держится на нём, когда ты двигаешь телефон.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 24),
                ..._features(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5A0),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ARTranslatorPage()),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Открыть камеру',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Работает офлайн · 10 языков · без API-ключей',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _features() {
    const items = [
      ['🎯', 'Перевод привязан к тексту и поворачивается вместе с ним'],
      ['🌐', 'Автоопределение языка — руками ничего не переключаешь'],
      ['📴', 'Офлайн-перевод на устройстве (ML Kit)'],
    ];
    return items
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e[0], style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e[1],
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
