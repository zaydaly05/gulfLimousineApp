import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../l10n/locale_service.dart';
import '../l10n/server_errors.dart';
import '../services/account_deletion_service.dart';
import '../services/payments_server_client.dart';

/// A message a customer can act on, in the app's language, for any error.
///
/// Raw errors ("Exception: ...", "[cloud_firestore/permission-denied] ...",
/// stack-trace-like text) never reach the screen: known errors get a clear
/// message and anything else a generic "Something went wrong".
String friendlyError(Object? error) {
  if (error == null) return tr('somethingWentWrong');
  if (error is String) return error.isEmpty ? tr('somethingWentWrong') : error;
  if (error is ServerException) return error.message;
  if (error is AccountDeletionException) return error.message;
  if (error is FirebaseAuthException) return _auth(error.code);
  if (error is FirebaseException) return _firebase(error.code);
  if (error is TimeoutException) return tr('errTimeout');
  if (error is PlatformException) return _platform(error);

  final text = error.toString();
  if (_looksOffline(text)) return tr('errOffline');
  // Our own messages, already translated: Exception(tr('...')).
  if (text.startsWith('Exception: ')) {
    final message = text.substring('Exception: '.length).trim();
    if (message.isNotEmpty && !_looksTechnical(message)) {
      return localizeServerMessage(message);
    }
  }
  return tr('somethingWentWrong');
}

bool _looksOffline(String text) {
  final t = text.toLowerCase();
  return t.contains('socketexception') ||
      t.contains('failed host lookup') ||
      t.contains('network is unreachable') ||
      t.contains('connection refused') ||
      t.contains('connection closed') ||
      t.contains('xmlhttprequest error') ||
      t.contains('clientexception') ||
      t.contains('network-request-failed');
}

bool _looksTechnical(String message) =>
    message.contains('[') ||
    message.contains('#0') ||
    message.contains('Instance of') ||
    message.contains('Null check') ||
    message.contains('type \'') ||
    message.contains('_TypeError');

String _auth(String code) => switch (code) {
  'invalid-email' => tr('errInvalidEmail'),
  'user-disabled' => tr('errUserDisabled'),
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' => tr('errWrongCredentials'),
  'email-already-in-use' => tr('errEmailInUse'),
  'weak-password' => tr('errWeakPassword'),
  'too-many-requests' => tr('tooManyAttempts'),
  'network-request-failed' => tr('errOffline'),
  'requires-recent-login' => tr('confirmAgainRetry'),
  'operation-not-allowed' => tr('notAvailableNow'),
  'popup-closed-by-user' ||
  'cancelled-popup-request' ||
  'web-context-canceled' => tr('errCancelled'),
  'account-exists-with-different-credential' => tr('errDifferentSignIn'),
  'missing-email' => tr('enterEmail'),
  _ => tr('somethingWentWrong'),
};

String _firebase(String code) => switch (code) {
  'permission-denied' || 'unauthenticated' => tr('errNoPermission'),
  'unavailable' || 'network-request-failed' => tr('errOffline'),
  'deadline-exceeded' => tr('errTimeout'),
  'not-found' => tr('errNotFound'),
  'already-exists' => tr('errAlreadyExists'),
  'resource-exhausted' => tr('errBusy'),
  'cancelled' || 'canceled' => tr('errCancelled'),
  'failed-precondition' || 'aborted' => tr('errChangedMeanwhile'),
  _ => tr('somethingWentWrong'),
};

String _platform(PlatformException e) {
  final code = e.code.toLowerCase();
  if (code.contains('permission') || code.contains('denied')) {
    return tr('errDevicePermission');
  }
  if (code.contains('camera')) return tr('errCamera');
  if (code.contains('network')) return tr('errOffline');
  return tr('somethingWentWrong');
}
