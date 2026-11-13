import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../core/bridge.dart';
import '../core/keys.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ceremony.dart';
import 'sync.dart';

/// Open a link handed over by Android: a nexvault:// code, or a QR image shared from
/// another app (`nexvault-image:<path>`, written by ShareReceiverActivity).
Future<void> openLink(BuildContext context, String link) async {
  const img = 'nexvault-image:';
  if (!link.startsWith(img)) {
    if (link.startsWith('nexvault://')) await openCode(context, link);
    return;
  }
  final f = File(link.substring(img.length));
  // defence in depth: only the share receiver's own cache folder (Kotlin checks this too)
  if (!f.path.contains('/cache/shared/qr-')) return;
  final ctrl = MobileScannerController(formats: const [BarcodeFormat.qrCode], autoStart: false);
  String? code;
  try {
    final cap = await ctrl.analyzeImage(f.path);
    code = cap?.barcodes.map((b) => b.rawValue).whereType<String>().where((s) => s.startsWith('nexvault://')).firstOrNull;
  } catch (_) {
  } finally {
    await ctrl.dispose();
    await f.delete().catchError((_) => f);
  }
  if (!context.mounted) return;
  if (code == null) {
    toast(context, tr.scanNoCodeInImage, error: true);
    return;
  }
  await openCode(context, code);
}

/// Route any nexvault:// code to the right screen.
Future<void> openCode(BuildContext context, String code, {bool replace = false}) async {
  code = code.trim();
  try {
    final kind = (await Core.call('code_kind', {'code': code}))['kind'];
    if (!context.mounted) return;
    final Widget? page = switch (kind) {
      'sync' => SyncJoinScreen(ticket: code),
      'invite' => CeremonyJoinScreen(invite: code),
      _ => null,
    };
    if (page == null) {
      toast(context, tr.scanNotNexVault, error: true);
      return;
    }
    final route = MaterialPageRoute(builder: (_) => page);
    if (!replace) {
      Navigator.push(context, route);
      return;
    }
    // Keep the scanner underneath until the join/sync screen closes, so whoever opened the
    // scanner (home) only reloads after the new data has arrived. pushReplacement would
    // complete the scanner's route immediately and the caller would reload too early.
    final nav = Navigator.of(context);
    await nav.push(route);
    if (nav.mounted && nav.canPop()) nav.pop();
  } catch (e) {
    if (context.mounted) toast(context, errText(e), error: true);
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final ctrl = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool done = false;
  bool waitingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Back from the system Settings screen: try the camera again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && waitingSettings) {
      waitingSettings = false;
      ctrl.start().catchError((_) {});
    }
  }

  void _found(String? v) {
    if (done || v == null || !v.startsWith('nexvault://')) return;
    done = true;
    ctrl.stop();
    openCode(context, v, replace: true);
  }

  Future<void> _fromImage() async {
    final r = await Keys.away(() => FilePicker.pickFiles(type: FileType.image));
    if (r.isEmpty) return;
    // picked images may be content:// URIs; copy to a temp file for the scanner
    final tmp = File('${(await getTemporaryDirectory()).path}/nv-scan-${DateTime.now().millisecondsSinceEpoch}');
    await tmp.writeAsBytes(await r.first.readAsBytes());
    final cap = await ctrl.analyzeImage(tmp.path);
    await tmp.delete().catchError((_) => tmp);
    final v = cap?.barcodes.map((b) => b.rawValue).whereType<String>().firstWhere((s) => s.startsWith('nexvault://'), orElse: () => '');
    if (v == null || v.isEmpty) {
      if (mounted) toast(context, tr.scanNoCodeInImage, error: true);
      return;
    }
    _found(v);
  }

  Future<void> _paste() async {
    final clip = (await Clipboard.getData('text/plain'))?.text ?? '';
    if (!mounted) return;
    final c = TextEditingController(text: clip.startsWith('nexvault://') ? clip : '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.scanPaste),
        content: TextField(
          controller: c,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(hintText: 'nexvault://…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.scanCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr.scanOpenCode)),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) _found(v.trim());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DarkZone(
    child: Scaffold(
      appBar: AppBar(title: Text(tr.scanTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(tr.scanHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: MobileScanner(
                  controller: ctrl,
                  onDetect: (c) => _found(c.barcodes.firstOrNull?.rawValue),
                  errorBuilder: (_, e) {
                    final denied = e.errorCode == MobileScannerErrorCode.permissionDenied;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.no_photography_outlined, color: NV.dSub, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              denied ? tr.scanCameraDenied : tr.scanCameraFailed,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: NV.dSub),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () async {
                                // asking again only works until "don't ask again"; then it is a Settings switch
                                await ctrl.start().catchError((_) {});
                                if (ctrl.value.error?.errorCode == MobileScannerErrorCode.permissionDenied) {
                                  setState(() => waitingSettings = true);
                                  await Keys.openAppSettings();
                                }
                              },
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(tr.scanAllowCamera),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _fromImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(tr.scanPickImage),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste), label: Text(tr.scanPaste)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
