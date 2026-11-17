import 'package:flutter/widgets.dart';

/// Keeps scrolling content clear of the phone's own bars.
///
/// Android 15+ draws apps edge to edge and iPhones have a home indicator, so
/// a list with a fixed padding scrolls its last item (often a button) under
/// the system navigation bar. Inside a [SafeArea] the inset is already 0, so
/// this never pads twice.
extension SafeInsets on EdgeInsets {
  EdgeInsets withSafeBottom(BuildContext context) =>
      copyWith(bottom: bottom + MediaQuery.paddingOf(context).bottom);
}
