import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'services/storage_service.dart';
import 'ad_service.dart';
import 'theme_service.dart';
import 'login_page.dart';

/// Completes with true when Firebase is ready, false if init failed.
/// LoginPage._submit() awaits this before signing in.
final firebaseReady = Completer<bool>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();

  // Run app immediately to avoid iOS black screen
  runApp(TeamTrackerApp(storageService: storageService));

  // Wait for first frame to render before starting heavy init
  final frameCompleter = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) => frameCompleter.complete());
  await frameCompleter.future;

  // StorageService init deferred to after first frame
  try {
    await storageService.init();
  } catch (e) {
    debugPrint('StorageService.init failed: $e');
  }

  // Firebase init
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Firebase init timed out'),
    );
    try {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    } catch (e) {
      debugPrint('Crashlytics setup failed: $e');
    }
    firebaseReady.complete(true);
  } catch (e) {
    debugPrint('Firebase.initializeApp failed: $e');
    firebaseReady.complete(false);
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
