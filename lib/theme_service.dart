import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _key = 'isDarkMode';
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDarkMode);
    notifyListeners();
  }

  ThemeData get themeData => _isDarkMode ? darkTheme : lightTheme;

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

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.black87,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    cardColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Colors.black87,
      secondary: Colors.black54,
      surface: Colors.white,
    ),
  );
}
