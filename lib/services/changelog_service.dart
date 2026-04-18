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
  static const String currentVersion = '1.0.0+19';

  static const List<ChangelogEntry> entries = [
    ChangelogEntry(Icons.shopping_cart, Colors.orange,            'App Store 內購正式啟用：訂閱標準版／專業版及球隊擴展包，可於設定 → 訂閱方案直接購買'),
    ChangelogEntry(Icons.search,           Colors.orange,            '場地關鍵字搜索：比賽、訓練及日常練習的場地選擇改為搜索面板，即時過濾並保留地區分組'),
    ChangelogEntry(Icons.lock_reset,       Colors.blue,              '忘記密碼：登入頁加入「忘記密碼？」按鈕，輸入 Email 即可收到重設密碼郵件'),
    ChangelogEntry(Icons.calendar_month,   Colors.green,             '一鍵新增日常練習：選擇星期幾及月份，自動新增當月所有對應日期的訓練記錄'),
    ChangelogEntry(Icons.list_alt,         Colors.green,             '訓練細項：可為每次訓練新增射球、跑步、自訂項目，記錄每名球員成績及達標率'),
    ChangelogEntry(Icons.login,            Colors.orange,            '登入頁面記住密碼：勾選後下次自動填入 Email 及密碼'),
    ChangelogEntry(Icons.edit,             Colors.blue,              '球隊設定按鈕移至球隊列表卡片編輯，內部頁面更簡潔'),
    ChangelogEntry(Icons.dark_mode,        Colors.white70,           '介面固定深色主題，移除主題切換選項'),
    ChangelogEntry(Icons.menu,             Colors.orange,             '左側選單：加入球隊、設定、重新整理、登出'),
    ChangelogEntry(Icons.event_available,  Color(0xFF4CAF50), '球員出席記錄頁面：點擊球員查看最近比賽及訓練出席率'),
    ChangelogEntry(Icons.tune,             Colors.orange,     '通知時間改為滑桿自選（1-24小時前）'),
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
