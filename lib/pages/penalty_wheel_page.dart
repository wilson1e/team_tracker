import 'dart:math';
import 'package:flutter/material.dart';

const _penalties = [
  '掌上壓\n20下',
  '蹲下起立\n20下',
  '自殺跑\n1次',
  '邊線衝刺\n3個來回',
  '波比跳\n15次',
  'Sit-up\n20下',
];

const _sliceColors = [
  Color(0xFFE53935),
  Color(0xFFFF6F00),
  Color(0xFF43A047),
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];

class PenaltyWheelPage extends StatefulWidget {
  const PenaltyWheelPage({super.key});

  @override
  State<PenaltyWheelPage> createState() => _PenaltyWheelPageState();
}

class _PenaltyWheelPageState extends State<PenaltyWheelPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  // Total accumulated rotation of the wheel (radians, clockwise)
  double _rotation = 0;
  int? _resultIndex;
  int? _pendingResult;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _spinning = false;
          _resultIndex = _pendingResult;
        });
        _showResult();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;
    setState(() {
      _spinning = true;
      _resultIndex = null;
    });

    final rng = Random();
    final n = _penalties.length;
    final sliceAngle = 2 * pi / n;

    // Pick a random target slice
    final targetSlice = rng.nextInt(n);
    _pendingResult = targetSlice;

    // Normalize current rotation to [0, 2π)
    final currentNorm = _rotation % (2 * pi);

    // Angle needed so slice center lands at top (pointer at -pi/2)
    // Slice i center in wheel coords = i * sliceAngle - pi/2 + sliceAngle/2
    // After rotation R, it appears at: center + R (mod 2π)
    // We want it at -pi/2 (top), so:
    //   R = -pi/2 - (i * sliceAngle - pi/2 + sliceAngle/2) (mod 2π)
    //   R = -(i * sliceAngle + sliceAngle/2) (mod 2π)
    final targetNorm =
        (-(targetSlice * sliceAngle + sliceAngle / 2)) % (2 * pi);
    // Ensure positive
    final targetNormPos = targetNorm < 0 ? targetNorm + 2 * pi : targetNorm;

    // How much extra to rotate from current position to reach target
    double delta = targetNormPos - currentNorm;
    if (delta < 0) delta += 2 * pi;

    // Add 5-8 full spins
    final fullSpins = (5 + rng.nextInt(4)) * 2 * pi;
    final endRotation = _rotation + fullSpins + delta;

    _ctrl.duration = const Duration(milliseconds: 3800);
    _anim = Tween<double>(begin: _rotation, end: endRotation).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.decelerate),
    )..addListener(() {
        setState(() => _rotation = _anim.value);
      });

    _ctrl.forward(from: 0);
  }

  void _showResult() {
    if (_resultIndex == null) return;
    final idx = _resultIndex!;
    final penalty = _penalties[idx].replaceAll('\n', ' ');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.emoji_events, color: _sliceColors[idx], size: 28),
          const SizedBox(width: 10),
          const Text('懲罰結果！',
              style: TextStyle(color: Colors.white, fontSize: 18)),
        ]),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: _sliceColors[idx].withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _sliceColors[idx].withValues(alpha: 0.4)),
          ),
          child: Text(
            penalty,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _sliceColors[idx],
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: _sliceColors[idx]),
            child: const Text('知道了！'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('懲罰抽獎',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('轉動圓盤，接受懲罰！',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 24),

            // Pointer + wheel stacked so pointer sits at top-center of wheel
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Wheel (leave 16px top padding so pointer overlaps)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => Transform.rotate(
                        angle: _rotation,
                        child: CustomPaint(
                          painter: _WheelPainter(),
                          size: const Size(300, 300),
                        ),
                      ),
                    ),
                  ),
                ),
                // Pointer triangle at top-center
                CustomPaint(
                  size: const Size(24, 28),
                  painter: _PointerPainter(),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // Spin button
            GestureDetector(
              onTap: _spin,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.orange.shade300,
                    Colors.orange.shade700,
                  ]),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: _spinning
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.casino, color: Colors.white, size: 32),
                            SizedBox(height: 4),
                            Text('抽！',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wheel painter ─────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final n = _penalties.length;
    final sliceAngle = 2 * pi / n;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      // Slice i starts at 12 o'clock and goes clockwise
      final startAngle = i * sliceAngle - pi / 2;

      paint.color = _sliceColors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );

      // Border
      paint
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );
      paint.style = PaintingStyle.fill;

      // Label text at center of slice
      final midAngle = startAngle + sliceAngle / 2;
      final textRadius = radius * 0.60;
      final textCenter = Offset(
        center.dx + textRadius * cos(midAngle),
        center.dy + textRadius * sin(midAngle),
      );

      canvas.save();
      canvas.translate(textCenter.dx, textCenter.dy);
      canvas.rotate(midAngle + pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: _penalties[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 76);

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Center dot
    paint
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, paint);
    paint
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 20, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Pointer painter ───────────────────────────────────────────────────────────

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height) // tip pointing down into wheel
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.orange);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
