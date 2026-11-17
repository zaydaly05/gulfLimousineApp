import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../utils/image_decode.dart';
import '../utils/safe_insets.dart';
import 'language_picker.dart';

/// The branded page for account screens (sign up, forgot password): the
/// Gulf logo on black at the top and a white rounded panel holding the
/// form, with a back button and the language switch.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      // White below the panel; the black header and the black behind the
      // panel's rounded corners are painted by the header and wrapper.
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Brand header.
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(8, top + 4, 8, 28),
              // Solid black so the logo's own black background blends in.
              color: Colors.black,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: tr('back'),
                        icon: const BackButtonIcon(),
                        color: Colors.white,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Spacer(),
                      const LanguageToggleButton(dark: true),
                      const SizedBox(width: 8),
                    ],
                  ),
                  Image.asset(
                    'assets/icon/app_icon.png',
                    height: 120,
                    cacheHeight: decodeWidth(context, 120),
                    semanticLabel: tr('appNameFull'),
                  ),
                ],
              ),
            ),
            // Form panel, on black so its rounded corners show.
            ColoredBox(
              color: Colors.black,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  24,
                ).withSafeBottom(context),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The login screen's field style: orange outline and icon.
InputDecoration authInputDecoration(
  String label,
  IconData icon, {
  Widget? suffixIcon,
  String? helperText,
}) {
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    helperMaxLines: 2,
    errorMaxLines: 3,
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
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red.shade700),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red.shade700, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

/// The login screen's main button: full width, orange, with a spinner
/// while [loading].
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }
}
