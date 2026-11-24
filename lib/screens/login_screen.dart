import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_keys.dart';
import 'dashboard_screen.dart';
import 'forgot_password.dart';
import 'signup_screen.dart';
import '../services/biometric_service.dart';
import '../services/auth_navigation.dart';
import '../widgets/language_picker.dart';
import '../l10n/locale_service.dart';
import '../services/user_profile_service.dart';
import '../utils/safe_insets.dart';
import '../widgets/app_feedback.dart';

class LoginScreen extends StatefulWidget {
  /// False when the user just chose "Use password instead", so the screen
  /// doesn't immediately reopen the fingerprint prompt they backed out of.
  final bool autoPromptBiometrics;

  const LoginScreen({super.key, this.autoPromptBiometrics = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _biometricHardwareAvailable = false;
  String _biometricLabel = tr('fingerprint');

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeGoogleSignIn());
    unawaited(_prepareBiometricLogin());
  }

  Future<void> _prepareBiometricLogin() async {
    final hardware = await BiometricService.isHardwareAvailable();
    final canDirect = await BiometricService.canLoginWithBiometrics();
    final label = await BiometricService.methodLabel();
    if (!mounted) return;
    setState(() {
      _biometricHardwareAvailable = hardware;
      _biometricLabel = label;
    });
    if (canDirect && widget.autoPromptBiometrics) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) await _loginWithBiometrics();
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: ApiKeys.googleServerClientId,
      );

      debugPrint('Google Sign-In initialized successfully');
    } catch (e) {
      debugPrint('Google Sign-In initialization failed: $e');
    }
  }

  /// Signs in with [password] exactly as typed, which is how sign-up saves
  /// it, then (if that is refused) trimmed, as earlier versions of this
  /// screen sent it. Trimming alone locked out anyone whose password starts
  /// or ends with a space. Returns the credential and the password that
  /// worked, for biometric login to remember.
  static Future<(UserCredential, String)> _signInWithPassword(
    String email,
    String password,
  ) async {
    Future<UserCredential> attempt(String p) => FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: p)
        .timeout(const Duration(seconds: 15));

    final trimmed = password.trim();
    try {
      return (await attempt(password), password);
    } on FirebaseAuthException catch (e) {
      const wrongPassword = {
        'wrong-password',
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
      };
      if (trimmed == password || !wrongPassword.contains(e.code)) rethrow;
    }
    return (await attempt(trimmed), trimmed);
  }

  /// 🔐 EMAIL LOGIN
  Future<void> _login(BuildContext context) async {
    final email = _emailController.text.trim();
    final typedPassword = _passwordController.text;
    if (email.isEmpty || typedPassword.trim().isEmpty) {
      _showError(tr('enterEmailPassword'));
      return;
    }

    try {
      setState(() => _isLoading = true);

      final (userCredential, password) = await _signInWithPassword(
        email,
        typedPassword,
      );

      // Credentials are only stored once biometric login is on: refreshed
      // here if it already is (e.g. after a password change), otherwise
      // saved by the opt-in prompt in _handleUserNavigation.
      if (await BiometricService.isEnabledForUid(userCredential.user!.uid)) {
        await BiometricService.rememberEmailLogin(email, password);
      }
      await _handleUserNavigation(
        userCredential.user!,
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 🔥 GOOGLE LOGIN
  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      await _googleSignIn.signOut();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));

      await UserProfileService.ensureGoogleUser(userCredential.user!);
      await _handleUserNavigation(userCredential.user!);
    } catch (e) {
      if (kDebugMode) debugPrint('Google sign-in error: $e');

      if (mounted) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('canceled') || errorStr.contains('cancelled')) {
          // Silent if user just cancelled
          return;
        }
        _showError(e, title: tr('googleSignInFailed'));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithBiometrics() async {
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);
      final hasSaved = await BiometricService.hasStoredPassword();
      final emailInput = _emailController.text.trim();
      final passwordInput = _passwordController.text;

      if (hasSaved) {
        final user = await BiometricService.loginWithBiometrics();
        await _handleUserNavigation(user, offerBiometrics: false);
      } else if (emailInput.isNotEmpty && passwordInput.trim().isNotEmpty) {
        final ok = await BiometricService.authenticate(
          reason: tr('authToSaveLogin', args: {'method': _biometricLabel}),
        );
        if (!ok) {
          if (mounted) {
            _showError(
              tr('authFailedCancelled', args: {'method': _biometricLabel}),
            );
          }
          return;
        }
        final (userCredential, password) = await _signInWithPassword(
          emailInput,
          passwordInput,
        );

        await BiometricService.rememberEmailLogin(emailInput, password);
        await BiometricService.setEnabledForUid(userCredential.user!.uid, true);
        await _handleUserNavigation(
          userCredential.user!,
          offerBiometrics: false,
        );
      } else {
        final ok = await BiometricService.authenticate(
          reason: tr('authForLogin', args: {'method': _biometricLabel}),
        );
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSuccess(
            context.t('setupBiometrics', args: {'method': _biometricLabel}),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🚀 Navigate Based on Role
  Future<void> _handleUserNavigation(
    User user, {
    bool offerBiometrics = true,
    String? email,
    String? password,
  }) async {
    try {
      if (!mounted) return;
      if (offerBiometrics) {
        await BiometricService.maybeOfferEnable(
          context,
          email: email,
          password: password,
        );
        if (!mounted) return;
      }
      await AuthNavigation.goToRoleHome(context);
    } catch (e) {
      debugPrint('Navigation error: $e');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    }
  }

  /// [error] is a message or any error (shown as a clear message).
  void _showError(Object error, {String? title}) {
    if (!mounted) return;
    showError(context, error, title: title);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orangeColor = Colors.orange;

    return Scaffold(
      // Opaque: the old translucent white24 showed the OS window colour
      // through, so the page was white or dark grey depending on dark mode.
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24).withSafeBottom(context),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: LanguageToggleButton(),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    context.t('appNameFull'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (_biometricHardwareAvailable) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onPressed: _isLoading ? null : _loginWithBiometrics,
                      icon: const Icon(
                        Icons.fingerprint,
                        color: Colors.orange,
                        size: 28,
                      ),
                      label: Text(
                        context.t(
                          'loginWithBiometrics',
                          args: {'method': _biometricLabel},
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.t('orUseEmail'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.email],
                    decoration: _inputDecoration(
                      context.t('email'),
                      Icons.email,
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!_isLoading) unawaited(_login(context));
                    },
                    decoration: _inputDecoration(
                      context.t('password'),
                      Icons.lock,
                      suffixIcon: _biometricHardwareAvailable
                          ? IconButton(
                              icon: const Icon(
                                Icons.fingerprint,
                                color: Colors.orange,
                                size: 26,
                              ),
                              tooltip: context.t(
                                'loginWithBiometrics',
                                args: {'method': _biometricLabel},
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : _loginWithBiometrics,
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      // Small side padding so the link lines up with the
                      // fields' edge instead of sitting 12px inside it.
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(
                              initialEmail: _emailController.text.trim(),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        context.t('forgotPassword'),
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orangeColor,
                      minimumSize: const Size.fromHeight(54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isLoading ? null : () => _login(context),
                    child: _isLoading
                        // Sized to the label so the button doesn't jump.
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            context.t('login'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.login, color: Colors.orange),
                    label: Text(
                      context.t('continueGoogle'),
                      style: const TextStyle(color: Colors.orange),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      minimumSize: const Size.fromHeight(54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isLoading ? null : _loginWithGoogle,
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.t('noAccount')),
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: Text(
                            context.t('signUp'),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.orange),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.orange),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
