import 'package:flutter_test/flutter_test.dart';
import 'package:moneytries/core/api/api_config.dart';
import 'package:moneytries/models/plan/plan_models.dart';

void main() {
  group('production response contracts', () {
    test('ROI withdrawal reads amount from the backend data envelope', () {
      final response = RoiWithdrawalResponse.fromJson({
        'success': true,
        'message': 'ROI withdrawn',
        'data': {'amount': 125.50},
      });

      expect(response.success, isTrue);
      expect(response.amount, 125.50);
    });

    test(
      'principal withdrawal reads amount from the backend data envelope',
      () {
        final response = PrincipalWithdrawalResponse.fromJson({
          'success': true,
          'message': 'Principal withdrawn',
          'data': {'amount': 5000},
        });

        expect(response.success, isTrue);
        expect(response.amount, 5000);
      },
    );

    test('active plan honors the backend calendar maturity date', () {
      final plan = ActivePlan.fromJson({
        'id': 1,
        'plan_type': 3,
        'monthly_amount': 1000,
        'months_paid': 1,
        'start_date': '2026-01-31',
        'maturity_date': '2026-04-30',
        'status': 'active',
      });

      expect(plan.maturityDate.toIso8601String().substring(0, 10), '2026-04-30');
    });
  });

  group('uploaded file URL resolution', () {
    test('normalizes every relative upload path shape', () {
      expect(
        ApiConfig.resolveUploadUrl('avatar.jpg'),
        'https://moneytries.com/v1/uploads/avatar.jpg',
      );
      expect(
        ApiConfig.resolveUploadUrl('uploads/avatar.jpg'),
        'https://moneytries.com/v1/uploads/avatar.jpg',
      );
      expect(
        ApiConfig.resolveUploadUrl('/uploads/avatar.jpg'),
        'https://moneytries.com/v1/uploads/avatar.jpg',
      );
    });

    test('preserves valid absolute URLs and empty paths', () {
      expect(
        ApiConfig.resolveUploadUrl('https://cdn.example.com/avatar.jpg'),
        'https://cdn.example.com/avatar.jpg',
      );
      expect(ApiConfig.resolveUploadUrl(''), '');
    });
  });
}
