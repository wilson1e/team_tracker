import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMembersPage extends StatefulWidget {
  final String ownerUid;
  final String teamId;
  final bool isOwner;

  const TeamMembersPage({
    super.key,
    required this.ownerUid,
    required this.teamId,
    required this.isOwner,
  });

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  Widget _buildMemberCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? '';
    final role = data['role'] ?? 'viewer';

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: widget.isOwner
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onSelected: (value) => _handleAction(value, doc.id, role),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'toggle', child: Text(role == 'viewer' ? '設為編輯者' : '設為查看者')),
                  const PopupMenuItem(value: 'remove', child: Text('移除成員', style: TextStyle(color: Colors.red))),
                ],
              )
            : Chip(
                label: Text(role == 'editor' ? '編輯者' : '查看者', style: const TextStyle(fontSize: 11)),
                backgroundColor: role == 'editor' ? Colors.orange : Colors.grey,
              ),
      ),
    );
  }

  Future<void> _handleAction(String action, String memberUid, String currentRole) async {
    if (action == 'toggle') {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ownerUid)
          .collection('teams')
          .doc(widget.teamId)
          .collection('members')
          .doc(memberUid)
          .update({'role': currentRole == 'viewer' ? 'editor' : 'viewer'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新角色')));
      }
    } else if (action == 'remove') {
      // 刪除成員記錄
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ownerUid)
          .collection('teams')
          .doc(widget.teamId)
          .collection('members')
          .doc(memberUid)
          .delete();

      // 刪除被移除成員本地的球隊記錄
      await FirebaseFirestore.instance
          .collection('users')
          .doc(memberUid)
          .collection('myTeams')
          .doc(widget.teamId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移除成員')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text('成員管理'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.ownerUid)
            .collection('teams')
            .doc(widget.teamId)
            .collection('members')
            .orderBy('joinedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('錯誤: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          final members = snapshot.data!.docs;
          if (members.isEmpty) {
            return const Center(child: Text('暫無成員', style: TextStyle(color: Colors.white70)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) => _buildMemberCard(members[index]),
          );
        },
      ),
    );
  }

}