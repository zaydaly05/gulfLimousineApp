import 'dart:async';

import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import '../l10n/locale_service.dart';
import 'app_feedback.dart';

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
  String _label = tr('biometrics');

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
      ScaffoldMessenger.of(context).showInfo(
        ok
            ? tr('biometricOn', args: {'method': _label})
            : tr('couldNotEnableBiometric'),
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
      return ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(tr('biometricLogin')),
      );
    }

    if (!_available) {
      return ListTile(
        leading: Icon(
          Icons.fingerprint,
          color: widget.dark ? Colors.orange : null,
        ),
        title: Text(tr('biometricLogin'), style: TextStyle(color: _textColor)),
        subtitle: Text(
          tr('biometricNotAvailable'),
          style: TextStyle(color: widget.dark ? Colors.white54 : Colors.grey),
        ),
      );
    }

    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint, color: Colors.orange),
      title: Text(
        tr('login2', args: {'_label': _label}),
        style: TextStyle(color: _textColor),
      ),
      subtitle: Text(
        widget.commitImmediately
            ? tr('biometricHint')
            : tr('biometricHintSave'),
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
