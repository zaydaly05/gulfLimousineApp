import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'package:gulflimousine_travel/screens/adminDashboard_screen.dart';
import 'package:gulflimousine_travel/screens/intro_screen.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';
import 'services/biometric_service.dart';
import 'services/auth_navigation.dart';
import 'widgets/biometric_lock_screen.dart';
import 'l10n/locale_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocaleService.instance.load();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('Firebase [DEFAULT] already initialized natively.');
    } else {
      debugPrint('Firebase initialization error: ${e.code} - ${e.message}');
    }
  } catch (e) {
    debugPrint('Unexpected initialization error: $e');
  }

  runApp(const GulfLimousineApp());
}

class GulfLimousineApp extends StatelessWidget {
  const GulfLimousineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: LocaleService.instance.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Restores session if already signed in; otherwise shows intro.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _resolveHome();
  }

  Future<Widget> _resolveHome() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const IntroScreen();

    try {
      final home = await AuthNavigation.homeForCurrentUser();
      
      if (await BiometricService.isEnabledForCurrentUser()) {
        return BiometricLockScreen(child: home);
      }
      return home;
    } catch (e) {
      debugPrint('Home resolution error: $e');
      return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const IntroScreen(); // Fallback
        }
        return snapshot.data ?? const IntroScreen();
      },
    );
  }
}
