import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _notificationService = NotificationService();
  bool _notificationsEnabled = true;
  String _notificationTime = '09:00';
  bool _isDarkMode = true;
  bool _isLoading = true;

  final _timeOptions = [
    '09:00',
    '3小時前',
    '1小時前',
    '30分鐘前',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = await _notificationService.isEnabled();
    final time = await _notificationService.getNotificationTime();
    setState(() {
      _notificationsEnabled = enabled;
      _notificationTime = time;
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

  Future<void> _changeNotificationTime(String? value) async {
    if (value == null) return;
    await _notificationService.setNotificationTime(value);
    setState(() => _notificationTime = value);
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
                        ListTile(
                          title: const Text(
                            '通知時間',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          trailing: DropdownButton<String>(
                            value: _timeOptions.contains(_notificationTime) ? _notificationTime : _timeOptions.first,
                            dropdownColor: const Color(0xFF1A1A2E),
                            style: const TextStyle(color: Colors.white),
                            underline: Container(),
                            items: _timeOptions.map((time) {
                              return DropdownMenuItem(
                                value: time,
                                child: Text(time),
                              );
                            }).toList(),
                            onChanged: _changeNotificationTime,
                          ),
                        ),
                      ],
                    ],
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
