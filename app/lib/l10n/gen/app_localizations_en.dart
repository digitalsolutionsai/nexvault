// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NexVault';

  @override
  String get langSystem => 'Phone language';

  @override
  String get langTitle => 'Language';

  @override
  String get authNeedScreenLock =>
      'Screen lock authentication is needed to protect your data. Try again.';

  @override
  String get authPinMismatchRetry => 'The PINs don\'t match. Enter them again.';

  @override
  String get authWelcomeTitle => 'Welcome to NexVault';

  @override
  String get authWelcomeBody =>
      'Secrets live only on members\' devices, never on a server. Your name is shown on the devices of the people in your workspaces.';

  @override
  String get authYourName => 'Your name';

  @override
  String get authContinue => 'Continue';

  @override
  String get authRestoreBackup => 'Restore from backup';

  @override
  String get authNoLockTitle => 'No screen lock on this device';

  @override
  String authNoLockBody(String bio) {
    return 'NexVault protects your data with the device\'s screen lock ($bio or device passcode). Set a screen lock in the device Settings, then tap Try again.\n\nIf you\'d rather not, you can use a separate 6-digit app PIN, but it is less secure than the screen lock.';
  }

  @override
  String get authRetry => 'Try again';

  @override
  String get authUseAppPin => 'Use an app PIN';

  @override
  String get authBioTitle => 'Unlock with fingerprint?';

  @override
  String get authBioBody =>
      'Your data key is sealed in the device\'s security chip and only released when your fingerprint matches. Your PIN still works when needed.';

  @override
  String get authBioEnable => 'Turn on fingerprint';

  @override
  String get authLater => 'Not now';

  @override
  String get authCreatePin => 'Create a 6-digit PIN';

  @override
  String get authRepeatPin => 'Enter the PIN again';

  @override
  String get authPinHint =>
      'This PIN unlocks the app on this device. NexVault cannot recover it.';

  @override
  String get authRecoveryTitle => 'Unlock with recovery code';

  @override
  String get authCancel => 'Cancel';

  @override
  String get authUnlock => 'Unlock';

  @override
  String authResealFailed(String error) {
    return 'Not protected by the screen lock yet: $error';
  }

  @override
  String authWrongRecovery(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Wrong recovery code, $left attempts left',
      one: 'Wrong recovery code, 1 attempt left',
    );
    return '$_temp0';
  }

  @override
  String authWrongPin(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Wrong PIN, $left attempts left',
      one: 'Wrong PIN, 1 attempt left',
    );
    return '$_temp0';
  }

  @override
  String get authNoLockSetPin =>
      'This device no longer has a screen lock. Set a 6-digit app PIN';

  @override
  String get authPinNowUsed =>
      'From now on, open NexVault with this PIN. Set a screen lock again to use fingerprint or your device passcode.';

  @override
  String get authPinsDontMatch => 'The PINs don\'t match';

  @override
  String get authLocked => 'NexVault is locked';

  @override
  String authDeviceUnlockHint(String bio) {
    return 'Unlock with $bio or your device passcode';
  }

  @override
  String authRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Try again in $seconds seconds',
      one: 'Try again in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get authUseRecovery => 'Use recovery code';

  @override
  String get authEnterAppPin => 'Enter your app PIN to unlock';

  @override
  String get authUseFingerprint => 'Use fingerprint';

  @override
  String get authForgotPinTitle => 'Forgot PIN';

  @override
  String get authForgotPinBody =>
      'Your PIN can\'t be recovered because your data lives only on this device. You can erase the data and restore from a backup, or ask another member to invite you again. Secrets on this device are lost if you have no backup.';

  @override
  String get authGotIt => 'Got it';

  @override
  String get authForgotPinLink => 'Forgot PIN?';

  @override
  String get ceremonyProposalSent =>
      'Proposal to add members sent. The other members need to approve it via sync.';

  @override
  String ceremonyCreateTitle(String name) {
    return 'Create $name';
  }

  @override
  String ceremonyInviteTitle(String name) {
    return 'Invite to $name';
  }

  @override
  String get ceremonyStep1Create =>
      'Step 1: each member opens NexVault, taps \"Scan code\" and scans this code. Both devices need to be on the same Wi-Fi, or connected to your hotspot.';

  @override
  String get ceremonyStep1Invite =>
      'Step 1: the new member opens NexVault, taps \"Scan code\" and scans this code while next to you. Then every other member needs to approve.';

  @override
  String get ceremonyStep2Host => 'Step 2: read the code aloud to each person';

  @override
  String get ceremonyFinishing => 'Finishing…';

  @override
  String get ceremonyWaitVerify => 'Waiting for verification';

  @override
  String ceremonyFinishWith(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Finish with $count people',
      one: 'Finish with 1 person',
    );
    return '$_temp0';
  }

  @override
  String ceremonyProposeAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Propose adding $count people',
      one: 'Propose adding 1 person',
    );
    return '$_temp0';
  }

  @override
  String get ceremonyWrongCode => 'Picked the wrong code';

  @override
  String get ceremonyWillBeAdded => 'Will be added';

  @override
  String get ceremonyPickedRight => 'Picked the right code';

  @override
  String get ceremonyWaitingPick => 'Waiting for a pick';

  @override
  String ceremonyReadAloud(String name) {
    return 'Read it aloud to $name. The seal must look the same on both devices.';
  }

  @override
  String get ceremonyMismatchHost =>
      'The codes don\'t match: someone may be intercepting the connection. Don\'t add this person; ask them to scan again.';

  @override
  String ceremonyIsThisPerson(String name) {
    return 'Is the person holding the device really $name?';
  }

  @override
  String get ceremonyNotThem => 'Not them';

  @override
  String get ceremonyRightPerson => 'Yes, it\'s them';

  @override
  String get ceremonyJoinFailed => 'Couldn\'t join';

  @override
  String ceremonyConnecting(String name) {
    return 'Connecting to $name…';
  }

  @override
  String ceremonySameWifi(String name) {
    return 'Both devices need to be on the same Wi-Fi, or connect to $name\'s hotspot.';
  }

  @override
  String ceremonyVerifyStep(String name) {
    return 'Step 2/3: verify $name';
  }

  @override
  String ceremonyPickCode(String name) {
    return 'Pick the 6 digits $name reads aloud';
  }

  @override
  String get ceremonySealMatch =>
      'The seal must also look the same on both devices.';

  @override
  String get ceremonyNoneMatch => 'None of these match, stop';

  @override
  String get ceremonyVerified => 'Verified';

  @override
  String ceremonyWaitFinish(String name) {
    return 'Waiting for $name to confirm and finish the workspace. Keep the app open.';
  }

  @override
  String get ceremonyStopped => 'Stopped';

  @override
  String ceremonyAbortedBody(String name) {
    return 'The codes didn\'t match, which means someone may be intercepting the connection between the two devices. You were not added. Ask $name to create a new invite and scan again.';
  }

  @override
  String ceremonyJoined(String name) {
    return 'Joined $name';
  }

  @override
  String get ceremonyStep3Done =>
      'Step 3/3 done. You and the other members have signed the workspace charter.';

  @override
  String get ceremonyOpenWorkspace => 'Open workspace';

  @override
  String get ceremonyJoinTitle => 'Join workspace';

  @override
  String get errWrongPin => 'Wrong PIN';

  @override
  String get errSyncExpired =>
      'This sync code has expired. Ask the person who opened sync for a new one.';

  @override
  String get errInviteExpired => 'This invite has expired.';

  @override
  String get errCodeDamaged =>
      'The code is damaged or incomplete. Scan it again.';

  @override
  String get errNotYourWorkspace =>
      'This code is not for any workspace on this device.';

  @override
  String get errNotNexVaultCode => 'This is not a NexVault code.';

  @override
  String get errHostUnreachable =>
      'Could not reach the other device. Use the same Wi-Fi, or have the device that opened sync switch to 4G/5G (most carriers support IPv6).';

  @override
  String get errRefused =>
      'The other device refused the connection. This device may no longer be a member.';

  @override
  String get errNeedMember => 'Add at least one other verified member.';

  @override
  String get errNotConfirmed =>
      'This person has not picked the right code yet.';

  @override
  String get errVaultUnreadable => 'Could not open the data on this device.';

  @override
  String get errRestoredSyncFirst =>
      'This device was just restored from a backup. Sync with a member before editing.';

  @override
  String get errRemoved =>
      'You were removed from this workspace, so it can no longer sync.';

  @override
  String get errFolderNotEmpty =>
      'The folder is not empty. Move or delete its secrets and subfolders first.';

  @override
  String get errFolderIntoItself => 'A folder cannot be moved into itself.';

  @override
  String get errFolderGone => 'The folder no longer exists.';

  @override
  String get errAlreadyProposed => 'This change has already been proposed.';

  @override
  String get errAlreadyMember => 'This person is already a member.';

  @override
  String get errOnlyMemberInvites =>
      'Only a member who holds the key can invite new people.';

  @override
  String get errWrongPassphrase => 'Wrong backup password.';

  @override
  String get errNotBackup => 'This file is not a NexVault backup.';

  @override
  String get errHasIdentity =>
      'This device already has an identity. Erase its data before restoring.';

  @override
  String get errPassphraseShort =>
      'The backup password needs at least 10 characters.';

  @override
  String get errSecretTooBig => 'The secret is larger than 10 MB.';

  @override
  String get errSessionFull => 'This sync session is full.';

  @override
  String get errNoKeyForItem =>
      'This device does not have the key for this item yet. Sync with another member.';

  @override
  String get errNewerVersion =>
      'The data was written by a newer NexVault. Update the app.';

  @override
  String get timeNeverSynced => 'not synced yet';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String timeDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String timeToday(String time) {
    return 'today $time';
  }

  @override
  String get keysEnableFingerprint => 'Turn on fingerprint unlock';

  @override
  String get keysProtectWithLock => 'Protect NexVault with your screen lock';

  @override
  String get keysReprotectWithLock =>
      'Protect NexVault with your screen lock again';

  @override
  String get keysUnlockTitle => 'Unlock NexVault';

  @override
  String get keysDevInvalidated =>
      'The screen lock on this device was turned off or changed. Open with your recovery code.';

  @override
  String keysBioInvalidated(String bio) {
    return 'The biometrics ($bio) on this device changed. Open with your PIN, then turn it on again.';
  }

  @override
  String get keysUnlockFirst => 'Unlock the app first.';

  @override
  String get keysNotEnrolled => 'Biometric unlock is not turned on.';

  @override
  String get keysSealFailed =>
      'Could not store the key. This device needs a passcode.';

  @override
  String get keysNoCipher => 'No key came back from the prompt.';

  @override
  String get keysUsePin => 'Use PIN';

  @override
  String get commonCancel => 'Cancel';

  @override
  String pinFilled(int filled, int length) {
    return '$filled of $length digits entered';
  }

  @override
  String get commonDelete => 'Delete';

  @override
  String get pinEnterToContinue => 'Enter your PIN to continue';

  @override
  String pinWrongLeft(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Wrong PIN, $left tries left',
      one: 'Wrong PIN, 1 try left',
    );
    return '$_temp0';
  }

  @override
  String get copyDisabled => 'Copying is turned off in Settings.';

  @override
  String get copyKeyboardTitle => 'Your keyboard may keep a copy';

  @override
  String get copyKeyboardBody =>
      'NexVault clears the clipboard after 30 seconds, but some keyboards (Samsung Keyboard, Gboard…) keep their own clipboard history that the app cannot clear. After pasting, delete the entry from the keyboard\'s history, or turn the keyboard\'s clipboard history off.\n\nYou can turn copying off entirely in Settings.';

  @override
  String get copyUnderstood => 'Got it, copy';

  @override
  String get qrLabel => 'QR code';

  @override
  String get recoveryTitle => 'Recovery code';

  @override
  String get recoveryIntro =>
      'Use it if this device\'s screen lock is turned off or reset. The code is shown only once.';

  @override
  String get recoveryPrint => 'Print';

  @override
  String get recoveryPrintHint => 'Use a printer at home only';

  @override
  String get recoverySaved => 'I wrote it down or printed it';

  @override
  String recoveryPrintMeta(String device, String date) {
    return 'Device: $device &middot; Created: $date';
  }

  @override
  String get recoveryPrintUse =>
      'Use this code to open NexVault on this device only, if its screen lock is turned off or reset.';

  @override
  String get recoveryPrintKeep =>
      'Keep this sheet somewhere safe, away from the device. Anyone with both this code and your device can open NexVault. When you create a new recovery code, this one stops working: destroy this sheet.';

  @override
  String get sealLabel => 'Workspace seal';

  @override
  String get commonDone => 'Done';

  @override
  String get homeCreateTitle => 'Create workspace';

  @override
  String get homeCreateBody =>
      'Every member needs to be here, on the same Wi-Fi or on your hotspot, to scan your code.';

  @override
  String get homeWorkspaceName => 'Workspace name';

  @override
  String get homeCancel => 'Cancel';

  @override
  String get homeCreateInvite => 'Create invite code';

  @override
  String get homeNotSynced => 'Not synced yet';

  @override
  String homeSyncedWith(String name, String ago) {
    return 'Synced with $name $ago';
  }

  @override
  String get homeTitle => 'Workspaces';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeLockApp => 'Lock app';

  @override
  String get homeEmptyTitle => 'No workspaces yet';

  @override
  String get homeEmptyBody =>
      'Create a workspace when the members are together, or scan the creator\'s invite code.';

  @override
  String get homePendingApproval => 'Waiting for members to approve';

  @override
  String get homeNeedsAction => 'A proposal needs your review';

  @override
  String homeCounts(int members, int secrets) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members members',
      one: '1 member',
    );
    String _temp1 = intl.Intl.pluralLogic(
      secrets,
      locale: localeName,
      other: '$secrets secrets',
      one: '1 secret',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String homeYouAre(String name, String device) {
    return 'You are $name, device $device';
  }

  @override
  String get homeCreateWorkspace => 'Create workspace';

  @override
  String get homeScanCode => 'Scan code';

  @override
  String get scanNoCodeInImage => 'No NexVault code found in the image.';

  @override
  String get scanNotNexVault => 'This is not a NexVault code.';

  @override
  String get scanPaste => 'Paste code';

  @override
  String get scanCancel => 'Cancel';

  @override
  String get scanOpenCode => 'Open code';

  @override
  String get scanTitle => 'Scan code';

  @override
  String get scanHint =>
      'Scan a workspace invite or a sync code on another member\'s device.';

  @override
  String get scanCameraDenied =>
      'NexVault isn\'t allowed to use the camera. Allow it to scan, or use \"Pick code image\" / \"Paste code\".';

  @override
  String get scanCameraFailed =>
      'Couldn\'t open the camera. Use \"Pick code image\" or \"Paste code\".';

  @override
  String get scanAllowCamera => 'Allow camera';

  @override
  String get scanPickImage => 'From image';

  @override
  String get secretActionCreated => 'created';

  @override
  String get secretActionEdited => 'edited';

  @override
  String get secretActionViewed => 'viewed';

  @override
  String get secretActionCopied => 'copied';

  @override
  String get secretActionExported => 'exported a file';

  @override
  String get secretFieldP12Password => '.p12 password';

  @override
  String get secretFieldExpires => 'Expires';

  @override
  String get secretFieldStorePassword => 'Store password';

  @override
  String get secretFieldKeyPassword => 'Key password';

  @override
  String get secretFieldHost => 'Host';

  @override
  String secretFieldSecretLabel(String field) {
    return '$field (secret)';
  }

  @override
  String get secretFieldExpiresHint => 'Expires (yyyy-mm-dd)';

  @override
  String secretAuthToView(String name) {
    return 'Authenticate to view $name';
  }

  @override
  String get secretBinaryUseExport =>
      'The content is a binary file. Use \"Export file\".';

  @override
  String get secretCopiedAutoClear =>
      'Copied. The clipboard clears itself after 30 seconds.';

  @override
  String get secretExportTitle => 'Export file?';

  @override
  String get secretExportBody =>
      'The file holds the private key unencrypted. Only save it somewhere you trust. The export is recorded in the history.';

  @override
  String get secretCancel => 'Cancel';

  @override
  String get secretExport => 'Export file';

  @override
  String get secretMoved => 'Moved to folder';

  @override
  String secretDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get secretDeleteBody =>
      'The secret is deleted on every device after the next sync. The history is kept.';

  @override
  String get secretDelete => 'Delete secret';

  @override
  String get secretMore => 'More';

  @override
  String get secretCopyContent => 'Copy content';

  @override
  String get secretAutoClear30 => 'Clears after 30 seconds';

  @override
  String secretCopyField(String field) {
    return 'Copy $field';
  }

  @override
  String get secretEdit => 'Edit';

  @override
  String get secretMoveFolder => 'Move to folder';

  @override
  String secretSubtitle(String kind, String version) {
    return '$kind, version $version';
  }

  @override
  String secretCopiedField(String field) {
    return 'Copied $field';
  }

  @override
  String secretFileSize(String name, String size) {
    return '$name, $size bytes';
  }

  @override
  String get secretContentShown => 'Secret content is showing';

  @override
  String get secretHoldToViewContent =>
      'Press and hold to view the secret content';

  @override
  String secretHideIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Hides in $seconds seconds',
      one: 'Hides in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get secretShow10s => 'Show for 10 seconds';

  @override
  String get secretHistory => 'History';

  @override
  String get secretConflictBody =>
      'Two people edited this secret at the same time. Both versions are kept; pick the right one.';

  @override
  String get secretView => 'View';

  @override
  String get secretKeepThis => 'Keep this one';

  @override
  String secretAuthToViewVersion(String name) {
    return 'Authenticate to view $name\'s version';
  }

  @override
  String secretVersionOf(String name) {
    return '$name\'s version';
  }

  @override
  String secretBinaryFile(String name, String size) {
    return 'Binary file $name, $size bytes';
  }

  @override
  String get secretClose => 'Close';

  @override
  String secretKeptVersion(String name) {
    return 'Kept $name\'s version';
  }

  @override
  String get secretHoldToView => 'Press and hold to view';

  @override
  String secretHoldToViewWhat(String what) {
    return 'Press and hold to view $what';
  }

  @override
  String get secretAuthedHint =>
      'Authenticated for 60 seconds. The content hides again when you let go.';

  @override
  String get secretNeedAuthHint =>
      'Needs your fingerprint or PIN. The content hides again when you let go.';

  @override
  String secretCopiedFieldAutoClear(String field) {
    return 'Copied $field. The clipboard clears itself after 30 seconds.';
  }

  @override
  String secretBinaryUseMenu(String name) {
    return 'Binary file $name. Use \"Export file\" in the menu.';
  }

  @override
  String get secretWhatKey => 'the private key';

  @override
  String get secretWhatP12 => 'the cert and password';

  @override
  String get secretWhatJks => 'the keystore and passwords';

  @override
  String get secretWhatEnv => 'the environment variables';

  @override
  String get secretWhatContent => 'the content';

  @override
  String get secretKindP12 => '.p12 certificate';

  @override
  String get secretKindEnv => '.env file';

  @override
  String get secretKindText => 'Secure note';

  @override
  String get secretNameRequired => 'Give the secret a name';

  @override
  String get secretFileOrPaste => 'Choose a file or paste the content';

  @override
  String get secretAddTitle => 'Add secret';

  @override
  String get secretEditTitle => 'Edit secret';

  @override
  String get secretKind => 'Type';

  @override
  String get secretNameHint => 'Name, e.g. Production server key';

  @override
  String get secretNoFolder => 'Not in a folder';

  @override
  String get secretChange => 'Change';

  @override
  String get secretChooseFile => 'Choose file';

  @override
  String secretChooseFileExt(String ext) {
    return 'Choose .$ext file';
  }

  @override
  String get secretChangeFile => 'Change file';

  @override
  String get secretOrPaste => 'Or paste the content';

  @override
  String get secretTextHint =>
      'Anything to keep private: backup codes, account numbers, notes…';

  @override
  String get secretEncryptedNote =>
      'The secret is encrypted on this device. Other members receive it at the next sync.';

  @override
  String get secretSaving => 'Saving…';

  @override
  String get secretSave => 'Save secret';

  @override
  String get settingsCurrentPin => 'Enter current PIN';

  @override
  String get settingsWrongPin => 'Wrong PIN';

  @override
  String get settingsNewPin => 'New PIN';

  @override
  String get settingsRepeatNewPin => 'Enter the new PIN again';

  @override
  String get settingsMismatch => 'The two entries don\'t match';

  @override
  String get settingsPinChanged => 'PIN changed';

  @override
  String get settingsPinToDevice => 'Enter PIN to switch to the screen lock';

  @override
  String get settingsSwitchedToDevice =>
      'NexVault now opens with the screen lock. The old PIN no longer works.';

  @override
  String get settingsAuthNewRecovery =>
      'Authenticate to create a new recovery code';

  @override
  String get settingsLockNow => 'As soon as you leave the app';

  @override
  String get settingsLock1 => 'After 1 minute';

  @override
  String get settingsLock5 => 'After 5 minutes';

  @override
  String get settingsAutoLock => 'Auto-lock';

  @override
  String get settingsAuthCopy => 'Authenticate to allow copying';

  @override
  String get settingsPinForBio => 'Enter PIN to turn on fingerprint unlock';

  @override
  String get settingsSetBackupPass => 'Set backup password';

  @override
  String get settingsBackupPass => 'Backup password';

  @override
  String get settingsBackupPassHint =>
      'At least 10 characters. There is no way to recover the backup if you forget this password. A long sentence works well.';

  @override
  String get settingsPassword => 'Password';

  @override
  String get settingsRepeat => 'Repeat';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsMinChars => 'At least 10 characters needed';

  @override
  String get settingsContinue => 'Continue';

  @override
  String get settingsAuthBackup => 'Authenticate to back up';

  @override
  String get settingsBackupSaved => 'Backup saved';

  @override
  String get settingsWipeTitle => 'Erase all data on this device?';

  @override
  String get settingsWipeBody =>
      'Your identity, workspaces and every secret on this device are permanently erased. Data on other members\' devices stays. To get back into a workspace, you need to restore from a backup or be invited again in person.';

  @override
  String get settingsWipeConfirm => 'Erase all';

  @override
  String get settingsAuthWipe => 'Authenticate to erase data';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDeviceId => 'Device ID ';

  @override
  String get settingsUnlockSection => 'Unlock';

  @override
  String get settingsScreenLock => 'Phone screen lock';

  @override
  String settingsScreenLockSub(String bio) {
    return 'Opens with $bio or the device passcode';
  }

  @override
  String get settingsNewRecovery => 'Create a new recovery code';

  @override
  String get settingsNewRecoverySub => 'The old code will stop working';

  @override
  String get settingsChangePin => 'Change PIN';

  @override
  String get settingsToDevice => 'Switch to the screen lock';

  @override
  String settingsToDeviceSub(String bio) {
    return 'Use $bio or the device passcode instead of the app PIN';
  }

  @override
  String get settingsBio => 'Unlock with fingerprint';

  @override
  String get settingsBioSub =>
      'The data key is sealed in the phone\'s security chip';

  @override
  String get settingsCopy => 'Allow copying secrets';

  @override
  String get settingsCopySub =>
      'Cleared after 30 seconds, but the keyboard\'s clipboard history may still keep it';

  @override
  String get settingsAutoLockAfter1 => 'After 1 minute in the background';

  @override
  String settingsAutoLockAfterMin(int minutes) {
    return 'After $minutes minutes in the background';
  }

  @override
  String settingsAutoLockSub(String when) {
    return '$when. Viewing a secret always asks again.';
  }

  @override
  String get settingsBackupSection => 'Backup';

  @override
  String get settingsExport => 'Export encrypted backup';

  @override
  String get settingsExportSub =>
      'Your identity and every workspace, locked with a separate password. Use it when you lose or change your phone.';

  @override
  String get settingsDangerSection => 'Danger zone';

  @override
  String get settingsWipe => 'Erase all data on this device';

  @override
  String settingsVersion(String core, String vault) {
    return 'NexVault core $core, vault format v$vault';
  }

  @override
  String get syncPeerDone => 'Done';

  @override
  String get syncPeerSyncing => 'Syncing';

  @override
  String get syncPeerLeft => 'Left';

  @override
  String get syncPeerNotScanned => 'Not scanned';

  @override
  String syncPeerRemovedName(String name) {
    return '$name (removed)';
  }

  @override
  String get syncPeerRejected => 'Rejected';

  @override
  String syncPeerNewMember(String name) {
    return '$name (new member)';
  }

  @override
  String syncStrangers(int count) {
    return 'Unknown devices ($count)';
  }

  @override
  String syncHostTitle(String name) {
    return 'Sync $name';
  }

  @override
  String get syncHostIntro =>
      'Members open NexVault and scan this code. For someone far away, send a picture of it by chat (only workspace devices can decrypt it) and keep this device on 4G/5G.';

  @override
  String get syncExpiresIn => 'Code expires in ';

  @override
  String get syncExpired => 'Code expired, connections are closed';

  @override
  String get syncConnectVia =>
      'Direct over Wi-Fi or 4G/5G, with no server in between';

  @override
  String syncShareText(String name, String left) {
    return 'NexVault sync code ($name), expires in $left';
  }

  @override
  String get syncShareButton => 'Send to someone far away';

  @override
  String get syncNewCode => 'New code';

  @override
  String get syncEnd => 'Finish';

  @override
  String syncJoinConnecting(String host) {
    return 'Connecting to $host…';
  }

  @override
  String get syncJoinConnectingHint =>
      'Trying the same Wi-Fi first, then a direct connection over 4G/5G.';

  @override
  String syncJoinSyncing(String host) {
    return 'Syncing with $host';
  }

  @override
  String syncJoinCounts(String received, String sent) {
    return 'Received $received, sent $sent changes.';
  }

  @override
  String syncJoinDone(String host) {
    return 'Synced with $host';
  }

  @override
  String syncJoinDoneBody(String received, String sent) {
    return 'Received $received, sent $sent changes. Keep this screen open to receive more changes from others in this session.';
  }

  @override
  String get syncJoinClosed => 'The sync session has ended';

  @override
  String get syncJoinFailed => 'Could not sync';

  @override
  String get syncDone => 'Done';

  @override
  String get syncClose => 'Close';

  @override
  String get workspaceSave => 'Save';

  @override
  String get workspaceFolderName => 'Folder name';

  @override
  String get workspaceCancel => 'Cancel';

  @override
  String get workspaceNewFolder => 'New folder';

  @override
  String get workspaceCreate => 'Create';

  @override
  String get workspaceRename => 'Rename';

  @override
  String get workspaceMoveFolder => 'Move to another folder';

  @override
  String get workspaceDeleteFolder => 'Delete folder';

  @override
  String get workspaceDeleteFolderHint => 'Only empty folders can be deleted';

  @override
  String get workspaceRenameFolder => 'Rename folder';

  @override
  String get workspaceMembers => 'Members';

  @override
  String get workspaceMembersRule =>
      'Adding someone needs every member to agree. Removing someone needs 2/3 of the members who stay to agree.';

  @override
  String workspaceMemberYou(String name) {
    return '$name (you)';
  }

  @override
  String get workspaceThisDevice => 'This device';

  @override
  String workspaceMemberSynced(String when) {
    return 'Synced $when';
  }

  @override
  String get workspaceProposeRemoval => 'Propose removal';

  @override
  String get workspaceInviteMember => 'Invite a new member';

  @override
  String workspaceProposeRemoveTitle(String name) {
    return 'Propose removing $name?';
  }

  @override
  String get workspaceProposeRemoveBody =>
      'The proposal takes effect once enough members agree over their syncs. The workspace then switches to a new key. The removed member has already seen the current secrets: rotate the important keys.';

  @override
  String get workspaceExpired => 'Expired';

  @override
  String workspaceExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $days days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get workspaceConflict => '2 versions, pick one';

  @override
  String workspaceVersionDate(String version, String date) {
    return 'Version $version, $date';
  }

  @override
  String get workspaceJustCreated => 'Just created';

  @override
  String workspaceUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String workspaceMemberYouShort(String name) {
    return '$name\n(you)';
  }

  @override
  String get workspacePendingBanner =>
      'Waiting for the members to agree to add you. Open sync with them to receive the approvals and the workspace key.';

  @override
  String get workspaceStaleBanner =>
      'This device was just restored from a backup. Open sync with a member to get the changes made after the backup; you can edit again after that.';

  @override
  String get workspaceRemovedBanner =>
      'You were removed from this workspace. New data will no longer reach this device.';

  @override
  String workspaceSearchHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search $count secrets',
      one: 'Search 1 secret',
    );
    return '$_temp0';
  }

  @override
  String get workspaceAll => 'All';

  @override
  String workspaceSecretCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secrets',
      one: '1 secret',
    );
    return '$_temp0';
  }

  @override
  String get workspaceFolderOptions => 'Folder options';

  @override
  String get workspaceEmpty =>
      'No secrets yet. Add logins, API keys, Wi-Fi passwords, notes or files such as .env and SSH keys, group them into folders, then open sync to share.';

  @override
  String get workspaceFolderEmpty => 'Empty folder.';

  @override
  String get workspaceAddSecret => 'Add secret';

  @override
  String get workspaceOpenSync => 'Open sync';

  @override
  String get workspaceNeverSynced => 'not synced';

  @override
  String get workspaceJustNow => 'just now';

  @override
  String workspaceMinutesShort(int n) {
    return '$n min';
  }

  @override
  String workspaceHoursShort(int n) {
    return '$n hr';
  }

  @override
  String workspaceDaysShort(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String workspaceProposalAdd(
    String proposer,
    String name,
    String approvals,
    String needed,
  ) {
    return '$proposer proposed adding $name: $approvals/$needed agreed';
  }

  @override
  String workspaceProposalRemove(String name, String approvals, String needed) {
    return 'Proposal to remove $name: $approvals/$needed agreed';
  }

  @override
  String workspaceProposalAwaitingKeys(String text) {
    return '$text. Waiting to hand over keys at the next sync.';
  }

  @override
  String workspaceApproveAddTitle(String name) {
    return 'Agree to add $name?';
  }

  @override
  String workspaceApproveRemoveTitle(String name) {
    return 'Agree to remove $name?';
  }

  @override
  String workspaceApproveAddBody(String proposer, String name) {
    return '$proposer met $name in person and verified them. Once everyone agrees, $name can read every secret in the workspace.';
  }

  @override
  String workspaceApproveRemoveBody(String name) {
    return 'Once enough members agree, $name no longer receives new data and the workspace switches to a new key.';
  }

  @override
  String get workspaceApprove => 'Agree';

  @override
  String get workspacePickFolder => 'Choose folder';

  @override
  String get workspaceNoFolder => 'Not in any folder';

  @override
  String get syncPathNoServer => 'No server in between';

  @override
  String get syncPathNearby => 'Same Wi-Fi';

  @override
  String get syncPathInternet => 'Direct over 4G/5G (IPv6)';

  @override
  String get syncPathEither => 'Same Wi-Fi, or direct over 4G/5G';

  @override
  String get syncPathThisDevice => 'This device';

  @override
  String get syncPathOther => 'Other device';

  @override
  String get syncHowTitle => 'How sync works';

  @override
  String get syncHowBody =>
      'The two devices connect to each other directly: over the same Wi-Fi when you are close, or over 4G/5G using IPv6 when you are apart.\n\nNo NexVault or third-party server is involved and nothing is stored anywhere else. Everything is end-to-end encrypted, so the Wi-Fi router or your carrier only carries packets it cannot read.\n\nThe code works for 5 minutes and only for members of this workspace.';

  @override
  String get syncHowButton => 'How it works';

  @override
  String get bioAndroid => 'fingerprint';

  @override
  String get bioIos => 'Face ID / Touch ID';

  @override
  String get ceremonyWaitingScan => 'Waiting for members to scan…';

  @override
  String get secretKindLogin => 'Login';

  @override
  String get secretKindApi => 'API key';

  @override
  String get secretKindWifi => 'Wi-Fi';

  @override
  String get secretKindFiles => 'Files & keys';

  @override
  String get secretKindFile => 'Any file';

  @override
  String get secretKindLoginLong => 'Login';

  @override
  String get secretKindApiLong => 'API key / token';

  @override
  String get secretKindWifiLong => 'Wi-Fi password';

  @override
  String get secretKindFileLong => 'File';

  @override
  String get secretFileType =>
      'File type: picked automatically from the file, or choose';

  @override
  String get secretFieldWebsite => 'Website or app';

  @override
  String get secretFieldUsername => 'Username or email';

  @override
  String get secretFieldWifiName => 'Network name';

  @override
  String get secretPassword => 'Password';

  @override
  String get secretApiValue => 'Key or token';

  @override
  String get secretGenerate => 'Generate a strong password';

  @override
  String get secretShowValue => 'Show';

  @override
  String get secretHideValue => 'Hide';

  @override
  String get secretPasswordRequired => 'Enter the password';

  @override
  String get secretKeyRequired => 'Enter the key or token';

  @override
  String get secretNameHintLogin => 'Name, e.g. Company Gmail';

  @override
  String get secretNameHintApi => 'Name, e.g. Stripe production';

  @override
  String get secretNameHintWifi => 'Name, e.g. Office Wi-Fi';

  @override
  String get secretNameHintNote => 'Name, e.g. 2FA backup codes';

  @override
  String get secretWhatPassword => 'the password';

  @override
  String get secretWhatApi => 'the key';

  @override
  String get secretCopyPassword => 'Copy password';

  @override
  String get secretWifiQr => 'Show QR to join this Wi-Fi';

  @override
  String get secretWifiQrHint =>
      'On the other phone, open the camera and scan to join. Closes by itself in 60 seconds.';

  @override
  String get secretWifiNoName => 'Add the network name first (Edit)';

  @override
  String get hotspotOffer =>
      'No shared Wi-Fi? Start a private Wi-Fi on this phone';

  @override
  String hotspotOnTitle(String ssid) {
    return 'Private Wi-Fi on: $ssid';
  }

  @override
  String get hotspotOnHint =>
      'The code includes it: the other phone joins by scanning. It has no internet and turns off when you leave this screen.';

  @override
  String get hotspotStop => 'Turn off';

  @override
  String get hotspotDenied =>
      'NexVault needs the Nearby devices permission to start a Wi-Fi. It does not use your location.';

  @override
  String get hotspotFailed =>
      'Could not start a Wi-Fi on this phone. Turn off the phone\'s own hotspot and try again.';

  @override
  String hotspotJoining(String ssid) {
    return 'Joining the other phone\'s Wi-Fi ($ssid)…';
  }

  @override
  String get hotspotJoinFailed =>
      'Could not join the other phone\'s Wi-Fi. Trying the current network instead.';

  @override
  String get hotspotPermTitle => 'Allow Nearby devices';

  @override
  String get hotspotPermBody =>
      'Android asks for the Nearby devices permission before an app can start a Wi-Fi. Its wording mentions the position of devices, but NexVault only uses it to start this private Wi-Fi and never sees your location.';

  @override
  String get hotspotPermContinue => 'Continue';
}
