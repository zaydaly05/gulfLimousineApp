import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/payment_validation.dart';

/// Pay by InstaPay transfer to the business's InstaPay address.
///
/// InstaPay has no public API for apps, so the payment can't be confirmed
/// automatically: the customer reports the transaction ID and sender number,
/// the booking waits as "awaiting payment check", and an admin confirms it
/// on the Payments screen. Pops a [ManualPaymentResult].
class InstaPayScreen extends StatefulWidget {
  final double amount;

  const InstaPayScreen({super.key, required this.amount});

  @override
  State<InstaPayScreen> createState() => _InstaPayScreenState();
}

class _InstaPayScreenState extends State<InstaPayScreen> {
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.egyptianbanks.instapay';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String instapayUsername = AppConfig.defaultInstapayAddress;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAddress());
  }

  Future<void> _loadAddress() async {
    final config = await AppConfigService.instance.load();
    if (!mounted) return;
    setState(() => instapayUsername = config.instapayAddress);
    await _copyUsername();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _copyUsername() async {
    await Clipboard.setData(ClipboardData(text: instapayUsername));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _openInstaPay() async {
    final instapayUri = Uri.parse('instapay://');
    try {
      if (await canLaunchUrl(instapayUri)) {
        await launchUrl(instapayUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(
          Uri.parse(playStoreUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Error launching InstaPay: $e');
    }
  }

  void _submit() {
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
    return Scaffold(
      appBar: AppBar(title: const Text('InstaPay Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Scan QR or Copy Username',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: instapayUsername,
                    version: QrVersions.auto,
                    size: 160.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Amount: EGP ${widget.amount.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _copyUsername,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.copy, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Receiver Username',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              instapayUsername,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_copied)
                        const Text(
                          'Copied!',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: 'Transaction ID / Reference',
                  hintText: 'Enter the 12-digit number from InstaPay',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.receipt_long),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => isValidPaymentReference(v ?? '')
                    ? null
                    : 'Enter the transaction ID from InstaPay',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Your InstaPay mobile number',
                  hintText: '01XXXXXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone_android),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => normalizeEgyptianMobile(v ?? '') == null
                    ? 'Enter the Egyptian mobile number you paid from'
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'How to pay:\n1. Open InstaPay app\n2. Transfer to IPA: $instapayUsername\n3. Enter the exact amount\n4. Copy the Transaction ID and paste it above\n\nYour booking is confirmed once we check the transfer.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _openInstaPay,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open InstaPay App'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit for Confirmation'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
