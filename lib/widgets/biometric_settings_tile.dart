import 'dart:async';

import 'package:flutter/material.dart';

import '../services/biometric_service.dart';

class BiometricSettingsTile extends StatefulWidget {
  final bool dark;
  final bool commitImmediately;

  const BiometricSettingsTile({
    super.key,
    this.dark = false,
    this.commitImmediately = true,
  });

  @override
  State<BiometricSettingsTile> createState() => BiometricSettingsTileState();
}

class BiometricSettingsTileState extends State<BiometricSettingsTile> {
  bool _available = false;
  bool _enabled = false;
  bool _loading = true;
  String _label = 'Biometrics';

  Color get _textColor => widget.dark ? Colors.white : Colors.black87;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final available = await BiometricService.isHardwareAvailable();
    final enabled = await BiometricService.isEnabledForCurrentUser();
    final label = await BiometricService.methodLabel();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
      _label = label;
      _loading = false;
    });
  }

  Future<bool> commit() async {
    if (!_available) return true;
    if (_enabled) {
      if (await BiometricService.isEnabledForCurrentUser()) return true;
      return BiometricService.enableWithPrompt();
    }
    await BiometricService.setEnabled(false);
    return true;
  }

  Future<void> _onChanged(bool value) async {
    if (!widget.commitImmediately) {
      setState(() => _enabled = value);
      return;
    }
    if (value) {
      final ok = await BiometricService.enableWithPrompt();
      if (!mounted) return;
      setState(() => _enabled = ok);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '$_label login is on' : 'Could not enable $_label',
          ),
        ),
      );
      return;
    }
    await BiometricService.setEnabled(false);
    if (!mounted) return;
    setState(() => _enabled = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Biometric login'),
      );
    }

    if (!_available) {
      return ListTile(
        leading: Icon(
          Icons.fingerprint,
          color: widget.dark ? Colors.orange : null,
        ),
        title: Text('Biometric login', style: TextStyle(color: _textColor)),
        subtitle: Text(
          'Not available on this device',
          style: TextStyle(color: widget.dark ? Colors.white54 : Colors.grey),
        ),
      );
    }

    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint, color: Colors.orange),
      title: Text('$_label login', style: TextStyle(color: _textColor)),
      subtitle: Text(
        widget.commitImmediately
            ? 'Use fingerprint or Face ID to log in'
            : 'Turn on, then tap Save Changes',
        style: TextStyle(
          color: widget.dark ? Colors.white70 : Colors.grey.shade700,
        ),
      ),
      value: _enabled,
      activeThumbColor: Colors.orange,
      onChanged: _onChanged,
    );
  }
}
