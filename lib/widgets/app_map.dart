import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_info.dart';
import '../models/geo_location.dart';

/// Shared map setup: one place for the tile source, the brand tint and the
/// default centre, instead of a copy in every map screen.

/// Cairo city centre ([GeoLocation.cairo]), the default map centre.
const kCairoLatLng = LatLng(GeoLocation.cairoLat, GeoLocation.cairoLng);

/// Darkened tiles used by the tracking / security maps.
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

/// OpenStreetMap tile layer tinted with [matrix].
TileLayer appTileLayer({List<double> matrix = kDarkMapMatrix}) {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: AppInfo.androidAppId,
    tileBuilder: (context, tileWidget, tile) => ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: tileWidget,
    ),
  );
}
