import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../screens/admin_dashboard_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/complete_profile_screen.dart';
import '../screens/login_screen.dart';
import 'notification_service.dart';
import '../l10n/locale_service.dart';

class AuthNavigation {
  static Future<Widget> homeForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(tr('notSignedIn'));
    }
    // Not awaited: notification setup (including the permission prompt)
    // must not hold up showing the home screen. initialize() handles its
    // own errors.
    unawaited(NotificationService.instance.initialize());

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final data = doc.data() ?? {};
      final role = data['role']?.toString() ?? 'user';

      if (role == 'admin') return const AdminDashboard();

      // For normal users, check if profile is complete
      final profileCompleted = data['profile_completed'] == true;
      if (!profileCompleted) {
        return const CompleteProfileScreen();
      }

      return const DashboardScreen();
    } catch (e) {
      debugPrint('Error resolving home: $e');
      // If we can't verify profile completion, don't allow access to dashboard.
      // Redirect to CompleteProfileScreen which will either show the form
      // or error out if it can't load data.
      return const CompleteProfileScreen();
    }
  }

  static Future<void> goToRoleHome(BuildContext context) async {
    final home = await homeForCurrentUser();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => home),
      (route) => false,
    );
  }

  /// Single sign-out path for every screen: stops per-user listeners,
  /// ends the Firebase (and Google) session and returns to the login screen.
  ///
  /// [autoPromptBiometrics] false keeps the login screen from opening the
  /// fingerprint prompt straight away (used by "Use password instead").
  static Future<void> signOut(
    BuildContext context, {
    bool autoPromptBiometrics = true,
  }) async {
    final navigator = Navigator.of(context);
    // Before Firebase sign-out: removing the token needs the user's auth.
    await NotificationService.instance.unregisterDevice();
    await NotificationService.instance.stop();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google, or plugin not initialized.
    }
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(autoPromptBiometrics: autoPromptBiometrics),
      ),
      (route) => false,
    );
  }
}
