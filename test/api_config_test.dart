import 'package:flutter_test/flutter_test.dart';
import 'package:moneytries/core/api/api_config.dart';

void main() {
  group('ApiConfig production defaults', () {
    test('targets the MoneyTries v1 deployment prefix', () {
      expect(ApiConfig.baseUrl, 'https://moneytries.com/v1');
    });

    test('composes API routes without duplicating the api segment', () {
      expect(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login').toString(),
        'https://moneytries.com/v1/api/auth/login',
      );
      expect(ApiConfig.baseUrl.endsWith('/api'), isFalse);
    });
  });
}
