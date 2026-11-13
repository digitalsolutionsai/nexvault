import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexvault/ui/seal.dart';
import 'package:nexvault/ui/theme.dart';

void main() {
  testWidgets('seal renders for any 9-byte hex and for bad input', (t) async {
    for (final hex in ['000000000000000000', 'ffffffffffffffffff', '0a1b2c3d4e5f607182', 'zz']) {
      await t.pumpWidget(MaterialApp(home: Center(child: Seal(hex, size: 80))));
      expect(find.byType(Seal), findsOneWidget);
    }
  });

  test('timeAgo handles null and past times', () {
    expect(timeAgo(null), isNotEmpty);
    expect(timeAgo(DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch), isNotEmpty);
  });
}
