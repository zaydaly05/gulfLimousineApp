import 'package:flutter/material.dart';

/// A wrapping row of mixed Elevated/Outlined action buttons that share one
/// compact height and padding, so a card's actions line up evenly.
///
/// Only size and spacing change; each button keeps its own colours.
class ActionButtonRow extends StatelessWidget {
  const ActionButtonRow({super.key, required this.children});

  final List<Widget> children;

  static const _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
  static const _minSize = Size(0, 40);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ButtonStyle compact(ButtonStyle? base) =>
        (base ?? const ButtonStyle()).copyWith(
          padding: const WidgetStatePropertyAll(_padding),
          minimumSize: const WidgetStatePropertyAll(_minSize),
          visualDensity: VisualDensity.standard,
        );

    return Theme(
      data: theme.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: compact(theme.elevatedButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: compact(theme.outlinedButtonTheme.style),
        ),
        textButtonTheme: TextButtonThemeData(
          style: compact(theme.textButtonTheme.style),
        ),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}
