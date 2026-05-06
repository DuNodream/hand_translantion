import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sign_language_interpretation/config/app_config.dart';

void main() {
  test('app config falls back to dev defaults in test runtime', () {
    final config = AppConfig.current;
    expect(config.wsUrl.isNotEmpty, isTrue);
    expect(config.apiBaseUrl.isNotEmpty, isTrue);
  });
}
