
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
final Set<String> _seenIds = {};

Future<void> initialize() async {
FirebaseMessaging.onBackgroundMessage(
firebaseMessagingBackgroundHandler,
);

// Local notifications initialization
const android = AndroidInitializationSettings(
'@mipmap/ic_launcher',
);

const ios = DarwinInitializationSettings();

await _local.initialize(
settings: const InitializationSettings(
android: android,
iOS: ios,
),
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
AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);

// Request notification permission
final settings = await _messaging
    .requestPermission(
alert: true,
badge: true,
sound: true,
)
    .timeout(
const Duration(seconds: 5),
onTimeout: () {
debugPrint(
'Notification permission request timed out',
);

return const NotificationSettings(
authorizationStatus:
AuthorizationStatus.notDetermined,
alert: AppleNotificationSetting.disabled,
announcement: AppleNotificationSetting.disabled,
badge: AppleNotificationSetting.disabled,
carPlay: AppleNotificationSetting.disabled,
criticalAlert: AppleNotificationSetting.disabled,
sound: AppleNotificationSetting.disabled,
lockScreen: AppleNotificationSetting.disabled,
notificationCenter:
AppleNotificationSetting.disabled,
showPreviews:
AppleShowPreviewSetting.never,
timeSensitive:
AppleNotificationSetting.disabled,
providesAppNotificationSettings:
AppleNotificationSetting.notSupported,
);
},
);

if (settings.authorizationStatus ==
AuthorizationStatus.denied) {
debugPrint('Notification permission denied');
}

// Save FCM token without blocking initialization
_saveToken()
    .timeout(
const Duration(seconds: 5),
)
    .catchError((e) {
debugPrint(
'Initial FCM token save timed out or failed: $e',
);
});

// Listen for token refresh
_messaging.onTokenRefresh.listen(
(token) => _saveToken(token: token),
);

// Foreground messages
FirebaseMessaging.onMessage.listen((message) {
final title =
message.notification?.title ??
message.data['title'];

final body =
message.notification?.body ??
message.data['body'];

if (title != null) {
showLocal(
title: title,
body: body ?? '',
);
}
});

// Firestore notification inbox
listenToInbox();
}

Future<void> _saveToken({String? token}) async {
final user = _auth.currentUser;

if (user == null) return;

try {
final fcmToken =
token ??
await _messaging
    .getToken()
    .timeout(const Duration(seconds: 5));

if (fcmToken == null) return;

await _firestore
    .collection('users')
    .doc(user.uid)
    .set(
{
'fcmToken': fcmToken,
'fcmUpdatedAt': FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
)
    .timeout(const Duration(seconds: 5));
} catch (e) {
debugPrint('FCM token save failed: $e');
}
}

void listenToInbox() {
_inboxSub?.cancel();

final user = _auth.currentUser;

if (user == null) return;

_inboxSub = _firestore
    .collection('users')
    .doc(user.uid)
    .collection('notifications')
    .orderBy(
'createdAt',
descending: true,
)
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
final age =
DateTime.now().difference(
created.toDate(),
);

if (age.inMinutes > 2) continue;
}

showLocal(
title:
(data['title'] ?? 'Gulf Limousine')
    .toString(),
body:
(data['body'] ?? '').toString(),
);
}
});
}

Future<void> showLocal({
required String title,
required String body,
}) async {
await _local.show(
id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
title: title,
body: body,
notificationDetails:
const NotificationDetails(
android: AndroidNotificationDetails(
'gulf_limousine',
'Gulf Limousine',
channelDescription:
'Booking and trip updates',
importance: Importance.high,
priority: Priority.high,
),
iOS: DarwinNotificationDetails(),
),
);
}

Future<void> dispose() async {
await _inboxSub?.cancel();
}
}
