import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 球員數據服務
/// 統一處理球員的 CRUD 和同步
class PlayerService {
  final String teamName;
  final String? inviteCode;
  final String? ownerUid;

  PlayerService({
    required this.teamName,
    this.inviteCode,
    this.ownerUid,
  });

  String get _localKey => 'players_$teamName';

  DocumentReference? get _teamRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final uid = ownerUid ?? user.uid;
    final teamId = inviteCode ?? teamName;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('teams')
        .doc(teamId);
  }

  /// 從雲端載入球員
  Future<List<Map<String, dynamic>>> loadFromCloud() async {
    try {
      final ref = _teamRef;
      if (ref == null) return [];

      final doc = await ref.collection('players').doc('data').get();
      if (doc.exists) {
        final data = doc.data()?['players'] as List?;
        if (data != null && data.isNotEmpty) {
          final players = data.map((e) => Map<String, dynamic>.from(e)).toList();
          await _saveToLocal(players);
          return players;
        }
      }
    } catch (e) {
      print('載入球員失敗: $e');
    }
    return [];
  }

  /// 儲存到本地
  Future<void> _saveToLocal(List<Map<String, dynamic>> players) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode(players));
  }

  /// 同步到雲端
  Future<void> syncToCloud(List<Map<String, dynamic>> players) async {
    try {
      final ref = _teamRef;
      if (ref == null) return;

      await ref.collection('players').doc('data').set({
        'players': players,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _saveToLocal(players);
    } catch (e) {
      print('同步球員失敗: $e');
    }
  }

  /// 新增球員
  Future<void> addPlayer(Map<String, dynamic> player, List<Map<String, dynamic>> currentPlayers) async {
    currentPlayers.add(player);
    await syncToCloud(currentPlayers);
  }

  /// 刪除球員
  Future<void> deletePlayer(int index, List<Map<String, dynamic>> currentPlayers) async {
    currentPlayers.removeAt(index);
    await syncToCloud(currentPlayers);
  }

  /// 更新球員
  Future<void> updatePlayer(int index, Map<String, dynamic> player, List<Map<String, dynamic>> currentPlayers) async {
    currentPlayers[index] = player;
    await syncToCloud(currentPlayers);
  }
}
