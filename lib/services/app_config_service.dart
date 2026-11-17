import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/api_keys.dart';

/// Settings an admin can change without rebuilding the app.
///
/// They live in two Firestore documents that any signed-in user can read and
/// only admins can write (see `match /config/{doc}` in firestore.rules):
///
/// * `config/ai`: `geminiApiKey`, `geminiModel`
/// * `config/payments`: `paymentsServerUrl`, `instapayAddress`,
///   `walletNumber`, `walletName`
///
/// Build-time `--dart-define` values win over Firestore, so a developer can
/// still test with a local key.
@immutable
class AppConfig {
  const AppConfig({
    this.geminiApiKey = '',
    this.geminiModel = defaultGeminiModel,
    this.paymentsServerUrl = '',
    this.instapayAddress = defaultInstapayAddress,
    this.walletNumber = '',
    this.walletName = '',
    this.methods = const {},
  });

  /// Admin switches in `config/payments.methods`; missing means on.
  static const methodKeys = [
    'card',
    'walletOnline',
    'walletTransfer',
    'instapay',
    'cash',
  ];

  /// Auto-updated alias for Google's newest Flash model, so the app keeps
  /// working when a specific model version is retired.
  static const defaultGeminiModel = 'gemini-flash-latest';
  static const defaultInstapayAddress = 'zaydaly@instapay';

  final String geminiApiKey;
  final String geminiModel;

  /// Base URL of payments_server (Paymob), e.g. https://x.vercel.app
  final String paymentsServerUrl;

  /// Where customers send InstaPay transfers (an InstaPay address, IPA).
  final String instapayAddress;

  /// Mobile-wallet number that receives manual wallet transfers.
  final String walletNumber;
  final String walletName;
  final Map<String, bool> methods;

  /// Whether the admin has this payment method switched on.
  bool isEnabled(String method) => methods[method] ?? true;

  bool get hasGemini =>
      geminiApiKey.isNotEmpty && !geminiApiKey.startsWith('YOUR_');

  /// Whether payments_server is set up (bookings and online payment go
  /// through it). A local http address is accepted for development.
  bool get hasPaymob =>
      paymentsServerUrl.startsWith('https://') ||
      paymentsServerUrl.startsWith('http://127.0.0.1') ||
      paymentsServerUrl.startsWith('http://localhost');
  bool get hasWalletTransfer => walletNumber.isNotEmpty;

  factory AppConfig.fromDocs(
    Map<String, dynamic>? ai,
    Map<String, dynamic>? payments,
  ) {
    String read(Map<String, dynamic>? doc, String key, String fallback) {
      final value = doc?[key]?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    String pick(String buildTime, String runtime) =>
        buildTime.isNotEmpty ? buildTime : runtime;

    final buildKey = ApiKeys.hasGeminiKey ? ApiKeys.gemini : '';
    final serverUrl = pick(
      _buildPaymentsServerUrl,
      read(payments, 'paymentsServerUrl', ''),
    );
    return AppConfig(
      geminiApiKey: pick(buildKey, read(ai, 'geminiApiKey', '')),
      geminiModel: pick(
        _buildGeminiModel,
        read(ai, 'geminiModel', defaultGeminiModel),
      ),
      // No trailing slash, so paths can be appended directly.
      paymentsServerUrl: serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl,
      instapayAddress: read(
        payments,
        'instapayAddress',
        defaultInstapayAddress,
      ),
      walletNumber: read(payments, 'walletNumber', ''),
      walletName: read(payments, 'walletName', ''),
      methods: {
        for (final key in methodKeys)
          key:
              (payments?['methods'] is Map
                  ? (payments!['methods'] as Map)[key]
                  : null) !=
              false,
      },
    );
  }

  static const _buildGeminiModel = String.fromEnvironment('GEMINI_MODEL');
  static const _buildPaymentsServerUrl = String.fromEnvironment(
    'PAYMENTS_SERVER_URL',
  );
}

class AppConfigService {
  AppConfigService._();
  static final instance = AppConfigService._();

  Future<AppConfig>? _pending;

  /// Loads the config once per app session. A failed read (offline, signed
  /// out) is not cached, so the next call tries again.
  Future<AppConfig> load() => _pending ??= _fetch();

  /// Forget the cached config, e.g. after an admin changes it.
  void refresh() => _pending = null;

  Future<AppConfig> _fetch() async {
    try {
      final db = FirebaseFirestore.instance;
      final docs = await Future.wait([
        db.collection('config').doc('ai').get(),
        db.collection('config').doc('payments').get(),
      ]).timeout(const Duration(seconds: 8));
      return AppConfig.fromDocs(docs[0].data(), docs[1].data());
    } catch (e) {
      debugPrint('App config unavailable, using defaults: $e');
      _pending = null;
      return AppConfig.fromDocs(null, null);
    }
  }
}
