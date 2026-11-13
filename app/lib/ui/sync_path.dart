import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'theme.dart';

/// Two devices with encrypted packets travelling straight between them, a crossed-out cloud
/// above ("no server"), and the network path below. Explains the sync while it runs.
///
/// [via]: 'nearby' (same Wi-Fi), 'internet' (4G/5G over IPv6), or '' (not known yet: shown as
/// "Wi-Fi or 4G/5G"). [moving]: packets flow; false draws a still picture. [searching]: still
/// connecting, packets only go out and fade. Honors the system "reduce motion" setting.
class SyncPath extends StatefulWidget {
  const SyncPath({super.key, this.via = '', this.moving = true, this.searching = false, this.connected = false, this.peer});
  final String via;
  final bool moving;
  final bool searching;

  /// Finished and still linked: a solid line instead of packets.
  final bool connected;
  final String? peer;

  @override
  State<SyncPath> createState() => _SyncPathState();
}

class _SyncPathState extends State<SyncPath> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  void _run(bool reduce) {
    final go = widget.moving && !reduce;
    if (go && !c.isAnimating) c.repeat();
    if (!go) {
      c.stop();
      c.value = .4; // a still frame with packets mid-way
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _run(MediaQuery.of(context).disableAnimations);
  }

  @override
  void didUpdateWidget(SyncPath old) {
    super.didUpdateWidget(old);
    _run(MediaQuery.of(context).disableAnimations);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (widget.via) {
      'nearby' => (Icons.wifi, tr.syncPathNearby),
      'internet' => (Icons.cell_tower, tr.syncPathInternet),
      _ => (Icons.swap_horiz, tr.syncPathEither),
    };
    const caption = TextStyle(fontSize: 12.5, color: NV.dSub, height: 1.2);
    return Semantics(
      label: '${tr.syncPathNoServer}. $label',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 18, color: NV.dSub),
              const SizedBox(width: 6),
              Text(tr.syncPathNoServer, style: caption),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                const _Device(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: c,
                    builder: (_, _) => CustomPaint(
                      size: const Size(double.infinity, 64),
                      painter: _PacketPainter(c.value, searching: widget.searching, connected: widget.connected),
                    ),
                  ),
                ),
                const _Device(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(width: 64, child: Text(tr.syncPathThisDevice, style: caption, textAlign: TextAlign.center)),
              const Spacer(),
              SizedBox(
                width: 64,
                child: Text(
                  widget.peer ?? tr.syncPathOther,
                  style: caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: NV.dText),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13.5, color: NV.dText, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Device extends StatelessWidget {
  const _Device();
  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    alignment: Alignment.center,
    child: Container(
      width: 36,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: NV.dText, width: 2),
        color: const Color(0x14FFFFFF),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.shield_outlined, size: 18, color: NV.brass),
    ),
  );
}

/// Dashed track plus lock "packets": three going out, two coming back (sync is two-way).
class _PacketPainter extends CustomPainter {
  _PacketPainter(this.t, {required this.searching, required this.connected});
  final double t;
  final bool searching;
  final bool connected;

  static final _lock = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.lock.codePoint),
      style: TextStyle(fontFamily: Icons.lock.fontFamily, package: Icons.lock.fontPackage, fontSize: 10, color: NV.ground),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    if (connected) {
      final line = Paint()
        ..color = NV.dOk
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), line);
      canvas.drawCircle(Offset(size.width / 2, y), 11, Paint()..color = NV.dOk);
      _lock.paint(canvas, Offset(size.width / 2, y) - Offset(_lock.width / 2, _lock.height / 2));
      return;
    }
    final track = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1.5;
    for (var x = 4.0; x < size.width - 4; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width - 4), y), track);
    }
    void packet(double p, {required bool back, required double opacity}) {
      final x = 8 + (size.width - 16) * (back ? 1 - p : p);
      final fade = math.sin(math.pi * p).clamp(0.0, 1.0); // ease in and out at the devices
      final paint = Paint()..color = (back ? NV.dOk : NV.dRun).withValues(alpha: opacity * fade);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, back ? y + 9 : y - 9), width: 16, height: 16), const Radius.circular(5));
      canvas.drawRRect(r, paint);
      if (fade > .5) _lock.paint(canvas, r.center - Offset(_lock.width / 2, _lock.height / 2));
    }

    for (final o in [0.0, 1 / 3, 2 / 3]) {
      final p = (t + o) % 1;
      // while connecting the packets only reach half way, like knocking on a door
      packet(searching ? p * .5 : p, back: false, opacity: searching ? .55 : 1);
    }
    if (!searching) {
      for (final o in [1 / 6, 1 / 2, 5 / 6]) {
        packet((t + o) % 1, back: true, opacity: .9);
      }
    }
  }

  @override
  bool shouldRepaint(_PacketPainter old) => old.t != t || old.searching != searching || old.connected != connected;
}
