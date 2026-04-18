import 'package:flutter/material.dart';
import '../../services/data/cross_team_service.dart';
import 'player_attendance_all_teams_page.dart';

class PlayerProfilePage extends StatefulWidget {
  final String playerName;
  final Map<String, dynamic> playerData; // number, position, height, weight
  final String currentTeamName;
  final List<Map<String, dynamic>> allTeams;
  final String? currentUserUid;

  const PlayerProfilePage({
    super.key,
    required this.playerName,
    required this.playerData,
    required this.currentTeamName,
    required this.allTeams,
    this.currentUserUid,
  });

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  late final Future<CrossTeamPlayerData> _future;

  @override
  void initState() {
    super.initState();
    _future = CrossTeamService(
      playerName: widget.playerName,
      allTeams: widget.allTeams,
    ).fetchPlayerData();
  }

  Color _positionColor(String pos) {
    final first = pos.split('/').first;
    switch (first) {
      case 'PG': return const Color(0xFF4FC3F7);
      case 'SG': return const Color(0xFF4DB6AC);
      case 'SF': return const Color(0xFF81C784);
      case 'PF': return const Color(0xFFFFB74D);
      case 'C':  return const Color(0xFFCE93D8);
      default:   return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(widget.playerName,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.orange),
      ),
      body: FutureBuilder<CrossTeamPlayerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('無法載入資料\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return _buildBody(data);
        },
      ),
    );
  }

  Widget _buildBody(CrossTeamPlayerData data) {
    final pos = (widget.playerData['position'] ?? '-') as String;
    final number = widget.playerData['number'] ?? 0;
    final height = widget.playerData['height'] ?? 0;
    final weight = widget.playerData['weight'] ?? 0;

    final upcoming = data.schedule.where((s) => !s.isPast).toList();
    final past = data.schedule.where((s) => s.isPast).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ① 球員基本資料 Header
        _buildHeaderCard(pos, number, height, weight),
        const SizedBox(height: 12),

        // ② 所屬隊伍 chips
        if (data.teamsWithPlayer.isNotEmpty) ...[
          _buildTeamsSection(data.teamsWithPlayer),
          const SizedBox(height: 12),
        ],

        // ③ 出席率摘要
        _buildAttendanceSummaryCard(data),
        const SizedBox(height: 16),

        // ④ 即將到來的日程
        if (upcoming.isNotEmpty) ...[
          _buildSubheader('即將到來', Icons.schedule),
          const SizedBox(height: 8),
          ...upcoming.map((item) => _buildScheduleTile(item)),
          const SizedBox(height: 16),
        ],

        // ⑤ 過去記錄（最近 10 項）
        _buildSubheader('過去記錄', Icons.history),
        const SizedBox(height: 8),
        if (past.isEmpty)
          _buildEmptyHint('未有過去記錄')
        else
          ...past.take(10).map((item) => _buildScheduleTile(item)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeaderCard(String pos, dynamic number, dynamic height, dynamic weight) {
    final posColor = _positionColor(pos);
    final positions = pos != '-' ? pos.split('/') : <String>[];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 號碼圓圈
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: posColor.withValues(alpha: 0.12),
              border: Border.all(color: posColor.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: Text('$number',
                  style: TextStyle(
                      color: posColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.playerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (positions.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: positions.map((p) {
                      final c = _positionColor(p);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p,
                            style: TextStyle(
                                color: c,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 6),
                Text('$height cm · $weight kg',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsSection(List<Map<String, dynamic>> teams) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.groups, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('所屬球隊',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: teams.map((t) {
              final name = t['teamName'] as String? ?? '';
              final isJoined = t['isJoined'] == true;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_basketball,
                        color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummaryCard(CrossTeamPlayerData data) {
    final overallRate = data.overallRate;
    final color = overallRate >= 0.8
        ? Colors.green
        : overallRate >= 0.6
            ? Colors.orange
            : overallRate > 0
                ? Colors.red
                : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text('出席統計',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              // 查看詳細出席記錄按鈕
              if (data.totalEvents > 0)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerAttendanceAllTeamsPage(
                        playerName: widget.playerName,
                        playerData: data,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('詳細記錄',
                          style: TextStyle(color: Colors.orange, fontSize: 12)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, color: Colors.orange, size: 16),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.totalEvents == 0)
            const Text('尚無出席記錄',
                style: TextStyle(color: Colors.white38, fontSize: 13))
          else ...[
            Text('總出席率 ${(overallRate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: overallRate,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statChip(
                    '比賽 ${data.matchAttended}/${data.matchTotal}',
                    data.matchRate,
                    Colors.blue),
                const SizedBox(width: 16),
                _statChip(
                    '訓練 ${data.trainingAttended}/${data.trainingTotal}',
                    data.trainingRate,
                    Colors.purple),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, double rate, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label (${(rate * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSubheader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 16),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildScheduleTile(ScheduleItem item) {
    final isMatch = item.type == 'match';
    final typeColor = isMatch ? Colors.blue : Colors.purple;
    final typeIcon = isMatch ? Icons.sports_basketball : Icons.fitness_center;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(
          item.attended ? Icons.check_circle : Icons.cancel,
          color: item.attended ? Colors.green : Colors.red,
          size: 22,
        ),
        title: Text(item.label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text('${item.date}  ${item.time}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.teamName,
                    style: const TextStyle(color: Colors.orange, fontSize: 10)),
              ),
            ],
          ),
        ),
        trailing: Icon(typeIcon, color: typeColor.withValues(alpha: 0.7), size: 20),
      ),
    );
  }

  Widget _buildEmptyHint(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(msg,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ),
    );
  }
}
