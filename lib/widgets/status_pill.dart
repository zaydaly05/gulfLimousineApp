import 'package:flutter/material.dart';

/// A small rounded badge: [label] in bold [color] on a translucent tint of
/// the same colour. Used for booking, ticket and payment statuses.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  /// Opacity of the background tint.
  final double alpha;
  final double horizontalPadding;
  final double verticalPadding;
  final double radius;
  final double fontSize;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.alpha = 0.2,
    this.horizontalPadding = 10,
    this.verticalPadding = 4,
    this.radius = 20,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
