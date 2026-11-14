import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/bridge.dart';
import '../core/keys.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'workspace.dart' show pickFolder;

String _action(String a) => switch (a) {
  'created' => tr.secretActionCreated,
  'edited' => tr.secretActionEdited,
  'viewed' => tr.secretActionViewed,
  'copied' => tr.secretActionCopied,
  'exported' => tr.secretActionExported,
  _ => a,
};

/// Field labels are stored with the secret and synced to every member, so they stay as written
/// (Vietnamese for the built-in kinds); only what is shown on screen is translated.
String fieldLabel(String raw) => switch (raw) {
  'Mật khẩu .p12' => tr.secretFieldP12Password,
  'Hết hạn' => tr.secretFieldExpires,
  'Mật khẩu store' => tr.secretFieldStorePassword,
  'Mật khẩu key' => tr.secretFieldKeyPassword,
  'Máy chủ' => tr.secretFieldHost,
  'Trang web' => tr.secretFieldWebsite,
  'Tên đăng nhập' => tr.secretFieldUsername,
  'Tên Wi-Fi' => tr.secretFieldWifiName,
  _ => raw,
};

class SecretScreen extends StatefulWidget {
  const SecretScreen({super.key, required this.ws, required this.id, this.folders = const []});
  final String ws, id;
  final List<Map<String, dynamic>> folders;
  @override
  State<SecretScreen> createState() => _SecretScreenState();
}

class _SecretScreenState extends State<SecretScreen> {
  Map<String, dynamic>? s;
  Map<String, dynamic>? revealed; // kept only while on this screen and authenticated
  DateTime? authedUntil;
  bool showing = false;
  bool copyOn = true;
  int timed = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    Keys.copyEnabled().then((v) {
      if (mounted) setState(() => copyOn = v);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    revealed = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Core.call('secret', {'ws': widget.ws, 'id': widget.id}) as Map<String, dynamic>;
      if (mounted) setState(() => s = r);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  bool get authed => authedUntil != null && DateTime.now().isBefore(authedUntil!);

  /// Authenticate (biometric or PIN) and decrypt once; valid for 60 s on this screen.
  Future<bool> _ensure({String action = 'viewed'}) async {
    if (authed && revealed != null && action == 'viewed') return true;
    final ok = await reauth(context, tr.secretAuthToView(s?['name'] ?? 'secret'));
    if (!ok) return false;
    try {
      final r = await Core.call('reveal', {'ws': widget.ws, 'id': widget.id, 'action': action}) as Map<String, dynamic>;
      setState(() {
        revealed = r;
        authedUntil = DateTime.now().add(const Duration(seconds: 60));
      });
      _load();
      return true;
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
      return false;
    }
  }

  Future<void> _showFor10s() async {
    if (!await _ensure()) return;
    timer?.cancel();
    setState(() {
      showing = true;
      timed = 10;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => timed--);
      if (timed <= 0) {
        t.cancel();
        setState(() => showing = false);
      }
    });
  }

  /// The standard Wi-Fi QR (what phone cameras understand), shown after the same check as
  /// viewing the password and closed again after 60 seconds.
  Future<void> _wifiQr() async {
    final ssid = (s!['fields'] as List).where((f) => f[0] == 'Tên Wi-Fi').map((f) => f[1] as String).firstOrNull ?? '';
    if (ssid.isEmpty) return toast(context, tr.secretWifiNoName, error: true);
    if (!await _ensure()) return;
    final pass = revealed?['text'] as String? ?? '';
    if (!mounted) return;
    final close = Timer(const Duration(seconds: 60), () {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    });
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(ssid, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrCard(wifiQrPayload(ssid, pass), size: 240),
            const SizedBox(height: 12),
            Text(tr.secretWifiQrHint, textAlign: TextAlign.center, style: Theme.of(d).textTheme.bodySmall),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(tr.commonDone))],
      ),
    );
    close.cancel();
  }

  Future<void> _menu(String v) async {
    switch (v) {
      case 'copy':
        if (!await mayCopy(context) || !await _ensure(action: 'copied')) return;
        final text = revealed!['text'] as String?;
        if (text == null) {
          if (mounted) toast(context, tr.secretBinaryUseExport, error: true);
          return;
        }
        await Keys.copySensitive(s!['name'], text);
        if (mounted) toast(context, tr.secretCopiedAutoClear);
      case final String c when c.startsWith('copyf:'):
        await _copyField(c.substring(6));
      case 'export':
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(tr.secretExportTitle),
            content: Text(tr.secretExportBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.secretCancel)),
              TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr.secretExport)),
            ],
          ),
        );
        if (ok != true || !mounted || !await _ensure(action: 'exported')) return;
        final bytes = base64Decode(revealed!['content_b64']);
        final name = (revealed!['file_name'] as String?) ?? '${s!['name']}.txt';
        await Keys.away(() => FilePicker.saveFile(fileName: name, bytes: Uint8List.fromList(bytes)));
      case 'edit':
        if (!await _ensure()) return;
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditSecretScreen(ws: widget.ws, existing: s, content: revealed, folders: widget.folders),
          ),
        );
        setState(() => revealed = null);
        _load();
      case 'move':
        final dest = await pickFolder(context, widget.folders, current: s!['folder']);
        if (dest == null) return;
        try {
          await Core.call('move_secret', {'ws': widget.ws, 'id': widget.id, 'folder': dest});
          if (mounted) toast(context, tr.secretMoved);
          _load();
        } catch (e) {
          if (mounted) toast(context, errText(e), error: true);
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(tr.secretDeleteTitle(s!['name'])),
            content: Text(tr.secretDeleteBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.secretCancel)),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: NV.danger),
                onPressed: () => Navigator.pop(d, true),
                child: Text(tr.secretDelete),
              ),
            ],
          ),
        );
        if (ok == true) {
          await Core.call('delete_secret', {'ws': widget.ws, 'id': widget.id});
          if (mounted) Navigator.pop(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final fields = (s!['fields'] as List).where((f) => !(f[0] as String).startsWith('*')).toList();
    final visible = showing && revealed != null && authed;
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: tr.secretMore,
            onSelected: _menu,
            itemBuilder: (_) => [
              if (copyOn)
                PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    title: Text(s!['kind'] == 'login' || s!['kind'] == 'wifi' ? tr.secretCopyPassword : tr.secretCopyContent),
                    subtitle: Text(tr.secretAutoClear30),
                  ),
                ),
              // one entry per secret field, e.g. the .p12 or keystore password
              if (copyOn)
                for (final f in (s!['fields'] as List).where((f) => (f[0] as String).startsWith('*')))
                  PopupMenuItem(value: 'copyf:${f[0]}', child: Text(tr.secretCopyField(fieldLabel((f[0] as String).substring(1)).toLowerCase()))),
              PopupMenuItem(value: 'export', child: Text(tr.secretExport)),
              PopupMenuItem(value: 'edit', child: Text(tr.secretEdit)),
              PopupMenuItem(value: 'move', child: Text(tr.secretMoveFolder)),
              PopupMenuItem(
                value: 'delete',
                child: Text(tr.secretDelete, style: TextStyle(color: NV.danger)),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                FileBadge(s!['kind']),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s!['name'], style: t.headlineSmall),
                      Text(tr.secretSubtitle(s!['note'] == '' ? _kindName(s!['kind']) : s!['note'], '${s!['version']}'), style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s!['conflict'] == true) _conflict(),
          if (_folderName() != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: NV.ink2),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_folderName()!, style: t.bodySmall)),
                ],
              ),
            ),
          for (final f in fields)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 6, 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: NV.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fieldLabel(f[0]), style: t.bodySmall),
                        Text(f[1], style: const TextStyle(fontFamily: NV.mono, fontSize: 15)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr.secretCopyField(fieldLabel(f[0])),
                    icon: const Icon(Icons.copy_outlined, size: 22),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: f[1]));
                      toast(context, tr.secretCopiedField(fieldLabel(f[0])));
                    },
                  ),
                ],
              ),
            ),
          if (s!['file_name'] != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: NV.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('File', style: t.bodySmall),
                  Text(tr.secretFileSize(s!['file_name'], '${s!['size']}'), style: const TextStyle(fontFamily: NV.mono, fontSize: 14.5)),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onLongPressStart: (_) async {
                if (!authed || revealed == null) {
                  await _ensure();
                  return; // the prompt took the finger away; hold again to view
                }
                HapticFeedback.mediumImpact();
                setState(() => showing = true);
              },
              onLongPressEnd: (_) {
                if (timed <= 0) setState(() => showing = false);
              },
              child: Semantics(
                button: true,
                label: visible ? tr.secretContentShown : tr.secretHoldToViewContent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  constraints: const BoxConstraints(minHeight: 190),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: NV.ground, borderRadius: BorderRadius.circular(18)),
                  child: visible ? _revealed() : _hidden(),
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(onPressed: _showFor10s, child: Text(timed > 0 ? tr.secretHideIn(timed) : tr.secretShow10s)),
          ),
          if (s!['kind'] == 'wifi')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: OutlinedButton.icon(
                onPressed: _wifiQr,
                icon: const Icon(Icons.qr_code_2),
                label: Text(tr.secretWifiQr),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(tr.secretHistory, style: t.bodySmall!.copyWith(fontWeight: FontWeight.w600)),
          ),
          for (final h in (s!['history'] as List).take(20))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
              child: Text.rich(
                TextSpan(
                  style: t.bodySmall!.copyWith(fontSize: 14),
                  children: [
                    TextSpan(
                      text: '${h['who']} ',
                      style: TextStyle(color: NV.ink, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: '${_action(h['action'])}, ${shortDate(h['ts'])}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String? _folderName() {
    final names = <String>[];
    String? id = s!['folder'];
    final seen = <String>{};
    while (id != null && seen.add(id)) {
      final f = widget.folders.where((x) => x['id'] == id).firstOrNull;
      if (f == null) break;
      names.insert(0, f['name']);
      id = f['parent'];
    }
    return names.isEmpty ? null : names.join(' / ');
  }

  /// Two devices edited the same secret between syncs: both versions are kept until someone picks one.
  Widget _conflict() {
    final versions = (s!['versions'] as List).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: NV.warn.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NV.warn.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.secretConflictBody,
            style: TextStyle(fontFamily: NV.sans, fontSize: 14.5, color: NV.ink, height: 1.4),
          ),
          for (final v in versions)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${v['who']}, ${shortDate(v['ts'])}',
                    style: TextStyle(fontFamily: NV.sans, fontSize: 14, color: NV.ink2),
                  ),
                ),
                TextButton(onPressed: () => _peek(v), child: Text(tr.secretView)),
                TextButton(onPressed: () => _keep(v), child: Text(tr.secretKeepThis)),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _peek(Map<String, dynamic> v) async {
    if (!await reauth(context, tr.secretAuthToViewVersion(v['who']))) return;
    try {
      final r = await Core.call('reveal', {'ws': widget.ws, 'id': widget.id, 'entry': v['entry']}) as Map<String, dynamic>;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (d) => DarkZone(
          child: AlertDialog(
            backgroundColor: NV.ground,
            title: Text(tr.secretVersionOf(v['who']), style: const TextStyle(color: NV.dText)),
            content: SingleChildScrollView(
              child: Text(
                r['text'] ?? tr.secretBinaryFile(r['file_name'] ?? '', '${base64Decode(r['content_b64']).length}'),
                style: const TextStyle(fontFamily: NV.mono, fontSize: 12.5, color: Color(0xFFCFE0DB)),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(tr.secretClose))],
          ),
        ),
      );
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _keep(Map<String, dynamic> v) async {
    try {
      await Core.call('resolve_conflict', {'ws': widget.ws, 'id': widget.id, 'entry': v['entry']});
      setState(() => revealed = null);
      if (mounted) toast(context, tr.secretKeptVersion(v['who']));
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Widget _hidden() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x73FFFFFF), width: 3),
        ),
        child: Icon(authed ? Icons.lock_open_outlined : Icons.lock_outline, color: NV.dText, size: 28),
      ),
      const SizedBox(height: 12),
      Text(
        authed ? tr.secretHoldToView : tr.secretHoldToViewWhat(_what()),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: NV.sans, fontSize: 16, fontWeight: FontWeight.w600, color: NV.dText),
      ),
      const SizedBox(height: 4),
      Text(
        authed ? tr.secretAuthedHint : tr.secretNeedAuthHint,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: NV.sans, fontSize: 13.5, color: NV.dSub),
      ),
    ],
  );

  /// Copy one secret field ('*' label): always re-authenticates, audited as "copied", clipboard auto-clears.
  Future<void> _copyField(String label) async {
    if (!await mayCopy(context) || !await _ensure(action: 'copied')) return;
    final f = (revealed!['secret_fields'] as List).where((x) => x[0] == label).firstOrNull;
    if (f == null) return;
    await Keys.copySensitive('${s!['name']} ${label.substring(1)}', f[1] as String);
    if (mounted) toast(context, tr.secretCopiedFieldAutoClear(fieldLabel(label.substring(1))));
    _load();
  }

  Widget _revealed() {
    final r = revealed!;
    final sf = (r['secret_fields'] as List? ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in sf)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fieldLabel((f[0] as String).substring(1)),
                  style: const TextStyle(fontFamily: NV.sans, fontSize: 13, color: NV.dSub),
                ),
                // plain Text, not SelectableText: system copy would bypass auto-clear and the audit log
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        f[1],
                        style: const TextStyle(fontFamily: NV.mono, fontSize: 15, color: NV.dText),
                      ),
                    ),
                    if (copyOn)
                      IconButton(
                        tooltip: tr.secretCopyField(fieldLabel((f[0] as String).substring(1))),
                        icon: const Icon(Icons.copy_outlined, color: NV.dText, size: 20),
                        onPressed: () => _copyField(f[0] as String),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (r['text'] != null)
          Text(
            r['text'],
            style: const TextStyle(fontFamily: NV.mono, fontSize: 12.5, height: 1.55, color: Color(0xFFCFE0DB)),
          )
        else
          Text(tr.secretBinaryUseMenu(r['file_name'] ?? ''), style: const TextStyle(color: NV.dSub)),
      ],
    );
  }

  String _what() => switch (s!['kind']) {
    'p8' || 'ssh' => tr.secretWhatKey,
    'p12' => tr.secretWhatP12,
    'jks' => tr.secretWhatJks,
    'env' => tr.secretWhatEnv,
    'login' || 'wifi' => tr.secretWhatPassword,
    'api' => tr.secretWhatApi,
    _ => tr.secretWhatContent,
  };
}

String _kindName(String k) => switch (k) {
  'login' => tr.secretKindLoginLong,
  'api' => tr.secretKindApiLong,
  'wifi' => tr.secretKindWifiLong,
  'p8' => 'Apple .p8 key',
  'p12' => tr.secretKindP12,
  'jks' => 'Android keystore',
  'ssh' => 'SSH key',
  'env' => tr.secretKindEnv,
  'file' => tr.secretKindFileLong,
  _ => tr.secretKindText,
};

class _Kind {
  const _Kind(this.id, this.fields, {this.file = false, this.ext, this.single = false, this.asText = false});
  final String id;
  final List<String> fields; // stored labels; '*' prefix = secret field
  final bool file; // a file can be picked
  final String? ext;
  final bool single; // one hidden line (password, key) instead of a text area
  final bool asText; // a picked file is read into the text area (.env, SSH key)
  bool get inFiles => _fileKinds.contains(id);
  String get label => switch (id) {
    'login' => tr.secretKindLogin,
    'api' => tr.secretKindApi,
    'wifi' => tr.secretKindWifi,
    'text' => tr.secretKindText,
    'p8' => 'Apple .p8',
    'p12' => 'Cert .p12',
    'jks' => 'Keystore',
    'ssh' => 'SSH key',
    'env' => '.env',
    _ => tr.secretKindFile,
  };
  IconData get icon => switch (id) {
    'login' => Icons.person_outline,
    'api' => Icons.vpn_key_outlined,
    'wifi' => Icons.wifi,
    'text' => Icons.sticky_note_2_outlined,
    _ => Icons.folder_outlined,
  };
}

// Most common first. Developer files sit together under "Files & keys".
const _kinds = [
  _Kind('login', ['Trang web', 'Tên đăng nhập'], single: true),
  _Kind('api', ['Hết hạn'], single: true),
  _Kind('wifi', ['Tên Wi-Fi'], single: true),
  _Kind('text', []),
  _Kind('file', [], file: true),
  _Kind('env', [], file: true, asText: true),
  _Kind('ssh', ['Máy chủ'], file: true, asText: true),
  _Kind('p12', ['*Mật khẩu .p12', 'Hết hạn'], file: true, ext: 'p12'),
  _Kind('jks', ['Alias', '*Mật khẩu store', '*Mật khẩu key'], file: true, ext: 'jks'),
  _Kind('p8', ['Key ID', 'Team ID'], file: true, ext: 'p8'),
];
const _fileKinds = ['file', 'env', 'ssh', 'p12', 'jks', 'p8'];
const _plainFields = ['Trang web', 'Tên đăng nhập', 'Tên Wi-Fi', 'Key ID', 'Team ID', 'Alias', 'Máy chủ'];

/// Guess the file kind from its name, so people need not know what a .p12 or keystore is.
String? _kindOfFile(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.p8')) return 'p8';
  if (n.endsWith('.p12') || n.endsWith('.pfx')) return 'p12';
  if (n.endsWith('.jks') || n.endsWith('.keystore')) return 'jks';
  if (n == '.env' || n.startsWith('.env.') || n.endsWith('.env')) return 'env';
  if (n.startsWith('id_') && !n.endsWith('.pub')) return 'ssh';
  return null;
}

/// 20 characters from a CSPRNG, without look-alikes (0/O, 1/l/I).
String _strongPassword() {
  const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789-_!@#%+=';
  final r = Random.secure();
  return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
}

class EditSecretScreen extends StatefulWidget {
  const EditSecretScreen({super.key, required this.ws, this.existing, this.content, this.folder, this.folders = const []});
  final String ws;
  final String? folder;
  final List<Map<String, dynamic>> folders;
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? content;
  @override
  State<EditSecretScreen> createState() => _EditSecretScreenState();
}

class _EditSecretScreenState extends State<EditSecretScreen> {
  late String kind = widget.existing?['kind'] ?? 'login';
  bool reveal = false;
  final name = TextEditingController();
  final text = TextEditingController();
  final fields = <String, TextEditingController>{};
  Uint8List? fileBytes;
  String? fileName;
  bool busy = false;
  late String? folder = widget.existing != null ? widget.existing!['folder'] : widget.folder;

  _Kind get k => _kinds.firstWhere((x) => x.id == kind, orElse: () => _kinds.firstWhere((x) => x.id == 'text'));

  @override
  void initState() {
    super.initState();
    final e = widget.existing, c = widget.content;
    if (e != null) {
      name.text = e['name'];
      for (final f in (e['fields'] as List)) {
        fields[f[0]] = TextEditingController(text: f[1]);
      }
      for (final f in (c?['secret_fields'] as List? ?? [])) {
        fields[f[0]] = TextEditingController(text: f[1]);
      }
      fileName = c?['file_name'];
      if (fileName != null) {
        fileBytes = base64Decode(c!['content_b64']);
      } else {
        text.text = c?['text'] ?? '';
      }
    }
  }

  /// A hidden one-line value (password) must not reappear in plain view in a text area, so the
  /// value is cleared when switching between the two kinds of input.
  void _setKind(String id) => setState(() {
    final next = _kinds.firstWhere((x) => x.id == id);
    if (next.single != k.single) {
      text.clear();
      reveal = false;
    }
    if (!next.file) {
      fileBytes = null;
      fileName = null;
    }
    kind = id;
  });

  TextEditingController _f(String label) => fields.putIfAbsent(label, () => TextEditingController());

  Future<void> _pick() async {
    final r = await Keys.away(() => FilePicker.pickFiles());
    if (r.isEmpty) return;
    final f = r.first;
    final bytes = await f.readAsBytes();
    setState(() {
      final guess = _kindOfFile(f.name);
      if (guess != null && widget.existing == null) kind = guess;
      if (k.asText) {
        try {
          text.text = utf8.decode(bytes);
          fileBytes = null;
          fileName = null;
          if (name.text.isEmpty) name.text = f.name;
          return;
        } on FormatException {
          // not text: keep it as a file
        }
      }
      fileBytes = bytes;
      fileName = f.name;
      if (name.text.isEmpty) name.text = f.name.split('.').first;
      // AuthKey_XXXXXXXXXX.p8 carries the Key ID in its name
      final m = RegExp(r'AuthKey_([A-Z0-9]{10})\.p8').firstMatch(f.name);
      if (m != null && kind == 'p8') _f('Key ID').text = m.group(1)!;
    });
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return toast(context, tr.secretNameRequired, error: true);
    if (fileBytes == null && text.text.isEmpty) {
      final msg = switch (kind) {
        'login' || 'wifi' => tr.secretPasswordRequired,
        'api' => tr.secretKeyRequired,
        _ => tr.secretFileOrPaste,
      };
      return toast(context, msg, error: true);
    }
    setState(() => busy = true);
    try {
      final fl = [
        for (final l in k.fields)
          if (_f(l).text.trim().isNotEmpty) [l, _f(l).text.trim()],
      ];
      await Core.call('put_secret', {
        'ws': widget.ws,
        if (widget.existing != null) 'id': widget.existing!['id'],
        'name': name.text.trim(),
        'kind': kind,
        'fields': fl,
        if (folder != null) 'folder': folder,
        if (fileBytes != null && k.file) ...{'content_b64': base64Encode(fileBytes!), 'file_name': fileName} else 'text': text.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => busy = false);
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  String _folderLabel(String id) {
    final names = <String>[];
    String? cur = id;
    final seen = <String>{};
    while (cur != null && seen.add(cur)) {
      final f = widget.folders.where((x) => x['id'] == cur).firstOrNull;
      if (f == null) break;
      names.insert(0, f['name']);
      cur = f['parent'];
    }
    return names.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? tr.secretAddTitle : tr.secretEditTitle)),
      // The save button sits in the body (not bottomNavigationBar) so it rides above the keyboard.
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              // the multi-line field has no "done" key on iOS: dragging the form closes the keyboard
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(tr.secretKind, style: t.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final x in _kinds.where((x) => !x.inFiles))
                      ChoiceChip(
                        avatar: Icon(x.icon, size: 18),
                        showCheckmark: false,
                        label: Text(x.label),
                        selected: kind == x.id,
                        onSelected: widget.existing != null ? null : (_) => _setKind(x.id),
                      ),
                    ChoiceChip(
                      avatar: const Icon(Icons.folder_outlined, size: 18),
                      showCheckmark: false,
                      label: Text(tr.secretKindFiles),
                      selected: k.inFiles,
                      onSelected: widget.existing != null ? null : (_) => _setKind(k.inFiles ? kind : 'file'),
                    ),
                  ],
                ),
                if (k.inFiles) ...[
                  const SizedBox(height: 14),
                  Text(tr.secretFileType, style: t.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final x in _kinds.where((x) => x.inFiles))
                        ChoiceChip(
                          label: Text(x.label),
                          labelStyle: const TextStyle(fontSize: 13),
                          visualDensity: VisualDensity.compact,
                          selected: kind == x.id,
                          onSelected: widget.existing != null ? null : (_) => _setKind(x.id),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: switch (kind) {
                      'login' => tr.secretNameHintLogin,
                      'api' => tr.secretNameHintApi,
                      'wifi' => tr.secretNameHintWifi,
                      'text' => tr.secretNameHintNote,
                      _ => tr.secretNameHint,
                    },
                  ),
                ),
                if (widget.folders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder == null ? tr.secretNoFolder : _folderLabel(folder!)),
                    trailing: Text(tr.secretChange),
                    onTap: () async {
                      final d = await pickFolder(context, widget.folders, current: folder);
                      if (d != null) setState(() => folder = d.isEmpty ? null : d);
                    },
                  ),
                ],
                for (final l in k.fields) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _f(l),
                    obscureText: l.startsWith('*'),
                    enableSuggestions: !l.startsWith('*'),
                    autocorrect: !l.startsWith('*') && !_plainFields.contains(l),
                    enableIMEPersonalizedLearning: !l.startsWith('*'),
                    keyboardType: switch (l) {
                      'Trang web' => TextInputType.url,
                      'Tên đăng nhập' => TextInputType.emailAddress,
                      _ => null,
                    },
                    decoration: InputDecoration(
                      labelText: l.startsWith('*')
                          ? tr.secretFieldSecretLabel(fieldLabel(l.substring(1)))
                          : l == 'Hết hạn'
                          ? tr.secretFieldExpiresHint
                          : fieldLabel(l),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (k.file) ...[
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.attach_file),
                    label: Text(fileName == null ? (k.ext != null ? tr.secretChooseFileExt(k.ext!) : tr.secretChooseFile) : tr.secretChangeFile),
                  ),
                  if (fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(tr.secretFileSize(fileName!, '${fileBytes!.length}'), style: const TextStyle(fontFamily: NV.mono, fontSize: 14)),
                    ),
                  const SizedBox(height: 12),
                  Text(tr.secretOrPaste, style: t.bodySmall),
                  const SizedBox(height: 8),
                ],
                if (k.single)
                  TextField(
                    controller: text,
                    obscureText: !reveal,
                    enableSuggestions: false,
                    autocorrect: false,
                    enableIMEPersonalizedLearning: false,
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(fontFamily: NV.mono, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: switch (kind) {
                        'api' => tr.secretApiValue,
                        _ => tr.secretPassword,
                      },
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (kind == 'login')
                            IconButton(
                              tooltip: tr.secretGenerate,
                              icon: const Icon(Icons.auto_awesome_outlined),
                              onPressed: () => setState(() {
                                text.text = _strongPassword();
                                reveal = true;
                              }),
                            ),
                          IconButton(
                            tooltip: reveal ? tr.secretHideValue : tr.secretShowValue,
                            icon: Icon(reveal ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => reveal = !reveal),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                TextField(
                  controller: text,
                  enabled: fileBytes == null,
                  minLines: 4,
                  maxLines: 10,
                  enableSuggestions: false,
                  autocorrect: false,
                  // ask the keyboard not to learn or store what is typed here (Gboard, Samsung Keyboard)
                  enableIMEPersonalizedLearning: false,
                  style: const TextStyle(fontFamily: NV.mono, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: switch (kind) {
                      'env' => 'KEY=value',
                      'ssh' => '-----BEGIN OPENSSH PRIVATE KEY-----',
                      'p8' => '-----BEGIN PRIVATE KEY-----',
                      _ => tr.secretTextHint,
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(tr.secretEncryptedNote, style: t.bodySmall),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: busy ? null : _save, child: Text(busy ? tr.secretSaving : tr.secretSave)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `WIFI:T:WPA;S:name;P:password;;` with \ ; , : " escaped, as read by the iOS and Android cameras.
String wifiQrPayload(String ssid, String password) {
  String esc(String v) => v.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');
  final type = password.isEmpty ? 'nopass' : 'WPA';
  return 'WIFI:T:$type;S:${esc(ssid)};${password.isEmpty ? '' : 'P:${esc(password)};'};';
}
