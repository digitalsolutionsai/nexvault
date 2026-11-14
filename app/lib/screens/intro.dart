import 'package:flutter/material.dart';

import '../core/keys.dart';
import '../l10n/l10n.dart';
import '../ui/sync_path.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// First launch only: three pictures with a line each on what is unusual about NexVault (a
/// shared vault, no server, joining in person), before the name and lock-screen setup. The
/// language can be picked here, and the whole thing skipped.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final pages = PageController();
  int page = 0;

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> _lang(String code) async {
    await Keys.setLanguage(code);
    language.value = code; // the app re-localizes and rebuilds this screen
  }

  @override
  Widget build(BuildContext context) {
    final t = NV.dark().textTheme;
    final items = [
      (const _VaultPicture(), tr.intro1Title, tr.intro1Body),
      (const _NoServerPicture(), tr.intro2Title, tr.intro2Body),
      (const _InPersonPicture(), tr.intro3Title, tr.intro3Body),
    ];
    final last = page == items.length - 1;
    final lang = tr.localeName.startsWith('vi') ? 'vi' : 'en';
    return DarkZone(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: const [
                            ButtonSegment(value: 'vi', label: Text('VI')),
                            ButtonSegment(value: 'en', label: Text('EN')),
                          ],
                          selected: {lang},
                          onSelectionChanged: (s) => _lang(s.first),
                        ),
                        const Spacer(),
                        // hidden on the last page, but keeps its room so the row does not jump
                        Visibility(
                          visible: !last,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: NV.dSub),
                            onPressed: widget.onDone,
                            child: Text(tr.introSkip),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: pages,
                      onPageChanged: (i) => setState(() => page = i),
                      children: [
                        for (final (pic, title, body) in items)
                          LayoutBuilder(
                            builder: (_, box) => SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: box.maxHeight),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(height: 220, child: Center(child: pic)),
                                    const SizedBox(height: 36),
                                    Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
                                    const SizedBox(height: 12),
                                    Text(
                                      body,
                                      style: t.bodyMedium?.copyWith(color: NV.dSub, height: 1.45),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      children: [
                        Semantics(
                          label: '${page + 1} / ${items.length}',
                          excludeSemantics: true,
                          child: Row(
                            children: [
                              for (var i = 0; i < items.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 6),
                                  width: i == page ? 22 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i == page ? NV.dText : const Color(0x40FFFFFF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          // the theme makes filled buttons full-width; this one sits beside the dots
                          style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
                          onPressed: last
                              ? widget.onDone
                              : () => pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
                          child: Text(last ? tr.introStart : tr.introNext),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's icon with the kinds of things a group keeps in it around it.
class _VaultPicture extends StatelessWidget {
  const _VaultPicture();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 280,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x0FFFFFFF)),
          ),
          ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/icon.png', width: 88, height: 88)),
          const Align(alignment: Alignment(-1, -.85), child: _Chip(Icons.wifi_password, 'Wi-Fi')),
          const Align(alignment: Alignment(1, -.7), child: _Chip(Icons.vpn_key_outlined, 'API key')),
          const Align(alignment: Alignment(-.9, .85), child: _Chip(Icons.description_outlined, '.env')),
          const Align(alignment: Alignment(.95, .9), child: _Chip(Icons.terminal, 'SSH')),
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: NV.dRun),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: NV.mono, fontSize: 12.5, color: NV.dText)),
      ],
    ),
  );
}

/// The sync picture: two phones, encrypted packets straight between them, no cloud.
class _NoServerPicture extends StatelessWidget {
  const _NoServerPicture();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 320, child: SyncPath());
}

/// Two people side by side, one reading a six-digit code to the other.
class _InPersonPicture extends StatelessWidget {
  const _InPersonPicture();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: NV.dText, borderRadius: BorderRadius.circular(16)),
          child: const Text('643 392', style: TextStyle(fontFamily: NV.mono, fontSize: 26, color: NV.ground, letterSpacing: 1)),
        ),
        CustomPaint(size: const Size(20, 12), painter: _Tail()),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Avatar('Lan', size: 72, dark: true),
            const SizedBox(width: 28),
            Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: NV.dOk, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 22, color: NV.ground),
                ),
                const SizedBox(height: 19),
              ],
            ),
            const SizedBox(width: 28),
            const Avatar('Minh', size: 72, dark: true),
          ],
        ),
      ],
    ),
  );
}

class _Tail extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    // the bubble's tail points down-left, at the person reading the code
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(-s.width * 1.6, s.height)
      ..close();
    c.drawPath(p, Paint()..color = NV.dText);
  }

  @override
  bool shouldRepaint(_Tail old) => false;
}
