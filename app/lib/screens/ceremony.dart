import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bridge.dart';
import '../core/keys.dart';
import '../l10n/l10n.dart';
import '../ui/seal.dart';
import '../ui/theme.dart';
import '../ui/hotspot.dart';
import '../ui/widgets.dart';
import 'workspace.dart';

/// Creator side of the in-person ceremony.
class CeremonyHostScreen extends StatefulWidget {
  const CeremonyHostScreen({super.key, required this.name, this.ws});
  final String name;

  /// set when inviting new members into an existing workspace
  final String? ws;
  @override
  State<CeremonyHostScreen> createState() => _CeremonyHostScreenState();
}

class _CeremonyHostScreenState extends State<CeremonyHostScreen> {
  String? invite;
  Map<String, dynamic>? st;
  Timer? poll;
  bool finishing = false;
  String? err;

  Map<String, dynamic>? wifi; // this phone's private Wi-Fi, when started

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      await Keys.refreshNet();
      final r = await Core.call('ceremony_create', {'name': widget.name, if (widget.ws != null) 'ws': widget.ws});
      if (!mounted) return;
      setState(() => invite = r['invite']);
      poll?.cancel();
      poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _refresh());
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  /// A new invite that carries the hotspot's address (only before anyone has scanned).
  Future<void> _reopen(Map<String, dynamic>? w) async {
    poll?.cancel();
    setState(() {
      wifi = w;
      invite = null;
      st = null;
    });
    await Core.call('ceremony_cancel').catchError((_) => null);
    await _open();
  }

  Future<void> _refresh() async {
    try {
      final s = await Core.call('ceremony_status') as Map<String, dynamic>;
      if (mounted) setState(() => st = s);
    } catch (_) {}
  }

  @override
  void dispose() {
    poll?.cancel();
    if (!finishing) Core.call('ceremony_cancel').catchError((_) => null);
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => finishing = true);
    poll?.cancel();
    try {
      final r = await Core.call('ceremony_finish');
      if (!mounted) return;
      if (widget.ws != null) {
        toast(context, tr.ceremonyProposalSent);
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WorkspaceScreen(id: r['ws'])));
    } catch (e) {
      setState(() {
        finishing = false;
        err = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NV.dark().textTheme; // this screen sits inside DarkZone
    final joiners = ((st?['joiners'] as List?) ?? []).cast<Map<String, dynamic>>();
    final accepted = joiners.where((j) => j['accepted'] == true).length;
    return DarkZone(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.ws == null ? tr.ceremonyCreateTitle(widget.name) : tr.ceremonyInviteTitle(widget.name))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              widget.ws == null
                  ? tr.ceremonyStep1Create
                  : tr.ceremonyStep1Invite,
              style: t.bodySmall,
            ),
            const SizedBox(height: 16),
            if (invite != null) Center(child: QrCard(withWifi(invite!, wifi), size: 240)),
            if (invite == null && err == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(err!, style: const TextStyle(color: NV.dBad)),
              ),
            const SizedBox(height: 22),
            if (joiners.isNotEmpty) Text(tr.ceremonyStep2Host, style: t.titleMedium),
            if (joiners.isEmpty && (invite != null || wifi != null))
              Padding(padding: const EdgeInsets.only(bottom: 14), child: HotspotButton(onChange: _reopen)),
            if (joiners.isEmpty && invite != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NV.dSub)),
                  const SizedBox(width: 10),
                  Text(tr.ceremonyWaitingScan, style: t.bodySmall),
                ],
              ),
            for (final j in joiners)
              _JoinerRow(j: j, onAccept: (ok) => Core.call('ceremony_accept', {'pk': j['pk'], 'ok': ok}).then((_) => _refresh())),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: accepted == 0 || finishing ? null : _finish,
              child: Text(
                finishing
                    ? tr.ceremonyFinishing
                    : accepted == 0
                    ? tr.ceremonyWaitVerify
                    : widget.ws == null
                    ? tr.ceremonyFinishWith(accepted + 1)
                    : tr.ceremonyProposeAdd(accepted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinerRow extends StatelessWidget {
  const _JoinerRow({required this.j, required this.onAccept});
  final Map<String, dynamic> j;
  final void Function(bool) onAccept;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final verified = j['verified'] == true, failed = j['failed'] == true, accepted = j['accepted'] == true;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0x10FFFFFF), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(j['name'], size: 36, dark: true),
              const SizedBox(width: 12),
              Expanded(child: Text(j['name'], style: t.titleMedium)),
              Text(
                failed
                    ? tr.ceremonyWrongCode
                    : accepted
                    ? tr.ceremonyWillBeAdded
                    : verified
                    ? tr.ceremonyPickedRight
                    : tr.ceremonyWaitingPick,
                style: TextStyle(
                  fontSize: 14,
                  color: failed
                      ? NV.dBad
                      : verified
                      ? NV.dOk
                      : NV.dRun,
                ),
              ),
            ],
          ),
          if (!verified && !failed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Seal(j['seal'], size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        j['code'],
                        style: const TextStyle(
                          fontFamily: NV.mono,
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          color: NV.dText,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(tr.ceremonyReadAloud(j['name']), style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr.ceremonyMismatchHost, style: t.bodySmall),
            ),
          if (verified && !accepted) ...[
            const SizedBox(height: 12),
            Text(tr.ceremonyIsThisPerson(j['name']), style: t.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => onAccept(false), child: Text(tr.ceremonyNotThem)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(onPressed: () => onAccept(true), child: Text(tr.ceremonyRightPerson)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Joiner side: pick the code the creator reads aloud, then wait for the charter.
class CeremonyJoinScreen extends StatefulWidget {
  const CeremonyJoinScreen({super.key, required this.invite});
  final String invite;
  @override
  State<CeremonyJoinScreen> createState() => _CeremonyJoinScreenState();
}

class _CeremonyJoinScreenState extends State<CeremonyJoinScreen> {
  Map<String, dynamic>? st;
  Timer? poll;
  String? err;

  @override
  void initState() {
    super.initState();
    Core.call('ceremony_join', {'invite': widget.invite})
        .then((s) {
          setState(() => st = s);
          poll = Timer.periodic(const Duration(milliseconds: 400), (_) => _refresh());
        })
        .catchError((e) => setState(() => err = errText(e)));
  }

  Future<void> _refresh() async {
    try {
      final s = await Core.call('ceremony_join_status') as Map<String, dynamic>;
      if (mounted) setState(() => st = s);
      if (s['state'] == 'done' || s['state'] == 'aborted' || s['state'] == 'error') poll?.cancel();
    } catch (_) {}
  }

  @override
  void dispose() {
    poll?.cancel();
    final s = st?['state'];
    if (s != 'done') Core.call('ceremony_cancel').catchError((_) => null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NV.dark().textTheme; // this screen sits inside DarkZone
    final s = st?['state'] ?? 'connecting';
    final creator = st?['creator'] ?? '';
    Widget body;
    if (err != null || s == 'error') {
      body = _Msg(icon: Icons.error_outline, color: NV.dBad, title: tr.ceremonyJoinFailed, text: err ?? coreErrorText('${st?['error']}'));
    } else if (s == 'connecting') {
      body = _Msg(
        icon: Icons.wifi_tethering,
        title: tr.ceremonyConnecting(creator),
        text: tr.ceremonySameWifi(creator),
        busy: true,
      );
    } else if (s == 'verify') {
      final choices = (st!['choices'] as List).cast<String>();
      body = Column(
        children: [
          Text(tr.ceremonyVerifyStep(creator), style: t.bodySmall),
          const SizedBox(height: 16),
          Seal(st!['seal'], size: 132),
          const SizedBox(height: 18),
          Text(tr.ceremonyPickCode(creator), style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(tr.ceremonySealMatch, style: t.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          for (final c in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(58)),
                onPressed: () async {
                  final r = await Core.call('ceremony_pick', {'code': c});
                  if (r['correct'] != true) _refresh();
                },
                child: Text(
                  c,
                  style: const TextStyle(fontFamily: NV.mono, fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: 2),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: NV.dBad,
              side: const BorderSide(color: Color(0x99F0A39A), width: 1.5),
            ),
            onPressed: () => Core.call('ceremony_pick', {'code': 'none'}).then((_) => _refresh()),
            child: Text(tr.ceremonyNoneMatch),
          ),
        ],
      );
    } else if (s == 'waiting') {
      body = _Msg(
        icon: Icons.verified_outlined,
        color: NV.dOk,
        title: tr.ceremonyVerified,
        text: tr.ceremonyWaitFinish(creator),
        busy: true,
      );
    } else if (s == 'aborted') {
      body = _Msg(
        icon: Icons.gpp_bad_outlined,
        color: NV.dBad,
        title: tr.ceremonyStopped,
        text: tr.ceremonyAbortedBody(creator),
      );
    } else {
      body = Column(
        children: [
          _Msg(
            icon: Icons.check_circle_outline,
            color: NV.dOk,
            title: tr.ceremonyJoined('${st!['ws_name']}'),
            text: tr.ceremonyStep3Done,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WorkspaceScreen(id: st!['ws']))),
            child: Text(tr.ceremonyOpenWorkspace),
          ),
        ],
      );
    }
    return DarkZone(
      child: Scaffold(
        appBar: AppBar(leading: const CloseButton(), title: Text(st?['ws_name'] ?? tr.ceremonyJoinTitle)),
        body: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: body),
        ),
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  const _Msg({required this.icon, required this.title, required this.text, this.color = NV.dText, this.busy = false});
  final IconData icon;
  final String title, text;
  final Color color;
  final bool busy;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(
      children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(text, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: CircularProgressIndicator(color: NV.dText),
          ),
      ],
    ),
  );
}
