import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'services/changelog_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _notificationService = NotificationService();
  bool _notificationsEnabled = true;
  int _notificationHours = 3;
  bool _isDarkMode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = await _notificationService.isEnabled();
    final timeStr = await _notificationService.getNotificationTime();
    int hours = 3;
    if (timeStr.contains('小時前')) {
      hours = int.tryParse(timeStr.replaceAll('小時前', '').trim()) ?? 3;
    }
    setState(() {
      _notificationsEnabled = enabled;
      _notificationHours = hours.clamp(1, 24);
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() => _isDarkMode = value);
  }

  Future<void> _toggleNotifications(bool value) async {
    await _notificationService.setEnabled(value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _changeNotificationHours(int hours) async {
    await _notificationService.setNotificationTime('$hours小時前');
    setState(() => _notificationHours = hours);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('設定', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.orange),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 主題設定
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      '深色主題',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: Text(
                      _isDarkMode ? '深色模式' : '淺色模式',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    value: _isDarkMode,
                    activeColor: Colors.white,
                    onChanged: _toggleTheme,
                  ),
                ),

                const SizedBox(height: 16),

                // 通知設定區塊
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // 通知開關
                      SwitchListTile(
                        title: const Text(
                          '比賽通知',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        subtitle: Text(
                          _notificationsEnabled ? '已開啟' : '已關閉',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        value: _notificationsEnabled,
                        activeColor: Colors.orange,
                        onChanged: _toggleNotifications,
                      ),

                      // 通知時間選擇
                      if (_notificationsEnabled) ...[
                        const Divider(color: Colors.white24, height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '比賽前 $_notificationHours 小時通知',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              Slider(
                                value: _notificationHours.toDouble(),
                                min: 1,
                                max: 24,
                                divisions: 23,
                                activeColor: Colors.orange,
                                inactiveColor: Colors.white24,
                                label: '$_notificationHours 小時',
                                onChanged: (v) => _changeNotificationHours(v.round()),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('1 小時', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  Text('24 小時', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 版本更新
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.new_releases, color: Colors.orange),
                    title: const Text('版本更新',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    subtitle: Text('v${ChangelogService.currentVersion}',
                        style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => ChangelogService.show(context, markAsSeen: false),
                  ),
                ),

                const SizedBox(height: 16),

                // 說明文字
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '提示：開啟通知後，系統會在設定的時間提醒你即將進行的比賽',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
