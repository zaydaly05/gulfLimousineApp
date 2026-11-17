import 'locale_service.dart';

/// payments_server answers in English. Its messages are a fixed set, so the
/// app recognises each one and shows its own translation. A message the app
/// does not know (a newer server) is shown as sent.
///
/// test/server_errors_test.dart reads payments_server and fails when the
/// server has a message missing here.
class _ServerMessage {
  const _ServerMessage(this.pattern, this.key, [this.argNames = const []]);
  final String pattern;
  final String key;
  final List<String> argNames;
}

const _messages = <_ServerMessage>[
  // Sign-in and requests
  _ServerMessage(r'Please sign in again\.', 'pleaseSignInAgain'),
  _ServerMessage(r'Use POST', 'somethingWentWrong'),
  _ServerMessage(r'Invalid signature', 'somethingWentWrong'),
  _ServerMessage(r'Not allowed\.?', 'notAllowed'),
  // Booking request
  _ServerMessage(r'Choose the pickup and return dates\.', 'srvChooseDates'),
  _ServerMessage(r'Choose valid dates\.', 'srvChooseDates'),
  _ServerMessage(r'The pickup date has passed\.', 'srvPickupPassed'),
  _ServerMessage(
    r'Return must be on or after pickup\.',
    'srvReturnAfterPickup',
  ),
  _ServerMessage(r'Bookings open up to a year ahead\.', 'srvYearAhead'),
  _ServerMessage(r'You can book 1 to (\d+) cars at a time\.', 'srvMaxCars', [
    'n',
  ]),
  _ServerMessage(
    r'Choose the pickup and drop-off locations\.',
    'selectPickupDropoffLoc',
  ),
  _ServerMessage(
    r'Please sign the rental agreement first\.?',
    'pleaseSignTheRentalAgreement',
  ),
  _ServerMessage(r'Choose a payment method\.', 'srvChooseMethod'),
  _ServerMessage(r'Online payment is not set up\.', 'srvOnlineNotSetUp'),
  _ServerMessage(r'Enter the transaction ID\.', 'enterTxnInstapay'),
  _ServerMessage(
    r'Enter the mobile number you paid from\.',
    'enterPaidFromNumber',
  ),
  _ServerMessage(r'Car not found\.', 'srvCarNotFound'),
  _ServerMessage(r'Invalid car\.', 'srvCarNotFound'),
  _ServerMessage(
    r'This payment method is not available right now\. Choose another\.',
    'srvMethodOffChoose',
  ),
  _ServerMessage(
    r'This payment method is not available right now\. Make a new booking with another method\.',
    'srvMethodOffNewBooking',
  ),
  _ServerMessage(
    r'Online payment is switched off right now\. Make a new booking with another method\.',
    'srvOnlineOff',
  ),
  _ServerMessage(r'This car has no price yet\.', 'srvNoPrice'),
  _ServerMessage(
    r'No cars of this model are free on those dates\.',
    'noCarsFree',
  ),
  _ServerMessage(
    r'Only (\d+) cars? (?:is|are) free on those dates\.',
    'srvOnlyNFree',
    ['n'],
  ),
  _ServerMessage(r'Could not save the booking\. Try again\.', 'srvSaveBooking'),
  _ServerMessage(
    r'Could not check availability\. Try again\.',
    'srvCheckAvailability',
  ),
  // Online payment
  _ServerMessage(
    r'Payment service is not configured yet\.',
    'srvOnlineNotSetUp',
  ),
  _ServerMessage(r'Invalid booking\.', 'bookingNotFound'),
  _ServerMessage(r'Booking not found\.?', 'bookingNotFound'),
  _ServerMessage(r'This booking belongs to another account', 'srvOtherAccount'),
  _ServerMessage(r'This booking is not an online payment', 'srvNotOnline'),
  _ServerMessage(
    r'This booking is no longer awaiting payment',
    'srvNotAwaiting',
  ),
  _ServerMessage(
    r'This booking is already paid or being checked',
    'srvAlreadyPaid',
  ),
  _ServerMessage(r'Booking has no amount', 'srvNoAmount'),
  _ServerMessage(
    r'The price has changed\. Please make a new booking\.',
    'srvPriceChanged',
  ),
  _ServerMessage(
    r'These cars were booked by someone else while this payment was pending\. Please make a new booking\.',
    'srvBookedMeanwhile',
  ),
  _ServerMessage(r'Add your phone number in Profile first\.', 'srvAddPhone'),
  _ServerMessage(
    r'Paymob could not start the payment\. Try again\.',
    'srvPaymobStart',
  ),
  _ServerMessage(r'Could not record payment', 'srvRecordPayment'),
  _ServerMessage(
    r'Could not record the payment\. Try again\.',
    'srvRecordPayment',
  ),
  // Return km and tickets
  _ServerMessage(
    r'Enter the return km as a whole number\.',
    'srvReturnKmWhole',
  ),
  _ServerMessage(r'This booking was cancelled\.', 'srvBookingCancelled'),
  _ServerMessage(r'Record pickup km first\.', 'srvPickupKmFirst'),
  _ServerMessage(r'Return km already recorded\.', 'srvReturnKmAlready'),
  _ServerMessage(r'Return km must be at least (\d+)\.', 'returnReadingMin', [
    'km',
  ]),
  _ServerMessage(
    r'That return km looks wrong\. Check it and try again\.',
    'srvReturnKmWrong',
  ),
  _ServerMessage(
    r'Could not save the return km\. Try again\.',
    'srvSaveReturnKm',
  ),
  _ServerMessage(
    r'The odometer photo did not upload\. Try again\.',
    'srvOdometerUpload',
  ),
  _ServerMessage(r'Ticket not found\.', 'srvTicketNotFound'),
  _ServerMessage(r'This ticket is already settled\.', 'srvTicketSettled'),
];

final _compiled = [for (final m in _messages) (RegExp('^${m.pattern}\$'), m)];

/// The translation key a server message maps to, or null if unknown.
String? serverMessageKey(String message) {
  for (final (re, m) in _compiled) {
    if (re.hasMatch(message.trim())) return m.key;
  }
  return null;
}

/// [message] from payments_server, in the app's language.
String localizeServerMessage(String message) {
  final text = message.trim();
  for (final (re, m) in _compiled) {
    final match = re.firstMatch(text);
    if (match == null) continue;
    return tr(
      m.key,
      args: {
        for (var i = 0; i < m.argNames.length; i++)
          m.argNames[i]: match.group(i + 1) ?? '',
      },
    );
  }
  return text;
}
