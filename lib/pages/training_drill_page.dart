import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Drill type constants ─────────────────────────────────────────────────────
const _kShooting = 'shooting';
const _kRunning  = 'running';
const _kCustom   = 'custom';

// ── TrainingDrillPage ────────────────────────────────────────────────────────
class TrainingDrillPage extends StatefulWidget {
  final Map<String, dynamic> training;
  final List<Map<String, dynamic>> players;
  final bool canEdit;
  final bool isAdmin;
  final bool canCustom;
  final void Function(Map<String, dynamic>)? onChanged;

  const TrainingDrillPage({
    super.key,
    required this.training,
    required this.players,
    required this.canEdit,
    required this.isAdmin,
    this.canCustom = false,
    this.onChanged,
  });

  @override
  State<TrainingDrillPage> createState() => _TrainingDrillPageState();
}

class _TrainingDrillPageState extends State<TrainingDrillPage> {
  late List<Map<String, dynamic>> _drillItems;

  // Cache TextEditingControllers keyed by "drillIndex_playerName"
  final Map<String, TextEditingController> _madeCtrlCache = {};

  TextEditingController _madeCtrl(int drillIndex, String name, Map<String, dynamic> result) {
    final key = '${drillIndex}_$name';
    if (!_madeCtrlCache.containsKey(key)) {
      final text = result['made']?.toString() ?? '';
      _madeCtrlCache[key] = TextEditingController(text: text)
        ..selection = TextSelection.collapsed(offset: text.length);
    }
    return _madeCtrlCache[key]!;
  }

  // Current logged-in user's display name (for player-view filter)
  final String? _currentUserName =
      FirebaseAuth.instance.currentUser?.displayName;

  // ── New drill form ───────────────────────────────────────────────────────
  String _newType = _kShooting;
  final _labelCtrl       = TextEditingController();
  final _targetMadeCtrl  = TextEditingController();
  final _targetTotalCtrl = TextEditingController();
  final _targetSecsCtrl  = TextEditingController();
  final _targetNoteCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Deep-copy drill_items from training
    final raw = widget.training['drill_items'];
    if (raw is List) {
      _drillItems = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      _drillItems = [];
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _targetMadeCtrl.dispose();
    _targetTotalCtrl.dispose();
    _targetSecsCtrl.dispose();
    _targetNoteCtrl.dispose();
    for (final c in _madeCtrlCache.values) c.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildUpdatedTraining() {
    final updated = Map<String, dynamic>.from(widget.training);
    updated['drill_items'] = _drillItems;
    return updated;
  }

  void _pop() => Navigator.pop(context, _buildUpdatedTraining());

  String _uid() => 'drill_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

  // Which players are visible — only those marked present in attendance
  List<Map<String, dynamic>> get _visiblePlayers {
    final attendance = widget.training['attendance'] as Map? ?? {};
    final presentPlayers = widget.players
        .where((p) => attendance[p['name'] as String] == true)
        .toList();

    // Non-editors only see themselves (if present)
    if (!widget.canEdit && !widget.isAdmin) {
      return presentPlayers
          .where((p) => p['name'] == _currentUserName)
          .toList();
    }
    return presentPlayers;
  }

  // ── Pass/fail calculation ─────────────────────────────────────────────────

  bool _calcPass(Map<String, dynamic> drill, Map<String, dynamic> result) {
    switch (drill['type'] as String) {
      case _kShooting:
        final made  = (result['made']  as num?)?.toDouble() ?? 0;
        final total = (result['total'] as num?)?.toDouble() ?? 0;
        final tMade  = (drill['target_made']  as num?)?.toDouble() ?? 0;
        final tTotal = (drill['target_total'] as num?)?.toDouble() ?? 1;
        if (total == 0) return false;
        return (made / total) >= (tMade / tTotal);
      case _kRunning:
        // Running uses direct pass/fail from checkbox, not time calculation
        return result['pass'] == true;
      case _kCustom:
      default:
        return result['pass'] == true;
    }
  }

  // ── Add drill ─────────────────────────────────────────────────────────────

  void _addDrill() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      _showMsg('請輸入項目名稱', isError: true);
      return;
    }

    if (_newType == _kCustom && !widget.canCustom) {
      _showMsg('自訂訓練項目需要升級訂閱', isError: true);
      return;
    }

    Map<String, dynamic> drill = {
      'id':    _uid(),
      'type':  _newType,
      'label': label,
      'player_results': <String, dynamic>{},
    };

    if (_newType == _kShooting) {
      final made  = int.tryParse(_targetMadeCtrl.text.trim())  ?? 0;
      final total = int.tryParse(_targetTotalCtrl.text.trim()) ?? 0;
      if (total == 0) { _showMsg('請輸入目標總數', isError: true); return; }
      drill['target_made']  = made;
      drill['target_total'] = total;
    } else if (_newType == _kRunning) {
      final secs = int.tryParse(_targetSecsCtrl.text.trim()) ?? 0;
      if (secs == 0) { _showMsg('請輸入目標秒數', isError: true); return; }
      drill['target_seconds'] = secs;
    } else {
      drill['target_note'] = _targetNoteCtrl.text.trim();
    }

    setState(() => _drillItems.add(drill));
    _labelCtrl.clear();
    _targetMadeCtrl.clear();
    _targetTotalCtrl.clear();
    _targetSecsCtrl.clear();
    _targetNoteCtrl.clear();
    _showMsg('項目已新增');
  }

  void _deleteDrill(int index) {
    setState(() => _drillItems.removeAt(index));
  }

  // ── Update player result ──────────────────────────────────────────────────

  void _updatePlayerResult(int drillIndex, String playerName, Map<String, dynamic> result) {
    setState(() {
      final drill = Map<String, dynamic>.from(_drillItems[drillIndex]);
      final results = Map<String, dynamic>.from(
          (drill['player_results'] as Map? ?? {}));
      final merged = Map<String, dynamic>.from(result);
      merged['pass'] = _calcPass(drill, merged);
      results[playerName] = merged;
      drill['player_results'] = results;
      _drillItems[drillIndex] = drill;
    });
    // Immediately notify parent to save
    widget.onChanged?.call(_buildUpdatedTraining());
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  String _typeLabel(String type) {
    switch (type) {
      case _kShooting: return '射波';
      case _kRunning:  return '跑步';
      case _kCustom:   return '自訂';
      default:         return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case _kShooting: return Colors.orange;
      case _kRunning:  return Colors.blue;
      case _kCustom:   return Colors.purple;
      default:         return Colors.grey;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.training['title'] ?? '訓練細項',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              Text('${widget.training['date']}  ${widget.training['time']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _pop,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drill items list ─────────────────────────────────────────
              if (_drillItems.isEmpty)
                _emptyState()
              else ...[
                ..._drillItems.asMap().entries.map((e) =>
                    _buildDrillCard(e.key, e.value)),
                const SizedBox(height: 8),
                // Summary cards: one per 5 drills
                ...List.generate(
                  ((_drillItems.length - 1) ~/ 5) + 1,
                  (page) => _buildSummary(page),
                ),
              ],

              const SizedBox(height: 20),

              // ── Add drill form (editor only) ─────────────────────────────
              if (widget.canEdit || widget.isAdmin)
                _buildAddDrillForm(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Training summary ─────────────────────────────────────────────────────

  Widget _buildSummary(int page) {
    final players = _visiblePlayers;
    final allDrills = _drillItems;
    if (players.isEmpty || allDrills.isEmpty) return const SizedBox.shrink();

    // Slice 5 drills per page
    final start  = page * 5;
    final end    = (start + 5).clamp(0, allDrills.length);
    final drills = allDrills.sublist(start, end);
    final pageLabel = allDrills.length > 5
        ? '訓練總結（${start + 1}–$end）'
        : '訓練總結';

    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.bar_chart, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(pageLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            // Header row
            Row(children: [
              const SizedBox(width: 80),
              ...drills.map((d) => Expanded(
                child: Text(
                  d['label'] as String? ?? '',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              )),
            ]),
            const Divider(color: Colors.white12, height: 10),
            // Per-player rows
            ...players.map((p) {
              final name   = p['name'] as String;
              final number = p['number']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      number.isNotEmpty ? '#$number $name' : name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  ...drills.map((d) {
                    final results = Map<String, dynamic>.from(
                        d['player_results'] as Map? ?? {});
                    final r    = results[name] as Map?;
                    final pass = r?['pass'] as bool?;
                    return Expanded(
                      child: Center(
                        child: pass == null
                            ? const Text('-',
                                style: TextStyle(color: Colors.white24, fontSize: 12))
                            : Icon(
                                pass ? Icons.check_circle : Icons.cancel,
                                size: 16,
                                color: pass ? Colors.green : Colors.red),
                      ),
                    );
                  }),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _emptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      Icon(Icons.list_alt, size: 48, color: Colors.white.withValues(alpha: 0.2)),
      const SizedBox(height: 12),
      const Text('尚未新增訓練項目', style: TextStyle(color: Colors.white54, fontSize: 15)),
      if (widget.canEdit || widget.isAdmin) ...[
        const SizedBox(height: 6),
        const Text('在下方新增射球、跑步或自訂項目',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    ]),
  );

  // ── Drill card ────────────────────────────────────────────────────────────

  Widget _buildDrillCard(int index, Map<String, dynamic> drill) {
    final type    = drill['type'] as String? ?? _kCustom;
    final label   = drill['label'] as String? ?? '';
    final results = Map<String, dynamic>.from(drill['player_results'] as Map? ?? {});
    final visible = _visiblePlayers;

    // Overall pass rate
    final passCount = visible.where((p) {
      final r = results[p['name'] as String];
      return r != null && r['pass'] == true;
    }).length;
    final totalWithData = visible.where((p) =>
        results.containsKey(p['name'] as String)).length;

    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor(type).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_typeLabel(type),
                    style: TextStyle(color: _typeColor(type), fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              // Pass rate badge
              if (totalWithData > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (passCount == totalWithData ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('達標 $passCount/$totalWithData',
                      style: TextStyle(
                          color: passCount == totalWithData ? Colors.green : Colors.orange,
                          fontSize: 11)),
                ),
              if (widget.canEdit || widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _deleteDrill(index),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
            ]),

            // Target description
            const SizedBox(height: 6),
            _buildTargetDesc(drill),

            const Divider(color: Colors.white12, height: 20),

            // Per-player input rows
            ...visible.map((p) => _buildPlayerRow(index, drill, p, results)),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetDesc(Map<String, dynamic> drill) {
    final type = drill['type'] as String? ?? _kCustom;
    String desc;
    switch (type) {
      case _kShooting:
        desc = '目標：${drill['target_made']}/${drill['target_total']} 達標';
        break;
      case _kRunning:
        desc = '目標：${drill['target_seconds']} 秒內完成';
        break;
      case _kCustom:
      default:
        final note = drill['target_note'] as String? ?? '';
        desc = note.isNotEmpty ? '目標：$note' : '自訂達標標準';
    }
    return Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12));
  }

  // ── Per-player row ────────────────────────────────────────────────────────

  Widget _buildPlayerRow(
      int drillIndex,
      Map<String, dynamic> drill,
      Map<String, dynamic> player,
      Map<String, dynamic> allResults) {
    final name   = player['name'] as String;
    final number = player['number']?.toString() ?? '';
    final result = Map<String, dynamic>.from(
        (allResults[name] as Map?)?.cast<String, dynamic>() ?? {});
    final type   = drill['type'] as String? ?? _kCustom;
    final canInput = widget.canEdit || widget.isAdmin;

    Widget inputWidget;
    switch (type) {
      case _kShooting:
        inputWidget = _shootingInput(drillIndex, drill, name, result, canInput);
        break;
      case _kRunning:
        inputWidget = _runningInput(drillIndex, drill, name, result, canInput);
        break;
      case _kCustom:
      default:
        inputWidget = _customInput(drillIndex, drill, name, result, canInput);
    }

    final pass = result['pass'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Player name + number
          SizedBox(
            width: 80,
            child: Row(children: [
              if (number.isNotEmpty)
                Text('#$number ',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Flexible(
                child: Text(name,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(child: inputWidget),
          const SizedBox(width: 8),
          // Pass/fail indicator
          if (pass != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (pass == true ? Colors.green : Colors.red)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(pass == true ? '達標' : '未達',
                  style: TextStyle(
                      color: pass == true ? Colors.green : Colors.red,
                      fontSize: 11)),
            )
          else
            const SizedBox(width: 38),
        ],
      ),
    );
  }

  // ── Shooting input ────────────────────────────────────────────────────────

  Widget _shootingInput(int drillIndex, Map<String, dynamic> drill,
      String name, Map<String, dynamic> result, bool canInput) {
    // Total is fixed from drill target — no need to re-enter
    final targetTotal = (drill['target_total'] as num?)?.toInt() ?? 0;
    final madeCtrl = _madeCtrl(drillIndex, name, result);

    if (!canInput) {
      final made  = result['made']  ?? '-';
      final total = result['total'] ?? targetTotal;
      final pct   = (result['made'] != null && targetTotal > 0)
          ? '${((result['made'] as num) / targetTotal * 100).toStringAsFixed(0)}%'
          : '';
      return Text('$made / $total  $pct',
          style: const TextStyle(color: Colors.white, fontSize: 13));
    }

    return Row(children: [
      Expanded(
        child: TextField(
          controller: madeCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco('入球數').copyWith(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
          onChanged: (v) {
            final made = int.tryParse(v) ?? 0;
            _updatePlayerResult(drillIndex, name,
                {'made': made, 'total': targetTotal});
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('/ $targetTotal',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ),
    ]);
  }

  // ── Running input ─────────────────────────────────────────────────────────

  Widget _runningInput(int drillIndex, Map<String, dynamic> drill,
      String name, Map<String, dynamic> result, bool canInput) {
    final pass = result['pass'] as bool?;

    if (!canInput) {
      if (pass == null) return const Text('-', style: TextStyle(color: Colors.white54, fontSize: 13));
      return Row(children: [
        Icon(pass ? Icons.check_circle : Icons.cancel,
            size: 16, color: pass ? Colors.green : Colors.red),
        const SizedBox(width: 4),
        Text(pass ? '輕鬆' : '搞唔掂',
            style: TextStyle(color: pass ? Colors.green : Colors.red, fontSize: 13)),
      ]);
    }

    return Row(children: [
      // 輕鬆 = 達標
      InkWell(
        onTap: () => _updatePlayerResult(drillIndex, name, {'pass': true}),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(pass == true ? Icons.check_box : Icons.check_box_outline_blank,
                color: Colors.green, size: 20),
            const SizedBox(width: 4),
            const Text('輕鬆', style: TextStyle(color: Colors.green, fontSize: 13)),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      // 搞唔掂 = 未達標
      InkWell(
        onTap: () => _updatePlayerResult(drillIndex, name, {'pass': false}),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(pass == false ? Icons.check_box : Icons.check_box_outline_blank,
                color: Colors.red, size: 20),
            const SizedBox(width: 4),
            const Text('搞唔掂', style: TextStyle(color: Colors.red, fontSize: 13)),
          ]),
        ),
      ),
    ]);
  }

  // ── Custom input ──────────────────────────────────────────────────────────

  Widget _customInput(int drillIndex, Map<String, dynamic> drill,
      String name, Map<String, dynamic> result, bool canInput) {
    final pass  = result['pass']  as bool?;
    final notes = result['notes'] as String? ?? '';

    if (!canInput) {
      // Read-only view
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(pass == true ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: pass == true ? Colors.green : Colors.red),
            const SizedBox(width: 4),
            Text(pass == true ? '達標' : '未達',
                style: TextStyle(
                    color: pass == true ? Colors.green : Colors.red,
                    fontSize: 13)),
          ]),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(notes,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
        ],
      );
    }

    final notesCtrl = TextEditingController(text: notes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pass / Fail checkboxes
        Row(children: [
          // 達標 checkbox
          GestureDetector(
            onTap: () => _updatePlayerResult(drillIndex, name,
                {'pass': true, 'notes': notesCtrl.text}),
            child: Row(children: [
              Icon(
                pass == true
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 4),
              const Text('達標',
                  style: TextStyle(color: Colors.green, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 16),
          // 未達標 checkbox
          GestureDetector(
            onTap: () => _updatePlayerResult(drillIndex, name,
                {'pass': false, 'notes': notesCtrl.text}),
            child: Row(children: [
              Icon(
                pass == false
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 4),
              const Text('未達標',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        // Notes field
        TextField(
          controller: notesCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDeco('標註（選填）').copyWith(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
          onChanged: (v) => _updatePlayerResult(drillIndex, name,
              {'pass': pass, 'notes': v}),
        ),
      ],
    );
  }

  // ── Add drill form ────────────────────────────────────────────────────────

  Widget _buildAddDrillForm() {
    return Card(
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (ctx, setForm) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('新增訓練項目',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Type selector
              Row(children: [
                const Text('類型：',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 8),
                ...[_kShooting, _kRunning, _kCustom].map((t) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_typeLabel(t)),
                      selected: _newType == t,
                      selectedColor: _typeColor(t).withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                          color: _newType == t ? _typeColor(t) : Colors.white54,
                          fontSize: 12),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: BorderSide(
                          color: _newType == t
                              ? _typeColor(t)
                              : Colors.white24),
                      onSelected: (_) =>
                          setForm(() => _newType = t),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Label
              TextField(
                controller: _labelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('項目名稱（例：三分線射球、繞場3圈）'),
              ),
              const SizedBox(height: 8),

              // Type-specific target fields
              if (_newType == _kShooting) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _targetMadeCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDeco('達標入數'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('/', style: TextStyle(color: Colors.white54)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _targetTotalCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDeco('總球數'),
                    ),
                  ),
                ]),
              ] else if (_newType == _kRunning) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _targetSecsCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDeco('目標秒數（越短越好）'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('秒', style: TextStyle(color: Colors.white54)),
                  ),
                ]),
              ] else ...[
                TextField(
                  controller: _targetNoteCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('達標說明（例：完成即達標）'),
                ),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addDrill,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                  child: const Text('新增項目'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
