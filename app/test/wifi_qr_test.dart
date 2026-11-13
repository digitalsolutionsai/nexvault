import 'package:flutter_test/flutter_test.dart';
import 'package:nexvault/screens/secret.dart';

void main() {
  test('Wi-Fi QR payload', () {
    expect(wifiQrPayload('Aurora Office', 'p@ss-2026'), 'WIFI:T:WPA;S:Aurora Office;P:p@ss-2026;;');
    // reserved characters are escaped with a backslash
    expect(wifiQrPayload(r'a;b,c:d"e\f', 'x;y'), r'WIFI:T:WPA;S:a\;b\,c\:d\"e\\f;P:x\;y;;');
    expect(wifiQrPayload('Guest', ''), 'WIFI:T:nopass;S:Guest;;');
  });
}
