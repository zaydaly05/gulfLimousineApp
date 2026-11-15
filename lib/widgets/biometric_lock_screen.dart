import 'package:flutter/material.dart';

import '../services/auth_navigation.dart';
import '../services/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget child;

  const BiometricLockScreen({super.key, required this.child});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _unlocked = false;
  bool _busy = false;
  String _label = 'Biometrics';

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final label = await BiometricService.methodLabel();
    if (mounted) setState(() => _label = label);
    final ok = await BiometricService.authenticate(
      reason: 'Unlock with $label',
    );
    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _busy = false;
    });
  }

  Future<void> _usePassword() =>
      AuthNavigation.signOut(context, autoPromptBiometrics: false);

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, color: Colors.orange, size: 88),
              const SizedBox(height: 24),
              const Text(
                'Gulf Limousine',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock with $_label',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              if (_busy)
                const CircularProgressIndicator(color: Colors.orange)
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Try again'),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _usePassword,
                child: const Text('Use password instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
