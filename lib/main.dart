import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/storage_service.dart';
import 'theme_service.dart';
import 'login_page.dart';

/// Completes with true when Firebase is ready, false if init failed.
/// LoginPage._submit() awaits this before signing in.
final firebaseReady = Completer<bool>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();

  // DIAGNOSTIC: Firebase removed — testing if basic UI renders on iOS
  // Complete firebaseReady immediately so login page is not blocked
  firebaseReady.complete(true);

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
