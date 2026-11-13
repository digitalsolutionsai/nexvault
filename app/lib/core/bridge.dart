import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../l10n/l10n.dart';

/// Error raised by the Rust core, with a message in the app language for the UI.
class CoreError implements Exception {
  CoreError(this.raw);
  final String raw;

  String get message => coreErrorText(raw);

  @override
  String toString() => message;
}

/// A core error (English, from Rust) as a message in the app language. Unknown errors are
/// shown as they are.
String coreErrorText(String e) {
  final map = {
    'wrong PIN': tr.errWrongPin,
    'sync code has expired': tr.errSyncExpired,
    'invite has expired': tr.errInviteExpired,
    'code is damaged or incomplete': tr.errCodeDamaged,
    'this sync code is not for a workspace on this device': tr.errNotYourWorkspace,
    'this sync code is for a workspace you are not in': tr.errNotYourWorkspace,
    'not a sync code': tr.errNotNexVaultCode,
    'not an invite code': tr.errNotNexVaultCode,
    'could not reach the host': tr.errHostUnreachable,
    'handshake rejected': tr.errRefused,
    'add at least one other member': tr.errNeedMember,
    'has not confirmed the code yet': tr.errNotConfirmed,
    'wrong master key or corrupted vault': tr.errVaultUnreadable,
    'restored from a backup': tr.errRestoredSyncFirst,
    'you were removed from this workspace': tr.errRemoved,
    'the host refused this device': tr.errRefused,
    'folder is not empty': tr.errFolderNotEmpty,
    'cannot move a folder into itself': tr.errFolderIntoItself,
    'folder does not exist': tr.errFolderGone,
    'this change is already proposed': tr.errAlreadyProposed,
    'already a member': tr.errAlreadyMember,
    'only a member can invite': tr.errOnlyMemberInvites,
    'wrong passphrase': tr.errWrongPassphrase,
    'not a NexVault backup': tr.errNotBackup,
    'this device already has an identity': tr.errHasIdentity,
    'passphrase must be at least 10 characters': tr.errPassphraseShort,
    'secret is larger than 10 MB': tr.errSecretTooBig,
    'too many peers in this session': tr.errSessionFull,
    'this device does not hold the key for this item': tr.errNoKeyForItem,
    'vault was written by a newer NexVault': tr.errNewerVersion,
  };
  for (final k in map.keys) {
    if (e.contains(k)) return map[k]!;
  }
  return e;
}

typedef _CallC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);

DynamicLibrary _open() => Platform.isIOS ? DynamicLibrary.process() : DynamicLibrary.open('libnexvault_core.so');

String _callSync(String req) {
  final lib = _open();
  final call = lib.lookupFunction<_CallC, _CallC>('nv_call');
  final free = lib.lookupFunction<_FreeC, _FreeD>('nv_free');
  final p = req.toNativeUtf8();
  final r = call(p);
  malloc.free(p);
  final s = r.toDartString();
  free(r);
  return s;
}

/// All calls into Rust run on a short-lived isolate so the UI never blocks
/// (Argon2, network handshakes, co-signing can take a moment).
class Core {
  static Future<dynamic> call(String cmd, [Map<String, dynamic> args = const {}]) async {
    final req = jsonEncode({'cmd': cmd, ...args});
    final res = await Isolate.run(() => _callSync(req));
    final m = jsonDecode(res) as Map<String, dynamic>;
    if (m['ok'] != true) throw CoreError('${m['error']}');
    return m['data'];
  }
}
