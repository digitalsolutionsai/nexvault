import 'package:flutter_test/flutter_test.dart';
import 'package:nexvault/ui/hotspot.dart';

void main() {
  test('code with private Wi-Fi round-trips, and plain codes stay untouched', () {
    const code = 'nexvault://t/abc-DEF_123';
    expect(withWifi(code, null), code);
    final c = withWifi(code, {'ssid': 'AndroidShare_4821', 'pass': 'p#ss=w;rd', 'sec': 1});
    expect(c.startsWith('$code#w='), isTrue);
    final (plain, w) = splitWifi(c);
    expect(plain, code);
    expect(w, {'s': 'AndroidShare_4821', 'p': 'p#ss=w;rd', 't': 1});
    expect(splitWifi(code), (code, null));
    // garbage after the marker: still opens the code, just without Wi-Fi
    expect(splitWifi('$code#w=%%%'), (code, null));
  });
}
