import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers/team_provider.dart';
import 'services/storage_service.dart';
import 'ad_service.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Initialize AdMob
    AdService.initialize();

    // Initialize storage
    final storageService = StorageService();
    await storageService.init();

    runApp(TeamTrackerApp(storageService: storageService));
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('初始化失敗: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    ));
  }
}

class TeamTrackerApp extends StatelessWidget {
  final StorageService storageService;

  const TeamTrackerApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TeamProvider(storageService)..loadData(),
      child: MaterialApp(
        title: '籃球隊管理',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A1A2E),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const LoginPage(),
      ),
    );
  }
}