import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';

class ManageReviewsScreen extends StatelessWidget {
  const ManageReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.t('reviewsTitle')),
        backgroundColor: Colors.black,
        actions: const [LanguageToggleButton(dark: true), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .snapshots(),
                builder: (context, snap2) {
                  final docs = snap2.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _empty(context);
                  }
                  return _list(context, docs);
                },
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return _empty(context);
            }
            return _list(context, docs);
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
          child: Center(
            child: Text(
              context.t('reviews'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final rating = (data['rating'] as num?)?.toInt() ?? 0;
        return Card(
          color: Colors.grey.shade900,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              data['carName']?.toString() ?? context.t('cars'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${'★' * rating}${'☆' * (5 - rating)}\n'
              '${data['userName'] ?? context.t('guest')}: ${data['comment'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await doc.reference.delete();
              },
            ),
          ),
        );
      },
    );
  }
}
