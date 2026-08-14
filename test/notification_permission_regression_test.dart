import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push startup has one notification permission request path', () {
    final source = File(
      'lib/services/push_notification_service.dart',
    ).readAsStringSync();

    expect(source, contains('_messaging.getNotificationSettings()'));
    expect(source, contains("'notification_permission_requested'"));
    expect(source, contains('preferences.getBool(_permissionRequestedKey)'));
    expect(source, contains('preferences.setBool(_permissionRequestedKey, true)'));
    expect(
      source,
      contains('settings.authorizationStatus == AuthorizationStatus.notDetermined'),
    );
    expect(source, contains('_messaging.requestPermission('));
    expect(source, isNot(contains('requestNotificationsPermission()')));
    expect(source, contains('requestAlertPermission: false'));
    expect(source, contains('requestBadgePermission: false'));
    expect(source, contains('requestSoundPermission: false'));
  });
}
