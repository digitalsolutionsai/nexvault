// On-device smoke test (iOS simulator / Android emulator):
//   flutter test integration_test/smoke_test.dart -d <device>
// Runs in whatever language the device uses (strings come from the app's own tables).
// Wipes the app's data first. Covers the Rust link (dart:ffi lookup), PIN custody in the core,
// lock/unlock, and binding the ceremony listener on the platform's interfaces.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexvault/core/bridge.dart';
import 'package:nexvault/core/keys.dart';
import 'package:nexvault/l10n/l10n.dart';
import 'package:nexvault/main.dart' as app;

Future<void> enterPin(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.text(d).last);
    await t.pump(const Duration(milliseconds: 120));
  }
  await t.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> settle(WidgetTester t, [int seconds = 3]) async {
  for (var i = 0; i < seconds * 4; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding, lock/unlock, ceremony listener', (t) async {
    Keys.noDeviceLockForTests = true;
    await Keys.wipe();
    expect((await Core.call('version'))['core'], isNotNull);

    app.main();
    await settle(t);
    // the intro pages come first on a fresh install: skip them
    expect(find.text(tr.intro1Title), findsOneWidget);
    await t.tap(find.text(tr.introSkip));
    await settle(t);
    await t.enterText(find.byType(TextField), 'An');
    await t.pump();
    await t.tap(find.text(tr.authContinue));
    await settle(t, 2);
    // the system lock-screen prompt cannot be driven from a test: the app offers its own PIN
    expect(find.text(tr.authNoLockTitle), findsOneWidget);
    await t.tap(find.text(tr.authUseAppPin));
    await settle(t, 1);
    await enterPin(t, '135790');
    await enterPin(t, '135790');
    await settle(t, 4); // Argon2id
    if (find.text(tr.authLater).evaluate().isNotEmpty) {
      await t.tap(find.text(tr.authLater));
      await settle(t, 1);
    }
    expect(find.text(tr.homeTitle), findsOneWidget);
    expect(find.textContaining(tr.homeYouAre('An', '').split(',').first), findsOneWidget);

    // lock, wrong PIN, right PIN
    await t.tap(find.byTooltip(tr.homeLockApp));
    await settle(t, 1);
    expect(find.text(tr.authLocked), findsOneWidget);
    await enterPin(t, '111111');
    await settle(t, 3);
    expect(find.text(tr.authLocked), findsOneWidget);
    await enterPin(t, '135790');
    await settle(t, 4);
    expect(find.text(tr.homeTitle), findsOneWidget);

    // the ceremony binds its listener on this platform's interfaces and shows an invite
    await Keys.refreshNet(); // iOS netIfaces -> core
    final r = await Core.call('ceremony_create', {'name': 'Smoke'});
    debugPrint('ceremony: $r');
    expect(r, isNotNull);
    final st = await Core.call('ceremony_status');
    debugPrint('ceremony status: $st');
    await Core.call('ceremony_cancel').catchError((_) => null);
  });
}
