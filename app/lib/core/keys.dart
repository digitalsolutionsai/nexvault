import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'bridge.dart';
import '../l10n/l10n.dart';

/// Master-key custody. The vault key never touches disk in clear, and never enters Dart.
/// Two modes:
///  - device (default where the platform allows): the key is sealed by a Keystore / Keychain
///    key that opens with a strong biometric or the device lock-screen credential, which the
///    secure hardware throttles. A recovery code (120 bits) wraps a second copy for when the
///    lock screen is reset.
///  - pin: the core returns a PIN-wrapped blob (Argon2id); unlock / re-auth / PIN change
///    happen inside the core. Optionally also sealed by a biometric-only key.
/// Unsealed bytes go native -> core directly (JNI on Android, C ABI on iOS) and are wiped.
class Keys {
  static const _native = MethodChannel('nexvault/native');
  static const _store = FlutterSecureStorage();
  static const maxAttempts = 10;

  /// Integration tests cannot answer the system lock-screen prompt; they take the PIN path.
  @visibleForTesting
  static bool noDeviceLockForTests = false;

  /// True while a system authentication prompt is up. On Android the device-credential screen
  /// is a separate activity that pauses ours; that pause must not count toward auto-lock.
  static bool prompting = false;

  static Future<T?> _prompt<T>(String method, Map<String, dynamic> args) => away(() => _native.invokeMethod<T>(method, args));

  /// Run [f] that shows a system screen (auth prompt, file picker, system settings) on top of
  /// the app, so the pause it causes is not taken as the user leaving the app.
  static Future<T> away<T>(Future<T> Function() f) async {
    prompting = true;
    try {
      return await f();
    } finally {
      prompting = false;
    }
  }

  static Future<String> vaultDir() async => '${(await getApplicationSupportDirectory()).path}/vault';

  /// True when there is both a vault on disk and a way to open it. Anything else is a leftover
  /// that can never be opened, and is cleared so onboarding starts clean: a first run cut off
  /// half-way (vault file, no custody yet), or iOS Keychain items that outlive an uninstall
  /// (custody, no vault).
  static Future<bool> isSetUp() async {
    final custody = await deviceMode() || (await _store.read(key: 'pin_blob')) != null;
    final dir = await vaultDir();
    final vault = await File('$dir/vault.bin').exists() || await File('$dir/vault.bak').exists();
    if (custody && vault) return true;
    if (custody || await Directory(dir).exists()) await wipe();
    return false;
  }

  /// True when the vault opens with the device lock screen (no app PIN).
  static Future<bool> deviceMode() async => (await _store.read(key: 'mode')) == 'dev';

  /// The device has a secure lock screen that can protect the vault key (Android 11+, iOS).
  static Future<bool> devAvailable() async {
    if (noDeviceLockForTests) return false;
    try {
      return await _native.invokeMethod<bool>('devAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Language picked in Settings: 'vi', 'en', or null to follow the phone.
  static Future<String?> language() => _store.read(key: 'lang');
  static Future<void> setLanguage(String? l) => l == null ? _store.delete(key: 'lang') : _store.write(key: 'lang', value: l);

  /// Seconds in the background before the app locks (0 = as soon as it leaves the screen).
  static Future<int> autoLockSeconds() async => int.tryParse(await _store.read(key: 'autolock') ?? '') ?? 60;
  static Future<void> setAutoLockSeconds(int s) => _store.write(key: 'autolock', value: '$s');

  /// First run in device mode: fresh key in the core, sealed behind the lock screen.
  /// Call [Core] create_identity / backup_import in between, then [finishDeviceSetup].
  static Future<void> startDeviceSetup() async => Core.call('device_setup', {'dir': await vaultDir()});

  /// Seal the open vault's key behind the lock screen and return a new recovery code.
  /// Also used to move an existing PIN user to device mode (the PIN and its seal are removed).
  static Future<String> finishDeviceSetup() async {
    await _seal('dev', tr.keysProtectWithLock);
    final code = await newRecoveryCode();
    await _store.write(key: 'mode', value: 'dev');
    await _store.delete(key: 'pin_blob');
    try {
      await disableBio();
    } catch (_) {}
    await _store.write(key: 'fails', value: '0');
    return code;
  }

  /// Replace the recovery code of the open vault. The old code stops working.
  static Future<String> newRecoveryCode() async {
    final r = await Core.call('recovery_new');
    await _store.write(key: 'rec_blob', value: r['blob'] as String);
    return r['code'] as String;
  }

  /// Unlock with the recovery code (lock screen reset or seal lost). Counted like the PIN.
  /// The device seal is renewed by the caller with [resealDevice] once unlocked.
  static Future<void> unlockWithRecovery(String code) async {
    final dir = await vaultDir();
    await _counted('rec_blob', (blob) => Core.call('recovery_open', {'code': code, 'blob': blob, 'dir': dir}));
  }

  /// Leave device custody for an app PIN (the lock screen was removed). Keeps the recovery code.
  static Future<void> switchToPin(String pin) async {
    final r = await Core.call('pin_set', {'pin': pin});
    await _store.write(key: 'pin_blob', value: r['blob'] as String);
    await _store.delete(key: 'mode');
    try {
      await _native.invokeMethod('bioClear', {'kind': 'dev'});
    } catch (_) {}
    await _store.write(key: 'fails', value: '0');
  }

  static Future<void> resealDevice() => _seal('dev', tr.keysReprotectWithLock);

  static Future<void> _seal(String kind, String title) async {
    try {
      await _prompt<void>('bioEnroll', {'title': title, 'kind': kind});
    } on PlatformException catch (e) {
      throw e.code == 'cancel' ? CoreError('cancelled') : _platformError(e, kind);
    }
  }

  /// Unlock with the device lock screen. False if the user cancelled.
  static Future<bool> unlockWithDevice() => _unlockSeal('dev', tr.keysUnlockTitle);

  static Future<int> failedAttempts() async => int.tryParse(await _store.read(key: 'fails') ?? '0') ?? 0;

  /// Seconds the user must wait before the next PIN attempt (grows after 5 failures).
  static Future<int> lockoutLeft() async {
    final until = int.tryParse(await _store.read(key: 'lock_until') ?? '0') ?? 0;
    final left = ((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return left > 0 ? left : 0;
  }

  /// First run: random master key, wrapped by PIN, then open the vault with it.
  static Future<void> setUp(String pin) async {
    final blob = (await Core.call('pin_setup', {'pin': pin, 'dir': await vaultDir()}))['blob'] as String;
    await _store.write(key: 'pin_blob', value: blob);
    await _store.write(key: 'fails', value: '0');
  }

  /// Unlock with PIN. Throws CoreError('wrong PIN') and counts the attempt.
  static Future<void> unlockWithPin(String pin) async {
    final dir = await vaultDir();
    await _counted('pin_blob', (blob) => Core.call('pin_open', {'pin': pin, 'blob': blob, 'dir': dir}));
  }

  /// Verify the PIN against the open vault (re-authentication before revealing a secret).
  static Future<void> checkPin(String pin) => _counted('pin_blob', (blob) => Core.call('pin_check', {'pin': pin, 'blob': blob}));

  /// Run a PIN / recovery-code operation; count failures and apply the growing lockout.
  static Future<T> _counted<T>(String blobKey, Future<T> Function(String blob) op) async {
    final blob = await _store.read(key: blobKey);
    if (blob == null) throw CoreError(blobKey == 'pin_blob' ? 'no PIN set' : 'no recovery code');
    try {
      final r = await op(blob);
      await _store.write(key: 'fails', value: '0');
      return r;
    } on CoreError {
      final n = await failedAttempts() + 1;
      await _store.write(key: 'fails', value: '$n');
      if (n >= 5) {
        final wait = 30 * (1 << (n - 5).clamp(0, 6)); // 30s, 60s, 120s ... capped
        await _store.write(key: 'lock_until', value: '${DateTime.now().millisecondsSinceEpoch + wait * 1000}');
      }
      rethrow;
    }
  }

  /// Re-wrap the master key under a new PIN. The biometric seal is unaffected.
  static Future<void> changePin(String oldPin, String newPin) async {
    final r = await _counted('pin_blob', (blob) => Core.call('pin_change', {'blob': blob, 'old': oldPin, 'new': newPin}));
    await _store.write(key: 'pin_blob', value: r['blob'] as String);
  }

  /// Erase everything on this device: vault files, PIN blob, biometric key.
  static Future<void> wipe() async {
    await Core.call('lock').catchError((_) => null);
    for (final kind in ['bio', 'dev']) {
      try {
        await _native.invokeMethod('bioClear', {'kind': kind});
      } catch (_) {}
    }
    await _store.deleteAll();
    final d = Directory(await vaultDir());
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// Tell the core which network interfaces peers can reach (skips the cellular IMS bearer).
  static Future<void> refreshNet() async {
    try {
      final names = await _native.invokeListMethod<String>('netIfaces');
      await Core.call('set_ifaces', {'names': names});
    } catch (_) {
      // no platform info: the core falls back to every interface
    }
  }

  /// System print dialog for an HTML page (recovery code sheet). Nothing is saved by the app.
  static Future<void> printHtml(String html) => away(() => _native.invokeMethod('printHtml', {'html': html}));

  /// Device name or model ("iPhone 13 mini", "Galaxy S24") to suggest as the member name.
  static Future<String> deviceName() async {
    try {
      return (await _native.invokeMethod<String>('deviceName'))?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<bool> bioAvailable() async => await _native.invokeMethod<bool>('bioAvailable') ?? false;
  static Future<bool> bioEnabled() async => await _native.invokeMethod<bool>('bioEnabled', {'kind': 'bio'}) ?? false;
  static Future<bool> devSealed() async => await _native.invokeMethod<bool>('bioEnabled', {'kind': 'dev'}) ?? false;

  /// Seal the open vault's key with the biometric key (the key moves core -> Kotlin over JNI).
  static Future<void> enableBio() async {
    try {
      await _prompt<void>('bioEnroll', {'title': tr.keysEnableFingerprint, 'kind': 'bio'});
    } on PlatformException catch (e) {
      throw _platformError(e, 'bio');
    }
  }

  /// A native auth / Keychain / Keystore failure as a message in the app language. The OS
  /// message (already localized by the system) is kept for unexpected errors.
  static CoreError _platformError(PlatformException e, String kind) => CoreError(switch (e.code) {
    'invalidated' => kind == 'dev' ? tr.keysDevInvalidated : tr.keysBioInvalidated(bioName),
    'locked' => tr.keysUnlockFirst,
    'not_enrolled' => tr.keysNotEnrolled,
    'seal_failed' => tr.keysSealFailed,
    'no_cipher' => tr.keysNoCipher,
    _ => e.message ?? e.code,
  });

  /// Tell the native layer the prompt button labels in the current language.
  static Future<void> setNativeLabels() async {
    try {
      await _native.invokeMethod('setLabels', {'usePin': tr.keysUsePin, 'cancel': tr.commonCancel});
    } catch (_) {}
  }

  static Future<void> disableBio() => _native.invokeMethod('bioClear', {'kind': 'bio'});

  /// Re-authenticate while unlocked (fingerprint, or the lock screen in device mode).
  /// null if the user cancelled / chose PIN instead.
  static Future<bool?> bioCheck(String title, {bool device = false}) async {
    try {
      return await _prompt<bool>('bioCheck', {'title': title, 'kind': device ? 'dev' : 'bio'}) ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'cancel') return null;
      throw _platformError(e, device ? 'dev' : 'bio');
    }
  }

  /// Unlock with a fingerprint. False if the user chose PIN instead.
  static Future<bool> unlockWithBio() => _unlockSeal('bio', tr.keysUnlockTitle);

  static Future<bool> _unlockSeal(String kind, String title) async {
    final String? r;
    try {
      r = await _prompt<String>('bioUnlock', {'title': title, 'dir': await vaultDir(), 'kind': kind});
    } on PlatformException catch (e) {
      if (e.code == 'cancel') return false;
      throw _platformError(e, kind);
    }
    final res = jsonDecode(r!) as Map<String, dynamic>;
    if (res['ok'] != true) throw CoreError(res['error'] as String);
    return true;
  }

  static Future<void> lock() => Core.call('lock');

  /// Copy can be turned off per device: keyboards such as Samsung Keyboard keep their own
  /// clipboard history and ignore both the "sensitive" flag and our 30 s auto-clear.
  static Future<bool> copyEnabled() async => (await _store.read(key: 'copy_off')) == null;
  static Future<void> setCopyEnabled(bool on) => on ? _store.delete(key: 'copy_off') : _store.write(key: 'copy_off', value: '1');
  static Future<bool> copyWarned() async => (await _store.read(key: 'copy_warned')) != null;
  static Future<void> setCopyWarned() => _store.write(key: 'copy_warned', value: '1');

  static Future<void> copySensitive(String label, String text) => _native.invokeMethod('copySensitive', {'label': label, 'text': text});

  static Future<void> openAppSettings() => away(() => _native.invokeMethod('openAppSettings'));

  static Future<String?> initialLink() => _native.invokeMethod<String>('initialLink');

  static void onLink(void Function(String) f) {
    _native.setMethodCallHandler((call) async {
      if (call.method == 'link') f(call.arguments as String);
      if (call.method == 'hotspotStopped') hotspotStopped.value++;
    });
  }

  // ---- private Wi-Fi for pairing/sync (see Hotspot.kt) ----

  /// Bumped when the system turns our hotspot off (e.g. the user started their own).
  static final hotspotStopped = ValueNotifier<int>(0);

  /// Only Android 13+ can start one; iOS can only join.
  static Future<bool> hotspotSupported() async {
    try {
      return await _native.invokeMethod<bool>('hotspotSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the local-only hotspot (asks for "Nearby devices" the first time).
  /// Returns {ssid, pass, sec}. Throws PlatformException(denied | failed | unsupported).
  static Future<Map<String, dynamic>> hotspotStart() async =>
      Map<String, dynamic>.from(await away(() => _native.invokeMethod<Map>('hotspotStart')) ?? {});

  static Future<bool> hotspotPermitted() async {
    try {
      return await _native.invokeMethod<bool>('hotspotPermitted') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> hotspotStop() => _native.invokeMethod('hotspotStop').catchError((_) => null);

  /// Join the other phone's hotspot for this session; the system asks the user to confirm.
  static Future<void> wifiJoin(Map<String, dynamic> w) =>
      away(() => _native.invokeMethod('wifiJoin', {'ssid': w['s'], 'pass': w['p'], 'sec': w['t'] ?? 1}));

  static Future<void> wifiLeave() => _native.invokeMethod('wifiLeave').catchError((_) => null);
}
