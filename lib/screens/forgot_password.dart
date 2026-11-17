import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';
import '../widgets/auth_scaffold.dart';

/// Sends a password reset link, then says where to look for it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  /// Prefilled from the login screen when the customer already typed it.
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _isLoading = false;
  String? _sentTo;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _email.text.trim();
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _sentTo = email);
    } catch (e) {
      if (mounted) showError(context, e, title: tr('failedSendReset'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return AuthScaffold(
      title: tr('forgotPasswordTitle'),
      subtitle: sentTo == null ? tr('forgotPasswordHint') : tr('checkInbox'),
      child: sentTo == null ? _form() : _sent(sentTo),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) {
              if (!_isLoading) unawaited(_send());
            },
            decoration: authInputDecoration(tr('email'), Icons.email_outlined),
            validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                ? null
                : tr('errInvalidEmail'),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: tr('sendResetLink'),
            loading: _isLoading,
            onPressed: _send,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.maybePop(context),
            child: Text(
              tr('backToLogin'),
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sent(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 48,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 12),
              Text(
                tr('resetSentTo', args: {'email': ltr(email)}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                tr('checkSpam'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: tr('backToLogin'),
          onPressed: () => Navigator.maybePop(context),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _send,
          child: Text(
            tr('resendLink'),
            style: const TextStyle(color: Colors.orange),
          ),
        ),
      ],
    );
  }
}
