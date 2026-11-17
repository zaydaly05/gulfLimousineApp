import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../utils/friendly_error.dart';

/// One look for every message the app shows at the bottom of the screen:
/// an icon, the text, and a colour that says what happened.
extension AppFeedback on ScaffoldMessengerState {
  /// [error] can be any error; it is turned into a clear message first.
  /// [title] says what failed ("Upload failed"), shown above the message.
  void showError(Object? error, {String? title}) => _show(
    friendlyError(error),
    Icons.error_outline,
    Colors.red.shade700,
    title: title,
  );

  void showSuccess(String message) =>
      _show(message, Icons.check_circle_outline, Colors.green.shade700);

  void showInfo(String message) =>
      _show(message, Icons.info_outline, Colors.grey.shade900);

  void _show(String message, IconData icon, Color color, {String? title}) {
    hideCurrentSnackBar();
    showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: message.length > 80 ? 6 : 4),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shorthand for screens: `showError(context, e)`.
void showError(BuildContext context, Object? error, {String? title}) =>
    ScaffoldMessenger.maybeOf(context)?.showError(error, title: title);

void showSuccess(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)?.showSuccess(message);

/// A full-area message for content that could not load, with a retry
/// button when [onRetry] is given. Scrollable, so pull-to-refresh still
/// works around it.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.dark = false,
  });

  final Object? error;

  /// Shown instead of the error's own message.
  final String? message;
  final VoidCallback? onRetry;

  /// White text for the black admin screens.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final text = message ?? friendlyError(error);
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: dark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('errCouldNotLoad'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(tr('tryAgain')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
