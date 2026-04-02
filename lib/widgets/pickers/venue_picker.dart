import 'package:flutter/material.dart';

/// 場地選擇器 - 共用元件
/// 支援下拉選單 + 手動輸入
class VenuePicker extends StatelessWidget {
  final String? selectedVenue;
  final TextEditingController venueController;
  final ValueChanged<String?> onChanged;
  final Map<String, List<String>> venuesByDistrict;

  const VenuePicker({
    super.key,
    required this.selectedVenue,
    required this.venueController,
    required this.onChanged,
    required this.venuesByDistrict,
  });

  @override
  Widget build(BuildContext context) {
    final allVenues = venuesByDistrict.values.expand((v) => v).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 下拉選單
        DropdownButtonFormField<String>(
          value: allVenues.contains(selectedVenue) ? selectedVenue : null,
          decoration: _inputDeco('選擇場地'),
          dropdownColor: const Color(0xFF1A1A2E),
          items: _buildDropdownItems(),
          onChanged: (v) {
            venueController.clear();
            onChanged(v);
          },
        ),
        const SizedBox(height: 8),
        // 手動輸入
        TextField(
          controller: venueController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco('或手動輸入場地').copyWith(
            prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.orange),
          ),
          onChanged: (v) {
            if (v.isNotEmpty) {
              onChanged(v);
            } else {
              onChanged(null);
            }
          },
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    return venuesByDistrict.entries.expand((entry) {
      return [
        // 地區標題
        DropdownMenuItem<String>(
          enabled: false,
          value: '___${entry.key}',
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              entry.key,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        // 場地列表
        ...entry.value.map((venue) => DropdownMenuItem(
          value: venue,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(venue, style: const TextStyle(color: Colors.white)),
          ),
        )),
      ];
    }).toList();
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
