import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/adminDashboard_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/complete_profile_screen.dart';
import 'notification_service.dart';

class AuthNavigation {
  static Future<Widget> homeForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }
    try {
      await NotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

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
}
