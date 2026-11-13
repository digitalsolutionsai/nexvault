import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'NexVault'**
  String get appName;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'Phone language'**
  String get langSystem;

  /// No description provided for @langTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get langTitle;

  /// No description provided for @authNeedScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Screen lock authentication is needed to protect your data. Try again.'**
  String get authNeedScreenLock;

  /// No description provided for @authPinMismatchRetry.
  ///
  /// In en, this message translates to:
  /// **'The PINs don\'t match. Enter them again.'**
  String get authPinMismatchRetry;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to NexVault'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Secrets live only on members\' devices, never on a server. Your name is shown on the devices of the people in your workspaces.'**
  String get authWelcomeBody;

  /// No description provided for @authYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authYourName;

  /// No description provided for @authContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// No description provided for @authRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get authRestoreBackup;

  /// No description provided for @authNoLockTitle.
  ///
  /// In en, this message translates to:
  /// **'No screen lock on this device'**
  String get authNoLockTitle;

  /// No description provided for @authNoLockBody.
  ///
  /// In en, this message translates to:
  /// **'NexVault protects your data with the device\'s screen lock (fingerprint / Face ID or device passcode). Set a screen lock in the device Settings, then tap Try again.\n\nIf you\'d rather not, you can use a separate 6-digit app PIN, but it is less secure than the screen lock.'**
  String get authNoLockBody;

  /// No description provided for @authRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get authRetry;

  /// No description provided for @authUseAppPin.
  ///
  /// In en, this message translates to:
  /// **'Use an app PIN'**
  String get authUseAppPin;

  /// No description provided for @authBioTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint?'**
  String get authBioTitle;

  /// No description provided for @authBioBody.
  ///
  /// In en, this message translates to:
  /// **'Your data key is sealed in the device\'s security chip and only released when your fingerprint matches. Your PIN still works when needed.'**
  String get authBioBody;

  /// No description provided for @authBioEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on fingerprint'**
  String get authBioEnable;

  /// No description provided for @authLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get authLater;

  /// No description provided for @authCreatePin.
  ///
  /// In en, this message translates to:
  /// **'Create a 6-digit PIN'**
  String get authCreatePin;

  /// No description provided for @authRepeatPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get authRepeatPin;

  /// No description provided for @authPinHint.
  ///
  /// In en, this message translates to:
  /// **'This PIN unlocks the app on this device. NexVault cannot recover it.'**
  String get authPinHint;

  /// No description provided for @authRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with recovery code'**
  String get authRecoveryTitle;

  /// No description provided for @authCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancel;

  /// No description provided for @authUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get authUnlock;

  /// No description provided for @authResealFailed.
  ///
  /// In en, this message translates to:
  /// **'Not protected by the screen lock yet: {error}'**
  String authResealFailed(String error);

  /// No description provided for @authWrongRecovery.
  ///
  /// In en, this message translates to:
  /// **'{left, plural, =1{Wrong recovery code, 1 attempt left} other{Wrong recovery code, {left} attempts left}}'**
  String authWrongRecovery(int left);

  /// No description provided for @authWrongPin.
  ///
  /// In en, this message translates to:
  /// **'{left, plural, =1{Wrong PIN, 1 attempt left} other{Wrong PIN, {left} attempts left}}'**
  String authWrongPin(int left);

  /// No description provided for @authNoLockSetPin.
  ///
  /// In en, this message translates to:
  /// **'This device no longer has a screen lock. Set a 6-digit app PIN'**
  String get authNoLockSetPin;

  /// No description provided for @authPinNowUsed.
  ///
  /// In en, this message translates to:
  /// **'From now on, open NexVault with this PIN. Set a screen lock again to use fingerprint or your device passcode.'**
  String get authPinNowUsed;

  /// No description provided for @authPinsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs don\'t match'**
  String get authPinsDontMatch;

  /// No description provided for @authLocked.
  ///
  /// In en, this message translates to:
  /// **'NexVault is locked'**
  String get authLocked;

  /// No description provided for @authDeviceUnlockHint.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint / Face ID or your device passcode'**
  String get authDeviceUnlockHint;

  /// No description provided for @authRetryIn.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Try again in 1 second} other{Try again in {seconds} seconds}}'**
  String authRetryIn(int seconds);

  /// No description provided for @authUseRecovery.
  ///
  /// In en, this message translates to:
  /// **'Use recovery code'**
  String get authUseRecovery;

  /// No description provided for @authEnterAppPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your app PIN to unlock'**
  String get authEnterAppPin;

  /// No description provided for @authUseFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get authUseFingerprint;

  /// No description provided for @authForgotPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN'**
  String get authForgotPinTitle;

  /// No description provided for @authForgotPinBody.
  ///
  /// In en, this message translates to:
  /// **'Your PIN can\'t be recovered because your data lives only on this device. You can erase the data and restore from a backup, or ask another member to invite you again. Secrets on this device are lost if you have no backup.'**
  String get authForgotPinBody;

  /// No description provided for @authGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get authGotIt;

  /// No description provided for @authForgotPinLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get authForgotPinLink;

  /// No description provided for @ceremonyProposalSent.
  ///
  /// In en, this message translates to:
  /// **'Proposal to add members sent. The other members need to approve it via sync.'**
  String get ceremonyProposalSent;

  /// No description provided for @ceremonyCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create {name}'**
  String ceremonyCreateTitle(String name);

  /// No description provided for @ceremonyInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite to {name}'**
  String ceremonyInviteTitle(String name);

  /// No description provided for @ceremonyStep1Create.
  ///
  /// In en, this message translates to:
  /// **'Step 1: each member opens NexVault, taps \"Scan code\" and scans this code. Both devices need to be on the same Wi-Fi, or connected to your hotspot.'**
  String get ceremonyStep1Create;

  /// No description provided for @ceremonyStep1Invite.
  ///
  /// In en, this message translates to:
  /// **'Step 1: the new member opens NexVault, taps \"Scan code\" and scans this code while next to you. Then every other member needs to approve.'**
  String get ceremonyStep1Invite;

  /// No description provided for @ceremonyStep2Host.
  ///
  /// In en, this message translates to:
  /// **'Step 2: read the code aloud to each person'**
  String get ceremonyStep2Host;

  /// No description provided for @ceremonyFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing…'**
  String get ceremonyFinishing;

  /// No description provided for @ceremonyWaitVerify.
  ///
  /// In en, this message translates to:
  /// **'Waiting for verification'**
  String get ceremonyWaitVerify;

  /// No description provided for @ceremonyFinishWith.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Finish with 1 person} other{Finish with {count} people}}'**
  String ceremonyFinishWith(int count);

  /// No description provided for @ceremonyProposeAdd.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Propose adding 1 person} other{Propose adding {count} people}}'**
  String ceremonyProposeAdd(int count);

  /// No description provided for @ceremonyWrongCode.
  ///
  /// In en, this message translates to:
  /// **'Picked the wrong code'**
  String get ceremonyWrongCode;

  /// No description provided for @ceremonyWillBeAdded.
  ///
  /// In en, this message translates to:
  /// **'Will be added'**
  String get ceremonyWillBeAdded;

  /// No description provided for @ceremonyPickedRight.
  ///
  /// In en, this message translates to:
  /// **'Picked the right code'**
  String get ceremonyPickedRight;

  /// No description provided for @ceremonyWaitingPick.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a pick'**
  String get ceremonyWaitingPick;

  /// No description provided for @ceremonyReadAloud.
  ///
  /// In en, this message translates to:
  /// **'Read it aloud to {name}. The seal must look the same on both devices.'**
  String ceremonyReadAloud(String name);

  /// No description provided for @ceremonyMismatchHost.
  ///
  /// In en, this message translates to:
  /// **'The codes don\'t match: someone may be intercepting the connection. Don\'t add this person; ask them to scan again.'**
  String get ceremonyMismatchHost;

  /// No description provided for @ceremonyIsThisPerson.
  ///
  /// In en, this message translates to:
  /// **'Is the person holding the device really {name}?'**
  String ceremonyIsThisPerson(String name);

  /// No description provided for @ceremonyNotThem.
  ///
  /// In en, this message translates to:
  /// **'Not them'**
  String get ceremonyNotThem;

  /// No description provided for @ceremonyRightPerson.
  ///
  /// In en, this message translates to:
  /// **'Yes, it\'s them'**
  String get ceremonyRightPerson;

  /// No description provided for @ceremonyJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join'**
  String get ceremonyJoinFailed;

  /// No description provided for @ceremonyConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}…'**
  String ceremonyConnecting(String name);

  /// No description provided for @ceremonySameWifi.
  ///
  /// In en, this message translates to:
  /// **'Both devices need to be on the same Wi-Fi, or connect to {name}\'s hotspot.'**
  String ceremonySameWifi(String name);

  /// No description provided for @ceremonyVerifyStep.
  ///
  /// In en, this message translates to:
  /// **'Step 2/3: verify {name}'**
  String ceremonyVerifyStep(String name);

  /// No description provided for @ceremonyPickCode.
  ///
  /// In en, this message translates to:
  /// **'Pick the 6 digits {name} reads aloud'**
  String ceremonyPickCode(String name);

  /// No description provided for @ceremonySealMatch.
  ///
  /// In en, this message translates to:
  /// **'The seal must also look the same on both devices.'**
  String get ceremonySealMatch;

  /// No description provided for @ceremonyNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'None of these match, stop'**
  String get ceremonyNoneMatch;

  /// No description provided for @ceremonyVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get ceremonyVerified;

  /// No description provided for @ceremonyWaitFinish.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to confirm and finish the workspace. Keep the app open.'**
  String ceremonyWaitFinish(String name);

  /// No description provided for @ceremonyStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get ceremonyStopped;

  /// No description provided for @ceremonyAbortedBody.
  ///
  /// In en, this message translates to:
  /// **'The codes didn\'t match, which means someone may be intercepting the connection between the two devices. You were not added. Ask {name} to create a new invite and scan again.'**
  String ceremonyAbortedBody(String name);

  /// No description provided for @ceremonyJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {name}'**
  String ceremonyJoined(String name);

  /// No description provided for @ceremonyStep3Done.
  ///
  /// In en, this message translates to:
  /// **'Step 3/3 done. You and the other members have signed the workspace charter.'**
  String get ceremonyStep3Done;

  /// No description provided for @ceremonyOpenWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open workspace'**
  String get ceremonyOpenWorkspace;

  /// No description provided for @ceremonyJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join workspace'**
  String get ceremonyJoinTitle;

  /// No description provided for @errWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get errWrongPin;

  /// No description provided for @errSyncExpired.
  ///
  /// In en, this message translates to:
  /// **'This sync code has expired. Ask the person who opened sync for a new one.'**
  String get errSyncExpired;

  /// No description provided for @errInviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite has expired.'**
  String get errInviteExpired;

  /// No description provided for @errCodeDamaged.
  ///
  /// In en, this message translates to:
  /// **'The code is damaged or incomplete. Scan it again.'**
  String get errCodeDamaged;

  /// No description provided for @errNotYourWorkspace.
  ///
  /// In en, this message translates to:
  /// **'This code is not for any workspace on this device.'**
  String get errNotYourWorkspace;

  /// No description provided for @errNotNexVaultCode.
  ///
  /// In en, this message translates to:
  /// **'This is not a NexVault code.'**
  String get errNotNexVaultCode;

  /// No description provided for @errHostUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the other device. Both need the same Wi-Fi, or the device that opened sync needs IPv6.'**
  String get errHostUnreachable;

  /// No description provided for @errRefused.
  ///
  /// In en, this message translates to:
  /// **'The other device refused the connection. This device may no longer be a member.'**
  String get errRefused;

  /// No description provided for @errNeedMember.
  ///
  /// In en, this message translates to:
  /// **'Add at least one other verified member.'**
  String get errNeedMember;

  /// No description provided for @errNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'This person has not picked the right code yet.'**
  String get errNotConfirmed;

  /// No description provided for @errVaultUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the data on this device.'**
  String get errVaultUnreadable;

  /// No description provided for @errRestoredSyncFirst.
  ///
  /// In en, this message translates to:
  /// **'This device was just restored from a backup. Sync with a member before editing.'**
  String get errRestoredSyncFirst;

  /// No description provided for @errRemoved.
  ///
  /// In en, this message translates to:
  /// **'You were removed from this workspace, so it can no longer sync.'**
  String get errRemoved;

  /// No description provided for @errFolderNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'The folder is not empty. Move or delete its secrets and subfolders first.'**
  String get errFolderNotEmpty;

  /// No description provided for @errFolderIntoItself.
  ///
  /// In en, this message translates to:
  /// **'A folder cannot be moved into itself.'**
  String get errFolderIntoItself;

  /// No description provided for @errFolderGone.
  ///
  /// In en, this message translates to:
  /// **'The folder no longer exists.'**
  String get errFolderGone;

  /// No description provided for @errAlreadyProposed.
  ///
  /// In en, this message translates to:
  /// **'This change has already been proposed.'**
  String get errAlreadyProposed;

  /// No description provided for @errAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'This person is already a member.'**
  String get errAlreadyMember;

  /// No description provided for @errOnlyMemberInvites.
  ///
  /// In en, this message translates to:
  /// **'Only a member who holds the key can invite new people.'**
  String get errOnlyMemberInvites;

  /// No description provided for @errWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong backup password.'**
  String get errWrongPassphrase;

  /// No description provided for @errNotBackup.
  ///
  /// In en, this message translates to:
  /// **'This file is not a NexVault backup.'**
  String get errNotBackup;

  /// No description provided for @errHasIdentity.
  ///
  /// In en, this message translates to:
  /// **'This device already has an identity. Erase its data before restoring.'**
  String get errHasIdentity;

  /// No description provided for @errPassphraseShort.
  ///
  /// In en, this message translates to:
  /// **'The backup password needs at least 10 characters.'**
  String get errPassphraseShort;

  /// No description provided for @errSecretTooBig.
  ///
  /// In en, this message translates to:
  /// **'The secret is larger than 10 MB.'**
  String get errSecretTooBig;

  /// No description provided for @errSessionFull.
  ///
  /// In en, this message translates to:
  /// **'This sync session is full.'**
  String get errSessionFull;

  /// No description provided for @errNoKeyForItem.
  ///
  /// In en, this message translates to:
  /// **'This device does not have the key for this item yet. Sync with another member.'**
  String get errNoKeyForItem;

  /// No description provided for @errNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'The data was written by a newer NexVault. Update the app.'**
  String get errNewerVersion;

  /// No description provided for @timeNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'not synced yet'**
  String get timeNeverSynced;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 minute ago} other{{n} minutes ago}}'**
  String timeMinutesAgo(int n);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 hour ago} other{{n} hours ago}}'**
  String timeHoursAgo(int n);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day ago} other{{n} days ago}}'**
  String timeDaysAgo(int n);

  /// No description provided for @timeToday.
  ///
  /// In en, this message translates to:
  /// **'today {time}'**
  String timeToday(String time);

  /// No description provided for @keysEnableFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Turn on fingerprint unlock'**
  String get keysEnableFingerprint;

  /// No description provided for @keysProtectWithLock.
  ///
  /// In en, this message translates to:
  /// **'Protect NexVault with your screen lock'**
  String get keysProtectWithLock;

  /// No description provided for @keysReprotectWithLock.
  ///
  /// In en, this message translates to:
  /// **'Protect NexVault with your screen lock again'**
  String get keysReprotectWithLock;

  /// No description provided for @keysUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock NexVault'**
  String get keysUnlockTitle;

  /// No description provided for @keysDevInvalidated.
  ///
  /// In en, this message translates to:
  /// **'The screen lock on this device was turned off or changed. Open with your recovery code.'**
  String get keysDevInvalidated;

  /// No description provided for @keysBioInvalidated.
  ///
  /// In en, this message translates to:
  /// **'The fingerprints or Face ID on this device changed. Open with your PIN, then turn it on again.'**
  String get keysBioInvalidated;

  /// No description provided for @keysUnlockFirst.
  ///
  /// In en, this message translates to:
  /// **'Unlock the app first.'**
  String get keysUnlockFirst;

  /// No description provided for @keysNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is not turned on.'**
  String get keysNotEnrolled;

  /// No description provided for @keysSealFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not store the key. This device needs a passcode.'**
  String get keysSealFailed;

  /// No description provided for @keysNoCipher.
  ///
  /// In en, this message translates to:
  /// **'No key came back from the prompt.'**
  String get keysNoCipher;

  /// No description provided for @keysUsePin.
  ///
  /// In en, this message translates to:
  /// **'Use PIN'**
  String get keysUsePin;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @pinFilled.
  ///
  /// In en, this message translates to:
  /// **'{filled} of {length} digits entered'**
  String pinFilled(int filled, int length);

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @pinEnterToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to continue'**
  String get pinEnterToContinue;

  /// No description provided for @pinWrongLeft.
  ///
  /// In en, this message translates to:
  /// **'{left, plural, =1{Wrong PIN, 1 try left} other{Wrong PIN, {left} tries left}}'**
  String pinWrongLeft(int left);

  /// No description provided for @copyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Copying is turned off in Settings.'**
  String get copyDisabled;

  /// No description provided for @copyKeyboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Your keyboard may keep a copy'**
  String get copyKeyboardTitle;

  /// No description provided for @copyKeyboardBody.
  ///
  /// In en, this message translates to:
  /// **'NexVault clears the clipboard after 30 seconds, but some keyboards (Samsung Keyboard, Gboard…) keep their own clipboard history that the app cannot clear. After pasting, delete the entry from the keyboard\'s history, or turn the keyboard\'s clipboard history off.\n\nYou can turn copying off entirely in Settings.'**
  String get copyKeyboardBody;

  /// No description provided for @copyUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Got it, copy'**
  String get copyUnderstood;

  /// No description provided for @qrLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get qrLabel;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get recoveryTitle;

  /// No description provided for @recoveryIntro.
  ///
  /// In en, this message translates to:
  /// **'Use it if this device\'s screen lock is turned off or reset. The code is shown only once.'**
  String get recoveryIntro;

  /// No description provided for @recoveryPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get recoveryPrint;

  /// No description provided for @recoveryPrintHint.
  ///
  /// In en, this message translates to:
  /// **'Use a printer at home only'**
  String get recoveryPrintHint;

  /// No description provided for @recoverySaved.
  ///
  /// In en, this message translates to:
  /// **'I wrote it down or printed it'**
  String get recoverySaved;

  /// No description provided for @recoveryPrintMeta.
  ///
  /// In en, this message translates to:
  /// **'Device: {device} &middot; Created: {date}'**
  String recoveryPrintMeta(String device, String date);

  /// No description provided for @recoveryPrintUse.
  ///
  /// In en, this message translates to:
  /// **'Use this code to open NexVault on this device only, if its screen lock is turned off or reset.'**
  String get recoveryPrintUse;

  /// No description provided for @recoveryPrintKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep this sheet somewhere safe, away from the device. Anyone with both this code and your device can open NexVault. When you create a new recovery code, this one stops working: destroy this sheet.'**
  String get recoveryPrintKeep;

  /// No description provided for @sealLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace seal'**
  String get sealLabel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @homeCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get homeCreateTitle;

  /// No description provided for @homeCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Every member needs to be here, on the same Wi-Fi or on your hotspot, to scan your code.'**
  String get homeCreateBody;

  /// No description provided for @homeWorkspaceName.
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get homeWorkspaceName;

  /// No description provided for @homeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get homeCancel;

  /// No description provided for @homeCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get homeCreateInvite;

  /// No description provided for @homeNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get homeNotSynced;

  /// No description provided for @homeSyncedWith.
  ///
  /// In en, this message translates to:
  /// **'Synced with {name} {ago}'**
  String homeSyncedWith(String name, String ago);

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get homeTitle;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeLockApp.
  ///
  /// In en, this message translates to:
  /// **'Lock app'**
  String get homeLockApp;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No workspaces yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create a workspace when the members are together, or scan the creator\'s invite code.'**
  String get homeEmptyBody;

  /// No description provided for @homePendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for members to approve'**
  String get homePendingApproval;

  /// No description provided for @homeNeedsAction.
  ///
  /// In en, this message translates to:
  /// **'A proposal needs your review'**
  String get homeNeedsAction;

  /// No description provided for @homeCounts.
  ///
  /// In en, this message translates to:
  /// **'{members, plural, =1{1 member} other{{members} members}}, {secrets, plural, =1{1 secret} other{{secrets} secrets}}'**
  String homeCounts(int members, int secrets);

  /// No description provided for @homeYouAre.
  ///
  /// In en, this message translates to:
  /// **'You are {name}, device {device}'**
  String homeYouAre(String name, String device);

  /// No description provided for @homeCreateWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get homeCreateWorkspace;

  /// No description provided for @homeScanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan code'**
  String get homeScanCode;

  /// No description provided for @scanNoCodeInImage.
  ///
  /// In en, this message translates to:
  /// **'No NexVault code found in the image.'**
  String get scanNoCodeInImage;

  /// No description provided for @scanNotNexVault.
  ///
  /// In en, this message translates to:
  /// **'This is not a NexVault code.'**
  String get scanNotNexVault;

  /// No description provided for @scanPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste code'**
  String get scanPaste;

  /// No description provided for @scanCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get scanCancel;

  /// No description provided for @scanOpenCode.
  ///
  /// In en, this message translates to:
  /// **'Open code'**
  String get scanOpenCode;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan code'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a workspace invite or a sync code on another member\'s device.'**
  String get scanHint;

  /// No description provided for @scanCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'NexVault isn\'t allowed to use the camera. Allow it to scan, or use \"Pick code image\" / \"Paste code\".'**
  String get scanCameraDenied;

  /// No description provided for @scanCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera. Use \"Pick code image\" or \"Paste code\".'**
  String get scanCameraFailed;

  /// No description provided for @scanAllowCamera.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get scanAllowCamera;

  /// No description provided for @scanPickImage.
  ///
  /// In en, this message translates to:
  /// **'Pick code image'**
  String get scanPickImage;

  /// No description provided for @secretActionCreated.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get secretActionCreated;

  /// No description provided for @secretActionEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get secretActionEdited;

  /// No description provided for @secretActionViewed.
  ///
  /// In en, this message translates to:
  /// **'viewed'**
  String get secretActionViewed;

  /// No description provided for @secretActionCopied.
  ///
  /// In en, this message translates to:
  /// **'copied'**
  String get secretActionCopied;

  /// No description provided for @secretActionExported.
  ///
  /// In en, this message translates to:
  /// **'exported a file'**
  String get secretActionExported;

  /// No description provided for @secretFieldP12Password.
  ///
  /// In en, this message translates to:
  /// **'.p12 password'**
  String get secretFieldP12Password;

  /// No description provided for @secretFieldExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get secretFieldExpires;

  /// No description provided for @secretFieldStorePassword.
  ///
  /// In en, this message translates to:
  /// **'Store password'**
  String get secretFieldStorePassword;

  /// No description provided for @secretFieldKeyPassword.
  ///
  /// In en, this message translates to:
  /// **'Key password'**
  String get secretFieldKeyPassword;

  /// No description provided for @secretFieldHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get secretFieldHost;

  /// No description provided for @secretFieldSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'{field} (secret)'**
  String secretFieldSecretLabel(String field);

  /// No description provided for @secretFieldExpiresHint.
  ///
  /// In en, this message translates to:
  /// **'Expires (yyyy-mm-dd)'**
  String get secretFieldExpiresHint;

  /// No description provided for @secretAuthToView.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to view {name}'**
  String secretAuthToView(String name);

  /// No description provided for @secretBinaryUseExport.
  ///
  /// In en, this message translates to:
  /// **'The content is a binary file. Use \"Export file\".'**
  String get secretBinaryUseExport;

  /// No description provided for @secretCopiedAutoClear.
  ///
  /// In en, this message translates to:
  /// **'Copied. The clipboard clears itself after 30 seconds.'**
  String get secretCopiedAutoClear;

  /// No description provided for @secretExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export file?'**
  String get secretExportTitle;

  /// No description provided for @secretExportBody.
  ///
  /// In en, this message translates to:
  /// **'The file holds the private key unencrypted. Only save it somewhere you trust. The export is recorded in the history.'**
  String get secretExportBody;

  /// No description provided for @secretCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get secretCancel;

  /// No description provided for @secretExport.
  ///
  /// In en, this message translates to:
  /// **'Export file'**
  String get secretExport;

  /// No description provided for @secretMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved to folder'**
  String get secretMoved;

  /// No description provided for @secretDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String secretDeleteTitle(String name);

  /// No description provided for @secretDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The secret is deleted on every device after the next sync. The history is kept.'**
  String get secretDeleteBody;

  /// No description provided for @secretDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete secret'**
  String get secretDelete;

  /// No description provided for @secretMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get secretMore;

  /// No description provided for @secretCopyContent.
  ///
  /// In en, this message translates to:
  /// **'Copy content'**
  String get secretCopyContent;

  /// No description provided for @secretAutoClear30.
  ///
  /// In en, this message translates to:
  /// **'Clears after 30 seconds'**
  String get secretAutoClear30;

  /// No description provided for @secretCopyField.
  ///
  /// In en, this message translates to:
  /// **'Copy {field}'**
  String secretCopyField(String field);

  /// No description provided for @secretEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get secretEdit;

  /// No description provided for @secretMoveFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get secretMoveFolder;

  /// No description provided for @secretSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{kind}, version {version}'**
  String secretSubtitle(String kind, String version);

  /// No description provided for @secretCopiedField.
  ///
  /// In en, this message translates to:
  /// **'Copied {field}'**
  String secretCopiedField(String field);

  /// No description provided for @secretFileSize.
  ///
  /// In en, this message translates to:
  /// **'{name}, {size} bytes'**
  String secretFileSize(String name, String size);

  /// No description provided for @secretContentShown.
  ///
  /// In en, this message translates to:
  /// **'Secret content is showing'**
  String get secretContentShown;

  /// No description provided for @secretHoldToViewContent.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to view the secret content'**
  String get secretHoldToViewContent;

  /// No description provided for @secretHideIn.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Hides in 1 second} other{Hides in {seconds} seconds}}'**
  String secretHideIn(int seconds);

  /// No description provided for @secretShow10s.
  ///
  /// In en, this message translates to:
  /// **'Show for 10 seconds'**
  String get secretShow10s;

  /// No description provided for @secretHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get secretHistory;

  /// No description provided for @secretConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Two people edited this secret at the same time. Both versions are kept; pick the right one.'**
  String get secretConflictBody;

  /// No description provided for @secretView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get secretView;

  /// No description provided for @secretKeepThis.
  ///
  /// In en, this message translates to:
  /// **'Keep this one'**
  String get secretKeepThis;

  /// No description provided for @secretAuthToViewVersion.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to view {name}\'s version'**
  String secretAuthToViewVersion(String name);

  /// No description provided for @secretVersionOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s version'**
  String secretVersionOf(String name);

  /// No description provided for @secretBinaryFile.
  ///
  /// In en, this message translates to:
  /// **'Binary file {name}, {size} bytes'**
  String secretBinaryFile(String name, String size);

  /// No description provided for @secretClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get secretClose;

  /// No description provided for @secretKeptVersion.
  ///
  /// In en, this message translates to:
  /// **'Kept {name}\'s version'**
  String secretKeptVersion(String name);

  /// No description provided for @secretHoldToView.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to view'**
  String get secretHoldToView;

  /// No description provided for @secretHoldToViewWhat.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to view {what}'**
  String secretHoldToViewWhat(String what);

  /// No description provided for @secretAuthedHint.
  ///
  /// In en, this message translates to:
  /// **'Authenticated for 60 seconds. The content hides again when you let go.'**
  String get secretAuthedHint;

  /// No description provided for @secretNeedAuthHint.
  ///
  /// In en, this message translates to:
  /// **'Needs your fingerprint or PIN. The content hides again when you let go.'**
  String get secretNeedAuthHint;

  /// No description provided for @secretCopiedFieldAutoClear.
  ///
  /// In en, this message translates to:
  /// **'Copied {field}. The clipboard clears itself after 30 seconds.'**
  String secretCopiedFieldAutoClear(String field);

  /// No description provided for @secretBinaryUseMenu.
  ///
  /// In en, this message translates to:
  /// **'Binary file {name}. Use \"Export file\" in the menu.'**
  String secretBinaryUseMenu(String name);

  /// No description provided for @secretWhatKey.
  ///
  /// In en, this message translates to:
  /// **'the private key'**
  String get secretWhatKey;

  /// No description provided for @secretWhatP12.
  ///
  /// In en, this message translates to:
  /// **'the cert and password'**
  String get secretWhatP12;

  /// No description provided for @secretWhatJks.
  ///
  /// In en, this message translates to:
  /// **'the keystore and passwords'**
  String get secretWhatJks;

  /// No description provided for @secretWhatEnv.
  ///
  /// In en, this message translates to:
  /// **'the environment variables'**
  String get secretWhatEnv;

  /// No description provided for @secretWhatContent.
  ///
  /// In en, this message translates to:
  /// **'the content'**
  String get secretWhatContent;

  /// No description provided for @secretKindP12.
  ///
  /// In en, this message translates to:
  /// **'.p12 certificate'**
  String get secretKindP12;

  /// No description provided for @secretKindEnv.
  ///
  /// In en, this message translates to:
  /// **'.env file'**
  String get secretKindEnv;

  /// No description provided for @secretKindText.
  ///
  /// In en, this message translates to:
  /// **'Password / text'**
  String get secretKindText;

  /// No description provided for @secretNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the secret a name'**
  String get secretNameRequired;

  /// No description provided for @secretFileOrPaste.
  ///
  /// In en, this message translates to:
  /// **'Choose a file or paste the content'**
  String get secretFileOrPaste;

  /// No description provided for @secretAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add secret'**
  String get secretAddTitle;

  /// No description provided for @secretEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit secret'**
  String get secretEditTitle;

  /// No description provided for @secretKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get secretKind;

  /// No description provided for @secretNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name, e.g. APNs production'**
  String get secretNameHint;

  /// No description provided for @secretNoFolder.
  ///
  /// In en, this message translates to:
  /// **'Not in a folder'**
  String get secretNoFolder;

  /// No description provided for @secretChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get secretChange;

  /// No description provided for @secretChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get secretChooseFile;

  /// No description provided for @secretChooseFileExt.
  ///
  /// In en, this message translates to:
  /// **'Choose .{ext} file'**
  String secretChooseFileExt(String ext);

  /// No description provided for @secretChangeFile.
  ///
  /// In en, this message translates to:
  /// **'Change file'**
  String get secretChangeFile;

  /// No description provided for @secretOrPaste.
  ///
  /// In en, this message translates to:
  /// **'Or paste the content'**
  String get secretOrPaste;

  /// No description provided for @secretTextHint.
  ///
  /// In en, this message translates to:
  /// **'Password or secret note'**
  String get secretTextHint;

  /// No description provided for @secretEncryptedNote.
  ///
  /// In en, this message translates to:
  /// **'The secret is encrypted on this device. Other members receive it at the next sync.'**
  String get secretEncryptedNote;

  /// No description provided for @secretSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get secretSaving;

  /// No description provided for @secretSave.
  ///
  /// In en, this message translates to:
  /// **'Save secret'**
  String get secretSave;

  /// No description provided for @settingsCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN'**
  String get settingsCurrentPin;

  /// No description provided for @settingsWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get settingsWrongPin;

  /// No description provided for @settingsNewPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get settingsNewPin;

  /// No description provided for @settingsRepeatNewPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the new PIN again'**
  String get settingsRepeatNewPin;

  /// No description provided for @settingsMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two entries don\'t match'**
  String get settingsMismatch;

  /// No description provided for @settingsPinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get settingsPinChanged;

  /// No description provided for @settingsPinToDevice.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to switch to the screen lock'**
  String get settingsPinToDevice;

  /// No description provided for @settingsSwitchedToDevice.
  ///
  /// In en, this message translates to:
  /// **'NexVault now opens with the screen lock. The old PIN no longer works.'**
  String get settingsSwitchedToDevice;

  /// No description provided for @settingsAuthNewRecovery.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to create a new recovery code'**
  String get settingsAuthNewRecovery;

  /// No description provided for @settingsLockNow.
  ///
  /// In en, this message translates to:
  /// **'As soon as you leave the app'**
  String get settingsLockNow;

  /// No description provided for @settingsLock1.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get settingsLock1;

  /// No description provided for @settingsLock5.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get settingsLock5;

  /// No description provided for @settingsAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get settingsAutoLock;

  /// No description provided for @settingsAuthCopy.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to allow copying'**
  String get settingsAuthCopy;

  /// No description provided for @settingsPinForBio.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to turn on fingerprint unlock'**
  String get settingsPinForBio;

  /// No description provided for @settingsSetBackupPass.
  ///
  /// In en, this message translates to:
  /// **'Set backup password'**
  String get settingsSetBackupPass;

  /// No description provided for @settingsBackupPass.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get settingsBackupPass;

  /// No description provided for @settingsBackupPassHint.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters. There is no way to recover the backup if you forget this password. A long sentence works well.'**
  String get settingsBackupPassHint;

  /// No description provided for @settingsPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsPassword;

  /// No description provided for @settingsRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get settingsRepeat;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsMinChars.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters needed'**
  String get settingsMinChars;

  /// No description provided for @settingsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get settingsContinue;

  /// No description provided for @settingsAuthBackup.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to back up'**
  String get settingsAuthBackup;

  /// No description provided for @settingsBackupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get settingsBackupSaved;

  /// No description provided for @settingsWipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase all data on this device?'**
  String get settingsWipeTitle;

  /// No description provided for @settingsWipeBody.
  ///
  /// In en, this message translates to:
  /// **'Your identity, workspaces and every secret on this device are permanently erased. Data on other members\' devices stays. To get back into a workspace, you need to restore from a backup or be invited again in person.'**
  String get settingsWipeBody;

  /// No description provided for @settingsWipeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Erase all'**
  String get settingsWipeConfirm;

  /// No description provided for @settingsAuthWipe.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to erase data'**
  String get settingsAuthWipe;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID '**
  String get settingsDeviceId;

  /// No description provided for @settingsUnlockSection.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get settingsUnlockSection;

  /// No description provided for @settingsScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Phone screen lock'**
  String get settingsScreenLock;

  /// No description provided for @settingsScreenLockSub.
  ///
  /// In en, this message translates to:
  /// **'Opens with fingerprint / Face ID or the device passcode'**
  String get settingsScreenLockSub;

  /// No description provided for @settingsNewRecovery.
  ///
  /// In en, this message translates to:
  /// **'Create a new recovery code'**
  String get settingsNewRecovery;

  /// No description provided for @settingsNewRecoverySub.
  ///
  /// In en, this message translates to:
  /// **'The old code will stop working'**
  String get settingsNewRecoverySub;

  /// No description provided for @settingsChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsChangePin;

  /// No description provided for @settingsToDevice.
  ///
  /// In en, this message translates to:
  /// **'Switch to the screen lock'**
  String get settingsToDevice;

  /// No description provided for @settingsToDeviceSub.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint / Face ID or the device passcode instead of the app PIN'**
  String get settingsToDeviceSub;

  /// No description provided for @settingsBio.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get settingsBio;

  /// No description provided for @settingsBioSub.
  ///
  /// In en, this message translates to:
  /// **'The data key is sealed in the phone\'s security chip'**
  String get settingsBioSub;

  /// No description provided for @settingsCopy.
  ///
  /// In en, this message translates to:
  /// **'Allow copying secrets'**
  String get settingsCopy;

  /// No description provided for @settingsCopySub.
  ///
  /// In en, this message translates to:
  /// **'Cleared after 30 seconds, but the keyboard\'s clipboard history may still keep it'**
  String get settingsCopySub;

  /// No description provided for @settingsAutoLockAfter1.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute in the background'**
  String get settingsAutoLockAfter1;

  /// No description provided for @settingsAutoLockAfterMin.
  ///
  /// In en, this message translates to:
  /// **'After {minutes} minutes in the background'**
  String settingsAutoLockAfterMin(int minutes);

  /// No description provided for @settingsAutoLockSub.
  ///
  /// In en, this message translates to:
  /// **'{when}. Viewing a secret always asks again.'**
  String settingsAutoLockSub(String when);

  /// No description provided for @settingsBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackupSection;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get settingsExport;

  /// No description provided for @settingsExportSub.
  ///
  /// In en, this message translates to:
  /// **'Your identity and every workspace, locked with a separate password. Use it when you lose or change your phone.'**
  String get settingsExportSub;

  /// No description provided for @settingsDangerSection.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerSection;

  /// No description provided for @settingsWipe.
  ///
  /// In en, this message translates to:
  /// **'Erase all data on this device'**
  String get settingsWipe;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'NexVault core {core}, vault format v{vault}'**
  String settingsVersion(String core, String vault);

  /// No description provided for @syncPeerDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get syncPeerDone;

  /// No description provided for @syncPeerSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncPeerSyncing;

  /// No description provided for @syncPeerLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get syncPeerLeft;

  /// No description provided for @syncPeerNotScanned.
  ///
  /// In en, this message translates to:
  /// **'Not scanned'**
  String get syncPeerNotScanned;

  /// No description provided for @syncPeerRemovedName.
  ///
  /// In en, this message translates to:
  /// **'{name} (removed)'**
  String syncPeerRemovedName(String name);

  /// No description provided for @syncPeerRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get syncPeerRejected;

  /// No description provided for @syncPeerNewMember.
  ///
  /// In en, this message translates to:
  /// **'{name} (new member)'**
  String syncPeerNewMember(String name);

  /// No description provided for @syncStrangers.
  ///
  /// In en, this message translates to:
  /// **'Unknown devices ({count})'**
  String syncStrangers(int count);

  /// No description provided for @syncHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync {name}'**
  String syncHostTitle(String name);

  /// No description provided for @syncHostIntro.
  ///
  /// In en, this message translates to:
  /// **'Members open NexVault and scan this code. If someone is far away, send them a picture of the code by chat: only devices in the workspace can decrypt it.'**
  String get syncHostIntro;

  /// No description provided for @syncExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Code expires in '**
  String get syncExpiresIn;

  /// No description provided for @syncExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired, connections are closed'**
  String get syncExpired;

  /// No description provided for @syncConnectVia.
  ///
  /// In en, this message translates to:
  /// **'Connects over the same Wi-Fi network or IPv6'**
  String get syncConnectVia;

  /// No description provided for @syncShareText.
  ///
  /// In en, this message translates to:
  /// **'NexVault sync code ({name}), expires in {left}'**
  String syncShareText(String name, String left);

  /// No description provided for @syncShareButton.
  ///
  /// In en, this message translates to:
  /// **'Send the code picture to someone far away'**
  String get syncShareButton;

  /// No description provided for @syncNewCode.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get syncNewCode;

  /// No description provided for @syncEnd.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get syncEnd;

  /// No description provided for @syncJoinConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {host}…'**
  String syncJoinConnecting(String host);

  /// No description provided for @syncJoinConnectingHint.
  ///
  /// In en, this message translates to:
  /// **'Trying the same Wi-Fi network first, then IPv6.'**
  String get syncJoinConnectingHint;

  /// No description provided for @syncJoinSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing with {host}'**
  String syncJoinSyncing(String host);

  /// No description provided for @syncJoinCounts.
  ///
  /// In en, this message translates to:
  /// **'Received {received}, sent {sent} changes.'**
  String syncJoinCounts(String received, String sent);

  /// No description provided for @syncJoinDone.
  ///
  /// In en, this message translates to:
  /// **'Synced with {host}'**
  String syncJoinDone(String host);

  /// No description provided for @syncJoinDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Received {received}, sent {sent} changes. Keep this screen open to receive more changes from others in this session.'**
  String syncJoinDoneBody(String received, String sent);

  /// No description provided for @syncJoinClosed.
  ///
  /// In en, this message translates to:
  /// **'The sync session has ended'**
  String get syncJoinClosed;

  /// No description provided for @syncJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sync'**
  String get syncJoinFailed;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get syncDone;

  /// No description provided for @syncClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get syncClose;

  /// No description provided for @workspaceSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get workspaceSave;

  /// No description provided for @workspaceFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get workspaceFolderName;

  /// No description provided for @workspaceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get workspaceCancel;

  /// No description provided for @workspaceNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get workspaceNewFolder;

  /// No description provided for @workspaceCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get workspaceCreate;

  /// No description provided for @workspaceRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get workspaceRename;

  /// No description provided for @workspaceMoveFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to another folder'**
  String get workspaceMoveFolder;

  /// No description provided for @workspaceDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get workspaceDeleteFolder;

  /// No description provided for @workspaceDeleteFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Only empty folders can be deleted'**
  String get workspaceDeleteFolderHint;

  /// No description provided for @workspaceRenameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get workspaceRenameFolder;

  /// No description provided for @workspaceMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get workspaceMembers;

  /// No description provided for @workspaceMembersRule.
  ///
  /// In en, this message translates to:
  /// **'Adding someone needs every member to agree. Removing someone needs 2/3 of the members who stay to agree.'**
  String get workspaceMembersRule;

  /// No description provided for @workspaceMemberYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String workspaceMemberYou(String name);

  /// No description provided for @workspaceThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get workspaceThisDevice;

  /// No description provided for @workspaceMemberSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced {when}'**
  String workspaceMemberSynced(String when);

  /// No description provided for @workspaceProposeRemoval.
  ///
  /// In en, this message translates to:
  /// **'Propose removal'**
  String get workspaceProposeRemoval;

  /// No description provided for @workspaceInviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite a new member'**
  String get workspaceInviteMember;

  /// No description provided for @workspaceProposeRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Propose removing {name}?'**
  String workspaceProposeRemoveTitle(String name);

  /// No description provided for @workspaceProposeRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The proposal takes effect once enough members agree over their syncs. The workspace then switches to a new key. The removed member has already seen the current secrets: rotate the important keys.'**
  String get workspaceProposeRemoveBody;

  /// No description provided for @workspaceExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get workspaceExpired;

  /// No description provided for @workspaceExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Expires in 1 day} other{Expires in {days} days}}'**
  String workspaceExpiresIn(int days);

  /// No description provided for @workspaceConflict.
  ///
  /// In en, this message translates to:
  /// **'2 versions, pick one'**
  String get workspaceConflict;

  /// No description provided for @workspaceVersionDate.
  ///
  /// In en, this message translates to:
  /// **'Version {version}, {date}'**
  String workspaceVersionDate(String version, String date);

  /// No description provided for @workspaceJustCreated.
  ///
  /// In en, this message translates to:
  /// **'Just created'**
  String get workspaceJustCreated;

  /// No description provided for @workspaceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {when}'**
  String workspaceUpdated(String when);

  /// No description provided for @workspaceMemberYouShort.
  ///
  /// In en, this message translates to:
  /// **'{name}\n(you)'**
  String workspaceMemberYouShort(String name);

  /// No description provided for @workspacePendingBanner.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the members to agree to add you. Open sync with them to receive the approvals and the workspace key.'**
  String get workspacePendingBanner;

  /// No description provided for @workspaceStaleBanner.
  ///
  /// In en, this message translates to:
  /// **'This device was just restored from a backup. Open sync with a member to get the changes made after the backup; you can edit again after that.'**
  String get workspaceStaleBanner;

  /// No description provided for @workspaceRemovedBanner.
  ///
  /// In en, this message translates to:
  /// **'You were removed from this workspace. New data will no longer reach this device.'**
  String get workspaceRemovedBanner;

  /// No description provided for @workspaceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Search 1 secret} other{Search {count} secrets}}'**
  String workspaceSearchHint(int count);

  /// No description provided for @workspaceAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get workspaceAll;

  /// No description provided for @workspaceSecretCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 secret} other{{count} secrets}}'**
  String workspaceSecretCount(int count);

  /// No description provided for @workspaceFolderOptions.
  ///
  /// In en, this message translates to:
  /// **'Folder options'**
  String get workspaceFolderOptions;

  /// No description provided for @workspaceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No secrets yet. Add a .p8 key, .p12 cert, keystore, SSH key or .env file, group them into folders, then open sync to share.'**
  String get workspaceEmpty;

  /// No description provided for @workspaceFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty folder.'**
  String get workspaceFolderEmpty;

  /// No description provided for @workspaceAddSecret.
  ///
  /// In en, this message translates to:
  /// **'Add secret'**
  String get workspaceAddSecret;

  /// No description provided for @workspaceOpenSync.
  ///
  /// In en, this message translates to:
  /// **'Open sync'**
  String get workspaceOpenSync;

  /// No description provided for @workspaceNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'not synced'**
  String get workspaceNeverSynced;

  /// No description provided for @workspaceJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get workspaceJustNow;

  /// No description provided for @workspaceMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String workspaceMinutesShort(int n);

  /// No description provided for @workspaceHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{n} hr'**
  String workspaceHoursShort(int n);

  /// No description provided for @workspaceDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day} other{{n} days}}'**
  String workspaceDaysShort(int n);

  /// No description provided for @workspaceProposalAdd.
  ///
  /// In en, this message translates to:
  /// **'{proposer} proposed adding {name}: {approvals}/{needed} agreed'**
  String workspaceProposalAdd(
    String proposer,
    String name,
    String approvals,
    String needed,
  );

  /// No description provided for @workspaceProposalRemove.
  ///
  /// In en, this message translates to:
  /// **'Proposal to remove {name}: {approvals}/{needed} agreed'**
  String workspaceProposalRemove(String name, String approvals, String needed);

  /// No description provided for @workspaceProposalAwaitingKeys.
  ///
  /// In en, this message translates to:
  /// **'{text}. Waiting to hand over keys at the next sync.'**
  String workspaceProposalAwaitingKeys(String text);

  /// No description provided for @workspaceApproveAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Agree to add {name}?'**
  String workspaceApproveAddTitle(String name);

  /// No description provided for @workspaceApproveRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Agree to remove {name}?'**
  String workspaceApproveRemoveTitle(String name);

  /// No description provided for @workspaceApproveAddBody.
  ///
  /// In en, this message translates to:
  /// **'{proposer} met {name} in person and verified them. Once everyone agrees, {name} can read every secret in the workspace.'**
  String workspaceApproveAddBody(String proposer, String name);

  /// No description provided for @workspaceApproveRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Once enough members agree, {name} no longer receives new data and the workspace switches to a new key.'**
  String workspaceApproveRemoveBody(String name);

  /// No description provided for @workspaceApprove.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get workspaceApprove;

  /// No description provided for @workspacePickFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get workspacePickFolder;

  /// No description provided for @workspaceNoFolder.
  ///
  /// In en, this message translates to:
  /// **'Not in any folder'**
  String get workspaceNoFolder;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'vi':
      return SVi();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
