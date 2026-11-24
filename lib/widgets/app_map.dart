import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_info.dart';
import '../models/geo_location.dart';
import '../l10n/locale_service.dart';
import '../services/link_launcher.dart';

/// Shared map setup: one place for the tile source, the map controls and the
/// default centre, instead of a copy in every map screen.
///
/// Tiles come from OpenStreetMap: free and keyless. (CARTO's basemaps have
/// required an API key since 25 Sep 2026.) OpenStreetMap's tile servers are
/// fine for a demo's traffic; a large production app would move to a tile
/// provider with an SLA.

/// Cairo city centre ([GeoLocation.cairo]), the default map centre.
const kCairoLatLng = LatLng(GeoLocation.cairoLat, GeoLocation.cairoLng);

/// Pan and pinch-zoom like Google Maps, without accidental two-finger
/// rotation (the map stays north-up).
const kAppMapInteraction = InteractionOptions(
  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
);

/// Camera that shows every point in [points]; a single point is shown at
/// street level. Returns null when there is nothing to show.
CameraFit? cameraFitFor(List<LatLng> points) {
  if (points.isEmpty) return null;
  if (points.length == 1) {
    return CameraFit.coordinates(coordinates: points, maxZoom: 15);
  }
  return CameraFit.coordinates(
    coordinates: points,
    padding: const EdgeInsets.all(72),
    maxZoom: 16,
  );
}

/// Darkened tiles used by the tracking and security maps.
const List<double> kDarkMapMatrix = [
  0.6, 0, 0, 0, -60, //
  0, 0.6, 0, 0, -60, //
  0, 0, 0.6, 0, -60, //
  0, 0, 0, 1, 0,
];

/// Softened tiles used by the location picker.
const List<double> kLightMapMatrix = [
  0.7, 0, 0, 0, 40, //
  0, 0.7, 0, 0, 40, //
  0, 0, 0.7, 0, 40, //
  0, 0, 0, 1, 0,
];

/// The base map: OpenStreetMap, darkened for the dark screens and softened
/// for the location picker.
class AppTileLayer extends StatelessWidget {
  const AppTileLayer({super.key, this.dark = true});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final matrix = dark ? kDarkMapMatrix : kLightMapMatrix;
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      maxNativeZoom: 19,
      // OpenStreetMap's tile policy asks apps to identify themselves.
      userAgentPackageName: AppInfo.androidAppId,
      tileBuilder: (context, tileWidget, tile) => ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: tileWidget,
      ),
    );
  }
}

/// Map credits, required by the OpenStreetMap licence.
class AppMapAttribution extends StatelessWidget {
  const AppMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => LinkLauncher.open(
            Uri.parse('https://www.openstreetmap.org/copyright'),
          ),
        ),
      ],
    );
  }
}

/// Google-Maps-style floating buttons on the right edge of the map: zoom
/// in/out, plus optional "show everything" and "my location" buttons.
///
/// Place it inside [FlutterMap.children]; it drives the map it sits in.
class AppMapControls extends StatelessWidget {
  const AppMapControls({
    super.key,
    this.dark = true,
    this.fitPoints = const [],
    this.onMyLocation,
    this.alignment = AlignmentDirectional.centerEnd,
  });

  /// Match the map style: dark buttons on dark maps, white on light ones.
  final bool dark;

  /// When not empty, a recenter button frames these points.
  final List<LatLng> fitPoints;

  /// When set, a "my location" button calls this.
  final VoidCallback? onMyLocation;

  final AlignmentGeometry alignment;

  void _zoomBy(BuildContext context, double delta) {
    // The controller's camera is current even between frames, so quick
    // repeated taps each add a step.
    final controller = MapController.of(context);
    final camera = controller.camera;
    final zoom = (camera.zoom + delta).clamp(camera.minZoom ?? 1, 19.0);
    controller.move(camera.center, zoom.toDouble());
  }

  void _fit(BuildContext context) {
    final fit = cameraFitFor(fitPoints);
    if (fit != null) MapController.of(context).fitCamera(fit);
  }

  @override
  Widget build(BuildContext context) {
    final background = dark ? Colors.grey.shade900 : Colors.white;
    final foreground = dark ? Colors.white : Colors.black87;

    Widget button({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        color: foreground,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      );
    }

    Widget group(List<Widget> children) {
      return Material(
        color: background,
        elevation: 3,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMyLocation != null || fitPoints.isNotEmpty) ...[
              group([
                if (onMyLocation != null)
                  button(
                    icon: Icons.my_location,
                    tooltip: tr('myLocation'),
                    onPressed: onMyLocation!,
                  ),
                if (fitPoints.isNotEmpty)
                  button(
                    icon: Icons.center_focus_strong,
                    tooltip: tr('showAll'),
                    onPressed: () => _fit(context),
                  ),
              ]),
              const SizedBox(height: 12),
            ],
            group([
              button(
                icon: Icons.add,
                tooltip: tr('zoomIn'),
                onPressed: () => _zoomBy(context, 1),
              ),
              Container(
                width: 32,
                height: 1,
                color: foreground.withValues(alpha: 0.15),
              ),
              button(
                icon: Icons.remove,
                tooltip: tr('zoomOut'),
                onPressed: () => _zoomBy(context, -1),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
