import 'package:flutter/material.dart';

const brandIndigo = Color(0xFF4F46E5);
const brandViolet = Color(0xFF9333EA);
const brandAmber = Color(0xFFF59E0B);

ThemeData buildPapyraTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandIndigo,
    brightness: brightness,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor:
        brightness == Brightness.dark ? const Color(0xFF0B0B12) : const Color(0xFFF7F7FB),
    cardTheme: CardThemeData(
      elevation: 0,
      color: brightness == Brightness.dark ? const Color(0xFF16161F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: brightness == Brightness.dark
              ? const Color(0xFF262633)
              : const Color(0xFFECECF4),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

LinearGradient brandGradient() => const LinearGradient(
      colors: [brandIndigo, brandViolet],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );