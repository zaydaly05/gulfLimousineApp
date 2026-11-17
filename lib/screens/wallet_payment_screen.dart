import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/payment_validation.dart';

/// Pay by sending money from a mobile wallet (Vodafone Cash, Orange Cash,
/// e& money, WE Pay) to the business's wallet number.
///
/// Like InstaPay, a person-to-person wallet transfer can't be confirmed by
/// the app, so the customer reports the transaction ID and sender number and
/// an admin confirms it on the Payments screen. Pops a [ManualPaymentResult].
/// (Automatic wallet checkout goes through Paymob instead.)
class WalletPaymentScreen extends StatefulWidget {
  final double amount;

  const WalletPaymentScreen({super.key, required this.amount});

  @override
  State<WalletPaymentScreen> createState() => _WalletPaymentScreenState();
}

class _WalletPaymentScreenState extends State<WalletPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedWallet;
  AppConfig? _config;

  final List<String> wallets = [
    'Vodafone Cash',
    'Orange Cash',
    'Etisalat Cash',
    'WE Pay',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final config = await AppConfigService.instance.load();
    if (mounted) setState(() => _config = config);
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _copyNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Wallet number copied')));
  }

  void _submit() {
    if (_selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the wallet you paid from')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ManualPaymentResult(
        reference: _referenceController.text.trim(),
        payerPhone: normalizeEgyptianMobile(_phoneController.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final amount = widget.amount.toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Payment')),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : !config.hasWalletTransfer
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Wallet transfers are not set up yet. '
                  'Please choose another payment method.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pay EGP $amount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Choose your mobile wallet:'),
                    const SizedBox(height: 16),
                    for (final wallet in wallets)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: _selectedWallet == wallet
                            ? AppTheme.accent.withValues(alpha: 0.1)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.account_balance_wallet,
                            color: _selectedWallet == wallet
                                ? AppTheme.accent
                                : Colors.grey,
                          ),
                          title: Text(wallet),
                          trailing: _selectedWallet == wallet
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.accent,
                                )
                              : null,
                          onTap: () => setState(() => _selectedWallet = wallet),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.call_received),
                        title: Text(config.walletNumber),
                        subtitle: Text(
                          config.walletName.isEmpty
                              ? 'Send the money to this wallet'
                              : 'Send to ${config.walletName}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Copy number',
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyNumber(config.walletNumber),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Wallet number you paid from',
                        hintText: '01XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => normalizeEgyptianMobile(v ?? '') == null
                          ? 'Enter an Egyptian mobile number (01XXXXXXXXX)'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID',
                        hintText: 'From the confirmation SMS',
                        prefixIcon: Icon(Icons.receipt_long),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => isValidPaymentReference(v ?? '')
                          ? null
                          : 'Enter the transaction ID from the SMS',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How to pay:\n'
                      '1. Open your wallet app or dial its menu\n'
                      '2. Send exactly EGP $amount to ${config.walletNumber}\n'
                      '3. Enter your number and the transaction ID above\n\n'
                      'Your booking is confirmed once we check the transfer.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Submit for Confirmation'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
