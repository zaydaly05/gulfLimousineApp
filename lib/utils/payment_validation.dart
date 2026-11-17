/// Input checks for payments the admin verifies by hand (InstaPay and
/// mobile-wallet transfers).
library;

/// What the customer reports after sending a manual transfer.
class ManualPaymentResult {
  const ManualPaymentResult({required this.reference, required this.payerPhone});

  /// Transaction ID shown by InstaPay or the wallet after sending.
  final String reference;

  /// The mobile number the money was sent from, normalised to 01XXXXXXXXX.
  final String payerPhone;
}

/// Normalises an Egyptian mobile number to `01XXXXXXXXX`, or returns null if
/// it isn't one. Accepts spaces/dashes and a +20 / 0020 / 20 prefix.
/// Valid prefixes: 010 (Vodafone), 011 (e&), 012 (Orange), 015 (WE).
String? normalizeEgyptianMobile(String input) {
  var digits = input.replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.startsWith('+')) digits = digits.substring(1);
  if (digits.startsWith('0020')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('20') && digits.length == 12) {
    digits = '0${digits.substring(2)}';
  }
  return RegExp(r'^01[0125]\d{8}$').hasMatch(digits) ? digits : null;
}

/// A transaction reference: 6 to 30 letters, digits or dashes.
bool isValidPaymentReference(String input) =>
    RegExp(r'^[A-Za-z0-9\-]{6,30}$').hasMatch(input.trim());
