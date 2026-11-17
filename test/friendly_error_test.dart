import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/l10n/locale_service.dart';
import 'package:gulflimousine_travel/services/payments_server_client.dart';
import 'package:gulflimousine_travel/utils/friendly_error.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  tearDown(() => LocaleService.instance.setLocale(const Locale('en')));

  test('sign-in errors read as plain sentences', () {
    expect(
      friendlyError(FirebaseAuthException(code: 'invalid-credential')),
      'The email or password is not correct.',
    );
    expect(
      friendlyError(FirebaseAuthException(code: 'email-already-in-use')),
      contains('already exists'),
    );
  });

  test('database, network and timeout errors are explained', () {
    expect(
      friendlyError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('permission'),
    );
    expect(friendlyError(TimeoutException('x')), contains('too long'));
    expect(
      friendlyError(Exception('SocketException: Failed host lookup')),
      contains('offline'),
    );
  });

  test('raw technical text never reaches the screen', () {
    expect(
      friendlyError(Exception("type 'Null' is not a subtype of type 'String'")),
      'Something went wrong. Try again.',
    );
    expect(
      friendlyError(StateError('Bad state')),
      'Something went wrong. Try again.',
    );
    expect(friendlyError(Exception('Booking not found')), 'Booking not found');
  });

  test('server refusals are already translated; Arabic works', () async {
    expect(friendlyError(const ServerException('Car is gone')), 'Car is gone');
    await LocaleService.instance.setLocale(const Locale('ar'));
    expect(
      friendlyError(FirebaseAuthException(code: 'wrong-password')),
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
    );
  });
}
