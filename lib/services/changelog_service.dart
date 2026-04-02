import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangelogEntry {
  final IconData icon;
  final Color color;
  final String text;
  const ChangelogEntry(this.icon, this.color, this.text);
}

class ChangelogService {
  static const _seenKey = 'changelog_seen_version';

  // ── 每次更新版本時修改這裡 ──────────────────────────────────────
  static const String currentVersion = '1.0.0+8';

  static const List<ChangelogEntry> entries = [
    ChangelogEntry(Icons.bug_report,    Color(0xFF4CAF50), '修復 iOS 啟動黑屏問題'),
    ChangelogEntry(Icons.label,         Color(0xFF2196F3), '修正 Android App 顯示名稱'),
    ChangelogEntry(Icons.info_outline,  Colors.orange,     '登入頁右下角顯示版本號'),
    ChangelogEntry(Icons.note_add,      Colors.orange,     '比賽記錄新增備註欄'),
    ChangelogEntry(Icons.lock_outline,  Colors.white54,    '匯出報表功能將於正式版開放'),
  ];
  // ────────────────────────────────────────────────────────────────

  /// Returns true if the changelog should be shown (not yet seen for this version).
  static Future<bool> shouldShow() async {
    final info  = await PackageInfo.fromPlatform();
    final ver   = '${info.version}+${info.buildNumber}';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_seenKey) != ver;
  }

  /// Mark the current version's changelog as seen.
  static Future<void> markSeen() async {
    final info  = await PackageInfo.fromPlatform();
    final ver   = '${info.version}+${info.buildNumber}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKey, ver);
  }

  /// Show the changelog dialog. Marks as seen automatically.
  static Future<void> show(BuildContext context, {bool markAsSeen = true}) async {
    if (markAsSeen) await markSeen();
    if (!context.mounted) return;

    final info    = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.new_releases, color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '版本更新  v$version',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(e.icon, color: e.color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.text,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ]),
            )).toList(),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
