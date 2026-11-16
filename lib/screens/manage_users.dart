import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_user_screen.dart';
import 'edit_user_screen.dart';

import 'package:intl/intl.dart';

import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';
import '../utils/live_refresh.dart';
import '../services/user_profile_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  // Streams are created once (late = on first use), not in build():
  // a rebuild (e.g. language change) would otherwise reopen the
  // Firestore listener and flash the loading spinner.
  final _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();

  static String _resolveName(Map<String, dynamic> user) {
    final name = user['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user['email']?.toString();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'No Name';
  }

  static String _resolvePhone(Map<String, dynamic> user) {
    return user['phone_number']?.toString() ?? user['phone']?.toString() ?? '';
  }

  static String _resolveAuthProvider(Map<String, dynamic> user) {
    if (user['auth_provider'] == 'google') return 'Google';
    if (user['createdAt'] != null && user['created_at'] == null) {
      return 'Google';
    }
    return 'Email';
  }

  static Timestamp? _resolveCreatedAt(Map<String, dynamic> user) {
    final createdAt = user['created_at'] ?? user['createdAt'];
    return createdAt is Timestamp ? createdAt : null;
  }

  static int _compareUsers(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final aData = a.data() as Map<String, dynamic>;
    final bData = b.data() as Map<String, dynamic>;
    final aTime = _resolveCreatedAt(aData);
    final bTime = _resolveCreatedAt(bData);

    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  }

  Future<void> deleteUser(BuildContext context, String id) async {
    unawaited(
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            context.t('delete'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            context.t('cannotBeUndone'),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.t('cancel')),
            ),
            TextButton(
              onPressed: () async {
                await UserProfileService.delete(id);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(
                context.t('delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.t('manageUsersTitle')),
        backgroundColor: Colors.black,
        actions: const [LanguageToggleButton(dark: true), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddUserScreen()),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _usersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Text(
                        context.t('users'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }

            final users = List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
              ..sort(_compareUsers);

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 100,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final doc = users[index];
                final user = doc.data() as Map<String, dynamic>;

                final timestamp = _resolveCreatedAt(user);
                final formattedDate = timestamp != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
                    : "N/A";
                final authProvider = _resolveAuthProvider(user);
                final isGoogleUser = authProvider == 'Google';

                return Card(
                  color: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.15),
                      child: Icon(
                        isGoogleUser ? Icons.g_mobiledata : Icons.person,
                        color: Colors.orange,
                        size: isGoogleUser ? 30 : 24,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _resolveName(user),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isGoogleUser
                                ? Colors.blue.withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            authProvider,
                            style: TextStyle(
                              color: isGoogleUser
                                  ? Colors.lightBlueAccent
                                  : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "${context.t('email')}: ${user['email'] ?? ''}\n"
                        "${context.t('phone')}: ${_resolvePhone(user)}\n"
                        "Role: ${user['role'] ?? ''}\n"
                        "Created: $formattedDate",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          height: 1.4,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditUserScreen(
                                  userId: doc.id,
                                  userData: user,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteUser(context, doc.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
