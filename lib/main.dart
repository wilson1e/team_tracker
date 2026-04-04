import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ad_service.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'services/storage_service.dart';
import 'theme_service.dart';

/// Completes with true when Firebase is ready, false if init failed.
/// LoginPage._submit() awaits this before signing in.
final firebaseReady = Completer<bool>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Storage
  final storageService = StorageService();
  await storageService.init();

  // 2. Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady.complete(true);
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    firebaseReady.complete(false);
  }

  // 3. ATT（iOS 14.5+，AdMob 顯示廣告前必須請求）
  if (Platform.isIOS) {
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  // 4. AdMob
  await AdService.initialize();

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
