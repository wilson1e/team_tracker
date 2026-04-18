import 'package:cloud_firestore/cloud_firestore.dart';

/// 代表統一時間線上的一個日程項目（比賽或訓練）
class ScheduleItem {
  final String teamName;
  final String type; // 'match' | 'training'
  final String date;
  final String time;
  final String label; // 'vs 對手' or 訓練標題
  final String? venue;
  final bool attended;
  final bool isPast;

  const ScheduleItem({
    required this.teamName,
    required this.type,
    required this.date,
    required this.time,
    required this.label,
    this.venue,
    required this.attended,
    required this.isPast,
  });
}

/// 跨隊球員資料
class CrossTeamPlayerData {
  /// 球員所屬的隊伍（包含在哪隊找到的球員資料）
  final List<Map<String, dynamic>> teamsWithPlayer;

  /// 統一排序的日程（即將到來在前，過去記錄在後）
  final List<ScheduleItem> schedule;

  /// 整體統計
  final int totalEvents;
  final int attendedEvents;
  final int matchTotal;
  final int matchAttended;
  final int trainingTotal;
  final int trainingAttended;

  double get overallRate => totalEvents > 0 ? attendedEvents / totalEvents : 0.0;
  double get matchRate => matchTotal > 0 ? matchAttended / matchTotal : 0.0;
  double get trainingRate => trainingTotal > 0 ? trainingAttended / trainingTotal : 0.0;

  const CrossTeamPlayerData({
    required this.teamsWithPlayer,
    required this.schedule,
    required this.totalEvents,
    required this.attendedEvents,
    required this.matchTotal,
    required this.matchAttended,
    required this.trainingTotal,
    required this.trainingAttended,
  });
}

/// 跨隊資料抓取服務
///
/// 輸入：球員名稱 + 用戶的所有隊伍列表
/// 1. 並行抓取所有隊伍的球員名單，篩出包含該球員的隊伍
/// 2. 對命中的隊伍並行抓取比賽和訓練資料
/// 3. 合併並按日期排序
class CrossTeamService {
  final String playerName;
  final List<Map<String, dynamic>> allTeams;

  const CrossTeamService({
    required this.playerName,
    required this.allTeams,
  });

  Future<CrossTeamPlayerData> fetchPlayerData() async {
    if (allTeams.isEmpty) {
      return const CrossTeamPlayerData(
        teamsWithPlayer: [],
        schedule: [],
        totalEvents: 0,
        attendedEvents: 0,
        matchTotal: 0,
        matchAttended: 0,
        trainingTotal: 0,
        trainingAttended: 0,
      );
    }

    // 1. 並行抓取所有隊伍的球員名單
    final teamChecks = await Future.wait(
      allTeams.map((team) => _checkPlayerInTeam(team)),
    );

    // 篩出包含該球員的隊伍
    final teamsWithPlayer = <Map<String, dynamic>>[];
    final hitTeams = <Map<String, dynamic>>[];
    for (int i = 0; i < allTeams.length; i++) {
      if (teamChecks[i] != null) {
        teamsWithPlayer.add(teamChecks[i]!);
        hitTeams.add(allTeams[i]);
      }
    }

    if (hitTeams.isEmpty) {
      return const CrossTeamPlayerData(
        teamsWithPlayer: [],
        schedule: [],
        totalEvents: 0,
        attendedEvents: 0,
        matchTotal: 0,
        matchAttended: 0,
        trainingTotal: 0,
        trainingAttended: 0,
      );
    }

    // 2. 並行抓取命中隊伍的比賽和訓練
    final scheduleResults = await Future.wait(
      hitTeams.map((team) => _fetchTeamSchedule(team)),
    );

    // 3. 合併所有日程
    final allItems = <ScheduleItem>[];
    int matchTotal = 0, matchAttended = 0;
    int trainingTotal = 0, trainingAttended = 0;

    for (final items in scheduleResults) {
      for (final item in items) {
        allItems.add(item);
        if (item.type == 'match') {
          matchTotal++;
          if (item.attended) matchAttended++;
        } else {
          trainingTotal++;
          if (item.attended) trainingAttended++;
        }
      }
    }

    // 4. 排序：即將到來（今日及以後，升序）在前，過去（降序）在後
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final upcoming = allItems.where((i) => !i.isPast).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = allItems.where((i) => i.isPast).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return CrossTeamPlayerData(
      teamsWithPlayer: teamsWithPlayer,
      schedule: [...upcoming, ...past],
      totalEvents: matchTotal + trainingTotal,
      attendedEvents: matchAttended + trainingAttended,
      matchTotal: matchTotal,
      matchAttended: matchAttended,
      trainingTotal: trainingTotal,
      trainingAttended: trainingAttended,
    );
  }

  /// 檢查球員是否在該隊，如有則回傳隊伍資料（含球員資訊），否則回傳 null
  Future<Map<String, dynamic>?> _checkPlayerInTeam(Map<String, dynamic> team) async {
    try {
      final ownerUid = team['ownerUid'] as String?;
      final inviteCode = team['inviteCode'] as String?;
      if (ownerUid == null || inviteCode == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('teams')
          .doc(inviteCode)
          .collection('players')
          .doc('data')
          .get();

      if (!doc.exists) return null;

      final players = doc.data()?['players'] as List?;
      if (players == null) return null;

      // 找到同名球員
      final match = players.cast<Map>().where((p) => p['name'] == playerName).toList();
      if (match.isEmpty) return null;

      return {
        'teamName': team['name'],
        'inviteCode': inviteCode,
        'ownerUid': ownerUid,
        'isJoined': team['isJoined'] ?? false,
        'playerData': Map<String, dynamic>.from(match.first),
      };
    } catch (e) {
      // 單隊失敗不影響其他隊伍
      return null;
    }
  }

  /// 抓取某隊的比賽和訓練，過濾出有該球員出席記錄的項目
  Future<List<ScheduleItem>> _fetchTeamSchedule(Map<String, dynamic> team) async {
    try {
      final ownerUid = team['ownerUid'] as String?;
      final inviteCode = team['inviteCode'] as String?;
      final teamName = team['name'] as String? ?? '';
      if (ownerUid == null || inviteCode == null) return [];

      final teamRef = FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('teams')
          .doc(inviteCode);

      // 並行抓比賽和訓練
      final results = await Future.wait([
        teamRef.collection('matches').doc('data').get(),
        teamRef.collection('training').doc('data').get(),
      ]);

      final matchesDoc = results[0];
      final trainingDoc = results[1];

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final items = <ScheduleItem>[];

      // 處理比賽
      if (matchesDoc.exists) {
        final matches = matchesDoc.data()?['matches'] as List? ?? [];
        for (final m in matches) {
          final att = m['attendance'] as Map?;
          if (att == null || !att.containsKey(playerName)) continue;
          final date = (m['date'] ?? '') as String;
          items.add(ScheduleItem(
            teamName: teamName,
            type: 'match',
            date: date,
            time: (m['time'] ?? '') as String,
            label: 'vs ${m['opponent'] ?? ''}',
            venue: m['venue'] as String? ?? m['location'] as String?,
            attended: att[playerName] == true,
            isPast: date.compareTo(todayStr) < 0,
          ));
        }
      }

      // 處理訓練
      if (trainingDoc.exists) {
        final training = trainingDoc.data()?['training'] as List? ?? [];
        for (final t in training) {
          final att = t['attendance'] as Map?;
          if (att == null || !att.containsKey(playerName)) continue;
          final date = (t['date'] ?? '') as String;
          items.add(ScheduleItem(
            teamName: teamName,
            type: 'training',
            date: date,
            time: (t['time'] ?? '') as String,
            label: (t['title'] ?? '訓練') as String,
            venue: t['venue'] as String?,
            attended: att[playerName] == true,
            isPast: date.compareTo(todayStr) < 0,
          ));
        }
      }

      return items;
    } catch (e) {
      return [];
    }
  }
}
