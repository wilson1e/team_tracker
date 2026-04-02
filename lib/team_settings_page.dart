import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TeamSettingsPage extends StatefulWidget {
  final String teamName;
  final String? logoPath;
  final String? homeJerseyColor;
  final String? awayJerseyColor;
  final Function(String name, String? logo, String? home, String? away) onSave;

  const TeamSettingsPage({
    super.key,
    required this.teamName,
    this.logoPath,
    this.homeJerseyColor,
    this.awayJerseyColor,
    required this.onSave,
  });

  @override
  State<TeamSettingsPage> createState() => _TeamSettingsPageState();
}

class _TeamSettingsPageState extends State<TeamSettingsPage> {
  late TextEditingController _nameCtrl;
  String? _selectedLogoPath;
  String? _selectedHomeJersey;
  String? _selectedAwayJersey;
  final ImagePicker _picker = ImagePicker();

  static const _jerseyColorNames = [
    '紅色', '藍色', '綠色', '黃色', '白色', '黑色', '紫色', '橙色',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.teamName);
    _selectedLogoPath = widget.logoPath;
    _selectedHomeJersey = widget.homeJerseyColor;
    _selectedAwayJersey = widget.awayJerseyColor;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color _getJerseyColor(String colorName) {
    const map = {
      '紅色': Colors.red, '藍色': Colors.blue, '綠色': Colors.green,
      '黃色': Colors.yellow, '白色': Colors.white, '黑色': Colors.black,
      '紫色': Colors.purple, '橙色': Colors.orange,
    };
    return map[colorName] ?? Colors.grey;
  }

  Widget _buildJerseyPicker({
    required String label,
    required String? selected,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _jerseyColorNames.map((color) {
            final isSelected = selected == color;
            return GestureDetector(
              onTap: () => setState(() => onChanged(isSelected ? null : color)),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _getJerseyColor(color),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey,
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text('球隊設定'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '球隊名稱',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha:0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('球隊標誌', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.orange,
                  backgroundImage: _selectedLogoPath != null && File(_selectedLogoPath!).existsSync()
                      ? FileImage(File(_selectedLogoPath!))
                      : null,
                  child: _selectedLogoPath == null
                      ? const Icon(Icons.group, color: Colors.white, size: 40)
                      : null,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() => _selectedLogoPath = image.path);
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(_selectedLogoPath != null ? '更換圖片' : '選擇標誌'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildJerseyPicker(
              label: '主場球衣顏色',
              selected: _selectedHomeJersey,
              onChanged: (c) => _selectedHomeJersey = c,
            ),
            const SizedBox(height: 24),
            _buildJerseyPicker(
              label: '作客球衣顏色',
              selected: _selectedAwayJersey,
              onChanged: (c) => _selectedAwayJersey = c,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請輸入球隊名稱')),
                    );
                    return;
                  }
                  widget.onSave(
                    _nameCtrl.text.trim(),
                    _selectedLogoPath,
                    _selectedHomeJersey,
                    _selectedAwayJersey,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
