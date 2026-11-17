import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';
import '../utils/live_refresh.dart';
import '../widgets/empty_state.dart';
import '../utils/safe_insets.dart';

class ManageReviewsScreen extends StatefulWidget {
  const ManageReviewsScreen({super.key});

  @override
  State<ManageReviewsScreen> createState() => _ManageReviewsScreenState();
}

class _ManageReviewsScreenState extends State<ManageReviewsScreen> {
  // Streams are created once (late = on first use), not in build():
  // a rebuild (e.g. language change) would otherwise reopen the
  // Firestore listener and flash the loading spinner.
  final _reviewsStream = FirebaseFirestore.instance
      .collection('reviews')
      .orderBy('createdAt', descending: true)
      .snapshots();
  // Unordered fallback, used only if the ordered query fails.
  late final _unorderedReviewsStream = FirebaseFirestore.instance
      .collection('reviews')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.t('reviewsTitle')),
        backgroundColor: Colors.black,
        actions: const [
          LanguageToggleButton(dark: true, showText: false),
          SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _reviewsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return StreamBuilder<QuerySnapshot>(
                stream: _unorderedReviewsStream,
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
    return EmptyState(
      icon: Icons.rate_review_outlined,
      message: context.t('noReviews'),
      dark: true,
    );
  }

  Widget _list(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16).withSafeBottom(context),
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
              tooltip: context.t('delete'),
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
