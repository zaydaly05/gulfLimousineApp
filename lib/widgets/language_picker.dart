import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/locale_service.dart';
import '../theme/app_theme.dart';

class LanguagePicker extends StatelessWidget {
  final bool compact;
  final bool dark;

  const LanguagePicker({super.key, this.compact = false, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final service = LocaleService.instance;
    final selected = service.locale.languageCode;

    if (compact) {
      return SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'en', label: Text('EN')),
          ButtonSegment(value: 'ar', label: Text('ع')),
        ],
        selected: {selected},
        onSelectionChanged: (value) {
          unawaited(service.setLocale(Locale(value.first)));
        },
      );
    }

    final textColor = dark ? Colors.white : Colors.black87;
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.orange),
      title: Text(context.t('language'), style: TextStyle(color: textColor)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            ChoiceChip(
              label: Text(
                context.t('english'),
                style: TextStyle(
                  color: selected == 'en'
                      ? Colors.white
                      : (dark ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: selected == 'en',
              selectedColor: Colors.orange,
              backgroundColor: dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              onSelected: (_) => service.setLocale(const Locale('en')),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: Text(
                context.t('arabic'),
                style: TextStyle(
                  color: selected == 'ar'
                      ? Colors.white
                      : (dark ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: selected == 'ar',
              selectedColor: Colors.orange,
              backgroundColor: dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              onSelected: (_) => service.setLocale(const Locale('ar')),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sleek button suitable for AppBars and Header bars that toggles between English and Arabic.
class LanguageToggleButton extends StatelessWidget {
  final bool dark;
  final bool showText;

  const LanguageToggleButton({
    super.key,
    this.dark = false,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final service = LocaleService.instance;
    final isAr = service.isArabic;
    final color = dark ? Colors.orange : AppTheme.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: InkWell(
        onTap: () => service.toggle(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(20),
            color: dark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.orange.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, color: color, size: 18),
              if (showText) ...[
                const SizedBox(width: 6),
                Text(
                  isAr ? 'English' : 'العربية',
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
