import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class InstaPayScreen extends StatefulWidget {
  final double amount;

  const InstaPayScreen({super.key, required this.amount});

  @override
  State<InstaPayScreen> createState() => _InstaPayScreenState();
}

class _InstaPayScreenState extends State<InstaPayScreen> {
  static const String instapayUsername = 'zaydaly@instapay';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.egyptianbanks.instapay';

  final TextEditingController _referenceController = TextEditingController();
  bool _copied = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    unawaited(_copyUsername());
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _copyUsername() async {
    await Clipboard.setData(const ClipboardData(text: instapayUsername));
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

  Future<void> _verifyAndSubmit() async {
    final ref = _referenceController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the Transaction ID')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    // Simulating "API" verification
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isVerifying = false);
      Navigator.pop(context, ref); // Return the reference ID
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InstaPay Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
            TextField(
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
            ),
            const SizedBox(height: 16),
            const Text(
              'How to pay:\n1. Open InstaPay app\n2. Transfer to IPA: $instapayUsername\n3. Enter the exact amount\n4. Copy the Transaction ID and paste it above',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (_isVerifying)
              const Center(child: CircularProgressIndicator())
            else ...[
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
                onPressed: _verifyAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Verify & Complete Booking'),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
