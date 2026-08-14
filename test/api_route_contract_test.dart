import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removed recurring plan-payment endpoint is not shipped', () {
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(dartSources, isNot(contains('/api/plans/\$planId/pay')));
    expect(dartSources, isNot(contains('payMonthlyInstalment')));
    expect(dartSources, isNot(contains('PlanPaymentScreen')));
  });
}
