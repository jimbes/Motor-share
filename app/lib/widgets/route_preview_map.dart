import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/models/track_point.dart';
import '../theme/redl_colors.dart';

/// A small, non-interactive OpenStreetMap preview of a ride's route -
/// used on feed cards and ride summaries in place of the mockup's flat
/// placeholder thumbnail.
class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({super.key, required this.points, this.interactive = false});

  final List<TrackPoint> points;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(color: RedlColors.surface3);
    }

    final latLngs = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final bounds = LatLngBounds.fromPoints(latLngs);

    return IgnorePointer(
      ignoring: !interactive,
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.redl.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(points: latLngs, color: RedlColors.accent, strokeWidth: 3),
            ],
          ),
        ],
      ),
    );
  }
}
