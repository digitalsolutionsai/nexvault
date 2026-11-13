import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Port of design/seal.js. Same bytes -> same glyph on every device; keep in sync.
class Seal extends StatelessWidget {
  const Seal(this.hex, {super.key, this.size = 56});
  final String hex;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr.sealLabel,
    child: CustomPaint(size: Size.square(size), painter: _SealPainter(_bytes(hex))),
  );

  static List<int> _bytes(String h) {
    final out = <int>[];
    for (var i = 0; i + 1 < h.length; i += 2) {
      out.add(int.tryParse(h.substring(i, i + 2), radix: 16) ?? 0);
    }
    while (out.length < 9) {
      out.add(0);
    }
    return out;
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter(this.b);
  final List<int> b;

  static const grounds = [0xFF173D3A, 0xFF2A3163, 0xFF5B2333, 0xFF3D2F14, 0xFF1E4A6B, 0xFF3E2457];
  static const metals = [0xFFD2A24A, 0xFFC9D2D6, 0xFFD98552];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    canvas.scale(k);
    final ground = Color(grounds[b[7] % grounds.length]);
    final ink = Color(metals[b[8] % metals.length]);
    const c = 50.0;
    final lobes = 5 + (b[0] % 8);
    final depth = 2 + (b[1] % 4) * 2.5;
    final rot = (b[2] / 255) * (360 / lobes) * math.pi / 180;
    final star = 3 + (b[3] % 6);
    final dots = (b[4] << 8) | b[5];
    final inner = 0.38 + (b[6] % 4) * 0.06;

    final rosette = Path();
    const steps = 180;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      final r = 44 - depth / 2 + depth / 2 * math.cos(a * lobes);
      final x = c + r * math.cos(a + rot), y = c + r * math.sin(a + rot);
      i == 0 ? rosette.moveTo(x, y) : rosette.lineTo(x, y);
    }
    rosette.close();
    canvas.drawPath(rosette, Paint()..color = ink);
    canvas.drawCircle(
      const Offset(c, c),
      36,
      Paint()
        ..color = ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * math.pi * 2 - math.pi / 2;
      final o = Offset(c + 29 * math.cos(a), c + 29 * math.sin(a));
      if ((dots >> i) & 1 == 1) {
        canvas.drawCircle(o, 2.6, Paint()..color = ground);
      } else {
        canvas.drawCircle(
          o,
          1.9,
          Paint()
            ..color = ground
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      }
    }
    canvas.drawCircle(const Offset(c, c), 25, Paint()..color = ground);
    final s = Path();
    for (var i = 0; i < star * 2; i++) {
      final a = i / (star * 2) * math.pi * 2 - math.pi / 2 + rot;
      final r = i.isOdd ? 20 * inner : 20.0;
      final x = c + r * math.cos(a), y = c + r * math.sin(a);
      i == 0 ? s.moveTo(x, y) : s.lineTo(x, y);
    }
    s.close();
    canvas.drawPath(s, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(covariant _SealPainter old) => old.b.toString() != b.toString();
}
