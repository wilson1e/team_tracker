import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'team_settings_page.dart';
import 'team_members_page.dart';
import 'calendar_service.dart';
import 'pages/team_detail/tabs/players_tab.dart';
import 'services/export/export_service.dart';
import 'pages/photo_gallery_page.dart';

// ── Color serialization helpers ───────────────────────────────────
int _colorToInt(Color? c) => c?.value ?? 0;
Color? _intToColor(int? v) => (v == null || v == 0) ? null : Color(v);

class TeamDetailPage extends StatefulWidget {
  final String teamName;
  final String? inviteCode;
  final String? logoPath;
  final String? homeJerseyColor;
  final String? awayJerseyColor;
  final String? userRole;
  final String? ownerUid;
  final bool isJoined;

  const TeamDetailPage({
    super.key,
    required this.teamName,
    this.inviteCode,
    this.logoPath,
    this.homeJerseyColor,
    this.awayJerseyColor,
    this.userRole,
    this.ownerUid,
    this.isJoined = false,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  // ── Player form ───────────────────────────────────────────────
  final _nameCtrl   = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _selectedPosition = '';
  List<Map<String, dynamic>> _players = [];

  // ── Match form ────────────────────────────────────────────────
  List<Map<String, dynamic>> _matches = [];
  DateTime  _selectedDate   = DateTime.now();
  TimeOfDay _selectedTime   = const TimeOfDay(hour: 20, minute: 0);
  String?   _selectedVenue;
  String    _selectedLeague  = 'Happy Basketball League';
  bool      _isHome          = true;
  Color?    _selectedJerseyColor;
  final     _opponentCtrl   = TextEditingController();
  final     _venueCtrl      = TextEditingController();

  // ── Training form ─────────────────────────────────────────────
  List<Map<String, dynamic>> _training = [];
  DateTime  _trainingDate = DateTime.now();
  TimeOfDay _trainingTime = const TimeOfDay(hour: 19, minute: 0);
  String?   _trainingVenue;
  final     _trainingTitleCtrl = TextEditingController();
  final     _trainingNotesCtrl = TextEditingController();
  final     _trainingVenueCtrl = TextEditingController();

  // ── Static data ───────────────────────────────────────────────
  final Map<String, List<String>> _venuesByDistrict = {
    '香港區': [
      '香港公園體育館', '石塘咀體育館', '上環體育館', '士美非路體育館',
      '中山紀念公園體育館', '柴灣體育館', '港島東體育館', '渣華道體育館',
      '鰂魚涌體育館', '西灣河體育館', '小西灣體育館', '香港仔體育館',
      '鴨脷洲體育館', '赤柱體育館', '黃竹坑體育館', '漁光道體育館',
      '港灣道體育館', '駱克道體育館',
    ],
    '九龍區': [
      '佛光街體育館', '紅磡市政大廈體育館', '九龍城體育館', '土瓜灣體育館',
      '彩榮路體育館', '振華道體育館', '曉光街體育館', '九龍灣體育館',
      '藍田南體育館', '鯉魚門體育館', '牛頭角道體育館', '瑞和街體育館',
      '順利邨體育館', '長沙灣體育館', '荔枝角公園體育館', '北河街體育館',
      '保安道體育館', '深水埗體育館', '石硤尾公園體育館', '彩虹道體育館',
      '竹園體育館', '東啟德體育館', '馬仔坑體育館', '摩士公園體育館',
      '牛池灣體育館', '蒲崗村道體育館', '界限街體育館', '花園街體育館',
      '官涌體育館', '大角咀體育館',
    ],
    '新界區': [
      '鳳琴街體育館', '朗屏體育館', '屏山天水圍體育館', '天暉路體育館',
      '天瑞體育館', '天水圍體育館', '元朗體育館', '友愛體育館',
      '大興體育館', '兆麟體育館', '良田體育館', '屯門蝴蝶灣體育館',
      '楊屋道體育館', '蕙荃體育館', '荃灣西約體育館', '荃灣體育館',
      '荃景圍體育館', '青衣體育館', '青衣西南體育館', '大窩口體育館',
      '林士德體育館', '北葵涌鄧肇堅體育館', '荔景體育館', '楓樹窩體育館',
      '長發體育館', '東涌文東路體育館', '坪洲體育館', '梅窩體育館',
      '長洲體育館',
    ],
  };
  final List<String> _leagues   = [
    'Happy Basketball League',
    'M League',
    '屯門元朗之友TYL',
    'SBL',
    'Phoenix Basketball',
    'Goat',
    '博亞 SportsArt',
    'Ace basketball league',
    'Ad Hoc Basketball League',
    'NTBC',
    'Bros League hk',
    'Goat League HK',
    'Friendly',
    '其他 Other',
  ];
  final List<String> _positions = ['PG', 'SG', 'SF', 'PF', 'C'];
  final List<Map<String, dynamic>> _jerseyColors = [
    {'name': 'Red',    'color': Colors.red},
    {'name': 'Blue',   'color': Colors.blue},
    {'name': 'Green',  'color': Colors.green},
    {'name': 'Yellow', 'color': Colors.yellow},
    {'name': 'White',  'color': Colors.white},
    {'name': 'Black',  'color': Colors.black},
    {'name': 'Purple', 'color': Colors.purple},
    {'name': 'Orange', 'color': Colors.orange},
  ];

  // ── SharedPreferences keys ────────────────────────────────────
  String get _playersKey  => 'players_${widget.teamName}';
  String get _matchesKey  => 'matches_${widget.teamName}';
  String get _trainingKey => 'training_${widget.teamName}';

  // ── Firestore reference shorthand ────────────────────────────
  DocumentReference? get _teamRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final uid = widget.ownerUid ?? user.uid;
    final teamId = widget.inviteCode ?? widget.teamName;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('teams')
        .doc(teamId);
  }

  // ============================================================
  // Lifecycle
  // ============================================================
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _opponentCtrl.dispose();
    _venueCtrl.dispose();
    _trainingTitleCtrl.dispose();
    _trainingNotesCtrl.dispose();
    _trainingVenueCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Persistence
  // ============================================================

  Future<void> _loadData() async {
    // Load from cloud only
    await _loadFromCloud();
  }

  // ── Helper: safely deserialize attendance map ─────────────────
  Map<String, bool> _deserializeAttendance(dynamic raw) {
    if (raw == null) return {};
    return Map<String, bool>.from(
      (raw as Map).map((k, v) => MapEntry(k.toString(), (v as bool?) ?? false)),
    );
  }

  // ── Load from Firestore ───────────────────────────────────────
  Future<void> _loadFromCloud() async {
    try {
      final ref = _teamRef;
      if (ref == null) return;

      // Only create parent doc if user is the owner
      if (!widget.isJoined) {
        await ref.set({'name': widget.teamName}, SetOptions(merge: true));
      }

      // Players
      final playersDoc = await ref.collection('players').doc('data').get();
      if (playersDoc.exists) {
        final data = playersDoc.data()?['players'] as List?;
        if (data != null && data.isNotEmpty) {
          final cloudPlayers = data
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (mounted) setState(() => _players = cloudPlayers);
          await _savePlayersLocal();
        }
      }

      // Matches
      final matchesDoc = await ref.collection('matches').doc('data').get();
      if (matchesDoc.exists) {
        final data = matchesDoc.data()?['matches'] as List?;
        if (data != null && data.isNotEmpty) {
          final cloudMatches = data.map((e) {
            final m = Map<String, dynamic>.from(e);
            m['jerseyColor'] = _intToColor(m['jerseyColor'] as int?);
            // FIX: attendance from Firestore comes as Map<String,dynamic>, not Map<String,bool>
            m['attendance'] = _deserializeAttendance(m['attendance']);
            return m;
          }).toList();
          if (mounted) setState(() => _matches = cloudMatches);
          await _saveMatchesLocal();
        }
      }

      // Training
      final trainingDoc = await ref.collection('training').doc('data').get();
      if (trainingDoc.exists) {
        final data = trainingDoc.data()?['training'] as List?;
        if (data != null && data.isNotEmpty) {
          final cloudTraining = data.map((e) {
            final t = Map<String, dynamic>.from(e);
            t['attendance'] = _deserializeAttendance(t['attendance']);
            return t;
          }).toList();
          if (mounted) setState(() => _training = cloudTraining);
          await _saveTrainingLocal();
        }
      }
    } catch (e) {
      debugPrint('_loadFromCloud ERROR: $e');
    }
  }

  // ── Local saves ───────────────────────────────────────────────

  Future<void> _savePlayersLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playersKey, jsonEncode(_players));
  }

  Future<void> _saveMatchesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = _matches.map((m) {
      final copy = Map<String, dynamic>.from(m);
      copy['jerseyColor'] = _colorToInt(m['jerseyColor'] as Color?);
      return copy;
    }).toList();
    await prefs.setString(_matchesKey, jsonEncode(serializable));
  }

  Future<void> _saveTrainingLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trainingKey, jsonEncode(_training));
  }

  // ── Save + sync (called on every mutation) ────────────────────

  Future<void> _savePlayers() async {
    if (!widget.isJoined) {
      await _syncPlayersToCloud();
    }
  }

  Future<void> _syncPlayersToCloud() async {
    try {
      final ref = _teamRef;
      if (ref == null) return;
      if (!widget.isJoined) {
        await ref.set({'name': widget.teamName}, SetOptions(merge: true));
      }
      await ref.collection('players').doc('data').set({
        'players':   _players,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('_syncPlayersToCloud error: $e');
    }
  }

  Future<void> _saveMatches() async {
    if (!widget.isJoined) {
      await _syncMatchesToCloud();
    }
  }

  Future<void> _syncMatchesToCloud() async {
    try {
      final ref = _teamRef;
      if (ref == null) return;
      final serializable = _matches.map((m) {
        final copy = Map<String, dynamic>.from(m);
        copy['jerseyColor'] = _colorToInt(m['jerseyColor'] as Color?);
        return copy;
      }).toList();
      if (!widget.isJoined) {
        await ref.set({'name': widget.teamName}, SetOptions(merge: true));
      }
      await ref.collection('matches').doc('data').set({
        'matches':   serializable,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Schedule notifications for all matches
      await _scheduleMatchNotifications();
    } catch (e) {
      debugPrint('_syncMatchesToCloud error: $e');
    }
  }

  Future<void> _scheduleMatchNotifications() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    for (int i = 0; i < _matches.length; i++) {
      final match = _matches[i];
      try {
        final matchDate = DateTime.parse(match['date']);
        await notificationService.scheduleMatchNotification(
          id: '${widget.teamName}_match_$i'.hashCode.abs(),
          teamName: widget.teamName,
          opponent: match['opponent'] ?? '',
          matchDate: matchDate,
          matchTime: match['time'] ?? '20:00',
          venue: match['location'] ?? '',
        );
      } catch (e) {
        debugPrint('Schedule notification error: $e');
      }
    }
  }

  Future<void> _saveTraining() async {
    if (!widget.isJoined) {
      await _syncTrainingToCloud();
    }
  }

  Future<void> _syncTrainingToCloud() async {
    try {
      final ref = _teamRef;
      if (ref == null) return;
      if (!widget.isJoined) {
        await ref.set({'name': widget.teamName}, SetOptions(merge: true));
      }
      await ref.collection('training').doc('data').set({
        'training':  _training,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Schedule notifications for all training
      await _scheduleTrainingNotifications();
    } catch (e) {
      debugPrint('_syncTrainingToCloud error: $e');
    }
  }

  Future<void> _scheduleTrainingNotifications() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    for (int i = 0; i < _training.length; i++) {
      final training = _training[i];
      try {
        final trainingDate = DateTime.parse(training['date']);
        await notificationService.scheduleTrainingNotification(
          id: '${widget.teamName}_training_$i'.hashCode.abs(),
          teamName: widget.teamName,
          title: training['title'] ?? '',
          trainingDate: trainingDate,
          trainingTime: training['time'] ?? '19:00',
          venue: training['venue'] ?? '',
        );
      } catch (e) {
        debugPrint('Schedule training notification error: $e');
      }
    }
  }

  // ============================================================
  // UI helpers
  // ============================================================

  Widget _buildVenuePicker({
    required String? selectedVenue,
    required TextEditingController venueCtrl,
    required void Function(String?) onChanged,
  }) {
    final allVenues = _venuesByDistrict.values.expand((v) => v).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: allVenues.contains(selectedVenue) ? selectedVenue : null,
          decoration: _inputDeco('選擇場地'),
          dropdownColor: const Color(0xFF1A1A2E),
          items: _venuesByDistrict.entries.expand((entry) {
            return [
              DropdownMenuItem<String>(
                enabled: false,
                value: '___${entry.key}',
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(entry.key, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              ...entry.value.map((v) => DropdownMenuItem(
                value: v,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(v, style: const TextStyle(color: Colors.white)),
                ),
              )),
            ];
          }).toList(),
          onChanged: (v) {
            venueCtrl.clear();
            onChanged(v);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: venueCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco('或手動輸入場地').copyWith(
            prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.orange),
          ),
          onChanged: (v) {
            if (v.isNotEmpty) {
              onChanged(v);
            } else {
              onChanged(null);
            }
          },
        ),
      ],
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? Colors.red : null,
    ));
  }

  Future<void> _exportReport() async {
    try {
      _showMessage('正在匯出報表...');
      final filePath = await ExportService.exportAttendanceReport(
        teamName: widget.teamName,
        players: _players,
        matches: _matches,
        training: _training,
      );

      if (!mounted) return;

      // 顯示選擇對話框
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('報表已生成', style: TextStyle(color: Colors.white)),
          content: Text(
            '檔案已儲存至:\n${filePath.split('/').last}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('關閉', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ExportService.shareReport(filePath, widget.teamName);
              },
              child: const Text('分享', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage('匯出失敗: $e', isError: true);
    }
  }

  Future<bool> _confirmDelete(String label) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('刪除?',
                style: TextStyle(color: Colors.white)),
            content: Text('移除 "$label"?',
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消',
                    style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
                child: const Text('刪除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled:     true,
        fillColor:  Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Colors.orange),
        ),
      );

  String _getLeagueAbbr(String league) {
    const map = {
      'Happy Basketball League': 'HBL',
      'M League': 'ML',
      '屯門元朗之友TYL': 'TYL',
      'SBL': 'SBL',
      'Phoenix Basketball': 'PHX',
      'Goat': 'GOAT',
      '博亞 SportsArt': 'SA',
      'Ace basketball league': 'ACE',
      'Ad Hoc Basketball League': 'AHBL',
      'NTBC': 'NTBC',
      'Bros League hk': 'BROS',
      'Goat League HK': 'GLHK',
      'Friendly': 'FRD',
      '其他 Other': 'OTH',
    };
    return map[league] ?? league.substring(0, 3).toUpperCase();
  }

  Color _positionColor(String pos) {
    switch (pos) {
      case 'PG': return const Color(0xFF4FC3F7);
      case 'SG': return const Color(0xFF4DB6AC);
      case 'SF': return const Color(0xFF81C784);
      case 'PF': return const Color(0xFFFFB74D);
      case 'C':  return const Color(0xFFCE93D8);
      default:   return Colors.grey;
    }
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(
                    color: Colors.white30, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Player statistics ─────────────────────────────────────────
  Map<String, dynamic> _getPlayerStats(String playerName) {
    int matchTotal = 0, matchAttended = 0, trainingTotal = 0, trainingAttended = 0;
    List<bool> recentMatches = [], recentTraining = [];

    for (var match in _matches) {
      final attendance = match['attendance'] as Map?;
      if (attendance != null && attendance.containsKey(playerName)) {
        matchTotal++;
        final attended = attendance[playerName] == true;
        if (attended) matchAttended++;
        if (recentMatches.length < 5) recentMatches.add(attended);
      }
    }

    for (var training in _training) {
      final attendance = training['attendance'] as Map?;
      if (attendance != null && attendance.containsKey(playerName)) {
        trainingTotal++;
        final attended = attendance[playerName] == true;
        if (attended) trainingAttended++;
        if (recentTraining.length < 5) recentTraining.add(attended);
      }
    }

    return {
      'matchRate': matchTotal > 0 ? (matchAttended / matchTotal * 100) : 0.0,
      'trainingRate': trainingTotal > 0 ? (trainingAttended / trainingTotal * 100) : 0.0,
      'overallRate': (matchTotal + trainingTotal) > 0
          ? ((matchAttended + trainingAttended) / (matchTotal + trainingTotal) * 100) : 0.0,
      'recentMatches': recentMatches,
      'recentTraining': recentTraining,
    };
  }

  // ============================================================
  // PLAYER METHODS
  // ============================================================

  void _addPlayer() {
    if (_nameCtrl.text.isEmpty) {
      _showMessage('請輸入球員名稱', isError: true);
      return;
    }

    // Validate number (0-99)
    final number = int.tryParse(_numberCtrl.text) ?? 0;
    if (number < 0 || number > 99) {
      _showMessage('球衣號碼必須在 0-99 之間', isError: true);
      return;
    }

    // Validate height (100-250 cm)
    final height = int.tryParse(_heightCtrl.text) ?? 0;
    if (height != 0 && (height < 100 || height > 250)) {
      _showMessage('身高必須在 100-250 cm 之間', isError: true);
      return;
    }

    // Validate weight (30-200 kg)
    final weight = int.tryParse(_weightCtrl.text) ?? 0;
    if (weight != 0 && (weight < 30 || weight > 200)) {
      _showMessage('體重必須在 30-200 kg 之間', isError: true);
      return;
    }

    setState(() {
      _players.add({
        'name':     _nameCtrl.text.trim(),
        'number':   number,
        'position': _selectedPosition.isEmpty ? '-' : _selectedPosition,
        'height':   height,
        'weight':   weight,
      });
      _selectedPosition = '';
    });
    _savePlayers();
    _nameCtrl.clear();
    _numberCtrl.clear();
    _heightCtrl.clear();
    _weightCtrl.clear();
    _showMessage('球員已新增');
  }

  Future<void> _deletePlayer(int index) async {
    if (!await _confirmDelete(_players[index]['name'])) return;
    setState(() => _players.removeAt(index));
    _savePlayers();
    _showMessage('球員已刪除');
  }

  void _showPlayerStats(int index) {
    final p = _players[index];
    final stats = _getPlayerStats(p['name']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('${p['name']} 統計', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('總出席率: ${stats['overallRate'].toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('比賽出席率: ${stats['matchRate'].toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text('訓練出席率: ${stats['trainingRate'].toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
              if ((stats['recentMatches'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('最近5場比賽:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: (stats['recentMatches'] as List<bool>).map((attended) =>
                    Icon(attended ? Icons.check_circle : Icons.cancel,
                      color: attended ? Colors.green : Colors.red, size: 20)).toList(),
                ),
              ],
              if ((stats['recentTraining'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('最近5次訓練:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: (stats['recentTraining'] as List<bool>).map((attended) =>
                    Icon(attended ? Icons.check_circle : Icons.cancel,
                      color: attended ? Colors.green : Colors.red, size: 20)).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
  }

  void _editPlayer(int index) {
    final p          = _players[index];
    final nameCtrl   = TextEditingController(text: p['name']);
    final numberCtrl = TextEditingController(text: '${p['number']}');
    final heightCtrl = TextEditingController(text: '${p['height']}');
    final weightCtrl = TextEditingController(text: '${p['weight']}');
    String editPos   = p['position'] == '-' ? '' : p['position'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('編輯球員',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: nameCtrl,
                  style:       const TextStyle(color: Colors.white),
                  decoration:  _inputDeco('名稱')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller:   numberCtrl,
                        style:        const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration:   _inputDeco('號碼'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller:   heightCtrl,
                        style:        const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration:   _inputDeco('身高 (cm)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller:   weightCtrl,
                        style:        const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration:   _inputDeco('體重 (kg)'))),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _positions
                    .map((pos) => ChoiceChip(
                          label:         Text(pos),
                          selected:      editPos == pos,
                          selectedColor: Colors.orange,
                          onSelected: (s) =>
                              setDS(() => editPos = s ? pos : ''),
                        ))
                    .toList(),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消',
                    style: TextStyle(color: Colors.white70))),
            ElevatedButton(
              style:     ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                setState(() {
                  _players[index] = {
                    'name':     nameCtrl.text.trim(),
                    'number':   int.tryParse(numberCtrl.text) ?? 0,
                    'position': editPos.isEmpty ? '-' : editPos,
                    'height':   int.tryParse(heightCtrl.text) ?? 0,
                    'weight':   int.tryParse(weightCtrl.text) ?? 0,
                  };
                });
                _savePlayers();
                Navigator.pop(ctx);
                _showMessage('球員已更新');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MATCH METHODS
  // ============================================================

  Future<void> _selectMatchDate() async {
    final d = await showDatePicker(
        context:     context,
        initialDate: _selectedDate,
        firstDate:   DateTime(2020),
        lastDate:    DateTime(2030));
    if (d != null && mounted) setState(() => _selectedDate = d);
  }

  Future<void> _selectMatchTime() async {
    final t = await showTimePicker(
        context: context, initialTime: _selectedTime);
    if (t != null && mounted) setState(() => _selectedTime = t);
  }

  void _addMatch() {
    if (_opponentCtrl.text.isEmpty) {
      _showMessage('請輸入對手名稱', isError: true);
      return;
    }
    final attendance = <String, bool>{
      for (final p in _players) p['name'] as String: false
    };

    // Auto-select jersey color based on home/away
    Color? autoJerseyColor = _selectedJerseyColor;
    if (autoJerseyColor == null) {
      if (_isHome && widget.homeJerseyColor != null) {
        autoJerseyColor = _getJerseyColorFromName(widget.homeJerseyColor!);
      } else if (!_isHome && widget.awayJerseyColor != null) {
        autoJerseyColor = _getJerseyColorFromName(widget.awayJerseyColor!);
      }
    }

    setState(() {
      _matches.add({
        'date':        _fmtDate(_selectedDate),
        'time':        _fmtTime(_selectedTime),
        'venue':       _selectedVenue ?? (_venueCtrl.text.trim().isNotEmpty ? _venueCtrl.text.trim() : 'TBD'),
        'league':      _selectedLeague,
        'isHome':      _isHome,
        'jerseyColor': autoJerseyColor,
        'opponent':    _opponentCtrl.text.trim(),
        'scoreUs':     null,
        'scoreThem':   null,
        'attendance':  attendance,
      });
      _matches.sort((a, b) => b['date'].compareTo(a['date']));
    });
    _saveMatches();
    _opponentCtrl.clear();
    _showMessage('比賽已新增');
  }

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

  Color? _getJerseyColorFromName(String colorName) {
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
    return map[colorName];
  }

  Future<void> _deleteMatch(int index) async {
    if (!await _confirmDelete('vs ${_matches[index]['opponent']}')) return;
    setState(() => _matches.removeAt(index));
    _saveMatches();
    _showMessage('比賽已刪除');
  }

  void _editMatch(int index) {
    final match     = _matches[index];
    final oppCtrl   = TextEditingController(text: match['opponent']);
    final usCtrl    = TextEditingController(
        text: match['scoreUs']?.toString() ?? '');
    final themCtrl  = TextEditingController(
        text: match['scoreThem']?.toString() ?? '');

    DateTime editDate  = DateTime.tryParse(match['date']) ?? DateTime.now();
    final tp           = (match['time'] as String).split(':');
    TimeOfDay editTime = TimeOfDay(
        hour:   int.tryParse(tp[0]) ?? 20,
        minute: int.tryParse(tp.length > 1 ? tp[1] : '0') ?? 0);
    final allVenues = _venuesByDistrict.values.expand((v) => v).toList();
    final rawEditVenue     = match['venue'] == 'TBD' ? null : match['venue'] as String?;
    String?  editVenue     = allVenues.contains(rawEditVenue) ? rawEditVenue : null;
    final editVenueCtrl    = TextEditingController(
        text: rawEditVenue != null && !allVenues.contains(rawEditVenue) ? rawEditVenue : '');
    String   editLeague     = match['league'];
    bool     editIsHome     = match['isHome'];
    Color?   editJerseyColor = match['jerseyColor'];
    Map<String, bool> editAttendance = _deserializeAttendance(match['attendance']);
    for (final p in _players) {
      editAttendance.putIfAbsent(p['name'] as String, () => false);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('編輯比賽',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context:     ctx,
                        initialDate: editDate,
                        firstDate:   DateTime(2020),
                        lastDate:    DateTime(2030));
                    if (d != null) setDS(() => editDate = d);
                  },
                  icon:  const Icon(Icons.calendar_today),
                  label: Text(_fmtDate(editDate)),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                        context: ctx, initialTime: editTime);
                    if (t != null) setDS(() => editTime = t);
                  },
                  icon:  const Icon(Icons.access_time),
                  label: Text(_fmtTime(editTime)),
                )),
              ]),
              const SizedBox(height: 8),
              // 場地：下拉 + 手動輸入
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: editVenue,
                    decoration: _inputDeco('選擇場地'),
                    dropdownColor: const Color(0xFF1A1A2E),
                    items: _venuesByDistrict.entries.expand((entry) {
                      return [
                        DropdownMenuItem<String>(
                          enabled: false,
                          value: '___${entry.key}',
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(entry.key, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        ...entry.value.map((v) => DropdownMenuItem(
                          value: v,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(v, style: const TextStyle(color: Colors.white)),
                          ),
                        )),
                      ];
                    }).toList(),
                    onChanged: (v) {
                      editVenueCtrl.clear();
                      setDS(() => editVenue = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: editVenueCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('或手動輸入場地').copyWith(
                      prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.orange),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty) setDS(() => editVenue = null);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                  value:         editLeague,
                  decoration:    _inputDeco('聯賽'),
                  dropdownColor: const Color(0xFF1A1A2E),
                  items:         _leagues
                      .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(l,
                              style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) => setDS(() => editLeague = v ?? 'Happy Basketball League'),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: DropdownButtonFormField<bool>(
                  value:         editIsHome,
                  decoration:    _inputDeco('主/客'),
                  dropdownColor: const Color(0xFF1A1A2E),
                  items: const [
                    DropdownMenuItem(
                        value: true,
                        child:
                            Text('主場', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(
                        value: false,
                        child:
                            Text('作客', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setDS(() => editIsHome = v ?? true),
                )),
              ]),
              const SizedBox(height: 8),
              TextField(
                  controller: oppCtrl,
                  style:       const TextStyle(color: Colors.white),
                  decoration:  _inputDeco('對手')),
              const SizedBox(height: 12),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('比分',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13))),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller:   usCtrl,
                        style:        const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration:   _inputDeco('我方'))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child:   Text(':',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold))),
                Expanded(
                    child: TextField(
                        controller:   themCtrl,
                        style:        const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration:   _inputDeco('對方'))),
              ]),
              if (editAttendance.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('出席',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13))),
                ...editAttendance.keys.map((name) => CheckboxListTile(
                      dense:       true,
                      title:       Text(name,
                          style: const TextStyle(color: Colors.white)),
                      value:       editAttendance[name],
                      activeColor: Colors.orange,
                      checkColor:  Colors.white,
                      onChanged:   (v) =>
                          setDS(() => editAttendance[name] = v ?? false),
                    )),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消',
                    style: TextStyle(color: Colors.white70))),
            ElevatedButton(
              style:     ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                if (oppCtrl.text.isEmpty) return;
                final finalVenue = editVenue ??
                    (editVenueCtrl.text.trim().isNotEmpty ? editVenueCtrl.text.trim() : 'TBD');
                setState(() {
                  _matches[index] = {
                    'date':        _fmtDate(editDate),
                    'time':        _fmtTime(editTime),
                    'venue':       finalVenue,
                    'league':      editLeague,
                    'isHome':      editIsHome,
                    'jerseyColor': editJerseyColor,
                    'opponent':    oppCtrl.text.trim(),
                    'scoreUs':     int.tryParse(usCtrl.text),
                    'scoreThem':   int.tryParse(themCtrl.text),
                    'attendance':  editAttendance,
                  };
                  _matches.sort((a, b) => b['date'].compareTo(a['date']));
                });
                _saveMatches();
                Navigator.pop(ctx);
                _showMessage('比賽已更新');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TRAINING METHODS
  // ============================================================

  Future<void> _selectTrainingDate() async {
    final d = await showDatePicker(
        context:     context,
        initialDate: _trainingDate,
        firstDate:   DateTime(2020),
        lastDate:    DateTime(2030));
    if (d != null && mounted) setState(() => _trainingDate = d);
  }

  Future<void> _selectTrainingTime() async {
    final t = await showTimePicker(
        context: context, initialTime: _trainingTime);
    if (t != null && mounted) setState(() => _trainingTime = t);
  }

  void _addTraining() {
    if (_trainingTitleCtrl.text.isEmpty) {
      _showMessage('請輸入訓練主題', isError: true);
      return;
    }
    final attendance = <String, bool>{
      for (final p in _players) p['name'] as String: false
    };
    setState(() {
      _training.add({
        'title':      _trainingTitleCtrl.text.trim(),
        'date':       _fmtDate(_trainingDate),
        'time':       _fmtTime(_trainingTime),
        'venue':      _trainingVenue ?? (_trainingVenueCtrl.text.trim().isNotEmpty ? _trainingVenueCtrl.text.trim() : 'TBD'),
        'notes':      _trainingNotesCtrl.text.trim(),
        'attendance': attendance,
      });
      _training.sort((a, b) => b['date'].compareTo(a['date']));
    });
    _saveTraining();
    _trainingTitleCtrl.clear();
    _trainingNotesCtrl.clear();
    _showMessage('訓練已新增');
  }

  Future<void> _deleteTraining(int index) async {
    if (!await _confirmDelete(_training[index]['title'])) return;
    setState(() => _training.removeAt(index));
    _saveTraining();
    _showMessage('訓練已刪除');
  }

  void _editTraining(int index) {
    final t          = _training[index];
    final titleCtrl  = TextEditingController(text: t['title']);
    final notesCtrl  = TextEditingController(text: t['notes']);

    DateTime editDate  = DateTime.tryParse(t['date']) ?? DateTime.now();
    final tp           = (t['time'] as String).split(':');
    TimeOfDay editTime = TimeOfDay(
        hour:   int.tryParse(tp[0]) ?? 19,
        minute: int.tryParse(tp.length > 1 ? tp[1] : '0') ?? 0);
    final allVenues = _venuesByDistrict.values.expand((v) => v).toList();
    final rawTrainingVenue  = t['venue'] == 'TBD' ? null : t['venue'] as String?;
    String? editVenue       = allVenues.contains(rawTrainingVenue) ? rawTrainingVenue : null;
    final editTrainingVenueCtrl = TextEditingController(
        text: rawTrainingVenue != null && !allVenues.contains(rawTrainingVenue) ? rawTrainingVenue : '');
    Map<String, bool> editAttendance = _deserializeAttendance(t['attendance']);
    for (final p in _players) {
      editAttendance.putIfAbsent(p['name'] as String, () => false);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('編輯訓練',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: titleCtrl,
                  style:       const TextStyle(color: Colors.white),
                  decoration:  _inputDeco('主題')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context:     ctx,
                        initialDate: editDate,
                        firstDate:   DateTime(2020),
                        lastDate:    DateTime(2030));
                    if (d != null) setDS(() => editDate = d);
                  },
                  icon:  const Icon(Icons.calendar_today),
                  label: Text(_fmtDate(editDate)),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                        context: ctx, initialTime: editTime);
                    if (time != null) setDS(() => editTime = time);
                  },
                  icon:  const Icon(Icons.access_time),
                  label: Text(_fmtTime(editTime)),
                )),
              ]),
              const SizedBox(height: 8),
              // 場地：下拉 + 手動輸入
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: editVenue,
                    decoration: _inputDeco('選擇場地'),
                    dropdownColor: const Color(0xFF1A1A2E),
                    items: _venuesByDistrict.entries.expand((entry) {
                      return [
                        DropdownMenuItem<String>(
                          enabled: false,
                          value: '___${entry.key}',
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(entry.key, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        ...entry.value.map((v) => DropdownMenuItem(
                          value: v,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(v, style: const TextStyle(color: Colors.white)),
                          ),
                        )),
                      ];
                    }).toList(),
                    onChanged: (v) {
                      editTrainingVenueCtrl.clear();
                      setDS(() => editVenue = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: editTrainingVenueCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('或手動輸入場地').copyWith(
                      prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.orange),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty) setDS(() => editVenue = null);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: notesCtrl,
                  style:       const TextStyle(color: Colors.white),
                  maxLines:    3,
                  decoration:  _inputDeco('備註')),
              if (editAttendance.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('出席',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13))),
                ...editAttendance.keys.map((name) => CheckboxListTile(
                      dense:       true,
                      title:       Text(name,
                          style: const TextStyle(color: Colors.white)),
                      value:       editAttendance[name],
                      activeColor: Colors.orange,
                      checkColor:  Colors.white,
                      onChanged:   (v) =>
                          setDS(() => editAttendance[name] = v ?? false),
                    )),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消',
                    style: TextStyle(color: Colors.white70))),
            ElevatedButton(
              style:     ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                if (titleCtrl.text.isEmpty) return;
                final finalTrainingVenue = editVenue ??
                    (editTrainingVenueCtrl.text.trim().isNotEmpty ? editTrainingVenueCtrl.text.trim() : 'TBD');
                setState(() {
                  _training[index] = {
                    'title':      titleCtrl.text.trim(),
                    'date':       _fmtDate(editDate),
                    'time':       _fmtTime(editTime),
                    'venue':      finalTrainingVenue,
                    'notes':      notesCtrl.text.trim(),
                    'attendance': editAttendance,
                  };
                  _training.sort((a, b) => b['date'].compareTo(a['date']));
                });
                _saveTraining();
                Navigator.pop(ctx);
                _showMessage('訓練已更新');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UI BUILDERS
  // ============================================================

  Widget _buildPlayerTab() {
    final canEdit = !widget.isJoined || widget.userRole == 'editor';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (canEdit)
          Card(
            elevation: 2,
            color: const Color(0xFF1A1A2E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('新增球員',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  TextField(
                      controller: _nameCtrl,
                      style:       const TextStyle(color: Colors.white),
                      decoration:  _inputDeco('名稱')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller:   _numberCtrl,
                            style:        const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration:   _inputDeco('號碼'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller:   _heightCtrl,
                            style:        const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration:   _inputDeco('身高 (cm)'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller:   _weightCtrl,
                            style:        const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration:   _inputDeco('體重 (kg)'))),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _positions
                        .map((pos) => ChoiceChip(
                              label:         Text(pos),
                              selected:      _selectedPosition == pos,
                              selectedColor: Colors.orange,
                              onSelected: (s) => setState(
                                  () => _selectedPosition = s ? pos : ''),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addPlayer,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      child: const Text('新增'),
                    ),
                  ),
                ]),
          ),
        ),
        const SizedBox(height: 16),
        if (_players.isEmpty)
          _emptyState(Icons.people_outline, '未有球員',
              '在上方新增你的第一位球員')
        else
          ...List.generate(_players.length, (index) {
            final p        = _players[index];
            final pos      = (p['position'] ?? '-') as String;
            final posColor = _positionColor(pos);
            return Card(
              color:  const Color(0xFF1A1A2E),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // 位置顏色左邊條
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: posColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // 球衣號碼圓圈
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: posColor.withOpacity(0.12),
                                border: Border.all(color: posColor.withOpacity(0.5), width: 1.5),
                              ),
                              child: Center(
                                child: Text('${p['number']}',
                                  style: TextStyle(color: posColor,
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 名稱 + 身體數據
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(p['name'],
                                    style: const TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w600, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Text('${p['height']} cm · ${p['weight']} kg',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            // 位置 Badge
                            if (pos != '-') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: posColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: posColor.withOpacity(0.4)),
                                ),
                                child: Text(pos,
                                  style: TextStyle(color: posColor,
                                      fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                            ],
                            // 操作按鈕
                            IconButton(
                              icon: const Icon(Icons.bar_chart, color: Colors.orange, size: 18),
                              onPressed: () => _showPlayerStats(index),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                            if (canEdit) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
                                onPressed: () => _editPlayer(index),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                onPressed: () => _deletePlayer(index),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ]),
    );
  }

  Widget _buildMatchTab() {
    final canEdit = !widget.isJoined || widget.userRole == 'editor';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (canEdit)
          Card(
            elevation: 2,
            color: const Color(0xFF1A1A2E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('新增比賽',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _selectMatchDate,
                            icon:  const Icon(Icons.calendar_today),
                            label: Text(_fmtDate(_selectedDate)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _selectMatchTime,
                            icon:  const Icon(Icons.access_time),
                            label: Text(_fmtTime(_selectedTime)))),
                  ]),
                  const SizedBox(height: 8),
                  _buildVenuePicker(
                    selectedVenue: _selectedVenue,
                    venueCtrl:     _venueCtrl,
                    onChanged: (v) => setState(() => _selectedVenue = v),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      value:         _selectedLeague,
                      decoration:    _inputDeco('聯賽'),
                      dropdownColor: const Color(0xFF1A1A2E),
                      items:         _leagues
                          .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l,
                                  style: const TextStyle(
                                      color: Colors.white))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedLeague = v ?? 'Happy Basketball League'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: DropdownButtonFormField<bool>(
                      value:         _isHome,
                      decoration:    _inputDeco('主/客'),
                      dropdownColor: const Color(0xFF1A1A2E),
                      items: [
                        DropdownMenuItem(
                            value: true,
                            child: Row(children: [
                              const Text('主場', style: TextStyle(color: Colors.white)),
                              if (widget.homeJerseyColor != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getJerseyColor(widget.homeJerseyColor!),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                ),
                              ],
                            ])),
                        DropdownMenuItem(
                            value: false,
                            child: Row(children: [
                              const Text('作客', style: TextStyle(color: Colors.white)),
                              if (widget.awayJerseyColor != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getJerseyColor(widget.awayJerseyColor!),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                ),
                              ],
                            ])),
                      ],
                      onChanged: (v) => setState(() {
                        _isHome = v ?? true;
                        if (_isHome && widget.homeJerseyColor != null) {
                          _selectedJerseyColor = _getJerseyColorFromName(widget.homeJerseyColor!);
                        } else if (!_isHome && widget.awayJerseyColor != null) {
                          _selectedJerseyColor = _getJerseyColorFromName(widget.awayJerseyColor!);
                        }
                      }),
                    )),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _opponentCtrl,
                      style:       const TextStyle(color: Colors.white),
                      decoration:  _inputDeco('對手')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: _addMatch,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        child: const Text('新增')),
                  ),
                ]),
          ),
        ),
        const SizedBox(height: 16),
        if (_matches.isEmpty)
          _emptyState(Icons.sports_basketball_outlined, '未有比賽',
              '在上方新增你的第一場比賽')
        else
          ...List.generate(_matches.length, (index) {
            final m       = _matches[index];
            final isHome  = m['isHome'] as bool;
            final accent  = isHome ? Colors.green.shade600 : Colors.blue.shade400;
            final int? us   = m['scoreUs'] as int?;
            final int? them = m['scoreThem'] as int?;
            final hasScore  = us != null && them != null;

            return Card(
              color:  const Color(0xFF1A1A2E),
              margin: const EdgeInsets.only(bottom: 8),
              shape:  RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:         BorderSide(color: accent, width: 1.5),
              ),
              child: ListTile(
                leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: accent,
                        radius:          20,
                        child:           Text(_getLeagueAbbr(m['league']),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 2),
                      Text(isHome ? '主場' : '作客',
                          style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ]),
                title: Row(children: [
                  Expanded(
                      child: Text('vs ${m['opponent']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600))),
                  if (hasScore)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (us! > them!
                                ? Colors.green
                                : Colors.red)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$us - $them',
                          style: TextStyle(
                              color: us > them
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                ]),
                subtitle: Text(
                    '${m['date']} ${m['time']} @ ${m['venue']}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.blue),
                        onPressed: () async {
                          try {
                            final success = await CalendarService.addMatchToCalendar(
                              teamName: widget.teamName,
                              opponent: m['opponent'] as String,
                              dateTime: DateTime.parse('${m['date']} ${m['time']}'),
                              venue: m['venue'] as String,
                              league: m['league'] as String,
                              isHome: m['isHome'] == true,
                            );
                            if (mounted) {
                              _showMessage(success ? '已添加到日曆' : '已取消或不支持');
                            }
                          } catch (e) {
                            if (mounted) {
                              _showMessage('日期格式錯誤');
                            }
                          }
                        },
                      ),
                      if (canEdit) ...[
                        IconButton(
                            icon:      const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _editMatch(index)),
                        IconButton(
                            icon:      const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMatch(index)),
                      ],
                    ]),
              ),
            );
          }),
      ]),
    );
  }

  Widget _buildTrainingTab() {
    final canEdit = !widget.isJoined || widget.userRole == 'editor';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (canEdit)
          Card(
            elevation: 2,
            color: const Color(0xFF1A1A2E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('新增訓練',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  TextField(
                      controller: _trainingTitleCtrl,
                      style:       const TextStyle(color: Colors.white),
                      decoration:  _inputDeco('訓練主題')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _selectTrainingDate,
                            icon:  const Icon(Icons.calendar_today),
                            label: Text(_fmtDate(_trainingDate)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _selectTrainingTime,
                            icon:  const Icon(Icons.access_time),
                            label: Text(_fmtTime(_trainingTime)))),
                  ]),
                  const SizedBox(height: 8),
                  _buildVenuePicker(
                    selectedVenue: _trainingVenue,
                    venueCtrl:     _trainingVenueCtrl,
                    onChanged: (v) => setState(() => _trainingVenue = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _trainingNotesCtrl,
                      style:       const TextStyle(color: Colors.white),
                      maxLines:    3,
                      decoration:  _inputDeco('備註')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: _addTraining,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        child: const Text('新增')),
                  ),
                ]),
          ),
        ),
        const SizedBox(height: 16),
        if (_training.isEmpty)
          _emptyState(Icons.fitness_center, '未有訓練記錄',
              '在上方新增你的第一次訓練')
        else
          ...List.generate(_training.length, (index) {
            final t            = _training[index];
            final attendance   = t['attendance'] as Map? ?? {};
            final presentCount = attendance.values.where((v) => v == true).length;
            final totalCount   = attendance.length;
            final rate         = totalCount > 0 ? presentCount / totalCount : 0.0;
            final rateColor    = rate >= 0.8 ? Colors.green
                               : rate >= 0.5 ? Colors.orange
                               : Colors.red;

            return Card(
              color:  const Color(0xFF1A1A2E),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fitness_center, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t['title'],
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, color: Colors.blue, size: 18),
                          onPressed: () async {
                            try {
                              final success = await CalendarService.addTrainingToCalendar(
                                teamName: widget.teamName,
                                title: t['title'] as String,
                                dateTime: DateTime.parse('${t['date']} ${t['time']}'),
                                venue: t['venue'] as String,
                                notes: t['notes'] as String?,
                              );
                              if (mounted) {
                                _showMessage(success ? '已添加到日曆' : '已取消或不支持');
                              }
                            } catch (e) {
                              if (mounted) {
                                _showMessage('日期格式錯誤');
                              }
                            }
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                        if (canEdit) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
                            onPressed: () => _editTraining(index),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            onPressed: () => _deleteTraining(index),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 11, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text('${t['date']}  ${t['time']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 10),
                        const Icon(Icons.location_on, size: 11, color: Colors.white38),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(t['venue'],
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    // 備註
                    if (t['notes'] != null && (t['notes'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.note, size: 12, color: Colors.orange),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(t['notes'],
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // 出席進度條
                    if (totalCount > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rate,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('$presentCount / $totalCount',
                            style: TextStyle(color: rateColor,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ]),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1E),
        appBar: AppBar(
          title:           Text(widget.teamName),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: '照片相簿',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoGalleryPage(
                      teamName: widget.teamName,
                      inviteCode: widget.inviteCode,
                      ownerUid: widget.ownerUid,
                    ),
                  ),
                );
              },
            ),
            if (!widget.isJoined)
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: '匯出報表',
                onPressed: _exportReport,
              ),
            if (!widget.isJoined)
              IconButton(
                icon: const Icon(Icons.people),
                tooltip: '成員管理',
                onPressed: () {
                  if (widget.ownerUid == null || widget.inviteCode == null) {
                    _showMessage('無法載入球隊資料');
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamMembersPage(
                        ownerUid: widget.ownerUid!,
                        teamId: widget.inviteCode!,
                        isOwner: true,
                      ),
                    ),
                  );
                },
              ),
            if (!widget.isJoined)
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: '球隊設定',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamSettingsPage(
                        teamName: widget.teamName,
                        logoPath: widget.logoPath,
                        homeJerseyColor: widget.homeJerseyColor,
                        awayJerseyColor: widget.awayJerseyColor,
                        onSave: (name, logo, home, away) {
                          _showMessage('設定已保存，請返回球隊列表查看更新');
                        },
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              icon:    const Icon(Icons.cloud_sync),
              tooltip: '重新同步',
              onPressed: () async {
                await _loadFromCloud();
                _showMessage('雲端同步完成');
              },
            ),
          ],
          bottom: TabBar(
            labelColor:           Colors.orange,
            unselectedLabelColor: Colors.white70,
            indicatorColor:       Colors.orange,
            tabs: [
              Tab(
                  text: '球員 (${_players.length})',
                  icon: const Icon(Icons.people)),
              Tab(
                  text: '比賽 (${_matches.length})',
                  icon: const Icon(Icons.sports_basketball)),
              Tab(
                  text: '訓練 (${_training.length})',
                  icon: const Icon(Icons.fitness_center)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PlayersTab(
              teamName: widget.teamName,
              inviteCode: widget.inviteCode,
              ownerUid: widget.ownerUid,
              isJoined: widget.isJoined,
              userRole: widget.userRole,
            ),
            _buildMatchTab(),
            _buildTrainingTab(),
          ],
        ),
      ),
    );
  }
}
