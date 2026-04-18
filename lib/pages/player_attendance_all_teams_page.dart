import 'package:flutter/material.dart';
import '../../services/data/cross_team_service.dart';

/// 跨隊出席詳細頁
/// 從 PlayerProfilePage 點擊「詳細記錄」進入
/// 按隊伍分 section 顯示出席率與每場記錄
class PlayerAttendanceAllTeamsPage extends StatelessWidget {
  final String playerName;
  final CrossTeamPlayerData playerData;

  const PlayerAttendanceAllTeamsPage({
    super.key,
    required this.playerName,
    required this.playerData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text('$playerName 出席記錄',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.orange),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 整體統計摘要
          _buildOverallSummary(),
          const SizedBox(height: 16),

          // 每隊的出席詳情
          ...playerData.teamsWithPlayer.map((team) {
            final teamName = team['teamName'] as String? ?? '';
            return _buildTeamSection(teamName);
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOverallSummary() {
    final overall = playerData.overallRate;
    final color = overall >= 0.8
        ? Colors.green
        : overall >= 0.6
            ? Colors.orange
            : overall > 0
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
            children: const [
              Icon(Icons.assessment, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('整體統計',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          if (playerData.totalEvents == 0)
            const Text('尚無出席記錄',
                style: TextStyle(color: Colors.white38))
          else ...[
            Text('總出席率 ${(overall * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: overall,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _summaryTile(
                    icon: Icons.sports_basketball,
                    iconColor: Colors.blue,
                    label: '比賽',
                    attended: playerData.matchAttended,
                    total: playerData.matchTotal,
                    rate: playerData.matchRate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryTile(
                    icon: Icons.fitness_center,
                    iconColor: Colors.purple,
                    label: '訓練',
                    attended: playerData.trainingAttended,
                    total: playerData.trainingTotal,
                    rate: playerData.trainingRate,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int attended,
    required int total,
    required double rate,
  }) {
    final rateColor = rate >= 0.8
        ? Colors.green
        : rate >= 0.6
            ? Colors.orange
            : rate > 0
                ? Colors.red
                : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text('$attended / $total',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${(rate * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: rateColor, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTeamSection(String teamName) {
    // 篩出屬於該隊的日程
    final teamItems = playerData.schedule
        .where((s) => s.teamName == teamName)
        .toList();

    final matches = teamItems.where((s) => s.type == 'match').toList();
    final trainings = teamItems.where((s) => s.type == 'training').toList();

    final matchAttended = matches.where((s) => s.attended).length;
    final trainingAttended = trainings.where((s) => s.attended).length;
    final totalAttended = matchAttended + trainingAttended;
    final total = teamItems.length;
    final rate = total > 0 ? totalAttended / total : 0.0;

    final rateColor = rate >= 0.8
        ? Colors.green
        : rate >= 0.6
            ? Colors.orange
            : rate > 0
                ? Colors.red
                : Colors.white38;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 隊伍標題 + 出席率
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.sports_basketball,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(teamName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (total > 0)
                    Text('${(rate * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: rateColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // 小進度條
            if (total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                  ),
                ),
              ),

            const Divider(color: Colors.white12, height: 1),

            // 比賽記錄
            if (matches.isNotEmpty) ...[
              _buildTypeHeader(
                  '比賽 $matchAttended/${matches.length}',
                  Icons.sports_basketball,
                  Colors.blue),
              ...matches.map((item) => _buildRecordTile(item)),
            ],

            // 訓練記錄
            if (trainings.isNotEmpty) ...[
              if (matches.isNotEmpty)
                const Divider(color: Colors.white12, height: 1),
              _buildTypeHeader(
                  '訓練 $trainingAttended/${trainings.length}',
                  Icons.fitness_center,
                  Colors.purple),
              ...trainings.map((item) => _buildRecordTile(item)),
            ],

            if (teamItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('未有出席記錄',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRecordTile(ScheduleItem item) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        item.attended ? Icons.check_circle : Icons.cancel,
        color: item.attended ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(item.label,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: item.venue != null && item.venue!.isNotEmpty
          ? Text(item.venue!,
              style: const TextStyle(color: Colors.white38, fontSize: 11))
          : null,
      trailing: Text('${item.date}  ${item.time}',
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    );
  }
}
