import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_keys.dart';
import 'biometric_service.dart';
import 'notification_service.dart';
import '../l10n/locale_service.dart';

/// Deletes the signed-in customer's account, as App Store and Google Play
/// require for apps with sign-up.
///
/// Removed: the profile (`users/{uid}`) with its favorites, notifications and
/// chat history, the saved fingerprint login on this device, and the Firebase
/// sign-in itself. Bookings, payments and traffic tickets stay: they are the
/// company's business and tax records.
class AccountDeletionService {
  AccountDeletionService._();

  static const _subcollections = [
    'favorites',
    'notifications',
    'chat_messages',
  ];

  /// Whether the account signs in with a password (and so must confirm it).
  static bool get usesPassword =>
      FirebaseAuth.instance.currentUser?.providerData.any(
        (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  /// Confirms who is deleting: Firebase only deletes an account after a
  /// recent sign-in. Pass [password] for password accounts; Google accounts
  /// sign in with Google again.
  static Future<void> reauthenticate({String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AccountDeletionException(tr('pleaseSignInAgain'));
    }

    try {
      if (usesPassword) {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email ?? '',
            password: password ?? '',
          ),
        );
      } else if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        try {
          await GoogleSignIn.instance.initialize(
            serverClientId: ApiKeys.googleServerClientId,
          );
        } catch (_) {
          // Already initialized by the login screen.
        }
        final account = await GoogleSignIn.instance.authenticate();
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            idToken: account.authentication.idToken,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(switch (e.code) {
        'wrong-password' || 'invalid-credential' => tr('passwordNotCorrect'),
        'user-mismatch' => tr('sameAccountDeleting'),
        'too-many-requests' => tr('tooManyAttempts'),
        _ => tr('couldNotConfirmYou'),
      });
    } on GoogleSignInException {
      throw AccountDeletionException(tr('googleCancelled'));
    }
  }

  /// Deletes the data and the account. Call [reauthenticate] first.
  static Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AccountDeletionException(tr('pleaseSignInAgain'));
    }
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      await NotificationService.instance.unregisterDevice();
      await NotificationService.instance.stop();
      for (final name in _subcollections) {
        await _deleteAll(userDoc.collection(name));
      }
      await userDoc.delete();
      await BiometricService.setEnabledForUid(user.uid, false);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        e.code == 'requires-recent-login'
            ? tr('confirmAgainRetry')
            : tr('couldNotDeleteAccount'),
      );
    } on FirebaseException {
      throw AccountDeletionException(tr('couldNotDeleteData'));
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google, or the plugin is not initialized.
    }
  }

  static Future<void> _deleteAll(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection.limit(200).get();
      if (page.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);
  final String message;

  @override
  String toString() => message;
}
