import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ad_service.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'platform_service.dart';
import 'services/storage_service.dart';
import 'theme_service.dart';

/// Completes with true when Firebase is ready, false if init failed.
/// LoginPage._submit() awaits this before signing in.
final firebaseReady = Completer<bool>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('=== main.dart: START ===');

  // 1. Storage
  debugPrint('=== main.dart: Init StorageService ===');
  final storageService = StorageService();
  await storageService.init();
  debugPrint('=== main.dart: StorageService done ===');

  // 2. Firebase
  debugPrint('=== main.dart: Init Firebase ===');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('=== main.dart: Firebase INIT SUCCESS ===');
    firebaseReady.complete(true);
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    firebaseReady.complete(false);
  }

  // 3. ATT（iOS 14.5+，AdMob 顯示廣告前必須請求）
  await requestATT();

  // 4. AdMob
  debugPrint('=== main.dart: Init AdMob ===');
  if (!kIsWeb) await AdService.initialize();
  debugPrint('=== main.dart: AdMob done ===');

  debugPrint('=== main.dart: Calling runApp ===');
  runApp(TeamTrackerApp(storageService: storageService));
  debugPrint('=== main.dart: runApp returned (should not happen) ===');
}

class TeamTrackerApp extends StatelessWidget {
  final StorageService storageService;

  const TeamTrackerApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) => MaterialApp(
          title: '籃球隊管理',
          debugShowCheckedModeBanner: false,
          theme: themeService.themeData,
          home: const LoginPage(),
        ),
      ),
    );
  }
}
