import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/screens/map_location_picker.dart';

void main() {
  // The geocoding plugin isn't registered in tests, just as it has no web
  // implementation. The picker used to crash on build in both.
  testWidgets('picker renders without the geocoding plugin', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MapLocationPicker(title: 'Pickup')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Confirm Location'), findsOneWidget);
    expect(find.byTooltip('My location'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
  });

  testWidgets('search without geocoding explains instead of failing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MapLocationPicker(title: 'Pickup')),
    );
    await tester.enterText(find.byType(TextField), 'Zamalek');
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();

    expect(find.textContaining("isn't available here"), findsOneWidget);
  });
}
