import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bridge.dart';
import '../core/keys.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/sync_path.dart';
import '../ui/hotspot.dart';
import '../ui/widgets.dart';

/// Host side of a group sync: a 5-minute code that members scan.
class SyncHostScreen extends StatefulWidget {
  const SyncHostScreen({super.key, required this.ws, required this.name, required this.members});
  final String ws, name;
  final List<Map<String, dynamic>> members;
  @override
  State<SyncHostScreen> createState() => _SyncHostScreenState();
}

class _SyncHostScreenState extends State<SyncHostScreen> {
  static const minutes = 5;
  Map<String, dynamic>? st;
  Timer? poll;
  String? err;
  Map<String, dynamic>? wifi; // this phone's private Wi-Fi, when started

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await Keys.refreshNet();
      await Core.call('sync_host', {'ws': widget.ws, 'minutes': minutes});
      await _refresh();
      poll?.cancel();
      poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _refresh());
    } catch (e) {
      setState(() => err = errText(e));
    }
  }

  Future<void> _refresh() async {
    try {
      final s = await Core.call('sync_host_status') as Map<String, dynamic>;
      if (mounted) setState(() => st = s);
    } catch (_) {}
  }

  @override
  void dispose() {
    poll?.cancel();
    Core.call('sync_stop').catchError((_) => null);
    super.dispose();
  }

  String _left() {
    if (st == null) return '';
    final ms = (st!['expires'] as int) - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return '0:00';
    final s = (ms / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  double _frac() {
    if (st == null) return 0;
    final ms = (st!['expires'] as int) - DateTime.now().millisecondsSinceEpoch;
    return (ms / (minutes * 60000)).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = NV.dark().textTheme; // this screen sits inside DarkZone
    final peers = ((st?['peers'] as List?) ?? []).cast<Map<String, dynamic>>();
    final accepting = st?['accepting'] == true;
    final live = ((st?['members'] as List?) ?? widget.members).cast<Map<String, dynamic>>();
    final others = live.where((m) => m['me'] != true).toList();
    final rows = <Widget>[];
    for (final m in others) {
      final p = peers.where((x) => x['pk'] == m['pk']).firstOrNull;
      final (label, color) = switch (p?['state']) {
        'done' => (tr.syncPeerDone, NV.dOk),
        'syncing' => (tr.syncPeerSyncing, NV.dRun),
        'left' => (tr.syncPeerLeft, NV.dWait),
        _ => (tr.syncPeerNotScanned, NV.dWait),
      };
      rows.add(_PeerRow(name: m['name'], label: label, color: color));
    }
    // devices that joined but were not in the member list when this screen opened (newcomers)
    for (final p in peers.where((p) => p['state'] == 'removed')) {
      rows.add(_PeerRow(name: p['name'] ?? '?', title: tr.syncPeerRemovedName('${p['name']}'), label: tr.syncPeerRejected, color: NV.dBad));
    }
    for (final p in peers.where((p) => !['rejected', 'removed'].contains(p['state']) && !others.any((m) => m['pk'] == p['pk']))) {
      final (label, color) = switch (p['state']) {
        'done' => (tr.syncPeerDone, NV.dOk),
        'left' => (tr.syncPeerLeft, NV.dWait),
        _ => (tr.syncPeerSyncing, NV.dRun),
      };
      rows.add(_PeerRow(name: p['name'] ?? '?', title: tr.syncPeerNewMember('${p['name'] ?? '?'}'), label: label, color: color));
    }
    final strangers = peers.where((p) => p['state'] == 'rejected').length;
    if (strangers > 0) rows.add(_PeerRow(name: '?', title: tr.syncStrangers(strangers), label: tr.syncPeerRejected, color: NV.dBad));

    return DarkZone(
      child: Scaffold(
        appBar: AppBar(leading: const CloseButton(), title: Text(tr.syncHostTitle(widget.name))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(
              tr.syncHostIntro,
              style: t.bodySmall,
            ),
            const SizedBox(height: 14),
            if (err != null) Text(err!, style: const TextStyle(color: NV.dBad)),
            if (st != null)
              Center(
                child: Opacity(opacity: accepting ? 1 : .25, child: QrCard(withWifi(st!['ticket'], wifi), size: 250)),
              ),
            const SizedBox(height: 14),
            if (st != null)
              Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: accepting ? tr.syncExpiresIn : tr.syncExpired, style: t.bodySmall),
                      if (accepting)
                        TextSpan(
                          text: _left(),
                          style: const TextStyle(fontFamily: NV.mono, fontSize: 22, color: NV.dText),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: _frac(), minHeight: 5, color: NV.dText, backgroundColor: const Color(0x40FFFFFF)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => showSyncHow(context),
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(tr.syncConnectVia, style: t.bodySmall?.copyWith(color: NV.dText), textAlign: TextAlign.center),
              ),
            ),
            HotspotButton(
              key: const ValueKey('hotspot'),
              onChange: (w) async {
                setState(() => wifi = w);
                await _start(); // a new code with the hotspot's address in it
              },
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: const Color(0x10FFFFFF), borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: rows),
            ),
            const SizedBox(height: 12),
            if (st != null)
              TextButton.icon(
                onPressed: () => shareQr(st!['ticket'], tr.syncShareText(widget.name, _left())),
                icon: const Icon(Icons.ios_share),
                label: Text(tr.syncShareButton),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _start, child: Text(tr.syncNewCode)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr.syncEnd)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({required this.name, required this.label, required this.color, this.title});
  final String name, label;
  final String? title;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: Row(
      children: [
        Avatar(name, size: 36, dark: true),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title ?? name,
            style: const TextStyle(fontFamily: NV.sans, fontSize: 15, fontWeight: FontWeight.w500, color: NV.dText),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontFamily: NV.sans, fontSize: 14, color: color),
        ),
      ],
    ),
  );
}

/// Member side: scanned a sync code.
class SyncJoinScreen extends StatefulWidget {
  const SyncJoinScreen({super.key, required this.ticket});
  final String ticket;
  @override
  State<SyncJoinScreen> createState() => _SyncJoinScreenState();
}

class _SyncJoinScreenState extends State<SyncJoinScreen> {
  Map<String, dynamic>? st;
  Timer? poll;
  String? err;

  @override
  void initState() {
    super.initState();
    Core.call('sync_join', {'ticket': widget.ticket})
        .then((s) {
          setState(() => st = s);
          poll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
            try {
              final s = await Core.call('sync_join_status') as Map<String, dynamic>;
              if (mounted) setState(() => st = s);
            } catch (_) {}
          });
        })
        .catchError((e) => setState(() => err = errText(e)));
  }

  @override
  void dispose() {
    poll?.cancel();
    Core.call('sync_stop').catchError((_) => null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NV.dark().textTheme; // this screen sits inside DarkZone
    final s = st?['state'] ?? (err != null ? 'error' : 'connecting');
    final host = st?['host'] ?? '';
    final (icon, color, title, text) = switch (s) {
      'connecting' => (Icons.wifi_tethering, NV.dText, tr.syncJoinConnecting('$host'), tr.syncJoinConnectingHint),
      'syncing' => (Icons.sync, NV.dRun, tr.syncJoinSyncing('$host'), tr.syncJoinCounts('${st?['received'] ?? 0}', '${st?['sent'] ?? 0}')),
      'done' => (
        Icons.check_circle_outline,
        NV.dOk,
        tr.syncJoinDone('$host'),
        tr.syncJoinDoneBody('${st?['received'] ?? 0}', '${st?['sent'] ?? 0}'),
      ),
      'closed' => (
        Icons.link_off,
        NV.dWait,
        tr.syncJoinClosed,
        tr.syncJoinCounts('${st?['received'] ?? 0}', '${st?['sent'] ?? 0}'),
      ),
      _ => (Icons.error_outline, NV.dBad, tr.syncJoinFailed, err ?? coreErrorText('${st?['error']}')),
    };
    return DarkZone(
      child: Scaffold(
        appBar: AppBar(leading: const CloseButton(), title: const Text('Sync')),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            children: [
              if (s == 'connecting' || s == 'syncing' || s == 'done')
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: SyncPath(
                    via: '${st?['via'] ?? ''}',
                    moving: s != 'done',
                    searching: s == 'connecting',
                    connected: s == 'done',
                    peer: '$host',
                  ),
                )
              else ...[
                Icon(icon, size: 56, color: color),
                const SizedBox(height: 18),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (s == 'done') ...[Icon(icon, size: 24, color: color), const SizedBox(width: 8)],
                  Flexible(child: Text(title, style: t.headlineSmall, textAlign: TextAlign.center)),
                ],
              ),
              const SizedBox(height: 8),
              Text(text, style: t.bodySmall, textAlign: TextAlign.center),
              const Spacer(),
              TextButton(onPressed: () => showSyncHow(context), child: Text(tr.syncHowButton)),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(s == 'done' ? tr.syncDone : tr.syncClose)),
          ),
        ),
      ),
    );
  }
}

/// "How sync works": the path picture and the no-server explanation.
Future<void> showSyncHow(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: NV.ground,
  showDragHandle: true,
  builder: (_) => DarkZone(
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.syncHowTitle, style: NV.dark().textTheme.headlineSmall),
            const SizedBox(height: 20),
            const SyncPath(),
            const SizedBox(height: 20),
            Text(tr.syncHowBody, style: NV.dark().textTheme.bodyMedium),
          ],
        ),
      ),
    ),
  ),
);
