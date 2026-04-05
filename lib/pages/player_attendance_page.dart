import 'package:flutter/material.dart';

class PlayerAttendancePage extends StatelessWidget {
  final String playerName;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> training;

  const PlayerAttendancePage({
    super.key,
    required this.playerName,
    required this.matches,
    required this.training,
  });

  Map<String, dynamic> _calcStats() {
    int matchTotal = 0, matchAttended = 0;
    int trainingTotal = 0, trainingAttended = 0;
    final List<Map<String, dynamic>> recentMatches = [];
    final List<Map<String, dynamic>> recentTraining = [];

    for (var m in matches) {
      final att = m['attendance'] as Map?;
      if (att != null && att.containsKey(playerName)) {
        matchTotal++;
        final attended = att[playerName] == true;
        if (attended) matchAttended++;
        if (recentMatches.length < 10) {
          recentMatches.add({
            'date': m['date'] ?? '',
            'label': 'vs ${m['opponent'] ?? ''}',
            'attended': attended,
          });
        }
      }
    }

    for (var t in training) {
      final att = t['attendance'] as Map?;
      if (att != null && att.containsKey(playerName)) {
        trainingTotal++;
        final attended = att[playerName] == true;
        if (attended) trainingAttended++;
        if (recentTraining.length < 10) {
          recentTraining.add({
            'date': t['date'] ?? '',
            'label': t['title'] ?? '訓練',
            'attended': attended,
          });
        }
      }
    }

    final total = matchTotal + trainingTotal;
    final totalAttended = matchAttended + trainingAttended;

    return {
      'matchTotal': matchTotal,
      'matchAttended': matchAttended,
      'matchRate': matchTotal > 0 ? matchAttended / matchTotal : 0.0,
      'trainingTotal': trainingTotal,
      'trainingAttended': trainingAttended,
      'trainingRate': trainingTotal > 0 ? trainingAttended / trainingTotal : 0.0,
      'overallRate': total > 0 ? totalAttended / total : 0.0,
      'recentMatches': recentMatches,
      'recentTraining': recentTraining,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calcStats();
    final overallRate = stats['overallRate'] as double;
    final matchRate = stats['matchRate'] as double;
    final trainingRate = stats['trainingRate'] as double;
    final matchAttended = stats['matchAttended'] as int;
    final matchTotal = stats['matchTotal'] as int;
    final trainingAttended = stats['trainingAttended'] as int;
    final trainingTotal = stats['trainingTotal'] as int;
    final recentMatches = stats['recentMatches'] as List<Map<String, dynamic>>;
    final recentTraining = stats['recentTraining'] as List<Map<String, dynamic>>;

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
          _buildSummaryCard(overallRate, matchRate, trainingRate),
          const SizedBox(height: 16),
          _buildSection(
            title: '比賽出席 ($matchAttended/$matchTotal)',
            icon: Icons.sports_basketball,
            records: recentMatches,
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: '訓練出席 ($trainingAttended/$trainingTotal)',
            icon: Icons.fitness_center,
            records: recentTraining,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double overall, double match, double training) {
    final pct = (overall * 100).toStringAsFixed(1);
    final color = overall >= 0.8
        ? Colors.green
        : overall >= 0.6
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('總出席率 $pct%',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip('比賽', match, Colors.blue),
              const SizedBox(width: 12),
              _statChip('訓練', training, Colors.purple),
            ],
          ),
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
        Text('$label ${(rate * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> records,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('未有記錄', style: TextStyle(color: Colors.white38)),
            )
          else
            ...records.map((r) => _buildRecord(r)),
        ],
      ),
    );
  }

  Widget _buildRecord(Map<String, dynamic> r) {
    final attended = r['attended'] as bool;
    return ListTile(
      dense: true,
      leading: Icon(
        attended ? Icons.check_circle : Icons.cancel,
        color: attended ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(r['label'] as String,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: Text(r['date'] as String,
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
    );
  }
}
