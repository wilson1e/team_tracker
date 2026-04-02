import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'teams_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoginMode = true;
  bool isLoading = false;
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Demo users for local fallback (only in debug mode)
  static final Map<String, Map<String, String>> _demoUsers = const bool.fromEnvironment('dart.vm.product')
      ? {} // Empty in production
      : {
          'admin@team.com':  {'password': '1234',      'name': '教練',     'role': 'admin'},
          'coach@team.com':  {'password': 'coach123',  'name': '教練助手', 'role': 'coach'},
          'player@team.com': {'password': 'player123', 'name': '球員',     'role': 'player'},
        };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Firebase helpers ───────────────────────────────────────────

  /// Fetch the display name for a Firebase UID from Firestore.
  /// Returns the stored name or falls back to [fallback].
  Future<String> _fetchUserName(String uid, String fallback) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return (doc.data()?['name'] as String?)?.trim().isNotEmpty == true
            ? doc.data()!['name'] as String
            : fallback;
      }
    } catch (_) {}
    return fallback;
  }

  /// Write/merge the user document in Firestore.
  Future<void> _upsertUserDoc({
    required String uid,
    required String email,
    required String name,
    required String role,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'email': email,
        'name': name,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ── Auth actions ───────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      if (isLoginMode) {
        await _login();
      } else {
        await _register();
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    // ── 1. Try Firebase ──────────────────────────────────────────
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid  = credential.user!.uid;
      // FIX: updateDisplayName as fallback so name is never blank
      final name = await _fetchUserName(uid, credential.user?.displayName ?? 'User');

      // Ensure doc exists (handles users who registered before this fix)
      await _upsertUserDoc(uid: uid, email: email, name: name, role: 'player');

      _navigateToHome(email: email, name: name);
      return;
    } on FirebaseAuthException catch (e) {
      // FIX: Firebase SDK v5+ uses 'invalid-credential' for wrong-password / user-not-found
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          _showError('Email 或密碼錯誤 (${e.code})');
          return;
        case 'invalid-email':
          _showError('Email 格式唔啱');
          return;
        case 'user-disabled':
          _showError('呢個帳號已被停用');
          return;
        case 'network-request-failed':
          _showError('網絡連接失敗');
          return;
        default:
          _showError('登入失敗: ${e.code}');
          return;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _showError('登入錯誤: $e');
      return;
    }
  }

  Future<void> _register() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    final name     = _nameController.text.trim();

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = credential.user!.uid;

      // FIX: set displayName on the Auth profile so it is always recoverable
      await credential.user!.updateDisplayName(name);

      // FIX: use set (with merge) keyed by UID, not add() with auto-ID
      await _upsertUserDoc(uid: uid, email: email, name: name, role: 'player');

      _navigateToHome(email: email, name: name);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _showError('呢個 Email 已經註冊，請直接登入');
          break;
        case 'weak-password':
          _showError('密碼太簡單，請用至少 6 個字');
          break;
        case 'invalid-email':
          _showError('Email 格式唔啱');
          break;
        default:
          _showError('註冊失敗: ${e.message ?? e.code}');
      }
    } catch (e) {
      _showError('網絡錯誤，請稍後再試');
    }
  }

  void _fallbackLogin(String email, String password) {
    final demo = _demoUsers[email];
    if (demo != null && demo['password'] == password) {
      _navigateToHome(
        email: email,
        name: demo['name']!,
        role: demo['role']!,
      );
    } else {
      _showError('登入失敗 — 請檢查 Email 同密碼');
    }
  }

  // ── Navigation ─────────────────────────────────────────────────

  void _navigateToHome({
    required String email,
    required String name,
    String role = 'player',
  }) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TeamsListPage(
          currentUserId:   email,
          currentUserName: name,
          userRole:        role,
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText:    label,
      labelStyle:   const TextStyle(color: Colors.white70),
      prefixIcon:   Icon(icon, color: Colors.orange),
      suffixIcon:   suffixIcon,
      filled:       true,
      fillColor:    Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.orange),
      ),
      errorStyle: const TextStyle(color: Colors.orangeAccent),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => isLoginMode = text == '登入'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color:         isSelected ? Colors.orange : Colors.transparent,
          borderRadius:  BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color:      isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    const Icon(Icons.sports_basketball,
                        size: 80, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      '🏀 籃球隊管理',
                      style: TextStyle(
                          fontSize:   28,
                          fontWeight: FontWeight.bold,
                          color:      Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text('Basketball Team Manager',
                        style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 48),

                    // Toggle
                    Container(
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleButton('登入', isLoginMode),
                          _buildToggleButton('註冊', !isLoginMode),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name field (register only)
                    if (!isLoginMode) ...[
                      TextFormField(
                        controller: _nameController,
                        style:       const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.words,
                        decoration: _buildInputDecoration('你的名稱', Icons.person),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '請輸入名稱' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    TextFormField(
                      controller:   _emailController,
                      style:        const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration:   _buildInputDecoration('Email', Icons.email),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '請輸入 Email';
                        if (!v.contains('@') || !v.contains('.')) {
                          return '請輸入有效嘅 Email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller:  _passwordController,
                      style:       const TextStyle(color: Colors.white),
                      obscureText: _obscurePassword,
                      decoration:  _buildInputDecoration(
                        '密碼',
                        Icons.lock,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '請輸入密碼';
                        if (!isLoginMode && v.length < 6) {
                          return '密碼至少 6 個字';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width:  double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width:  24,
                                height: 24,
                                child:  CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isLoginMode ? '登入' : '註冊',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
