import 'package:flutter/foundation.dart';

/// Installs the app's two global error handlers. Call first in `main()`,
/// right after `WidgetsFlutterBinding.ensureInitialized()`, so nothing that
/// runs later can fail unseen.
///
/// - [FlutterError.onError]: errors thrown during build, layout and paint.
/// - [PlatformDispatcher.onError]: uncaught asynchronous errors.
///
/// Together they cover every path, so no `runZonedGuarded` is needed.
void installErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      FlutterError.presentError(details);
    } catch (_) {
      // An error handler must never throw (it would recurse into itself),
      // so a failure here is deliberately discarded.
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      debugPrint('Uncaught async error: $error\n$stack');
    } catch (_) {
      // Same reason as above: never let the error handler throw.
    }
    // Always true: `false` hands the error to the engine's fallback, which
    // may terminate the app.
    return true;
  };
}
