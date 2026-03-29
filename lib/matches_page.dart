import 'package:flutter/material.dart';
import 'models/match.dart';
import 'constants.dart';

// 球衣颜色选项 (name to Color)
final Map<String, Color> jerseyColorMap = {
  '紅色': Colors.red,
  '藍色': Colors.blue,
  '綠色': Colors.green,
  '黃色': Colors.yellow,
  '白色': Colors.white,
  '黑色': Colors.black,
  '紫色': Colors.purple,
  '橙色': Colors.orange,
  '粉色': Colors.pink,
  '棕色': Colors.brown,
  '青色': Colors.cyan,
  '藍綠色': Colors.teal,
};

final jerseyColors = [
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.yellow,
  Colors.purple,
  Colors.orange,
  Colors.black,
  Colors.white,
  Colors.pink,
  Colors.brown,
  Colors.cyan,
  Colors.teal,
];

// 时间选项 (00:00 - 23:00)
final timeOptions = List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');

// Re-export from constants
final hkVenues = [
  '維多利亞公園', '九龍公園體育館', '修頓球場', '伊利沙伯體育館',
  '香港仔運動場', '小西灣運動場', '柴灣體育館', '渣華道體育館',
  '港島東體育館', '鰂魚涌公園', '北角渡輪碼頭體育館',
  '觀塘遊樂場', '藍田配水庫遊樂場', '秀茂坪體育館', '牛頭角道遊樂場',
  '九龍灣體育館', '彩虹道體育館', '牛池灣體育館', '坪石遊樂場',
  '黃大仙摩士公園', '鑽石山體育館', '斧山道運動場', '樂富體育館',
  '土瓜灣體育館', '紅磡市政大廈體育館', '何文田體育館', '愛民體育館',
  '旺角大球場', '花墟公園', '深水埗運動場', '石硤尾公園體育館',
  '長沙灣體育館', '荔枝角公園體育館', '麗閣體育館', '歌和老街體育館',
  '界限街體育館', '九龍仔公園', '順利邨體育館', '順天體育館',
  '大埔運動場', '大埔體育館', '太和體育館', '富亨體育館',
  '沙田體育館', '源禾路體育館', '馬鞍山體育館', '顯徑體育館',
  '瀝源體育館', '禾輋體育館', '圓洲角體育館', '小瀝源路遊樂場',
  '屯門體育館', '屯門西北體育館', '友愛體育館', '蝴蝶灣體育館',
  '元朗體育館', '天水圍體育館', '天暉路體育館', '朗屏體育館',
  '荃灣體育館', '蕙荃體育館', '城門谷體育館', '楊屋道體育館',
  '葵涌運動場', '葵盛體育館', '林士德體育館', '北葵涌鄧肇堅體育館',
  '青衣體育館', '青衣西南體育館', '長青體育館', '青衣公園',
  '西貢體育館', '將軍澳體育館', '調景嶺體育館', '坑口體育館',
  '北區公園體育館', '粉嶺遊樂場', '上水體育館', '和興體育館',
  '東涌文東路體育館', '東涌體育館', '離島體育館',
];
final leagues = AppConstants.leagues;
final homeAwayOptions = AppConstants.homeAwayOptions;

class MatchesPage extends StatefulWidget {
  final List<Match> matches;
  final Function(List<Match>) onSave;
  final String? homeJerseyColor;
  final String? awayJerseyColor;
  
  const MatchesPage({super.key, required this.matches, required this.onSave, this.homeJerseyColor, this.awayJerseyColor});

  @override State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  late List<Match> _matches;
  
  @override
  void initState() {
    super.initState();
    _matches = List.from(widget.matches);
  }
  
  void _saveMatches() {
    widget.onSave(_matches);
  }

  void _addMatch() {
    _showMatchDialog(null, null);
  }

  void _editMatch(int index) {
    _showMatchDialog(index, _matches[index]);
  }

  void _deleteMatch(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('刪除比賽', style: TextStyle(color: Colors.white)),
        content: const Text('確定要刪除這場比賽嗎？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _matches.removeAt(index);
              });
              _saveMatches();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(int? index, Match? match) {
    final isEdit = index != null;
    final existingMatch = match; // Local reference for type narrowing
    
    DateTime selectedDate = isEdit && existingMatch != null
        ? DateTime.tryParse(existingMatch.date) ?? DateTime.now()
        : DateTime.now();
    String selectedTime = isEdit && existingMatch != null ? existingMatch.time : '20:00';
    String? selectedVenue = isEdit && existingMatch != null && hkVenues.contains(existingMatch.location) ? existingMatch.location : null;
    String customVenue = isEdit && existingMatch != null && !hkVenues.contains(existingMatch.location) ? existingMatch.location : '';
    String? selectedLeague = isEdit && existingMatch != null ? existingMatch.league : null;
    String? selectedHomeAway = isEdit && existingMatch != null ? existingMatch.homeAway : null;
    Color? selectedJerseyColor = isEdit && existingMatch != null ? existingMatch.jerseyColor : null;
    final opponentCtrl = TextEditingController(text: isEdit && existingMatch != null ? existingMatch.opponent : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(isEdit ? '編輯比賽' : '添加比賽', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日期选择
                ListTile(
                  title: Text(
                    '日期: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: Colors.orange),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.orange,
                            surface: Color(0xFF1A1A2E),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 8),
                
                // 时间选择
                Row(
                  children: [
                    const Text('時間: ', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: DropdownButton<String>(
                        value: timeOptions.contains(selectedTime) ? selectedTime : null,
                        dropdownColor: const Color(0xFF1A1A2E),
                        hint: const Text('選擇時間', style: TextStyle(color: Colors.white70)),
                        items: timeOptions.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(color: Colors.white)),
                        )).toList(),
                        onChanged: (v) => setDialogState(() => selectedTime = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 手动输入时间
                TextField(
                  controller: TextEditingController(text: timeOptions.contains(selectedTime) ? '' : selectedTime),
                  decoration: const InputDecoration(
                    labelText: '或輸入時間 (如 19:30)',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && !timeOptions.contains(v)) {
                      selectedTime = v;
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // 地点选择
                Row(
                  children: [
                    const Text('地點: ', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedVenue,
                        dropdownColor: const Color(0xFF1A1A2E),
                        hint: const Text('選擇球場', style: TextStyle(color: Colors.white70)),
                        items: hkVenues.map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, style: const TextStyle(color: Colors.white)),
                        )).toList(),
                        onChanged: (v) => setDialogState(() {
                          selectedVenue = v;
                          customVenue = '';
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 手动输入地点
                TextField(
                  controller: TextEditingController(text: customVenue),
                  decoration: const InputDecoration(
                    labelText: '或輸入地點',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) {
                    customVenue = v;
                    if (v.isNotEmpty) {
                      selectedVenue = null;
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // 联赛选择
                Row(
                  children: [
                    const Text('聯賽: ', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedLeague,
                        dropdownColor: const Color(0xFF1A1A2E),
                        hint: const Text('選擇聯賽', style: TextStyle(color: Colors.white70)),
                        items: leagues.map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(l, style: const TextStyle(color: Colors.white)),
                        )).toList(),
                        onChanged: (v) => setDialogState(() => selectedLeague = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 主/客选择
                Row(
                  children: [
                    const Text('主/客: ', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedHomeAway,
                        dropdownColor: const Color(0xFF1A1A2E),
                        hint: const Text('選擇', style: TextStyle(color: Colors.white70)),
                        items: homeAwayOptions.map((h) => DropdownMenuItem(
                          value: h,
                          child: Text(h, style: const TextStyle(color: Colors.white)),
                        )).toList(),
                        onChanged: (v) => setDialogState(() {
                          selectedHomeAway = v;
                          // Auto-select jersey color based on home/away
                          if (v == '主場' && widget.homeJerseyColor != null) {
                            selectedJerseyColor = jerseyColorMap[widget.homeJerseyColor];
                          } else if (v == '作客' && widget.awayJerseyColor != null) {
                            selectedJerseyColor = jerseyColorMap[widget.awayJerseyColor];
                          }
                          if (v == null) selectedJerseyColor = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 球衣颜色选择 (如果选择了主/客)
                if (selectedHomeAway != null) ...[
                  const Text('球衣顏色: ', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: jerseyColors.map((color) {
                      final isSelected = selectedJerseyColor?.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedJerseyColor = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(
                              color: isSelected ? Colors.orange : Colors.grey,
                              width: isSelected ? 3 : 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: color == Colors.white || color == Colors.yellow ? Colors.black : Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 对手
                TextField(
                  controller: opponentCtrl,
                  decoration: const InputDecoration(
                    labelText: '對手',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                final location = selectedVenue ?? customVenue;
                
                if (location.isEmpty || selectedLeague == null || 
                    selectedHomeAway == null || opponentCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請填寫所有必填項目')),
                  );
                  return;
                }
                
                final newMatch = Match(
                  date: dateStr,
                  time: selectedTime,
                  location: location,
                  league: selectedLeague!,
                  homeAway: selectedHomeAway!,
                  opponent: opponentCtrl.text,
                  jerseyColor: selectedJerseyColor,
                );
                
                final editIndex = isEdit ? index : null;
                
                setState(() {
                  if (editIndex != null) {
                    _matches[editIndex] = newMatch;
                  } else {
                    _matches.add(newMatch);
                  }
                });
                _saveMatches();
                Navigator.pop(ctx);
              },
              child: Text(isEdit ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_basketball, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text('暂无比賽', style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addMatch,
              icon: const Icon(Icons.add),
              label: const Text('添加比賽'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF16213E)),
            dataRowColor: WidgetStateProperty.all(const Color(0xFF1A1A2E)),
            columns: const [
              DataColumn(label: Text('日期', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('時間', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('地點', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('聯賽', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('主/客', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('對手', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('操作', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
            ],
            rows: _matches.asMap().entries.map((entry) {
              final index = entry.key;
              final match = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text(match.date, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(match.time, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(match.location, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(match.league, style: const TextStyle(color: Colors.white))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(match.homeAway, style: const TextStyle(color: Colors.white)),
                        if (match.jerseyColor != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: match.jerseyColor,
                              border: Border.all(color: Colors.white, width: 1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  DataCell(Text(match.opponent, style: const TextStyle(color: Colors.white))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _editMatch(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteMatch(index),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMatch,
        backgroundColor: Colors.orange.shade800,
        child: const Icon(Icons.add),
      ),
    );
  }
}