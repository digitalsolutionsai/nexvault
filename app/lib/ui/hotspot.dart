import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/keys.dart';
import '../l10n/l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// The QR on a host screen can carry the host's private Wi-Fi, so the other phone joins it and
/// connects in one scan: `nexvault://…#w=<base64url {"s":ssid,"p":pass,"t":security}>`.
/// The core never sees the part after '#'. Shared pictures for far-away members leave it out.
String withWifi(String code, Map<String, dynamic>? wifi) {
  if (wifi == null) return code;
  final j = jsonEncode({'s': wifi['ssid'], 'p': wifi['pass'], 't': wifi['sec']});
  return '$code#w=${base64Url.encode(utf8.encode(j)).replaceAll('=', '')}';
}

/// Splits a scanned code into the NexVault code and the Wi-Fi to join first (or null).
(String, Map<String, dynamic>?) splitWifi(String scanned) {
  final i = scanned.indexOf('#w=');
  if (i < 0) return (scanned, null);
  final code = scanned.substring(0, i);
  try {
    final b = scanned.substring(i + 3);
    final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(b))));
    if (j is Map && j['s'] is String && j['p'] is String && (j['s'] as String).isNotEmpty) {
      return (code, Map<String, dynamic>.from(j));
    }
  } catch (_) {}
  return (code, null);
}

/// "No shared Wi-Fi? Start a private Wi-Fi on this phone" on host screens (Android 13+ only).
/// [onChange] gets the hotspot ({ssid, pass, sec}) or null, and should make a new code so the
/// hotspot's address and name go into it.
class HotspotButton extends StatefulWidget {
  const HotspotButton({super.key, required this.onChange});
  final Future<void> Function(Map<String, dynamic>? wifi) onChange;
  @override
  State<HotspotButton> createState() => _HotspotButtonState();
}

class _HotspotButtonState extends State<HotspotButton> {
  bool supported = false;
  bool busy = false;
  Map<String, dynamic>? wifi;

  @override
  void initState() {
    super.initState();
    Keys.hotspotSupported().then((v) {
      if (mounted) setState(() => supported = v);
    });
    Keys.hotspotStopped.addListener(_stoppedBySystem);
  }

  @override
  void dispose() {
    Keys.hotspotStopped.removeListener(_stoppedBySystem);
    if (wifi != null) Keys.hotspotStop();
    super.dispose();
  }

  void _stoppedBySystem() {
    if (wifi == null || !mounted) return;
    setState(() => wifi = null);
    widget.onChange(null);
  }

  Future<void> _start() async {
    // Android's own prompt talks about the position of devices: say first what it is for
    if (!await Keys.hotspotPermitted()) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(tr.hotspotPermTitle),
          content: Text(tr.hotspotPermBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.commonCancel)),
            TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr.hotspotPermContinue)),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      final w = await Keys.hotspotStart();
      // the access point needs a moment to get its address before the new code lists it
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() => wifi = w);
      await widget.onChange(w);
    } on PlatformException catch (e) {
      if (mounted) toast(context, e.code == 'denied' ? tr.hotspotDenied : tr.hotspotFailed, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _stop() async {
    await Keys.hotspotStop();
    if (!mounted) return;
    setState(() => wifi = null);
    await widget.onChange(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!supported) return const SizedBox.shrink();
    final t = NV.dark().textTheme; // host screens sit inside DarkZone
    if (wifi == null) {
      return Center(
        child: TextButton.icon(
          onPressed: busy ? null : _start,
          icon: busy
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NV.dSub))
              : const Icon(Icons.wifi_tethering, size: 20),
          label: Text(tr.hotspotOffer, textAlign: TextAlign.center),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering, color: NV.dOk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.hotspotOnTitle('${wifi!['ssid']}'), style: t.titleMedium?.copyWith(fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(tr.hotspotOnHint, style: t.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: _stop, child: Text(tr.hotspotStop)),
        ],
      ),
    );
  }
}
