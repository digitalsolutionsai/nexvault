import 'package:flutter/material.dart';

import '../core/bridge.dart';
import '../l10n/l10n.dart';
import '../ui/seal.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ceremony.dart';
import 'secret.dart';
import 'sync.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.id});
  final String id;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  Map<String, dynamic>? w;
  String q = '';
  String? folder; // current folder id, null = root

  @override
  void initState() {
    super.initState();
    _load(maintain: true);
  }

  Future<void> _load({bool maintain = false}) async {
    try {
      if (maintain) {
        // supply keys for membership changes that reached their threshold without them
        await Core.call('maintain', {'ws': widget.id}).catchError((_) => null);
      }
      final r = await Core.call('workspace', {'ws': widget.id}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        w = r;
        if (folder != null && !folders.any((f) => f['id'] == folder)) folder = null;
      });
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _go(Widget p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => p));
    _load(maintain: true);
  }

  List<Map<String, dynamic>> get members => ((w?['members'] as List?) ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get folders => ((w?['folders'] as List?) ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get secrets => ((w?['secrets'] as List?) ?? []).cast<Map<String, dynamic>>();
  bool get canWrite => w?['can_read'] == true && w?['is_member'] == true && w?['stale'] != true;

  Map<String, dynamic>? _folder(String? id) => id == null ? null : folders.where((f) => f['id'] == id).firstOrNull;

  List<Map<String, dynamic>> _crumbs() {
    final out = <Map<String, dynamic>>[];
    var f = _folder(folder);
    final seen = <String>{};
    while (f != null && seen.add(f['id'])) {
      out.insert(0, f);
      f = _folder(f['parent']);
    }
    return out;
  }

  int _countIn(String id) {
    var n = secrets.where((s) => s['folder'] == id).length;
    for (final c in folders.where((f) => f['parent'] == id)) {
      n += _countIn(c['id']);
    }
    return n;
  }

  Future<String?> _askName(String title, {String initial = '', String? action}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(d, v.trim()),
          decoration: InputDecoration(labelText: tr.workspaceFolderName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tr.workspaceCancel)),
          TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(action ?? tr.workspaceSave)),
        ],
      ),
    );
  }

  Future<void> _newFolder() async {
    final name = await _askName(tr.workspaceNewFolder, action: tr.workspaceCreate);
    if (name == null || name.isEmpty) return;
    try {
      await Core.call('put_folder', {'ws': widget.id, 'name': name, if (folder != null) 'parent': folder});
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _folderMenu(Map<String, dynamic> f) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr.workspaceRename), onTap: () => Navigator.pop(ctx, 'rename')),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: Text(tr.workspaceMoveFolder),
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: NV.danger),
              title: Text(tr.workspaceDeleteFolder, style: const TextStyle(color: NV.danger)),
              subtitle: Text(tr.workspaceDeleteFolderHint),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    try {
      if (v == 'rename') {
        final name = await _askName(tr.workspaceRenameFolder, initial: f['name']);
        if (name == null || name.isEmpty) return;
        await Core.call('put_folder', {'ws': widget.id, 'id': f['id'], 'name': name, if (f['parent'] != null) 'parent': f['parent']});
      } else if (v == 'move') {
        if (!mounted) return;
        final dest = await pickFolder(context, folders, exclude: f['id'], current: f['parent']);
        if (dest == null) return;
        await Core.call('put_folder', {'ws': widget.id, 'id': f['id'], 'name': f['name'], if (dest.isNotEmpty) 'parent': dest});
      } else if (v == 'delete') {
        await Core.call('delete_folder', {'ws': widget.id, 'id': f['id']});
      }
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  void _membersSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(tr.workspaceMembers, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  tr.workspaceMembersRule,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ),
              for (final m in members)
                ListTile(
                  leading: Avatar(m['name'], size: 40, me: m['me'] == true),
                  title: Text(m['me'] == true ? tr.workspaceMemberYou(m['name']) : m['name']),
                  subtitle: Text(m['me'] == true ? tr.workspaceThisDevice : tr.workspaceMemberSynced(timeAgo(m['last_sync']))),
                  trailing: m['me'] == true || !canWrite
                      ? null
                      : TextButton(
                          style: TextButton.styleFrom(foregroundColor: NV.danger),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _proposeRemove(m);
                          },
                          child: Text(tr.workspaceProposeRemoval),
                        ),
                ),
              if (canWrite)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _go(CeremonyHostScreen(name: w!['name'], ws: widget.id));
                    },
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(tr.workspaceInviteMember),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _proposeRemove(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr.workspaceProposeRemoveTitle(m['name'])),
        content: Text(tr.workspaceProposeRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.workspaceCancel)),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr.workspaceProposeRemoval)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Core.call('propose_remove', {'ws': widget.id, 'member': m['pk']});
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  String? _expiry(Map<String, dynamic> s) {
    for (final f in (s['fields'] as List)) {
      if (f[0] == 'Hết hạn') {
        final d = DateTime.tryParse(f[1] as String);
        if (d == null) return null;
        final days = d.difference(DateTime.now()).inDays;
        if (days < 0) return tr.workspaceExpired;
        if (days <= 30) return tr.workspaceExpiresIn(days);
      }
    }
    return null;
  }

  String _subtitle(Map<String, dynamic> s) {
    if (s['conflict'] == true) return tr.workspaceConflict;
    if (s['file_name'] != null) return s['file_name'];
    final f = (s['fields'] as List).where((x) => !(x[0] as String).startsWith('*') && x[1] != '').toList();
    String? val(String label) => f.where((x) => x[0] == label).map((x) => x[1] as String).firstOrNull;
    // a login is recognised by who signs in, a Wi-Fi by its network name
    final plain = switch (s['kind']) {
      'login' => val('Tên đăng nhập') ?? val('Trang web'),
      'wifi' => val('Tên Wi-Fi'),
      _ => null,
    };
    if (plain != null) return plain;
    if (f.isNotEmpty) return '${fieldLabel(f.first[0])}: ${f.first[1]}';
    return tr.workspaceVersionDate('${s['version']}', shortDate(s['ts']));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (w == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final searching = q.isNotEmpty;
    final readable = w!['can_read'] == true;
    final visibleFolders = searching ? <Map<String, dynamic>>[] : folders.where((f) => f['parent'] == folder).toList();
    final visibleSecrets = searching
        ? secrets.where((s) => (s['name'] as String).toLowerCase().contains(q.toLowerCase())).toList()
        : secrets.where((s) => s['folder'] == folder).toList();
    final proposals = ((w!['proposals'] as List?) ?? []).cast<Map<String, dynamic>>();
    final crumbs = _crumbs();

    return PopScope(
      canPop: folder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => folder = _folder(folder)?['parent']);
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(tooltip: tr.workspaceMembers, onPressed: _membersSheet, icon: const Icon(Icons.group_outlined)),
            const SizedBox(width: 6),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _load(maintain: true),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Seal(w!['seal'], size: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w!['name'], style: t.headlineSmall),
                          Text(w!['last_change'] == 0 ? tr.workspaceJustCreated : tr.workspaceUpdated(timeAgo(w!['last_change'])), style: t.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final m in members)
                      SizedBox(
                        width: 84,
                        child: Column(
                          children: [
                            Avatar(m['name'], me: m['me'] == true),
                            const SizedBox(height: 6),
                            Text(
                              m['me'] == true ? tr.workspaceMemberYouShort(m['name']) : '${m['name']}\n${_memberSync(m['last_sync'])}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall!.copyWith(
                                fontSize: 13,
                                height: 1.3,
                                color: _old(m) ? NV.warn : NV.ink2,
                                fontWeight: _old(m) ? FontWeight.w500 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (w!['pending'] == true)
                _banner(tr.workspacePendingBanner, NV.verdigris),
              if (w!['stale'] == true)
                _banner(tr.workspaceStaleBanner, NV.warn),
              if (w!['removed'] == true) _banner(tr.workspaceRemovedBanner, NV.danger),
              for (final p in proposals) _proposal(p),
              if (readable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: TextField(
                    onChanged: (v) => setState(() => q = v.trim()),
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr.workspaceSearchHint(secrets.length)),
                  ),
                ),
              if (!searching && crumbs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => folder = null),
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: Text(tr.workspaceAll),
                        ),
                        for (final c in crumbs) ...[
                          const Icon(Icons.chevron_right, size: 18, color: NV.ink2),
                          TextButton(onPressed: () => setState(() => folder = c['id']), child: Text(c['name'])),
                        ],
                      ],
                    ),
                  ),
                ),
              if (readable)
                for (final f in visibleFolders)
                  InkWell(
                    onTap: () => setState(() => folder = f['id']),
                    onLongPress: canWrite ? () => _folderMenu(f) : null,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: NV.line)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: const Color(0xFFDCE8E4), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.folder_outlined, color: NV.verdigris),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f['name'],
                                  style: const TextStyle(fontFamily: NV.sans, fontSize: 15.5, fontWeight: FontWeight.w600),
                                ),
                                Text(tr.workspaceSecretCount(_countIn(f['id'])), style: t.bodySmall),
                              ],
                            ),
                          ),
                          if (canWrite)
                            IconButton(tooltip: tr.workspaceFolderOptions, onPressed: () => _folderMenu(f), icon: const Icon(Icons.more_vert)),
                        ],
                      ),
                    ),
                  ),
              if (secrets.isEmpty && folders.isEmpty && w!['pending'] != true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                  child: Text(
                    tr.workspaceEmpty,
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                ),
              if (!searching && visibleFolders.isEmpty && visibleSecrets.isEmpty && folder != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                  child: Text(tr.workspaceFolderEmpty, textAlign: TextAlign.center, style: t.bodySmall),
                ),
              if (readable)
                for (final s in visibleSecrets) _secretRow(s, t),
              if (canWrite)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _newFolder,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: Text(tr.workspaceNewFolder),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canWrite ? () => _go(EditSecretScreen(ws: widget.id, folder: folder, folders: folders)) : null,
                    child: Text(tr.workspaceAddSecret),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: w!['removed'] == true ? null : () => _go(SyncHostScreen(ws: widget.id, name: w!['name'], members: members)),
                    icon: const Icon(Icons.sync),
                    label: Text(tr.workspaceOpenSync),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secretRow(Map<String, dynamic> s, TextTheme t) {
    final warn = _expiry(s) != null || s['conflict'] == true;
    final path = q.isNotEmpty && s['folder'] != null ? _pathName(s['folder']) : null;
    return InkWell(
      onTap: () => _go(SecretScreen(ws: widget.id, id: s['id'], folders: folders)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: NV.line)),
        ),
        child: Row(
          children: [
            FileBadge(s['kind']),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['name'],
                    style: const TextStyle(fontFamily: NV.sans, fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path ?? _expiry(s) ?? _subtitle(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall!.copyWith(
                      color: warn && path == null ? NV.warn : NV.ink2,
                      fontWeight: warn && path == null ? FontWeight.w500 : null,
                      fontFamily: s['file_name'] != null && !warn && path == null ? NV.mono : NV.sans,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pathName(String id) {
    final names = <String>[];
    var f = _folder(id);
    final seen = <String>{};
    while (f != null && seen.add(f['id'])) {
      names.insert(0, f['name']);
      f = _folder(f['parent']);
    }
    return names.join(' / ');
  }

  Widget _banner(String text, Color c) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.withValues(alpha: .4)),
    ),
    child: Text(
      text,
      style: const TextStyle(fontFamily: NV.sans, fontSize: 14.5, color: NV.ink, height: 1.4),
    ),
  );

  /// Compact age for the avatar row (fits ~84 px).
  String _memberSync(int? ms) {
    if (ms == null) return tr.workspaceNeverSynced;
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return tr.workspaceJustNow;
    if (d.inHours < 1) return tr.workspaceMinutesShort(d.inMinutes);
    if (d.inDays < 1) return tr.workspaceHoursShort(d.inHours);
    return tr.workspaceDaysShort(d.inDays);
  }

  bool _old(Map<String, dynamic> m) {
    if (m['me'] == true) return false;
    final ms = m['last_sync'] as int?;
    return ms == null || DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms)).inDays >= 14;
  }

  Widget _proposal(Map<String, dynamic> p) {
    final add = p['kind'] == 'add';
    final text = add
        ? tr.workspaceProposalAdd('${p['proposer'] ?? '?'}', '${p['name']}', '${p['approvals']}', '${p['needed']}')
        : tr.workspaceProposalRemove('${p['name']}', '${p['approvals']}', '${p['needed']}');
    final color = add ? NV.verdigris : NV.danger;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p['needs_keys'] == true ? tr.workspaceProposalAwaitingKeys(text) : text,
              style: const TextStyle(fontFamily: NV.sans, fontSize: 14.5, color: NV.ink, height: 1.35),
            ),
          ),
          if (p['can_approve'] == true)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: color),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text(add ? tr.workspaceApproveAddTitle('${p['name']}') : tr.workspaceApproveRemoveTitle('${p['name']}')),
                    content: Text(
                      add
                          ? tr.workspaceApproveAddBody('${p['proposer']}', '${p['name']}')
                          : tr.workspaceApproveRemoveBody('${p['name']}'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.workspaceCancel)),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr.workspaceApprove)),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await Core.call('approve', {'ws': widget.id, 'proposal': p['id']});
                  _load();
                } catch (e) {
                  if (mounted) toast(context, errText(e), error: true);
                }
              },
              child: Text(tr.workspaceApprove),
            ),
        ],
      ),
    );
  }
}

/// Folder chooser. Returns '' for the root, a folder id, or null if cancelled.
Future<String?> pickFolder(BuildContext context, List<Map<String, dynamic>> folders, {String? exclude, String? current}) {
  // exclude a folder and everything below it (moving a folder into itself)
  final banned = <String>{};
  if (exclude != null) {
    banned.add(exclude);
    var grew = true;
    while (grew) {
      grew = false;
      for (final f in folders) {
        if (!banned.contains(f['id']) && banned.contains(f['parent'])) {
          banned.add(f['id']);
          grew = true;
        }
      }
    }
  }
  String label(Map<String, dynamic> f) {
    final names = <String>[f['name']];
    var p = f['parent'];
    final seen = <String>{};
    while (p != null && seen.add(p)) {
      final pf = folders.where((x) => x['id'] == p).firstOrNull;
      if (pf == null) break;
      names.insert(0, pf['name']);
      p = pf['parent'];
    }
    return names.join(' / ');
  }

  final options = folders.where((f) => !banned.contains(f['id'])).map((f) => (f['id'] as String, label(f))).toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(tr.workspacePickFolder, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(tr.workspaceNoFolder),
              trailing: current == null ? const Icon(Icons.check, color: NV.verdigris) : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final o in options)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(o.$2),
                trailing: current == o.$1 ? const Icon(Icons.check, color: NV.verdigris) : null,
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
          ],
        ),
      ),
    ),
  );
}
