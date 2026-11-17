import 'package:flutter/foundation.dart';

import '../l10n/locale_service.dart';
import '../l10n/content_labels.dart';

/// How many cars of one model the company has in one colour.
@immutable
class FleetColor {
  const FleetColor({required this.name, required this.count});

  final String name;
  final int count;

  Map<String, dynamic> toMap() => {'name': name, 'count': count};

  static FleetColor? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString().trim() ?? '';
    final count = raw['count'];
    if (name.isEmpty || count is! num || count < 0) return null;
    return FleetColor(name: name, count: count.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is FleetColor && other.name == name && other.count == count;

  @override
  int get hashCode => Object.hash(name, count);
}

/// A car model's fleet: its colours and how many of each.
///
/// Stored on `cars/{id}` as `colors: [{name, count}, ...]`. Cars saved
/// before colours existed have no `colors` and count as one car.
class Fleet {
  Fleet._();

  static List<FleetColor> colorsOf(Map<String, dynamic> car) {
    final raw = car['colors'];
    if (raw is! List) return const [];
    return raw.map(FleetColor.fromMap).whereType<FleetColor>().toList();
  }

  /// Total cars of this model.
  static int totalOf(Map<String, dynamic> car) {
    final colors = colorsOf(car);
    if (colors.isEmpty) return 1;
    return colors.fold(0, (sum, c) => sum + c.count);
  }

  /// "5 cars · Black 3, White 2", or empty for a car without colours.
  static String summary(Map<String, dynamic> car) {
    final colors = colorsOf(car);
    if (colors.isEmpty) return '';
    final total = totalOf(car);
    final parts = colors
        .map((c) => '${colourLabel(c.name)} ${c.count}')
        .join(', ');
    return '${carCount(total)} · $parts';
  }

  /// "2 cars: White 2" / "3 cars: Black 1, White 2" for a booking, or empty
  /// for a single car with no colour assigned (older bookings).
  static String bookingSummary(Map<String, dynamic> booking) {
    final quantity = (booking['quantity'] as num?)?.toInt() ?? 1;
    final raw = booking['allocatedColors'];
    final colors = raw is List
        ? raw.map(FleetColor.fromMap).whereType<FleetColor>().toList()
        : const <FleetColor>[];
    if (quantity <= 1 && colors.isEmpty) return '';
    final cars = carCount(quantity);
    if (colors.isEmpty) return cars;
    return '$cars: ${colors.map((c) => '${colourLabel(c.name)} ${c.count}').join(', ')}';
  }

  /// Why [colors] can't be saved, or null if they can.
  static String? validate(List<FleetColor> colors) {
    final seen = <String>{};
    for (final c in colors) {
      if (c.name.trim().isEmpty) return tr('colourNeedsName');
      if (!seen.add(c.name.trim().toLowerCase())) {
        return tr('colourListedTwice', args: {'name': c.name});
      }
      if (c.count < 0) return tr('countsNotNegative');
    }
    return null;
  }
}
