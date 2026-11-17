import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/app_feedback.dart';
import '../widgets/auth_scaffold.dart';

/// Create an account with name, email and password.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _isLoading = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      await UserProfileService.createEmailUser(
        uid: credential.user!.uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSuccess(tr('accountCreated'));
    } catch (e) {
      if (mounted) showError(context, e, title: tr('signupFailed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibility = IconButton(
      tooltip: tr(_hidePassword ? 'showPassword' : 'hidePassword'),
      icon: Icon(
        _hidePassword ? Icons.visibility_outlined : Icons.visibility_off,
        color: Colors.grey.shade600,
      ),
      onPressed: () => setState(() => _hidePassword = !_hidePassword),
    );

    return AuthScaffold(
      title: tr('createAccount'),
      subtitle: tr('signUpSubtitle'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: authInputDecoration(
                  tr('fullName'),
                  Icons.person_outline,
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? tr('enterYourName') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: authInputDecoration(
                  tr('email'),
                  Icons.email_outlined,
                ),
                validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                    ? null
                    : tr('errInvalidEmail'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: authInputDecoration(
                  tr('password'),
                  Icons.lock_outline,
                  suffixIcon: visibility,
                  helperText: tr('passwordHint'),
                ),
                validator: (v) =>
                    (v ?? '').length < 6 ? tr('errWeakPassword') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isLoading) unawaited(_signUp());
                },
                decoration: authInputDecoration(
                  tr('confirmPassword'),
                  Icons.lock_outline,
                ),
                validator: (v) =>
                    v != _password.text ? tr('passwordsDontMatch') : null,
              ),
              const SizedBox(height: 28),
              AuthPrimaryButton(
                label: tr('createAccount'),
                loading: _isLoading,
                onPressed: _signUp,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(tr('haveAccount'))),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.maybePop(context),
                    child: Text(
                      tr('login'),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
