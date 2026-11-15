import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../utils/live_refresh.dart';
import '../theme/app_theme.dart';

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  // Streams are created once (late = on first use), not in build():
  // a rebuild (e.g. language change) would otherwise reopen the
  // Firestore listener and flash the loading spinner.
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _inbox = FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('notifications');
  late final _notificationsStream = _inbox
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();
  // Unordered fallback, used only if the ordered query fails.
  late final _unorderedNotificationsStream = _inbox.limit(50).snapshots();

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(body: Center(child: Text(context.t('signInTickets'))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t('notificationsTitle'))),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _notificationsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return StreamBuilder<QuerySnapshot>(
                stream: _unorderedNotificationsStream,
                builder: (context, snap2) {
                  final docs = snap2.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _empty(context);
                  }
                  return _list(docs);
                },
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return _empty(context);
            }
            return _list(docs);
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 400,
          child: Center(child: Text(context.t('noNotifications'))),
        ),
      ],
    );
  }

  Widget _list(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final read = data['read'] == true;
        return ListTile(
          leading: Icon(
            Icons.notifications,
            color: read ? Colors.grey : AppTheme.accent,
          ),
          title: Text(
            data['title']?.toString() ?? '',
            style: TextStyle(
              fontWeight: read ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(data['body']?.toString() ?? ''),
          onTap: () {
            doc.reference.update({'read': true});
          },
        );
      },
    );
  }
}
