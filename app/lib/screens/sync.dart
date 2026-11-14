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
  bool hotspot = false; // this phone can start one

  @override
  void initState() {
    super.initState();
    _start();
    Keys.hotspotSupported().then((v) {
      if (mounted) setState(() => hotspot = v);
    });
  }

  /// Far-away members: say once what sending the picture means, then share it.
  Future<void> _share() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr.syncShareTitle),
        content: Text(tr.syncShareBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr.syncShareGo)),
        ],
      ),
    );
    if (go == true && st != null) await shareQr(st!['ticket'], tr.syncShareText(widget.name, _left()));
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
    final chips = <Widget>[];
    for (final m in others) {
      final p = peers.where((x) => x['pk'] == m['pk']).firstOrNull;
      final state = switch (p?['state']) {
        'done' => _Peer.done,
        'syncing' => _Peer.syncing,
        'left' => _Peer.left,
        _ => _Peer.waiting,
      };
      chips.add(_PeerChip(name: m['name'], state: state));
    }
    // devices that joined but were not in the member list when this screen opened (newcomers)
    for (final p in peers.where((p) => p['state'] == 'removed')) {
      chips.add(_PeerChip(name: p['name'] ?? '?', title: tr.syncPeerRemovedName('${p['name']}'), state: _Peer.rejected));
    }
    for (final p in peers.where((p) => !['rejected', 'removed'].contains(p['state']) && !others.any((m) => m['pk'] == p['pk']))) {
      final state = switch (p['state']) {
        'done' => _Peer.done,
        'left' => _Peer.left,
        _ => _Peer.syncing,
      };
      chips.add(_PeerChip(name: p['name'] ?? '?', title: tr.syncPeerNewMember('${p['name'] ?? '?'}'), state: state));
    }
    final strangers = peers.where((p) => p['state'] == 'rejected').length;
    if (strangers > 0) chips.add(_PeerChip(name: tr.syncStrangers(strangers), mark: '?', state: _Peer.rejected));

    return DarkZone(
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(tr.syncHostTitle(widget.name)),
          actions: [IconButton(tooltip: tr.syncHowTitle, onPressed: () => showSyncHow(context), icon: const Icon(Icons.help_outline))],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          children: [
            // every child above the Wi-Fi button is always present, so its place in the list
            // (and the running hotspot it owns) never moves
            err != null ? Text(err!, style: const TextStyle(color: NV.dBad)) : const SizedBox.shrink(),
            if (st == null) const SizedBox.shrink() else
              Center(
                child: Opacity(opacity: accepting ? 1 : .25, child: QrCard(withWifi(st!['ticket'], wifi), size: 250)),
              ),
            const SizedBox(height: 12),
            if (st == null) const SizedBox.shrink() else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: accepting
                    ? [
                        Text(tr.syncScanHint, style: t.bodyMedium?.copyWith(color: NV.dText)),
                        const SizedBox(width: 12),
                        SizedBox.square(
                          dimension: 16,
                          child: ExcludeSemantics(child: CircularProgressIndicator(value: _frac(), strokeWidth: 2.5, color: NV.dText, backgroundColor: const Color(0x40FFFFFF))),
                        ),
                        const SizedBox(width: 6),
                        Text(_left(), style: const TextStyle(fontFamily: NV.mono, fontSize: 17, color: NV.dText)),
                      ]
                    : [Flexible(child: Text(tr.syncExpired, style: t.bodySmall, textAlign: TextAlign.center))],
              ),
            const SizedBox(height: 6),
            NetLine(wifi: wifi, plain: tr.netDirect, onInfo: () => showSyncHow(context)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hotspot) ...[
                  HotspotButton(
                    key: const ValueKey('hotspot'),
                    onChange: (w) async {
                      setState(() => wifi = w);
                      await _start(); // a new code with the hotspot's address in it
                    },
                  ),
                  const SizedBox(width: 24),
                ],
                ActionTile(icon: Icons.ios_share, label: tr.syncShareShort, onTap: st == null || !accepting ? null : _share),
              ],
            ),
            const SizedBox(height: 18),
            if (chips.isNotEmpty)
              Container(
                decoration: BoxDecoration(color: const Color(0x10FFFFFF), borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Wrap(spacing: 10, runSpacing: 12, children: chips),
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

enum _Peer { waiting, syncing, done, left, rejected }

/// A member as a face with a small badge for where their sync stands; the words are in the
/// tooltip and for screen readers.
class _PeerChip extends StatelessWidget {
  const _PeerChip({required this.name, required this.state, this.title, this.mark});
  final String name;
  final String? title, mark; // mark: the avatar's letter, when not the name's first
  final _Peer state;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _Peer.done => (tr.syncPeerDone, NV.dOk),
      _Peer.syncing => (tr.syncPeerSyncing, NV.dRun),
      _Peer.left => (tr.syncPeerLeft, NV.dWait),
      _Peer.rejected => (tr.syncPeerRejected, NV.dBad),
      _Peer.waiting => (tr.syncPeerNotScanned, NV.dWait),
    };
    final badge = switch (state) {
      _Peer.syncing => Padding(padding: const EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2, color: color)),
      _ => Icon(
        switch (state) {
          _Peer.done => Icons.check,
          _Peer.left => Icons.logout,
          _Peer.rejected => Icons.block,
          _ => Icons.schedule,
        },
        size: 13,
        color: state == _Peer.done ? NV.dark().scaffoldBackgroundColor : color,
      ),
    };
    final who = title ?? name;
    return Tooltip(
      message: '$who: $label',
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: '$who: $label',
        excludeSemantics: true,
        child: SizedBox(
          width: 66,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(opacity: state == _Peer.waiting || state == _Peer.left ? .55 : 1, child: Avatar(mark ?? name, size: 48, dark: true)),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: state == _Peer.done ? color : NV.dark().scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: state == _Peer.done ? color : const Color(0x40FFFFFF), width: 1.5),
                      ),
                      child: badge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: NV.sans, fontSize: 12.5, color: state == _Peer.rejected ? NV.dBad : NV.dText),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
