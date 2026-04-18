import 'package:flutter/material.dart';

/// 場地選擇器 - 支援關鍵字搜索 + 手動輸入
class VenuePicker extends StatefulWidget {
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
  State<VenuePicker> createState() => _VenuePickerState();
}

class _VenuePickerState extends State<VenuePicker> {
  void _openSearch() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _VenueSearchSheet(
        venuesByDistrict: widget.venuesByDistrict,
      ),
    );
    if (result != null) {
      widget.venueController.clear();
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.selectedVenue?.isNotEmpty == true
        ? widget.selectedVenue!
        : (widget.venueController.text.isNotEmpty
            ? widget.venueController.text
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索選擇按鈕
        GestureDetector(
          onTap: _openSearch,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayText ?? '搜索場地...',
                    style: TextStyle(
                      color: displayText != null ? Colors.white : Colors.white54,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white38),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 手動輸入
        TextField(
          controller: widget.venueController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco('或手動輸入場地').copyWith(
            prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.orange),
          ),
          onChanged: (v) {
            widget.onChanged(v.isNotEmpty ? v : null);
          },
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange),
        ),
      );
}

class _VenueSearchSheet extends StatefulWidget {
  final Map<String, List<String>> venuesByDistrict;
  const _VenueSearchSheet({required this.venuesByDistrict});

  @override
  State<_VenueSearchSheet> createState() => _VenueSearchSheetState();
}

class _VenueSearchSheetState extends State<_VenueSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _buildFiltered();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          // 頂部把手
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '輸入場地名稱...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          // 結果列表
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off,
                            color: Colors.white38, size: 48),
                        const SizedBox(height: 8),
                        const Text('無符合場地',
                            style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 4),
                        const Text('可關閉後手動輸入',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      if (item['isHeader'] == true) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            item['text'] as String,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        title: Text(
                          item['text'] as String,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () =>
                            Navigator.pop(context, item['text'] as String),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildFiltered() {
    final q = _query.toLowerCase();
    final result = <Map<String, dynamic>>[];
    for (final entry in widget.venuesByDistrict.entries) {
      final venues = q.isEmpty
          ? entry.value
          : entry.value
              .where((v) => v.toLowerCase().contains(q))
              .toList();
      if (venues.isEmpty) continue;
      result.add({'isHeader': true, 'text': entry.key});
      for (final v in venues) {
        result.add({'isHeader': false, 'text': v});
      }
    }
    return result;
  }
}
