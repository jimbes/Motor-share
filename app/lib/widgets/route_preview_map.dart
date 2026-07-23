import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/models/track_point.dart';
import '../core/speed_color.dart';
import '../theme/redl_colors.dart';

/// A small, non-interactive OpenStreetMap preview of a ride's route -
/// used on feed cards and ride summaries in place of the mockup's flat
/// placeholder thumbnail. Colored by speed relative to [avgSpeedKmh] when
/// available (red below average, green above, gradient in between).
class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({super.key, required this.points, this.interactive = false, this.avgSpeedKmh = 0});

  final List<TrackPoint> points;
  final bool interactive;
  final double avgSpeedKmh;

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
            userAgentPackageName: 'com.besse.redl',
          ),
          PolylineLayer(polylines: speedColoredSegments(points, avgSpeedKmh)),
        ],
      ),
    );
  }
}
