import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/config/app_config.dart';

void main() {
  test('provides an absolute API URL valid for the current platform', () {
    final uri = Uri.parse(AppConfig.apiBaseUrl);

    expect(uri.isAbsolute, true);
    expect(uri.host, isNotEmpty);
    expect(['http', 'https'], contains(uri.scheme));
    if (kIsWeb) expect(uri.host, isNot('10.0.2.2'));
  });
}
