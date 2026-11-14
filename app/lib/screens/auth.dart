import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bridge.dart';
import '../core/keys.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings.dart' show pickBackup;

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) =>
      ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/icon.png', width: 72, height: 72));
}

/// First run: your name (shown to other members), then the vault key is sealed behind the
/// device lock screen with a recovery code. Without a secure lock screen: a 6-digit app PIN.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final name = TextEditingController();
  int step = 0; // 0 name, 1 pin, 2 confirm, 3 biometric, 5 no lock screen
  String pin = '', first = '';
  String? err;
  bool busy = false;
  (String, String)? restore; // (backup b64, passphrase) when restoring instead of starting fresh

  @override
  void initState() {
    super.initState();
    // Suggest the device name; the cursor sits at the end so the user can add their own name.
    Keys.deviceName().then((n) {
      if (!mounted || n.isEmpty || name.text.isNotEmpty) return;
      setState(() => name.value = TextEditingValue(text: '$n ', selection: TextSelection.collapsed(offset: n.length + 1)));
    });
  }

  /// After the name (or picking a backup): device-lock custody if possible, else explain.
  Future<void> _next() async {
    if (busy) return;
    FocusScope.of(context).unfocus(); // keep the keyboard down behind the system prompt and dialogs
    setState(() {
      busy = true;
      err = null;
    });
    if (!await Keys.devAvailable()) {
      setState(() {
        busy = false;
        step = 5;
      });
      return;
    }
    try {
      await Keys.startDeviceSetup();
      if (restore != null) {
        await Core.call('backup_import', {'b64': restore!.$1, 'passphrase': restore!.$2});
      } else {
        await Core.call('create_identity', {'name': name.text.trim()});
      }
      final code = await Keys.finishDeviceSetup();
      if (!mounted) return;
      await showRecoveryCode(context, code);
      widget.onDone();
    } catch (e) {
      debugPrint('onboarding failed: $e');
      // nothing half-done stays behind: start over from the name
      await Keys.wipe();
      if (!mounted) return;
      setState(() {
        busy = false;
        step = 0;
        restore = null;
        err = e is CoreError && e.raw == 'cancelled' ? tr.authNeedScreenLock : errText(e);
      });
    }
  }

  Future<void> _digit(String d) async {
    if (pin.length >= 6 || busy) return;
    setState(() => pin += d);
    if (pin.length < 6) return;
    if (step == 1) {
      setState(() {
        first = pin;
        pin = '';
        step = 2;
        err = null;
      });
    } else if (step == 2) {
      if (pin != first) {
        setState(() {
          pin = '';
          step = 1;
          err = tr.authPinMismatchRetry;
        });
        return;
      }
      setState(() => busy = true);
      try {
        await Keys.setUp(pin);
        if (restore != null) {
          try {
            await Core.call('backup_import', {'b64': restore!.$1, 'passphrase': restore!.$2});
          } catch (e) {
            // start over so the user can retry with the right passphrase
            await Keys.wipe();
            setState(() {
              busy = false;
              step = 0;
              restore = null;
              pin = '';
            });
            if (mounted) toast(context, errText(e), error: true);
            return;
          }
        } else {
          await Core.call('create_identity', {'name': name.text.trim()});
        }
        final bio = await Keys.bioAvailable();
        if (!bio) return widget.onDone();
        setState(() {
          busy = false;
          step = 3;
        });
      } catch (e) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NV.dark().textTheme; // this screen sits inside DarkZone
    return DarkZone(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: switch (step) {
              // scrolls when the keyboard leaves less room than the layout needs
              0 => LayoutBuilder(
                builder: (_, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const _Brand(),
                        const SizedBox(height: 24),
                        Text(tr.authWelcomeTitle, style: t.headlineSmall),
                        const SizedBox(height: 8),
                        Text(tr.authWelcomeBody, style: t.bodySmall),
                        const SizedBox(height: 28),
                        TextField(
                          controller: name,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(labelText: tr.authYourName),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (err != null) ...[const SizedBox(height: 12), Text(err!, style: const TextStyle(color: NV.dBad, fontSize: 14))],
                        const Spacer(),
                        if (busy) const LinearProgressIndicator(color: NV.dText),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: name.text.trim().isEmpty || busy ? null : _next, child: Text(tr.authContinue)),
                        const SizedBox(height: 8),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: NV.dText),
                          onPressed: () async {
                            final r = await pickBackup(context);
                            if (r != null) {
                              restore = r;
                              await _next();
                            }
                          },
                          child: Text(tr.authRestoreBackup),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
              5 => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.phonelink_lock_outlined, size: 56, color: NV.dText),
                  const SizedBox(height: 20),
                  Text(tr.authNoLockTitle, style: t.headlineSmall),
                  const SizedBox(height: 8),
                  Text(tr.authNoLockBody(bioName), style: t.bodySmall),
                  const Spacer(),
                  if (busy) const LinearProgressIndicator(color: NV.dText),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: busy ? null : _next, child: Text(tr.authRetry)),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: busy ? null : () => setState(() => step = 1), child: Text(tr.authUseAppPin)),
                  const SizedBox(height: 20),
                ],
              ),
              3 => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.fingerprint, size: 56, color: NV.dText),
                  const SizedBox(height: 20),
                  Text(tr.authBioTitle, style: t.headlineSmall),
                  const SizedBox(height: 8),
                  Text(tr.authBioBody, style: t.bodySmall),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await Keys.enableBio();
                      } catch (e) {
                        if (context.mounted) toast(context, errText(e), error: true);
                      }
                      widget.onDone();
                    },
                    child: Text(tr.authBioEnable),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: widget.onDone, child: Text(tr.authLater)),
                  const SizedBox(height: 20),
                ],
              ),
              _ => Column(
                children: [
                  const TopGap(40),
                  Text(step == 1 ? tr.authCreatePin : tr.authRepeatPin, style: t.headlineSmall),
                  const SizedBox(height: 8),
                  Text(tr.authPinHint, style: t.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 30),
                  PinDots(pin.length),
                  SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(err ?? '', style: const TextStyle(color: NV.dBad, fontSize: 14)),
                    ),
                  ),
                  PinPad(
                    enabled: !busy,
                    onDigit: _digit,
                    onBackspace: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1)),
                  ),
                  const Spacer(),
                  if (busy) const LinearProgressIndicator(color: NV.dText),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;
  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  String pin = '';
  String? err;
  bool busy = false;
  bool bio = false;
  bool? dev; // device-lock custody (no app PIN)
  bool sealed = true; // false: the key store was reset and the seal went with it; only the code opens it
  int lockLeft = 0;
  Timer? timer;
  final code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshLock();
    _start();
  }

  Future<void> _start() async {
    // no app PIN on record means device custody, even if the store forgot its 'mode'
    final d = await Keys.deviceMode() || !await Keys.hasPin();
    final s = !d || await Keys.devSealed().catchError((_) => true);
    if (!mounted) return;
    setState(() {
      dev = d;
      sealed = s;
    });
    if (d) {
      if (s) _device();
      return;
    }
    final v = await Keys.bioEnabled().catchError((_) => false);
    if (!mounted) return;
    setState(() => bio = v);
    if (v) _bio();
  }

  Future<void> _device() async {
    if (busy) return;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      if (await Keys.unlockWithDevice()) return widget.onUnlocked();
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  /// Lock screen reset or seal lost: open with the recovery code, then seal again.
  Future<void> _recovery() async {
    final c = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr.authRecoveryTitle),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: NV.mono),
          decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tr.authCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, code.text), child: Text(tr.authUnlock)),
        ],
      ),
    );
    code.clear();
    if (c == null || c.trim().isEmpty || lockLeft > 0) return;
    setState(() => busy = true);
    try {
      await Keys.unlockWithRecovery(c);
      if (!await Keys.devSealed()) {
        if (await Keys.devAvailable()) {
          try {
            await Keys.resealDevice();
          } catch (e) {
            if (mounted) toast(context, tr.authResealFailed(errText(e)), error: true);
          }
        } else if (mounted) {
          // no lock screen any more: keep the vault usable with an app PIN
          await _choosePin();
        }
      }
      widget.onUnlocked();
    } catch (e) {
      final left = Keys.maxAttempts - await Keys.failedAttempts();
      setState(() {
        busy = false;
        err = e is CoreError && e.raw.contains('wrong recovery code') ? tr.authWrongRecovery(left < 0 ? 0 : left) : errText(e);
      });
      _refreshLock();
    }
  }

  @override
  void dispose() {
    code.dispose();
    timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLock() async {
    final l = await Keys.lockoutLeft();
    setState(() => lockLeft = l);
    timer?.cancel();
    if (l > 0) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final l = await Keys.lockoutLeft();
        if (mounted) setState(() => lockLeft = l);
        if (l == 0) timer?.cancel();
      });
    }
  }

  Future<void> _bio() async {
    try {
      if (await Keys.unlockWithBio()) widget.onUnlocked();
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  Future<void> _digit(String d) async {
    if (busy || pin.length >= 6 || lockLeft > 0) return;
    setState(() => pin += d);
    if (pin.length < 6) return;
    setState(() => busy = true);
    try {
      await Keys.unlockWithPin(pin);
      widget.onUnlocked();
    } catch (e) {
      final left = Keys.maxAttempts - await Keys.failedAttempts();
      setState(() {
        pin = '';
        busy = false;
        err = e is CoreError && e.raw.contains('wrong PIN') ? tr.authWrongPin(left < 0 ? 0 : left) : errText(e);
      });
      _refreshLock();
    }
  }

  Future<void> _choosePin() async {
    while (true) {
      if (!mounted) return;
      final a = await readPin(context, tr.authNoLockSetPin);
      if (a == null || !mounted) continue;
      final b = await readPin(context, tr.authRepeatPin);
      if (b == a) {
        await Keys.switchToPin(a);
        if (mounted) toast(context, tr.authPinNowUsed);
        return;
      }
      if (mounted) toast(context, tr.authPinsDontMatch, error: true);
    }
  }

  Widget _deviceBody(TextTheme t) => Column(
    children: [
      const TopGap(36),
      const _Brand(),
      const SizedBox(height: 20),
      Text(tr.authLocked, style: t.headlineSmall),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(sealed ? tr.authDeviceUnlockHint(bioName) : tr.authSealLostHint, style: t.bodySmall, textAlign: TextAlign.center),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Text(
              lockLeft > 0 ? tr.authRetryIn(lockLeft) : (err ?? ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: NV.dBad, fontSize: 14),
            ),
          ),
        ),
      ),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: sealed
              ? FilledButton.icon(onPressed: busy ? null : _device, icon: const Icon(Icons.lock_open), label: Text(tr.authUnlock))
              : FilledButton.icon(onPressed: busy || lockLeft > 0 ? null : _recovery, icon: const Icon(Icons.key), label: Text(tr.authUseRecovery)),
        ),
      ),
      const SizedBox(height: 8),
      if (sealed)
        TextButton(
          onPressed: busy || lockLeft > 0 ? null : _recovery,
          child: Text(
            tr.authUseRecovery,
            style: const TextStyle(color: NV.dSub, fontWeight: FontWeight.w500),
          ),
        ),
      const SizedBox(height: 20),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = NV.dark().textTheme; // this screen sits inside DarkZone
    if (dev != false) {
      return DarkZone(
        child: Scaffold(body: SafeArea(child: dev == true ? _deviceBody(t) : const SizedBox())),
      );
    }
    return DarkZone(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const TopGap(36),
              const _Brand(),
              const SizedBox(height: 20),
              Text(tr.authLocked, style: t.headlineSmall),
              const SizedBox(height: 6),
              Text(tr.authEnterAppPin, style: t.bodySmall),
              const SizedBox(height: 28),
              PinDots(pin.length),
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    lockLeft > 0 ? tr.authRetryIn(lockLeft) : (err ?? ''),
                    style: const TextStyle(color: NV.dBad, fontSize: 14),
                  ),
                ),
              ),
              PinPad(
                enabled: !busy && lockLeft == 0,
                onDigit: _digit,
                onBackspace: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    if (bio)
                      Expanded(
                        child: OutlinedButton.icon(onPressed: _bio, icon: const Icon(Icons.fingerprint), label: Text(tr.authUseFingerprint)),
                      ),
                    if (!bio) const Spacer(),
                    TextButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(tr.authForgotPinTitle),
                          content: Text(tr.authForgotPinBody),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.authGotIt))],
                        ),
                      ),
                      child: Text(
                        tr.authForgotPinLink,
                        style: const TextStyle(color: NV.dSub, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
