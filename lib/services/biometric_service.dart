import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();

  static const _enabledPrefix = 'biometric_enabled_';
  static const _lastUidKey = 'biometric_last_uid';
  static const _emailKey = 'biometric_email';
  static const _passwordKey = 'biometric_password';
  static final _auth = LocalAuthentication();
  static const _secure = FlutterSecureStorage();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String _keyFor(String uid) => '$_enabledPrefix$uid';

  static Future<bool> isHardwareAvailable() async {
    try {
      return await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  static Future<String> methodLabel() async {
    final types = await availableTypes();
    final hasFace = types.contains(BiometricType.face);
    final hasFingerprint = types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak);
    if (hasFace && hasFingerprint) return 'Face ID / fingerprint';
    if (hasFace) return 'Face ID';
    if (hasFingerprint) return 'Fingerprint';
    return 'Biometrics';
  }

  static Future<bool> isEnabledForCurrentUser() async {
    final uid = _uid;
    if (uid == null) return false;
    return isEnabledForUid(uid);
  }

  static Future<bool> isEnabledForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFor(uid)) ?? false;
  }

  static Future<bool> hasStoredPassword() async {
    final email = await _secure.read(key: _emailKey);
    final password = await _secure.read(key: _passwordKey);
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  static Future<bool> canLoginWithBiometrics() async {
    if (!await isHardwareAvailable()) return false;
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && await isEnabledForUid(current.uid)) {
      return true;
    }
    final uid = await lastEnabledUid();
    if (uid == null || !await isEnabledForUid(uid)) return false;
    return hasStoredPassword();
  }

  static Future<String?> lastEnabledUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUidKey);
  }

  static Future<void> rememberEmailLogin(String email, String password) async {
    await _secure.write(key: _emailKey, value: email.trim());
    await _secure.write(key: _passwordKey, value: password);
  }

  static Future<void> setEnabled(bool enabled) async {
    final uid = _uid;
    if (uid == null) return;
    await setEnabledForUid(uid, enabled);
  }

  static Future<void> setEnabledForUid(String uid, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(uid), enabled);
    if (enabled) {
      await prefs.setString(_lastUidKey, uid);
    } else {
      final last = prefs.getString(_lastUidKey);
      if (last == uid) {
        await prefs.remove(_lastUidKey);
      }
      await _secure.delete(key: _emailKey);
      await _secure.delete(key: _passwordKey);
    }
  }

  static Future<bool> authenticate({
    String reason = 'Unlock Gulf Limousine',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric error: $e');
      return false;
    }
  }

  static Future<bool> enableWithPrompt() async {
    final ok = await authenticate(
      reason: 'Confirm fingerprint or Face ID to enable login',
    );
    if (ok) await setEnabled(true);
    return ok;
  }

  static Future<User> loginWithBiometrics() async {
    final label = await methodLabel();
    final ok = await authenticate(reason: 'Log in with $label');
    if (!ok) {
      throw Exception('$label cancelled or failed');
    }

    final email = await _secure.read(key: _emailKey);
    final password = await _secure.read(key: _passwordKey);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      throw Exception(
        'Sign in with email and password once to set up $label login.',
      );
    }

    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    await setEnabledForUid(uid, true);
    return credential.user!;
  }

  static Future<void> maybeOfferEnable(BuildContext context) async {
    if (!await isHardwareAvailable()) return;
    if (await isEnabledForCurrentUser()) return;
    if (!context.mounted) return;

    final label = await methodLabel();
    if (!context.mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable biometric login?'),
        content: Text(
          'Use $label to log in next time. You can also turn this on in Profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable == true) {
      final ok = await enableWithPrompt();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '$label login is on' : 'Could not enable biometric login',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// Clears all stored biometric credentials and metadata.
  /// Should be called on logout or when security is compromised.
  static Future<void> clearAllStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_enabledPrefix)) {
        await prefs.remove(key);
      }
    }
    await prefs.remove(_lastUidKey);
    await _secure.deleteAll();
  }
}
