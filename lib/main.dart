import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'services/storage_service.dart';
import 'ad_service.dart';
import 'theme_service.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with timeout — prevents black screen if Firebase hangs
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Firebase init timed out'),
    );
    // Capture Flutter errors and send to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (e) {
    debugPrint('Firebase.initializeApp failed: $e');
    // Continue anyway — login page will show Firebase errors inline
  }

  // AdMob init is already non-fatal with its own timeout
  await AdService.initialize();

  final storageService = StorageService();
  try {
    await storageService.init();
  } catch (e) {
    debugPrint('StorageService.init failed: $e');
  }

  runApp(TeamTrackerApp(storageService: storageService));
}

class TeamTrackerApp extends StatelessWidget {
  final StorageService storageService;

  const TeamTrackerApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (_, themeService, __) => MaterialApp(
          title: '籃球隊管理',
          debugShowCheckedModeBanner: false,
          theme: themeService.themeData,
          home: const LoginPage(),
        ),
      ),
    );
  }
}
