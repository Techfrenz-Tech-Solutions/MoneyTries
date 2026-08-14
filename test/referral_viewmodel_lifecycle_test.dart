import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytries/data/referral/referral_repository.dart';
import 'package:moneytries/models/referral/referral_model.dart';
import 'package:moneytries/viewmodels/referral/referral_viewmodel.dart';

class _DeferredReferralRepository extends ReferralRepository {
  final info = Completer<ReferralInfo>();

  @override
  Future<ReferralInfo> fetchReferralInfo() => info.future;
}

void main() {
  test('in-flight referral load completes safely after view model disposal', () async {
    final repository = _DeferredReferralRepository();
    final viewModel = ReferralViewModel(repo: repository);

    final load = viewModel.loadReferralInfo();
    viewModel.dispose();
    repository.info.complete(
      const ReferralInfo(
        myReferralCode: 'TEST',
        totalEarnings: 0,
        totalRefers: 0,
        taskProgress: 0,
        taskTarget: 5,
        taskCompleted: false,
        rewardClaimed: false,
      ),
    );

    await expectLater(load, completes);
  });
}
