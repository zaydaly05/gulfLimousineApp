import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Writes to `users/{uid}` profile documents.
///
/// Each sign-up path stores a slightly different set of fields (for example
/// email sign-up has no `phone_number`, Google sign-in also writes
/// `createdAt`); those shapes are kept exactly as they were.
class UserProfileService {
  UserProfileService._();

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  /// Profile for a new email/password sign-up.
  static Future<void> createEmailUser({
    required String uid,
    required String name,
    required String email,
  }) {
    return _users.doc(uid).set({
      'name': name,
      'email': email,
      'phone': '',
      'role': 'user',
      'auth_provider': 'email',
      'profile_completed': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Creates the profile on first Google sign-in, or fills in fields an
  /// older profile is missing (name, auth_provider, created_at).
  static Future<void> ensureGoogleUser(User user) async {
    final userRef = _users.doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      await userRef.set({
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email,
        'phone': '',
        'phone_number': '',
        'role': 'user',
        'auth_provider': 'google',
        'profile_completed': false,
        'created_at': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = userDoc.data() ?? {};
    final updates = <String, dynamic>{};

    if ((data['name'] == null || data['name'].toString().isEmpty) &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      updates['name'] = user.displayName;
    }
    if (data['auth_provider'] == null) {
      updates['auth_provider'] = 'google';
    }
    if (data['created_at'] == null && data['createdAt'] != null) {
      updates['created_at'] = data['createdAt'];
    }

    if (updates.isNotEmpty) {
      await userRef.update(updates);
    }
  }

  /// Profile for an account an admin created. Must be called as the admin:
  /// the rules only let admins assign a role.
  static Future<void> adminCreateUser({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String role,
  }) {
    return _users.doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'phone_number': phone,
      'role': role,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Saves the verification details from Complete Profile. Merges, so it
  /// also works if the profile document was never created.
  static Future<void> completeProfile(
    String uid, {
    required String nationalId,
    required String phone,
    required Map<String, dynamic> nationalIdUpload,
    required Map<String, dynamic> licenseIdUpload,
  }) {
    return _users.doc(uid).set({
      'national_id': nationalId,
      'phone': phone,
      'phone_number': phone,
      'national_id_url': nationalIdUpload['secure_url'],
      'national_id_public_id': nationalIdUpload['public_id'],
      'license_id_url': licenseIdUpload['secure_url'],
      'license_id_public_id': licenseIdUpload['public_id'],
      'profile_completed': true,
    }, SetOptions(merge: true));
  }

  /// Updates fields of a profile (the user's own, or any profile for admins).
  static Future<void> update(String uid, Map<String, dynamic> fields) =>
      _users.doc(uid).update(fields);

  /// Deletes a profile document (admins only).
  static Future<void> delete(String uid) => _users.doc(uid).delete();
}
