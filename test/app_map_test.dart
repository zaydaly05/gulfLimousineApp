import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/widgets/app_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Controls only; the tile layer needs the network, so it's left out.
  Widget harness(MapController controller, {List<LatLng> fit = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          mapController: controller,
          options: const MapOptions(
            initialCenter: kCairoLatLng,
            initialZoom: 10,
          ),
          children: [AppMapControls(fitPoints: fit)],
        ),
      ),
    );
  }

  testWidgets('zoom buttons change the zoom by one step', (tester) async {
    final controller = MapController();
    await tester.pumpWidget(harness(controller));

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(controller.camera.zoom, 11);

    await tester.tap(find.byTooltip('Zoom out'));
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pump();
    expect(controller.camera.zoom, 9);
  });

  testWidgets('"Show all" frames the given points', (tester) async {
    final controller = MapController();
    const a = LatLng(30.00, 31.20);
    const b = LatLng(30.10, 31.40);
    await tester.pumpWidget(harness(controller, fit: const [a, b]));

    controller.move(const LatLng(0, 0), 3);
    await tester.pump();
    await tester.tap(find.byTooltip('Show all'));
    await tester.pump();

    final bounds = controller.camera.visibleBounds;
    expect(bounds.contains(a) && bounds.contains(b), isTrue);
  });

  testWidgets('no "Show all" or "My location" unless asked for', (
    tester,
  ) async {
    await tester.pumpWidget(harness(MapController()));
    expect(find.byTooltip('Show all'), findsNothing);
    expect(find.byTooltip('My location'), findsNothing);
  });

  test('cameraFitFor has nothing to frame for no points', () {
    expect(cameraFitFor(const []), isNull);
  });
}
