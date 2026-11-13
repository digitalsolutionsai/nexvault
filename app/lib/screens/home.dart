import 'package:flutter/material.dart';

import '../core/bridge.dart';
import '../l10n/l10n.dart';
import '../ui/seal.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ceremony.dart';
import 'scan.dart';
import 'settings.dart';
import 'workspace.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onLock, required this.onWiped});
  final VoidCallback onLock, onWiped;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic>? items;
  Map<String, dynamic>? me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await Core.call('workspaces') as List<dynamic>;
      final m = await Core.call('me') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        items = w;
        me = m;
      });
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.homeCreateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.homeCreateBody),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: tr.homeWorkspaceName),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.homeCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr.homeCreateInvite)),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) _go(CeremonyHostScreen(name: name.text.trim()));
  }

  String _syncLine(Map<String, dynamic> w) {
    final others = (w['members'] as List).where((m) => m['me'] != true).toList();
    int? best;
    String? who;
    for (final m in others) {
      final t = m['last_sync'] as int?;
      if (t != null && (best == null || t > best)) {
        best = t;
        who = m['name'] as String;
      }
    }
    if (best == null) return tr.homeNotSynced;
    return tr.homeSyncedWith(who!, timeAgo(best));
  }

  bool _stale(Map<String, dynamic> w) {
    final ts = (w['members'] as List).where((m) => m['me'] != true).map((m) => m['last_sync'] as int?).whereType<int>();
    if (ts.isEmpty) return true;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts.reduce((a, b) => a > b ? a : b))).inDays >= 14;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          tr.homeTitle,
          style: TextStyle(fontFamily: NV.sans, fontSize: 26, fontWeight: FontWeight.w700, color: NV.ink),
        ),
        actions: [
          IconButton(
            tooltip: tr.homeSettings,
            onPressed: () => _go(SettingsScreen(onWiped: widget.onWiped)),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(tooltip: tr.homeLockApp, onPressed: widget.onLock, icon: const Icon(Icons.lock_outline)),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            if (items != null && items!.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 48, 8, 0),
                child: Column(
                  children: [
                    const Icon(Icons.groups_2_outlined, size: 48, color: NV.ink2),
                    const SizedBox(height: 16),
                    Text(tr.homeEmptyTitle, style: t.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      tr.homeEmptyBody,
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final w in (items ?? []).cast<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: NV.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _go(WorkspaceScreen(id: w['id'])),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Seal(w['seal'], size: 56),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w['name'],
                                  style: const TextStyle(fontFamily: NV.sans, fontSize: 17, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  w['pending'] == true
                                      ? tr.homePendingApproval
                                      : w['needs_action'] == true
                                      ? tr.homeNeedsAction
                                      : tr.homeCounts((w['members'] as List).length, w['secret_count'] as int),
                                  style: t.bodySmall!.copyWith(
                                    color: w['needs_action'] == true ? NV.verdigris : null,
                                    fontWeight: w['needs_action'] == true ? FontWeight.w600 : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(_stale(w) ? Icons.error_outline : Icons.sync, size: 15, color: _stale(w) ? NV.warn : NV.ink2),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _syncLine(w),
                                        style: t.bodySmall!.copyWith(
                                          color: _stale(w) ? NV.warn : NV.ink2,
                                          fontWeight: _stale(w) ? FontWeight.w500 : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
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
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (me != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(tr.homeYouAre(me!['name'], me!['device']), style: t.bodySmall),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _create,
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text(tr.homeCreateWorkspace, maxLines: 1)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _go(const ScanScreen()),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text(tr.homeScanCode, maxLines: 1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
