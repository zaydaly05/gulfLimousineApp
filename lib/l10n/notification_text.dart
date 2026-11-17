import 'locale_service.dart';
import 'translations.dart';

/// A notification's title and body in the reader's language.
///
/// Notifications are written once (by the app or payments_server) and read
/// later by someone else, so besides the English `title`/`body` they carry
/// `i18n: {title: key, body: key, args: {...}}`. The reader's app translates
/// the keys; older notifications without keys show their English text.
/// Args named `...Status` are booking/trip statuses and are translated too.
(String, String) notificationText(Map<String, dynamic> data) {
  var title = data['title']?.toString() ?? '';
  var body = data['body']?.toString() ?? '';
  final i18n = data['i18n'];
  if (i18n is! Map) return (title, body);

  final args = <String, String>{};
  final rawArgs = i18n['args'];
  if (rawArgs is Map) {
    rawArgs.forEach((name, value) {
      final text = value?.toString() ?? '';
      args['$name'] = '$name'.endsWith('Status') ? statusLabel(text) : text;
    });
  }
  String? translate(Object? key) =>
      key is String && translations['en']!.containsKey(key)
      ? tr(key, args: args)
      : null;

  title = translate(i18n['title']) ?? title;
  body = translate(i18n['body']) ?? body;
  return (title, body);
}

/// The `i18n` map stored on a notification; see [notificationText].
Map<String, Object> notificationI18n(
  String titleKey,
  String bodyKey, [
  Map<String, String> args = const {},
]) => {'title': titleKey, 'body': bodyKey, 'args': args};
