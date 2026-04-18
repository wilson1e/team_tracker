import 'package:flutter/material.dart';
import '../../../services/data/player_service.dart';
import '../../player_profile_page.dart';

/// 球員管理 Tab
/// 從 team_detail_page.dart 拆分出來
class PlayersTab extends StatefulWidget {
  final String teamName;
  final String? inviteCode;
  final String? ownerUid;
  final bool isJoined;
  final String? userRole;
  final ValueChanged<List<Map<String, dynamic>>>? onPlayersChanged;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> training;
  final List<Map<String, dynamic>> allTeams;
  final String? currentUserUid;

  const PlayersTab({
    super.key,
    required this.teamName,
    this.inviteCode,
    this.ownerUid,
    this.isJoined = false,
    this.userRole,
    this.onPlayersChanged,
    this.matches = const [],
    this.training = const [],
    this.allTeams = const [],
    this.currentUserUid,
  });

  @override
  State<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<PlayersTab> {
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  List<String> _selectedPositions = [];
  List<Map<String, dynamic>> _players = [];

  final List<String> _positions = ['PG', 'SG', 'SF', 'PF', 'C'];

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    final service = PlayerService(
      teamName: widget.teamName,
      inviteCode: widget.inviteCode,
      ownerUid: widget.ownerUid,
    );
    final players = await service.loadFromCloud();
    if (mounted) {
      setState(() => _players = players);
      widget.onPlayersChanged?.call(_players);
    }
  }

  Future<void> _savePlayers() async {
    final service = PlayerService(
      teamName: widget.teamName,
      inviteCode: widget.inviteCode,
      ownerUid: widget.ownerUid,
    );
    await service.syncToCloud(_players);
    widget.onPlayersChanged?.call(_players);
  }

  void _addPlayer() {
    if (_nameCtrl.text.isEmpty) {
      _showMessage('請輸入球員名稱', isError: true);
      return;
    }

    final number = int.tryParse(_numberCtrl.text) ?? 0;
    if (number < 0 || number > 99) {
      _showMessage('球衣號碼必須在 0-99 之間', isError: true);
      return;
    }

    setState(() {
      _players.add({
        'name': _nameCtrl.text.trim(),
        'number': number,
        'position': _selectedPositions.isEmpty ? '-' : _selectedPositions.join('/'),
        'height': int.tryParse(_heightCtrl.text) ?? 0,
        'weight': int.tryParse(_weightCtrl.text) ?? 0,
      });
      _selectedPositions = [];
    });

    _savePlayers();
    _nameCtrl.clear();
    _numberCtrl.clear();
    _heightCtrl.clear();
    _weightCtrl.clear();
    _showMessage('球員已新增');
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Color _positionColor(String pos) {
    final first = pos.split('/').first;
    switch (first) {
      case 'PG': return const Color(0xFF4FC3F7);
      case 'SG': return const Color(0xFF4DB6AC);
      case 'SF': return const Color(0xFF81C784);
      case 'PF': return const Color(0xFFFFB74D);
      case 'C': return const Color(0xFFCE93D8);
      default: return Colors.grey;
    }
  }

  void _editPlayer(int index) {
    final player = _players[index];
    final nameCtrl = TextEditingController(text: player['name'] as String? ?? '');
    final numberCtrl = TextEditingController(text: '${player['number'] ?? 0}');
    final heightCtrl = TextEditingController(text: '${player['height'] ?? 0}');
    final weightCtrl = TextEditingController(text: '${player['weight'] ?? 0}');
    final currentPos = (player['position'] as String? ?? '-');
    List<String> selectedPositions = currentPos == '-'
        ? []
        : currentPos.split('/').where((p) => p.isNotEmpty).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('編輯球員',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('名稱'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(
                          controller: numberCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: _inputDeco('號碼'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: heightCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: _inputDeco('身高 cm'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: weightCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: _inputDeco('體重 kg'),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: _positions.map((pos) => ChoiceChip(
                        label: Text(pos),
                        selected: selectedPositions.contains(pos),
                        selectedColor: Colors.orange,
                        onSelected: (s) => setDialogState(() {
                          if (s) {
                            selectedPositions.add(pos);
                          } else {
                            selectedPositions.remove(pos);
                          }
                        }),
                      )).toList(),
                    ),
                  ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('刪除球員', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeletePlayer(index);
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('請輸入球員名稱'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final number = int.tryParse(numberCtrl.text) ?? 0;
                    if (number < 0 || number > 99) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('球衣號碼必須在 0-99 之間'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _players[index] = {
                        'name': name,
                        'number': number,
                        'position': selectedPositions.isEmpty ? '-' : selectedPositions.join('/'),
                        'height': int.tryParse(heightCtrl.text) ?? 0,
                        'weight': int.tryParse(weightCtrl.text) ?? 0,
                      };
                    });
                    _savePlayers();
                    Navigator.pop(ctx);
                    _showMessage('球員資料已更新');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('儲存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlayer(int index) {
    final name = _players[index]['name'] ?? '此球員';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('刪除球員', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('確定要刪除「$name」？\n此操作不可撤銷。',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _players.removeAt(index));
              _savePlayers();
              Navigator.pop(ctx);
              _showMessage('$name 已刪除');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = !widget.isJoined || widget.userRole == 'editor';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canEdit) _buildAddPlayerForm(),
          const SizedBox(height: 16),
          if (_players.isEmpty)
            _buildEmptyState()
          else
            ..._players.asMap().entries.map((entry) =>
              _buildPlayerCard(entry.key, entry.value, canEdit: canEdit)
            ),
        ],
      ),
    );
  }

  Widget _buildAddPlayerForm() {
    return Card(
      elevation: 2,
      color: const Color(0xFF1A1A2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('新增球員',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('名稱'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: _numberCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('號碼'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _heightCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('身高 (cm)'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _weightCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('體重 (kg)'),
                )),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _positions.map((pos) => ChoiceChip(
                label: Text(pos),
                selected: _selectedPositions.contains(pos),
                selectedColor: Colors.orange,
                onSelected: (s) => setState(() {
                  if (s) { _selectedPositions.add(pos); } else { _selectedPositions.remove(pos); }
                }),
              )).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addPlayer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('新增'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text('未有球員', style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 6),
            Text('在上方新增你的第一位球員', style: const TextStyle(color: Colors.white30, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(int index, Map<String, dynamic> player, {bool canEdit = false}) {
    final pos = (player['position'] ?? '-') as String;
    final posColor = _positionColor(pos);

    final positionBadges = pos != '-' ? Wrap(
      spacing: 4,
      children: pos.split('/').map((p) {
        final c = _positionColor(p);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(p, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
        );
      }).toList(),
    ) : null;

    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: posColor.withValues(alpha:0.12),
            border: Border.all(color: posColor.withValues(alpha:0.5), width: 1.5),
          ),
          child: Center(
            child: Text('${player['number']}',
                style: TextStyle(color: posColor, fontWeight: FontWeight.bold)),
          ),
        ),
        title: Text(player['name'], style: const TextStyle(color: Colors.white)),
        subtitle: Text('${player['height']} cm · ${player['weight']} kg',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfilePage(
              playerName: player['name'],
              playerData: player,
              currentTeamName: widget.teamName,
              allTeams: widget.allTeams,
              currentUserUid: widget.currentUserUid,
            ),
          ),
        ),
        trailing: canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (positionBadges != null) positionBadges,
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                    tooltip: '編輯球員',
                    onPressed: () => _editPlayer(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              )
            : positionBadges,
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withValues(alpha:0.1),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.orange),
    ),
  );
}
