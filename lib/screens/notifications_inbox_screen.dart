import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';

class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(context.t('signInTickets'))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t('notificationsTitle'))),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('notifications')
                    .limit(50)
                    .snapshots(),
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
            color: read ? Colors.grey : const Color(0xFFFF8C00),
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
