import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/user_plan_service.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      setState(() {
        _users = snap.docs.map((d) {
          final data = d.data();
          return {
            'uid': d.id,
            'email': data['email'] ?? '',
            'name': data['name'] ?? '',
            'isBetaTester': data['isBetaTester'] ?? false,
            'maxTeams': data['maxTeams'],
            'plan': data['plan'] ?? 'free',
          };
        }).toList();
        _users.sort((a, b) =>
            (a['name'] as String).compareTo(b['name'] as String));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> updates) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
    final idx = _users.indexWhere((u) => u['uid'] == uid);
    if (idx != -1) {
      setState(() => _users[idx] = {..._users[idx], ...updates});
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) {
      return (u['name'] as String).toLowerCase().contains(q) ||
          (u['email'] as String).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('Admin 管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: '用戶列表'),
            Tab(icon: Icon(Icons.bar_chart), text: '統計'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(),
                _buildStats(),
              ],
            ),
    );
  }

  Widget _buildUserList() {
    final users = _filteredUsers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '搜索姓名或 email…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? const Center(
                  child: Text('沒有找到用戶', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) => _buildUserCard(users[i]),
                ),
        ),
      ],
    );
  }

  Color _planColor(String plan) {
    if (plan == 'pro') return Colors.amber;
    if (plan == 'standard') return Colors.orange;
    return Colors.white54;
  }

  String _planLabel(String plan) {
    if (plan == 'pro') return '專業版';
    if (plan == 'standard') return '標準版';
    return '免費版';
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final uid = user['uid'] as String;
    final isBeta = user['isBetaTester'] as bool;
    final maxTeams = user['maxTeams'] as int?;
    final plan = user['plan'] as String? ?? 'free';
    final maxCtrl = TextEditingController(
      text: maxTeams != null ? maxTeams.toString() : '',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 姓名 + email
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isBeta
                      ? Colors.orange.withAlpha(60)
                      : Colors.white12,
                  child: Text(
                    (user['name'] as String).isNotEmpty
                        ? (user['name'] as String)[0]
                        : '?',
                    style: TextStyle(
                      color: isBeta ? Colors.orange : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] as String,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        user['email'] as String,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isBeta)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange, width: 0.5),
                    ),
                    child: const Text('Beta',
                        style: TextStyle(color: Colors.orange, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Beta Tester Toggle
            Row(
              children: [
                const Text('Beta Tester',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: isBeta,
                  activeColor: Colors.orange,
                  onChanged: (val) => _updateUser(uid, {'isBetaTester': val}),
                ),
              ],
            ),
            // 訂閱等級
            Row(
              children: [
                const Text('訂閱等級',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                DropdownButton<String>(
                  value: plan,
                  dropdownColor: const Color(0xFF1A1A2E),
                  underline: const SizedBox(),
                  items: ['free', 'standard', 'pro'].map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(
                        _planLabel(p),
                        style: TextStyle(color: _planColor(p), fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _updateUser(uid, {'plan': val});
                  },
                ),
              ],
            ),
            // 球隊上限覆蓋
            Row(
              children: [
                const Text('球隊上限',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 8),
                const Text('(空=依等級)',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const Spacer(),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      filled: true,
                      fillColor: const Color(0xFF0F0F1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    onSubmitted: (val) {
                      final n = int.tryParse(val);
                      _updateUser(uid, {'maxTeams': n});
                    },
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    final n = int.tryParse(maxCtrl.text);
                    _updateUser(uid, {'maxTeams': n});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('已更新'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Text('儲存',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final betaCount =
        _users.where((u) => u['isBetaTester'] == true).length;
    final freeCount = _users
        .where((u) =>
            (u['plan'] ?? 'free') == 'free' && u['isBetaTester'] != true)
        .length;
    final standardCount = _users
        .where((u) =>
            (u['plan'] ?? 'free') == 'standard' || u['isBetaTester'] == true)
        .length;
    final proCount =
        _users.where((u) => (u['plan'] ?? 'free') == 'pro').length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _statCard('總用戶數', _users.length.toString(), Icons.people,
              Colors.blue),
          const SizedBox(height: 12),
          _statCard('Beta Tester', betaCount.toString(), Icons.star,
              Colors.orange),
          const SizedBox(height: 12),
          _statCard('免費版', freeCount.toString(), Icons.person,
              Colors.white54),
          const SizedBox(height: 12),
          _statCard('標準版', standardCount.toString(), Icons.workspace_premium,
              Colors.orange),
          const SizedBox(height: 12),
          _statCard('專業版', proCount.toString(), Icons.diamond,
              Colors.amber),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
