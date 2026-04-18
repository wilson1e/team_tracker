import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  ThemeData get themeData => darkTheme;

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.white,
    scaffoldBackgroundColor: const Color(0xFF0F0F1E),
    cardColor: const Color(0xFF1A1A2E),
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.white70,
      surface: Color(0xFF1A1A2E),
    ),
  );
}
