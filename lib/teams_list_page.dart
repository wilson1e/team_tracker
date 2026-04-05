import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'team_detail_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'ad_service.dart';
import 'services/changelog_service.dart';

// Helper function to generate invite code
String generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
}

class TeamsListPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String userRole;

  const TeamsListPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.userRole,
  });

  @override
  State<TeamsListPage> createState() => _TeamsListPageState();
}

class _TeamsListPageState extends State<TeamsListPage> {
  final List<Map<String, dynamic>> _teams = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  BannerAd? _bannerAd;

  // ── Lifecycle ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // FIX: was missing — teams were never loaded on page open
    _loadTeamsFromCloud();
    _bannerAd = AdService.createBannerAd();
    AdService.loadInterstitialAd();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await ChangelogService.shouldShow()) {
        if (mounted) ChangelogService.show(context);
      }
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // ── Cloud sync ─────────────────────────────────────────────────

  Future<void> _loadTeamsFromCloud() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Demo / fallback user — nothing to load from cloud
        setState(() => _isLoading = false);
        return;
      }
      final teamsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('myTeams')
          .doc('teamsList')
          .get();

      if (teamsDoc.exists && teamsDoc.data() != null) {
        final data = teamsDoc.data()!['teams'] as List?;
        if (data != null) {
          setState(() {
            _teams.clear();
            _teams.addAll(data.map((e) => Map<String, dynamic>.from(e)));
          });
        }
      }
    } catch (e) {
      debugPrint('Load teams error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted) _registerExistingInviteCodes();
  }

  Future<void> _registerExistingInviteCodes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    bool needsSave = false;
    try {
      for (int i = 0; i < _teams.length; i++) {
        final team = _teams[i];
        if (team['isJoined'] == true || team['codeRegistered'] == true) continue;
        final code = team['inviteCode'] as String?;
        if (code == null) continue;
        await FirebaseFirestore.instance.collection('inviteCodes').doc(code).set({
          'ownerUid':  user.uid,
          'teamName':  team['name'] as String,
          'ownerName': widget.currentUserName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _teams[i] = Map<String, dynamic>.from(team)..['codeRegistered'] = true;
        needsSave = true;
      }
      if (needsSave) {
        setState(() {});
        await _saveTeamsToCloud();
      }
    } catch (e) {
      debugPrint('Register invite codes error: $e');
    }
  }

  Future<void> _saveTeamsToCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('myTeams')
          .doc('teamsList')
          .set({
        'teams':     _teams,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Save teams error: $e');
    }
  }

  // ── Team CRUD ──────────────────────────────────────────────────

  void _addTeam(String name, String? logoPath, String? homeJersey, String? awayJersey) {
    if (name.trim().isEmpty) return;
    if (name.contains('/') || name.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('球隊名稱不能包含 / 或 . 字符')),
      );
      return;
    }
    final code = generateInviteCode();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _teams.add({
        'name':           name.trim(),
        'logo':           logoPath,
        'inviteCode':     code,
        'homeJersey':     homeJersey,
        'awayJersey':     awayJersey,
        'ownerUid':       user?.uid,
        'ownerName':      widget.currentUserName,
        'isJoined':       false,
        'codeRegistered': true,
      });
    });
    _saveTeamsToCloud();
    _registerInviteCode(code, name.trim());
  }

  Future<void> _registerInviteCode(String code, String teamName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('inviteCodes').doc(code).set({
        'ownerUid':  user.uid,
        'teamName':  teamName,
        'ownerName': widget.currentUserName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Register invite code error: $e');
    }
  }

  void _updateTeam(int index, String name, String? logoPath,
      String? homeJersey, String? awayJersey) {
    if (name.trim().isEmpty) return;
    setState(() {
      _teams[index] = {
        ..._teams[index],
        'name':       name.trim(),
        'logo':       logoPath,
        'homeJersey': homeJersey,
        'awayJersey': awayJersey,
      };
    });
    _saveTeamsToCloud();
  }

  Future<bool> _deleteTeam(int index) async {
    final team = _teams[index];
    final isJoined = team['isJoined'] == true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(isJoined ? '離開球隊?' : '刪除球隊?',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          isJoined
              ? '確定離開「${team['name']}」?'
              : '確定刪除「${team['name']}」? 此操作不可撤銷。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isJoined ? '離開' : '刪除'),
          ),
        ],
      ),
    );
    if (confirm != true) return false;
    // Guard: list may have changed during async dialog
    if (index >= _teams.length) return false;
    if (_teams[index]['inviteCode'] != team['inviteCode']) return false;
    setState(() => _teams.removeAt(index));
    _saveTeamsToCloud();
    return true;
  }

  // ── Jersey colour helpers ──────────────────────────────────────

  static const _jerseyColorNames = [
    '紅色', '藍色', '綠色', '黃色', '白色', '黑色', '紫色', '橙色',
  ];

  Color _getJerseyColor(String colorName) {
    const map = {
      '紅色': Colors.red,
      '藍色': Colors.blue,
      '綠色': Colors.green,
      '黃色': Colors.yellow,
      '白色': Colors.white,
      '黑色': Colors.black,
      '紫色': Colors.purple,
      '橙色': Colors.orange,
    };
    return map[colorName] ?? Colors.grey;
  }

  // ── Jersey picker widget (reusable) ───────────────────────────

  Widget _buildJerseyPicker({
    required String label,
    required String? selected,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _jerseyColorNames.map((color) {
            final isSelected = selected == color;
            return GestureDetector(
              onTap: () => onChanged(isSelected ? null : color),
              child: Container(
                width:  40,
                height: 40,
                decoration: BoxDecoration(
                  color:  _getJerseyColor(color),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey,
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────

  void _showAddTeamDialog() {
    // Beta limit: max 1 team
    final ownedTeams = _teams.where((t) => t['isJoined'] != true).toList();
    if (ownedTeams.length >= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('測試版限制', style: TextStyle(color: Colors.white)),
          content: const Text(
            '測試版暫時只支援 1 個球隊。\n正式版將開放更多球隊功能。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
      return;
    }
    final nameController = TextEditingController();
    String? selectedLogoPath;
    String? selectedHomeJersey;
    String? selectedAwayJersey;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('新增球隊', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize:     MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style:       const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:   '球隊名稱',
                    hintStyle:  const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.group, color: Colors.white54),
                    filled:     true,
                    fillColor:  Colors.white.withValues(alpha:0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:   BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Logo picker
                Row(
                  children: [
                    CircleAvatar(
                      radius:          30,
                      backgroundColor: Colors.orange,
                      backgroundImage: selectedLogoPath != null &&
                              File(selectedLogoPath!).existsSync()
                          ? FileImage(File(selectedLogoPath!))
                          : null,
                      child: selectedLogoPath == null
                          ? const Icon(Icons.group, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final XFile? image = await _picker.pickImage(
                              source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() => selectedLogoPath = image.path);
                          }
                        } catch (_) {}
                      },
                      icon:  const Icon(Icons.add_photo_alternate),
                      label: Text(selectedLogoPath != null ? '已選擇圖片' : '選擇標誌'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // FIX: extracted into _buildJerseyPicker — no more duplication
                _buildJerseyPicker(
                  label:     '主場球衣顏色:',
                  selected:  selectedHomeJersey,
                  onChanged: (c) => setDialogState(() => selectedHomeJersey = c),
                ),
                const SizedBox(height: 16),
                _buildJerseyPicker(
                  label:     '作客球衣顏色:',
                  selected:  selectedAwayJersey,
                  onChanged: (c) => setDialogState(() => selectedAwayJersey = c),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _addTeam(nameController.text, selectedLogoPath,
                      selectedHomeJersey, selectedAwayJersey);
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTeamDialog(int index) {
    final team               = _teams[index];
    final nameController     = TextEditingController(text: team['name']);
    String? selectedLogoPath = team['logo'];
    String? selectedHomeJersey = team['homeJersey'];
    String? selectedAwayJersey = team['awayJersey'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('編輯球隊', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize:     MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style:       const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:   '球隊名稱',
                    hintStyle:  const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.group, color: Colors.white54),
                    filled:     true,
                    fillColor:  Colors.white.withValues(alpha:0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:   BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius:          30,
                      backgroundColor: Colors.orange,
                      backgroundImage: selectedLogoPath != null &&
                              File(selectedLogoPath!).existsSync()
                          ? FileImage(File(selectedLogoPath!))
                          : null,
                      child: selectedLogoPath == null
                          ? const Icon(Icons.group, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final XFile? image = await _picker.pickImage(
                              source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() => selectedLogoPath = image.path);
                          }
                        } catch (_) {}
                      },
                      icon:  const Icon(Icons.add_photo_alternate),
                      label: Text(selectedLogoPath != null ? '更換圖片' : '選擇標誌'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildJerseyPicker(
                  label:     '主場球衣:',
                  selected:  selectedHomeJersey,
                  onChanged: (c) => setDialogState(() => selectedHomeJersey = c),
                ),
                const SizedBox(height: 16),
                _buildJerseyPicker(
                  label:     '作客球衣:',
                  selected:  selectedAwayJersey,
                  onChanged: (c) => setDialogState(() => selectedAwayJersey = c),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _updateTeam(index, nameController.text, selectedLogoPath,
                      selectedHomeJersey, selectedAwayJersey);
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteCodeDialog(String teamName, String inviteCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('$teamName 邀請碼',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        Colors.orange.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                inviteCode,
                style: const TextStyle(
                  fontSize:    32,
                  fontWeight:  FontWeight.bold,
                  letterSpacing: 4,
                  color:       Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '分享呢個邀請碼比隊友，等佢哋加入球隊',
              style:     TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('邀請碼已複製')),
              );
            },
            child: const Text('複製', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('關閉')),
        ],
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────

  void _showJoinTeamDialog() {
    if (_teams.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('測試版限制', style: TextStyle(color: Colors.white)),
          content: const Text(
            '測試版暫時只支援 1 個球隊。\n正式版將開放更多球隊功能。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
      return;
    }
    final codeCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('加入球隊', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('輸入教練分享的6位邀請碼',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                style: const TextStyle(color: Colors.orange, fontSize: 24,
                    fontWeight: FontWeight.bold, letterSpacing: 6),
                textAlign: TextAlign.center,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 24, letterSpacing: 6),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha:0.1),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('取消', style: TextStyle(color: Colors.white70))),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請輸入6位邀請碼')));
                  return;
                }
                setDS(() => isLoading = true);
                final success = await _joinTeamByCode(code);
                if (success && mounted) Navigator.pop(ctx);
                else if (mounted) setDS(() => isLoading = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('加入'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMemberRecord({
    required String ownerUid,
    required String teamId,
    required String memberUid,
    required String memberName,
    required String memberEmail,
    required String inviteCode,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('teams')
          .doc(teamId)
          .collection('members')
          .doc(memberUid)
          .set({
        'uid': memberUid,
        'name': memberName,
        'email': memberEmail,
        'role': 'viewer',
        'joinedAt': FieldValue.serverTimestamp(),
        'inviteCode': inviteCode,
      });
      debugPrint('成員記錄已添加: $memberUid');
    } catch (e) {
      debugPrint('添加成員記錄失敗: $e');
      rethrow;
    }
  }

  Future<bool> _joinTeamByCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demo模式不支援加入球隊，請先登入')));
      }
      return false;
    }
    try {
      final codeDoc = await FirebaseFirestore.instance.collection('inviteCodes').doc(code).get();
      if (!codeDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('邀請碼無效，請確認後再試'), backgroundColor: Colors.red));
        }
        return false;
      }
      final data = codeDoc.data()!;
      final ownerUid = data['ownerUid'] as String;
      final teamName = data['teamName'] as String;
      final ownerName = (data['ownerName'] as String?) ?? '';
      if (ownerUid == user.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('呢個係你自己既球隊')));
        }
        return false;
      }
      final alreadyJoined = _teams.any((t) => t['ownerUid'] == ownerUid && t['name'] == teamName);
      if (alreadyJoined) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('你已經加入咗呢個球隊')));
        }
        return false;
      }
      setState(() {
        _teams.add({
          'name': teamName, 'logo': null, 'inviteCode': code,
          'homeJersey': null, 'awayJersey': null,
          'ownerUid': ownerUid, 'ownerName': ownerName, 'isJoined': true,
        });
      });
      await _saveTeamsToCloud();

      // 添加成員記錄到創建者的 members 集合
      await _addMemberRecord(
        ownerUid: ownerUid,
        teamId: code,
        memberUid: user.uid,
        memberName: widget.currentUserName,
        memberEmail: user.email ?? '',
        inviteCode: code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功加入「$teamName」！')));
      }
      return true;
    } on FirebaseException catch (e) {
      debugPrint('Join team FirebaseException: ${e.code} - ${e.message}');
      String msg = '網絡錯誤，請稍後再試';
      if (e.code == 'permission-denied') {
        msg = '權限不足，請確認 Firestore Rules 已更新';
      } else if (e.code == 'unavailable') {
        msg = '網絡連接失敗，請檢查網絡';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
      return false;
    } catch (e) {
      debugPrint('Join team error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('發生錯誤，請稍後再試'), backgroundColor: Colors.red));
      }
      return false;
    }
  }

  Future<void> _logout() async {
    // FIX: was missing Firebase sign-out — user stayed signed in on next launch
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: Text('🏀 ${widget.currentUserName} 的球隊'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showJoinTeamDialog,
            tooltip: '加入球隊',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            tooltip: '設定',
          ),
          IconButton(
            icon:    const Icon(Icons.refresh),
            onPressed: _loadTeamsFromCloud,
            tooltip: '重新整理',
          ),
          IconButton(
            icon:    const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '登出',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange))
          : _teams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off,
                          size: 80, color: Colors.white.withValues(alpha:0.3)),
                      const SizedBox(height: 16),
                      const Text('暫時未有球隊',
                          style: TextStyle(color: Colors.white70, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('撳下面按鈕新增球隊',
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:    const EdgeInsets.all(16),
                  itemCount:  _teams.length,
                  itemBuilder: (context, index) {
                    final team     = _teams[index];
                    final logoFile = team['logo'] != null
                        ? File(team['logo'] as String)
                        : null;

                    return Dismissible(
                      key:       ValueKey(team['inviteCode']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding:   const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color:        Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _deleteTeam(index),
                      child: Card(
                        color:  const Color(0xFF1A1A2E),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: Colors.orange, width: 0.5),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor:  Colors.orange,
                            backgroundImage:
                                logoFile != null && logoFile.existsSync()
                                    ? FileImage(logoFile)
                                    : null,
                            child: logoFile == null || !logoFile.existsSync()
                                ? const Icon(Icons.group, color: Colors.white)
                                : null,
                          ),
                          title: Text(
                            team['name'] as String,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (team['isJoined'] == true)
                                Text('👥 加入自: ${team['ownerName'] ?? '其他教練'}',
                                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
                              Text('邀請碼: ${team['inviteCode']}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              if (team['homeJersey'] != null ||
                                  team['awayJersey'] != null)
                                Row(
                                  children: [
                                    if (team['homeJersey'] != null) ...[
                                      Container(
                                        width: 11, height: 11,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getJerseyColor(team['homeJersey'] as String),
                                          border: Border.all(color: Colors.white30, width: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Text('主  ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                    ],
                                    if (team['awayJersey'] != null) ...[
                                      Container(
                                        width: 11, height: 11,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getJerseyColor(team['awayJersey'] as String),
                                          border: Border.all(color: Colors.white30, width: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Text('客', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (team['isJoined'] != true) ...[
                                IconButton(
                                  icon:    const Icon(Icons.edit, color: Colors.white54),
                                  onPressed: () => _showEditTeamDialog(index),
                                  tooltip: '編輯球隊',
                                ),
                                IconButton(
                                  icon:    const Icon(Icons.share, color: Colors.orange),
                                  onPressed: () => _showInviteCodeDialog(
                                      team['name'] as String,
                                      team['inviteCode'] as String),
                                  tooltip: '邀請碼',
                                ),
                              ],
                              const Icon(Icons.chevron_right,
                                  color: Colors.white38),
                            ],
                          ),
                          onTap: () async {
                            String? userRole;
                            if (team['isJoined'] == true) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                // Show loading overlay while fetching member role
                                if (mounted) setState(() => _isLoading = true);
                                try {
                                  final memberDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(team['ownerUid'] as String)
                                      .collection('teams')
                                      .doc(team['inviteCode'] as String)
                                      .collection('members')
                                      .doc(user.uid)
                                      .get();
                                  userRole = memberDoc.data()?['role'] as String?;
                                } catch (_) {}
                                if (mounted) setState(() => _isLoading = false);
                              }
                            }
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamDetailPage(
                                  teamName:       team['name'] as String,
                                  inviteCode:     team['inviteCode'] as String?,
                                  logoPath:       team['logo'] as String?,
                                  homeJerseyColor: team['homeJersey'] as String?,
                                  awayJerseyColor: team['awayJersey'] as String?,
                                  ownerUid:       team['ownerUid'] as String?,
                                  isJoined:       team['isJoined'] == true,
                                  userRole:       userRole,
                                ),
                              ),
                            );
                            // Refresh in case team data changed
                            _loadTeamsFromCloud();
                            // 顯示插頁廣告
                            AdService.showInterstitialAd();
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       _showAddTeamDialog,
        backgroundColor: Colors.orange,
        icon:  const Icon(Icons.add),
        label: const Text('新增球隊'),
      ),
      bottomNavigationBar: _bannerAd != null
          ? SizedBox(
              height: 50,
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
    );
  }
}
