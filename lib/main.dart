import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'services/storage_service.dart';
import 'ad_service.dart';
import 'theme_service.dart';
import 'login_page.dart';

/// Completes when Firebase is ready; LoginPage awaits this before signing in.
final firebaseReady = Completer<void>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  try {
    await storageService.init();
  } catch (e) {
    debugPrint('StorageService.init failed: $e');
  }

  // Run app immediately to avoid iOS black screen
  runApp(TeamTrackerApp(storageService: storageService));

  // Init Firebase + AdMob in background after UI is visible
  await Future.delayed(const Duration(milliseconds: 500));
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Firebase init timed out'),
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (e) {
    debugPrint('Firebase.initializeApp failed: $e');
  } finally {
    firebaseReady.complete();
  }
  AdService.initialize();
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
