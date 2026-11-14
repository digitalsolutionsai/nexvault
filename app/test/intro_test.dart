import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexvault/l10n/l10n.dart';
import 'package:nexvault/screens/intro.dart';

void main() {
  for (final lang in ['en', 'vi']) {
    testWidgets('intro pages lay out on a phone ($lang), Next walks them, the last one finishes', (t) async {
      tr = lookupS(Locale(lang));
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      var done = 0;
      await t.pumpWidget(MaterialApp(home: IntroScreen(onDone: () => done++)));
      await t.pump(const Duration(milliseconds: 300));
      for (final title in [tr.intro1Title, tr.intro2Title, tr.intro3Title]) {
        expect(find.text(title), findsOneWidget);
        await t.tap(find.text(title == tr.intro3Title ? tr.introStart : tr.introNext));
        await t.pump(); // start the page animation, then let it finish
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(done, 1);
    });
  }

  testWidgets('Skip finishes at once', (t) async {
    tr = lookupS(const Locale('en'));
    var done = 0;
    await t.pumpWidget(MaterialApp(home: IntroScreen(onDone: () => done++)));
    await t.tap(find.text(tr.introSkip));
    expect(done, 1);
  });
}
