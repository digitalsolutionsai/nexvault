import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/bridge.dart';
import '../core/keys.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onWiped});
  final VoidCallback onWiped;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? bioAvail, bioOn, copyOn, devMode, devAvail;
  String? lang; // 'vi', 'en' or null = phone language
  int autoLock = 60;
  Map<String, dynamic>? me, ver;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await Keys.bioAvailable();
    final o = await Keys.bioEnabled();
    final c = await Keys.copyEnabled();
    final dm = await Keys.deviceMode();
    final da = await Keys.devAvailable();
    final al = await Keys.autoLockSeconds();
    final lg = await Keys.language();
    final m = await Core.call('me') as Map<String, dynamic>;
    final v = await Core.call('version') as Map<String, dynamic>;
    if (mounted) {
      setState(() {
        bioAvail = a;
        bioOn = o;
        copyOn = c;
        devMode = dm;
        devAvail = da;
        autoLock = al;
        lang = lg;
        me = m;
        ver = v;
      });
    }
  }

  Future<void> _changePin() async {
    final old = await readPin(context, tr.settingsCurrentPin);
    if (old == null || !mounted) return;
    try {
      await Keys.checkPin(old);
    } catch (_) {
      if (mounted) toast(context, tr.settingsWrongPin, error: true);
      return;
    }
    if (!mounted) return;
    final a = await readPin(context, tr.settingsNewPin);
    if (a == null || !mounted) return;
    final b = await readPin(context, tr.settingsRepeatNewPin);
    if (b == null || !mounted) return;
    if (a != b) return toast(context, tr.settingsMismatch, error: true);
    try {
      await Keys.changePin(old, a);
      if (mounted) toast(context, tr.settingsPinChanged);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _toDevice() async {
    if (!await askPin(context, title: tr.settingsPinToDevice)) return;
    try {
      final code = await Keys.finishDeviceSetup();
      if (!mounted) return;
      await showRecoveryCode(context, code);
      _load();
      if (mounted) toast(context, tr.settingsSwitchedToDevice);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _newRecovery() async {
    if (!await reauth(context, tr.settingsAuthNewRecovery)) return;
    try {
      final code = await Keys.newRecoveryCode();
      if (mounted) await showRecoveryCode(context, code);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _pickAutoLock() async {
    final opts = {0: tr.settingsLockNow, 60: tr.settingsLock1, 300: tr.settingsLock5};
    final v = await showDialog<int>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(tr.settingsAutoLock),
        children: [
          for (final e in opts.entries)
            ListTile(
              title: Text(e.value),
              leading: Icon(e.key == autoLock ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              onTap: () => Navigator.pop(d, e.key),
            ),
        ],
      ),
    );
    if (v == null) return;
    await Keys.setAutoLockSeconds(v);
    setState(() => autoLock = v);
  }

  String _langLabel() => lang == 'vi' ? 'Tiếng Việt' : lang == 'en' ? 'English' : tr.langSystem;

  Future<void> _pickLanguage() async {
    final opts = {'system': tr.langSystem, 'vi': 'Tiếng Việt', 'en': 'English'};
    final current = lang ?? 'system';
    final v = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(tr.langTitle),
        children: [
          for (final e in opts.entries)
            ListTile(
              title: Text(e.value),
              leading: Icon(e.key == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              onTap: () => Navigator.pop(d, e.key),
            ),
        ],
      ),
    );
    if (v == null) return;
    final code = v == 'system' ? null : v;
    await Keys.setLanguage(code);
    language.value = code;
    if (mounted) setState(() => lang = code);
  }

  Future<void> _toggleCopy(bool on) async {
    // turning copy back on is a weakening: ask for the PIN
    if (on && !await reauth(context, tr.settingsAuthCopy)) return;
    await Keys.setCopyEnabled(on);
    if (mounted) setState(() => copyOn = on);
  }

  Future<void> _toggleBio(bool on) async {
    if (on && !await askPin(context, title: tr.settingsPinForBio)) return;
    try {
      if (on) {
        await Keys.enableBio();
      } else {
        await Keys.disableBio();
      }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
    _load();
  }

  Future<String?> _passphrase({required bool confirm}) async {
    final a = TextEditingController(), b = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(confirm ? tr.settingsSetBackupPass : tr.settingsBackupPass),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirm)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(tr.settingsBackupPassHint),
                ),
              TextField(
                controller: a,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: tr.settingsPassword),
              ),
              if (confirm) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: b,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr.settingsRepeat),
                ),
              ],
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(err!, style: const TextStyle(color: NV.danger)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(tr.settingsCancel)),
            TextButton(
              onPressed: () {
                if (confirm && a.text.characters.length < 10) return set(() => err = tr.settingsMinChars);
                if (confirm && a.text != b.text) return set(() => err = tr.settingsMismatch);
                Navigator.pop(d, a.text);
              },
              child: Text(tr.settingsContinue),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    if (!await reauth(context, tr.settingsAuthBackup)) return;
    final pass = await _passphrase(confirm: true);
    if (pass == null || !mounted) return;
    try {
      final r = await Core.call('backup_export', {'passphrase': pass});
      final bytes = base64Decode(r['b64']);
      final d = DateTime.now();
      final name = 'nexvault-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.nxbackup';
      final path = await Keys.away(() => FilePicker.saveFile(fileName: name, bytes: Uint8List.fromList(bytes)));
      if (mounted && path != null) toast(context, tr.settingsBackupSaved);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr.settingsWipeTitle),
        content: Text(tr.settingsWipeBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr.settingsCancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: NV.danger),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr.settingsWipeConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!await reauth(context, tr.settingsAuthWipe)) return;
    await Keys.wipe();
    widget.onWiped();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget head(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Text(s, style: t.bodySmall!.copyWith(fontWeight: FontWeight.w600)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr.settingsTitle)),
      body: ListView(
        children: [
          if (me != null)
            ListTile(
              leading: Avatar(me!['name'], size: 40, me: true),
              title: Text(me!['name']),
              subtitle: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: tr.settingsDeviceId),
                    TextSpan(
                      text: me!['device'],
                      style: const TextStyle(fontFamily: NV.mono),
                    ),
                  ],
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(tr.langTitle),
            subtitle: Text(_langLabel()),
            onTap: _pickLanguage,
          ),
          head(tr.settingsUnlockSection),
          if (devMode == true) ...[
            ListTile(
              leading: const Icon(Icons.phonelink_lock_outlined),
              title: Text(tr.settingsScreenLock),
              subtitle: Text(tr.settingsScreenLockSub(bioName)),
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(tr.settingsNewRecovery),
              subtitle: Text(tr.settingsNewRecoverySub),
              onTap: _newRecovery,
            ),
          ] else ...[
            ListTile(leading: const Icon(Icons.pin_outlined), title: Text(tr.settingsChangePin), onTap: _changePin),
            if (devAvail == true)
              ListTile(
                leading: const Icon(Icons.phonelink_lock_outlined),
                title: Text(tr.settingsToDevice),
                subtitle: Text(tr.settingsToDeviceSub(bioName)),
                onTap: _toDevice,
              ),
          ],
          if (devMode != true && bioAvail == true)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(tr.settingsBio),
              subtitle: Text(tr.settingsBioSub),
              value: bioOn ?? false,
              onChanged: _toggleBio,
            ),
          SwitchListTile(
            secondary: const Icon(Icons.content_copy_outlined),
            title: Text(tr.settingsCopy),
            subtitle: Text(tr.settingsCopySub),
            value: copyOn ?? true,
            onChanged: _toggleCopy,
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(tr.settingsAutoLock),
            subtitle: Text(
              tr.settingsAutoLockSub(
                autoLock == 0
                    ? tr.settingsLockNow
                    : autoLock == 60
                    ? tr.settingsAutoLockAfter1
                    : tr.settingsAutoLockAfterMin(autoLock ~/ 60),
              ),
            ),
            onTap: _pickAutoLock,
          ),
          head(tr.settingsBackupSection),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(tr.settingsExport),
            subtitle: Text(tr.settingsExportSub),
            onTap: _export,
          ),
          head(tr.settingsDangerSection),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: NV.danger),
            title: Text(tr.settingsWipe, style: const TextStyle(color: NV.danger)),
            onTap: _wipe,
          ),
          if (ver != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Text(tr.settingsVersion('${ver!['core']}', '${ver!['vault']}'), style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Restore flow used by onboarding: pick a backup file and its passphrase.
/// Returns (base64 blob, passphrase) or null.
Future<(String, String)?> pickBackup(BuildContext context) async {
  final files = await Keys.away(() => FilePicker.pickFiles());
  if (files.isEmpty || !context.mounted) return null;
  final bytes = await files.first.readAsBytes();
  if (!context.mounted) return null;
  final c = TextEditingController();
  final pass = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(tr.settingsBackupPass),
      content: TextField(
        controller: c,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: tr.settingsPassword),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(tr.settingsCancel)),
        TextButton(onPressed: () => Navigator.pop(d, c.text), child: Text(tr.settingsContinue)),
      ],
    ),
  );
  if (pass == null || pass.isEmpty) return null;
  return (base64Encode(bytes), pass);
}
