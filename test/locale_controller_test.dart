import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LocaleController defaults to Thai and persists English', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = LocaleController();

    await controller.init();
    expect(controller.languageCode, 'th');

    await controller.setLanguage('en');
    expect(controller.languageCode, 'en');

    final restored = LocaleController();
    await restored.init();
    expect(restored.languageCode, 'en');
  });
}
