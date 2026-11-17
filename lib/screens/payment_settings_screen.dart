import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_config_service.dart';
import '../utils/payment_validation.dart';

/// Admin: switch each payment method on or off and set where manual
/// transfers go. Saved to `config/payments`; checkout hides switched-off
/// methods and payments_server refuses them.
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  static const _labels = <String, (String, String, IconData)>{
    'card': ('Credit / Debit Card', 'Online through Paymob', Icons.credit_card),
    'walletOnline': (
      'Mobile Wallet (instant)',
      'Online through Paymob',
      Icons.bolt,
    ),
    'walletTransfer': (
      'Mobile Wallet Transfer',
      'Customer sends to your wallet; you confirm it',
      Icons.account_balance_wallet,
    ),
    'instapay': (
      'InstaPay',
      'Customer sends to your InstaPay address; you confirm it',
      Icons.phone_android,
    ),
    'cash': ('Cash on Pickup', 'Paid when the car is collected', Icons.money),
  };

  final _doc = FirebaseFirestore.instance.collection('config').doc('payments');
  final _formKey = GlobalKey<FormState>();
  final _instapay = TextEditingController();
  final _wallet = TextEditingController();
  final _walletName = TextEditingController();
  final Map<String, bool> _enabled = {
    for (final k in AppConfig.methodKeys) k: true,
  };
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _instapay.dispose();
    _wallet.dispose();
    _walletName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = (await _doc.get()).data() ?? {};
      final methods = data['methods'] is Map ? data['methods'] as Map : {};
      if (!mounted) return;
      setState(() {
        for (final k in AppConfig.methodKeys) {
          _enabled[k] = methods[k] != false;
        }
        _instapay.text = data['instapayAddress']?.toString() ?? '';
        _wallet.text = data['walletNumber']?.toString() ?? '';
        _walletName.text = data['walletName']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load settings: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_enabled.values.any((on) => on)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one payment method on')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final wallet = _wallet.text.trim();
      await _doc.set({
        'methods': _enabled,
        'instapayAddress': _instapay.text.trim(),
        'walletNumber': wallet.isEmpty ? '' : normalizeEgyptianMobile(wallet),
        'walletName': _walletName.text.trim(),
      }, SetOptions(merge: true));
      AppConfigService.instance.refresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment settings saved')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.white38),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade700),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.orange),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Payment Methods'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Customers only see the methods that are on.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  for (final key in AppConfig.methodKeys)
                    Card(
                      color: Colors.grey.shade900,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: SwitchListTile(
                        value: _enabled[key]!,
                        onChanged: (on) => setState(() => _enabled[key] = on),
                        activeThumbColor: Colors.orange,
                        secondary: Icon(_labels[key]!.$3, color: Colors.orange),
                        title: Text(
                          _labels[key]!.$1,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _labels[key]!.$2,
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Where manual transfers go',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instapay,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration(
                      'InstaPay address',
                      hint: 'name@instapay',
                    ),
                    validator: (v) =>
                        _enabled['instapay']! && (v ?? '').trim().isEmpty
                        ? 'Needed while InstaPay is on'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _wallet,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration(
                      'Wallet number',
                      hint: '01XXXXXXXXX',
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) {
                        return _enabled['walletTransfer']!
                            ? 'Needed while wallet transfers are on'
                            : null;
                      }
                      return normalizeEgyptianMobile(value) == null
                          ? 'Enter an Egyptian mobile number'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _walletName,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Name on the wallet (optional)'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
