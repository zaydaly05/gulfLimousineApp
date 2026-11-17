import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/locale_service.dart';
import '../l10n/notification_text.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler — OS displays the FCM notification.
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _inboxSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  final Set<String> _seenIds = {};

  /// Uid the inbox listener is currently attached to.
  String? _inboxUid;
  Future<void>? _setup;

  /// Safe to call many times (login, dashboards, app start): platform setup and
  /// global listeners run once; the inbox listener follows the signed-in user.
  Future<void> initialize() async {
    final setup = _setup ??= _setupOnce();
    try {
      await setup;
    } catch (e) {
      // Allow a later call to retry instead of caching the failure.
      if (identical(_setup, setup)) _setup = null;
      debugPrint('Notification setup failed: $e');
    }
    if (_auth.currentUser?.uid != _inboxUid) {
      unawaited(
        _saveToken().timeout(const Duration(seconds: 5)).catchError((e) {
          debugPrint('FCM token save timed out or failed: $e');
        }),
      );
      listenToInbox();
    }
  }

  /// Detaches this device from the signed-in user so their push messages stop
  /// arriving here: removes the token from their profile and invalidates it.
  /// Call while still signed in (the profile write needs auth). Best effort.
  Future<void> unregisterDevice() async {
    final user = _auth.currentUser;
    try {
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()})
            .timeout(const Duration(seconds: 5));
      }
      await _messaging.deleteToken().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('FCM unregister failed: $e');
    }
  }

  /// Stops per-user listeners. Call on logout.
  Future<void> stop() async {
    await _inboxSub?.cancel();
    _inboxSub = null;
    _inboxUid = null;
    _seenIds.clear();
  }

  Future<void> _setupOnce() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Local notifications initialization
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings();

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    // Android notification channel
    const channel = AndroidNotificationChannel(
      'gulf_limousine',
      'Gulf Limousine',
      description: 'Booking and trip updates',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Request notification permission
    final settings = await _messaging
        .requestPermission(alert: true, badge: true, sound: true)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Notification permission request timed out');

            return const NotificationSettings(
              authorizationStatus: AuthorizationStatus.notDetermined,
              alert: AppleNotificationSetting.disabled,
              announcement: AppleNotificationSetting.disabled,
              badge: AppleNotificationSetting.disabled,
              carPlay: AppleNotificationSetting.disabled,
              criticalAlert: AppleNotificationSetting.disabled,
              sound: AppleNotificationSetting.disabled,
              lockScreen: AppleNotificationSetting.disabled,
              notificationCenter: AppleNotificationSetting.disabled,
              showPreviews: AppleShowPreviewSetting.never,
              timeSensitive: AppleNotificationSetting.disabled,
              providesAppNotificationSettings:
                  AppleNotificationSetting.notSupported,
            );
          },
        );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission denied');
    }

    // Listen for token refresh
    _tokenSub = _messaging.onTokenRefresh.listen(
      (token) => _saveToken(token: token),
    );

    // Foreground messages
    _messageSub = FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? message.data['title'];

      final body = message.notification?.body ?? message.data['body'];

      if (title != null) {
        unawaited(showLocal(title: title, body: body ?? ''));
      }
    });
  }

  Future<void> _saveToken({String? token}) async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final fcmToken =
          token ??
          await _messaging.getToken().timeout(const Duration(seconds: 5));

      if (fcmToken == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
            'fcmToken': fcmToken,
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  void listenToInbox() {
    unawaited(_inboxSub?.cancel());
    _inboxSub = null;

    final user = _auth.currentUser;
    _inboxUid = user?.uid;

    if (user == null) return;

    _inboxSub = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) {
              continue;
            }

            final id = change.doc.id;

            if (_seenIds.contains(id)) continue;

            _seenIds.add(id);

            final data = change.doc.data();

            if (data == null) continue;

            final created = data['createdAt'];

            if (created is Timestamp) {
              final age = DateTime.now().difference(created.toDate());

              if (age.inMinutes > 2) continue;
            }

            final (title, body) = notificationText(data);
            unawaited(
              showLocal(
                title: title.isEmpty ? tr('appName') : title,
                body: body,
              ),
            );
          }
        });
  }

  /// Shows a local notification. Never throws (failures are logged), so
  /// callers may fire and forget it.
  Future<void> showLocal({required String title, required String body}) async {
    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'gulf_limousine',
            'Gulf Limousine',
            channelDescription: 'Booking and trip updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Local notification failed: $e\n$stack');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _tokenSub?.cancel();
    await _messageSub?.cancel();
  }
}
