import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/bridge.dart';
import '../core/keys.dart';
import '../l10n/l10n.dart';
import 'theme.dart';

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: NV.sans, color: Colors.white),
        ),
        backgroundColor: error ? NV.danger : NV.ink,
      ),
    );
}

String errText(Object e) => e is CoreError ? e.message : e.toString();

/// Wraps a screen in the dark "high-risk moment" theme.
class DarkZone extends StatelessWidget {
  const DarkZone({super.key, required this.child});
  final Widget child;
  @override
  // light status-bar icons on the dark ground (iOS keeps dark icons otherwise)
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Theme(data: NV.dark(), child: child),
  );
}

/// On tablets and wide windows (iPad, Android tablets, split view) the phone layout sits in a
/// centred column on the brand ground instead of stretching across the screen. Dialogs and
/// sheets open inside the column too, since the navigator lives in it.
class WideFrame extends StatelessWidget {
  const WideFrame({super.key, required this.child});
  final Widget child;

  static const columnWidth = 600.0;
  static const breakpoint = 720.0;
  static const backdrop = Color(0xFF0F2F2C);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < breakpoint) return child;
    // the column starts under the status bar, so the bar always sits on the dark backdrop
    final top = mq.padding.top + 12;
    final inner = mq.copyWith(
      size: Size(columnWidth, mq.size.height - top),
      padding: mq.padding.copyWith(top: 0, left: 0, right: 0),
      viewPadding: mq.viewPadding.copyWith(top: 0, left: 0, right: 0),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: backdrop,
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: Center(
            child: SizedBox(
              width: columnWidth,
              height: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: MediaQuery(data: inner, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top gap of a full-screen column: fixed on phones; on tall screens (tablets) it flexes so the
/// content sits in the middle (pair it with a Spacer below).
class TopGap extends StatelessWidget {
  const TopGap(this.height, {super.key});
  final double height;
  @override
  Widget build(BuildContext context) => MediaQuery.sizeOf(context).height > 960 ? const Spacer() : SizedBox(height: height);
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 46, this.me = false, this.dark = false});
  final String name;
  final double size;
  final bool me;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final bg = me ? NV.verdigris : (dark ? const Color(0x1FFFFFFF) : const Color(0xFFDCE5E2));
    final fg = me ? Colors.white : (dark ? NV.dText : NV.ink);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(fontFamily: NV.sans, fontWeight: FontWeight.w600, fontSize: size * .37, color: fg),
      ),
    );
  }
}

/// The folded-corner file badge (.p8, .p12, ssh…).
class FileBadge extends StatelessWidget {
  const FileBadge(this.kind, {super.key});
  final String kind;
  static String label(String k) => switch (k) {
    'p8' => '.p8',
    'p12' => '.p12',
    'jks' => '.jks',
    'ssh' => 'ssh',
    'env' => '.env',
    _ => 'txt',
  };
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFE4E9E7),
      border: Border.all(color: const Color(0xFFC5D0CD), width: 1.5),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(8),
        topRight: Radius.circular(14),
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
    ),
    child: Text(
      label(kind),
      style: const TextStyle(fontFamily: NV.mono, fontSize: 12, fontWeight: FontWeight.w500, color: NV.ink),
    ),
  );
}

class PinDots extends StatelessWidget {
  const PinDots(this.filled, {super.key, this.length = 6});
  final int filled;
  final int length;
  @override
  Widget build(BuildContext context) => Semantics(
    label: tr.pinFilled(filled, length),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        length,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 9),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled ? NV.dText : Colors.transparent,
            border: Border.all(color: i < filled ? NV.dText : const Color(0xFF8FB3AA), width: 2),
          ),
        ),
      ),
    ),
  );
}

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.enabled = true});
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  Widget _key(String d) => Semantics(
    button: true,
    label: d,
    child: Material(
      color: const Color(0x12FFFFFF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onDigit(d);
              }
            : null,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Center(
            child: Text(
              d,
              style: const TextStyle(fontFamily: NV.sans, fontSize: 28, fontWeight: FontWeight.w500, color: NV.dText),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [for (final w in c) Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: w)],
      ),
    );
    // hardware keyboards (iPad Magic Keyboard, tablets, desktop): digits and backspace
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (!enabled || e is KeyUpEvent) return KeyEventResult.ignored;
        final c = e.character;
        if (c != null && c.length == 1 && '0123456789'.contains(c)) {
          onDigit(c);
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.backspace || e.logicalKey == LogicalKeyboardKey.delete) {
          onBackspace();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([_key('1'), _key('2'), _key('3')]),
          row([_key('4'), _key('5'), _key('6')]),
          row([_key('7'), _key('8'), _key('9')]),
          row([
            const SizedBox(width: 76, height: 76),
            _key('0'),
            SizedBox(
              width: 76,
              height: 76,
              child: IconButton(
                tooltip: tr.commonDelete,
                onPressed: enabled ? onBackspace : null,
                icon: const Icon(Icons.backspace_outlined, color: NV.dText, size: 26),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Asks for the app PIN in a dark bottom sheet. Returns true when correct.
Future<bool> askPin(BuildContext context, {String? title}) async {
  final ok = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NV.ground,
    builder: (_) => DarkZone(child: _PinSheet(title: title ?? tr.pinEnterToContinue)),
  );
  return ok == true;
}

/// Collects 6 digits without checking them (new PIN entry). Returns null if dismissed.
Future<String?> readPin(BuildContext context, String title) async {
  final r = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NV.ground,
    builder: (_) => DarkZone(child: _PinSheet(title: title, check: false)),
  );
  return r is String ? r : null;
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.title, this.check = true});
  final String title;
  final bool check;
  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String pin = '';
  String? err;
  bool busy = false;

  Future<void> _digit(String d) async {
    if (busy || pin.length >= 6) return;
    setState(() => pin += d);
    if (pin.length == 6) {
      if (!widget.check) return Navigator.pop(context, pin);
      setState(() => busy = true);
      try {
        await Keys.checkPin(pin);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        final left = Keys.maxAttempts - await Keys.failedAttempts();
        setState(() {
          pin = '';
          busy = false;
          err = tr.pinWrongLeft(left);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 22),
          PinDots(pin.length),
          SizedBox(
            height: 30,
            child: Center(
              child: Text(err ?? '', style: const TextStyle(color: NV.dBad, fontSize: 14)),
            ),
          ),
          PinPad(
            enabled: !busy,
            onDigit: _digit,
            onBackspace: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1)),
          ),
        ],
      ),
    ),
  );
}

/// Re-authenticate before showing secret material: the lock screen in device mode; otherwise
/// the fingerprint if enabled, else the app PIN.
Future<bool> reauth(BuildContext context, String title) async {
  if (await Keys.deviceMode()) {
    try {
      return await Keys.bioCheck(title, device: true) == true;
    } catch (e) {
      if (context.mounted) toast(context, errText(e), error: true);
      return false;
    }
  }
  if (await Keys.bioEnabled()) {
    try {
      final ok = await Keys.bioCheck(title);
      if (ok == true) return true;
    } catch (e) {
      if (context.mounted) toast(context, errText(e), error: true);
    }
  }
  if (!context.mounted) return false;
  return askPin(context, title: title);
}

/// Before copying secret material (call it before re-auth, so a cancel is not audited): respects the device "no copy" setting and, the first time, warns that
/// keyboard clipboard history (Samsung Keyboard, Gboard...) may keep a copy we cannot clear.
Future<bool> mayCopy(BuildContext context) async {
  if (!await Keys.copyEnabled()) {
    if (context.mounted) toast(context, tr.copyDisabled, error: true);
    return false;
  }
  if (!await Keys.copyWarned()) {
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr.copyKeyboardTitle),
        content: Text(tr.copyKeyboardBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr.copyUnderstood)),
        ],
      ),
    );
    if (ok != true) return false;
    await Keys.setCopyWarned();
  }
  return true;
}

/// QR on a light card, plus helpers to share it as an image.
class QrCard extends StatelessWidget {
  const QrCard(this.data, {super.key, this.size = 250});
  final String data;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: NV.surface, borderRadius: BorderRadius.circular(22)),
    child: Stack(
      alignment: Alignment.center,
      children: [
        QrImageView(
          data: data,
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          gapless: true,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: NV.ink),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: NV.ink),
          semanticsLabel: tr.qrLabel,
        ),
      ],
    ),
  );
}

Future<void> shareQr(String data, String text) async {
  const px = 900.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(const Rect.fromLTWH(0, 0, px, px), Paint()..color = Colors.white);
  canvas.translate(60, 60);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: NV.ink),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: NV.ink),
  ).paint(canvas, const Size(px - 120, px - 120));
  final img = await rec.endRecording().toImage(px.toInt(), px.toInt());
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  final f = File('${(await getTemporaryDirectory()).path}/nexvault-sync.png');
  await f.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(f.path, mimeType: 'image/png')],
      text: text,
    ),
  );
}

/// Shows a new recovery code once. The user must confirm they wrote it down.
/// "AAAA-BBBB-CCCC-DDDD-EEEE-FFFF" as two lines of three groups (fits a phone dialog).
String _twoLines(String code) {
  final g = code.split('-');
  return g.length == 6 ? '${g.take(3).join('-')}-\n${g.skip(3).join('-')}' : code;
}

/// Recovery code sheet for printing. Built in memory and handed to the system print dialog.
Future<void> _printRecoveryCode(String code) async {
  final device = const HtmlEscape().convert(await Keys.deviceName());
  final d = DateTime.now();
  final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  await Keys.printHtml("""
<!doctype html><html><head><meta charset="utf-8"><style>
body{font-family:-apple-system,Roboto,Helvetica,sans-serif;margin:40px;color:#111}
h1{font-size:30px;margin:0 0 8px} .meta{color:#444;font-size:18px;margin:0}
.code{font-family:Menlo,'Roboto Mono',monospace;font-size:34px;letter-spacing:2px;border:3px solid #111;
border-radius:10px;padding:26px;text-align:center;margin:32px 0}
p{font-size:19px;line-height:1.55}
</style></head><body>
<h1>NexVault &middot; ${tr.recoveryTitle}</h1>
<p class="meta">${tr.recoveryPrintMeta(device, date)}</p>
<div class="code">$code</div>
<p>${tr.recoveryPrintUse}</p>
<p>${tr.recoveryPrintKeep}</p>
</body></html>""");
}

Future<void> showRecoveryCode(BuildContext context, String code) {
  // a text field left focused underneath (the onboarding name) would bring the keyboard back
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (d) {
      var saved = false;
      return StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(tr.recoveryTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.recoveryIntro),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFE4E9E7), borderRadius: BorderRadius.circular(12)),
                  child: SelectableText(
                    _twoLines(code),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: NV.mono, fontSize: 17, height: 1.5, color: NV.ink),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _printRecoveryCode(code),
                      icon: const Icon(Icons.print_outlined, size: 20),
                      label: Text(tr.recoveryPrint),
                    ),
                    Expanded(
                      child: Text(tr.recoveryPrintHint, style: const TextStyle(fontSize: 13, color: NV.ink2)),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: saved,
                  onChanged: (v) => set(() => saved = v ?? false),
                  title: Text(tr.recoverySaved, style: const TextStyle(fontSize: 15)),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [FilledButton(onPressed: saved ? () => Navigator.pop(d) : null, child: Text(tr.commonDone))],
        ),
      );
    },
  );
}
