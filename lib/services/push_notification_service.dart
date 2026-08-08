// lib/services/push_notification_service.dart
//
// Central Firebase Cloud Messaging integration.
//
//   - Requests notification permission and obtains the device's FCM token.
//   - Registers/refreshes that token with the backend (PushRepository) so
//     the server knows which device(s) to push to for this account.
//   - Background / terminated state: nothing to do here — every push now
//     carries a top-level `notification` block (see utils/pushService.js
//     on the backend), so Android renders it itself, directly, without
//     ever needing this app's Dart code to run. This is deliberate: a lot
//     of real Android OEMs (Xiaomi/MIUI, Vivo/Funtouch, Oppo/ColorOS,
//     Realme UI, etc.) restrict background isolate execution for apps
//     that aren't manually whitelisted in their battery/autostart
//     settings, which is why a PURE data-only message can silently never
//     arrive on such a phone even though it works fine on an emulator or
//     a stock/Pixel device. A `notification` block sidesteps that
//     entirely, since the OS — not app code — renders it.
//   - Foreground state: the OS never auto-displays a push while the app
//     itself is open, in ANY app state, on ANY device — that's standard
//     FCM behaviour, not an OEM quirk. So this is the one state this app
//     DOES have to render itself, via flutter_local_notifications, which
//     is what FirebaseMessaging.onMessage below does.
//   - Routes a notification tap (foreground, background, or cold start)
//     to the screen named in the push payload's `route` field, using the
//     app's global navigatorKey — mirrors how SessionManager.forceLogout
//     already navigates from outside the widget tree.
//
// Call PushNotificationService.instance.initialize() once, early in
// main(), before runApp().
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/session/session_manager.dart';
import '../data/push/push_repository.dart';
import '../routes/app_routes.dart';

/// Must be a top-level (or static) function — this is FCM's contract for
/// handling messages that arrive while the app is fully terminated or in
/// the background. Kept intentionally minimal: FCM already renders the
/// system notification itself in this state from the `notification`
/// block, so there's nothing further to do here. (Doing anything more,
/// e.g. also calling flutter_local_notifications here, would show a
/// DUPLICATE notification alongside the OS's own one.)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the OS shows the notification automatically in this app state.
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final PushRepository _repository = PushRepository();

  static const String _channelId = 'greenvault_notifications';
  static const String _channelName = 'MoneyTries Notifications';
  static const String _channelDescription =
      'Deposits, withdrawals, ROI, KYC, referrals, and account alerts';

  bool _initialized = false;
  String? _currentToken;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // Not gated behind kDebugMode — visible via `adb logcat` on a release
    // APK too, which is exactly the build type this needs diagnosing on.
    // If this ever reads anything other than `authorized` on a real
    // device, that alone explains why NOTHING (including foreground
    // pushes) will show: the OS is refusing every notification the app
    // tries to post, regardless of how it's posted. Check Android
    // Settings > Apps > Moneytries > Notifications if so.
    debugPrint(
      '[PushNotificationService] permission status: ${settings.authorizationStatus}',
    );

    // iOS: show the system banner even while the app is in the foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initLocalNotifications();

    // Foreground: FCM never auto-shows a bar notification while the app is
    // open, so render one ourselves via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Tapped while app was backgrounded (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateForMessageData(message.data);
    });

    // App was launched (cold start) by tapping a notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateForMessageData(initialMessage.data);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      debugPrint('[PushNotificationService] token refreshed');
      _repository.registerToken(newToken);
    });

    await registerToken();
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('ic_stat_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final ok = await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _navigateForMessageData(
            data.map((k, v) => MapEntry(k, v?.toString())),
          );
        } catch (_) {}
      },
    );
    debugPrint(
      '[PushNotificationService] local_notifications initialized: $ok',
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(androidChannel);

    // Belt-and-suspenders alongside FirebaseMessaging.requestPermission()
    // above: on some Android 13+ devices / plugin-version combinations,
    // flutter_local_notifications doesn't reliably pick up a permission
    // grant made only through the firebase_messaging plugin, and will
    // silently refuse to post anything until asked directly through its
    // own API. Safe to call unconditionally — it's a no-op once granted.
    final localGranted = await androidPlugin?.requestNotificationsPermission();
    debugPrint(
      '[PushNotificationService] local_notifications permission granted: $localGranted',
    );

    // Diagnostic only — logs whatever importance the channel actually
    // ended up with. If this ever prints anything below "high" on a real
    // device, Android is silently capping it (this happens if the
    // channel ID was already auto-created with a lower importance by the
    // OS itself, e.g. from the very first push ever received, BEFORE
    // this code ran) — the fix in that case is to uninstall the app
    // completely (not just reinstall) so Android forgets the old channel,
    // then reinstall fresh.
    if (androidPlugin != null) {
      final channels = await androidPlugin.getNotificationChannels();
      final ours = channels?.where((c) => c.id == _channelId).toList();
      debugPrint(
        '[PushNotificationService] channel importance: ${ours?.map((c) => c.importance).toList()}',
      );
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    // Prefer the top-level notification block; fall back to data.title/
    // data.body (the backend sends both — see utils/pushService.js) in
    // case a future message is ever sent data-only.
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    debugPrint(
      '[PushNotificationService] onMessage (foreground): '
      'title="$title" body="$body" data=${message.data}',
    );

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      debugPrint('[PushNotificationService] nothing to show, skipping');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_notification',
      largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
      color: const Color(0xFF4CAF7D),
      colorized: false,
      styleInformation: BigTextStyleInformation(
        body ?? '',
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
      ),
    );

    // Prefer the backend's real notification_id so this never collides
    // with, or gets silently replaced by, another notification.
    final notificationId =
        int.tryParse(message.data['notification_id']?.toString() ?? '') ??
        (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
      debugPrint(
        '[PushNotificationService] local notification posted (id=$notificationId)',
      );
    } catch (e, st) {
      // Previously this call was unguarded — if `.show()` ever threw (a
      // missing drawable resource, a plugin/channel error, etc.) the
      // exception vanished into an unawaited Future with no visible
      // error anywhere, which looks EXACTLY like "no outside notification
      // shown" with no clue why. Now it's printed to the `flutter run`
      // console so the real cause is visible instead of silent.
      debugPrint(
        '[PushNotificationService] FAILED to show foreground notification: $e',
      );
      debugPrint('$st');
    }
  }

  void _navigateForMessageData(Map<String, dynamic> data) {
    final route = data['route']?.toString();
    final nav = SessionManager.instance.navigatorKey.currentState;
    if (nav == null) return;

    if (route != null && route.isNotEmpty) {
      nav.pushNamed(route);
    } else {
      nav.pushNamed(AppRoutes.notifications);
    }
  }

  /// Fetches the current FCM token (if permission has been granted) and
  /// registers it with the backend for the account currently signed in.
  /// Safe to call repeatedly — e.g. after every login/register/app-unlock.
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint(
          '[PushNotificationService] getToken() returned null — no FCM token available yet',
        );
        return;
      }
      _currentToken = token;
      debugPrint(
        '[PushNotificationService] registering token: ${token.substring(0, 16)}...',
      );
      await _repository.registerToken(token);
    } catch (e) {
      debugPrint('[PushNotificationService] registerToken error: $e');
    }
  }

  /// Removes this device's token from the backend — call right before a
  /// manual "Logout" clears the local session, passing the auth token that
  /// is still valid at that point.
  Future<void> unregisterToken({String? authToken}) async {
    try {
      final token = _currentToken ?? await _messaging.getToken();
      if (token == null) return;
      await _repository.unregisterToken(token, authToken: authToken);
    } catch (e) {
      debugPrint('[PushNotificationService] unregisterToken error: $e');
    }
  }
}