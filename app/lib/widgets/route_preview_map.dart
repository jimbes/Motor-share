import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/models/point_of_interest.dart';
import '../core/models/track_point.dart';
import '../core/speed_color.dart';
import '../theme/redl_colors.dart';

/// A small, non-interactive OpenStreetMap preview of a ride's route -
/// used on feed cards and ride summaries in place of the mockup's flat
/// placeholder thumbnail. Colored by speed relative to [avgSpeedKmh] when
/// available (red below average, green above, gradient in between).
/// Optionally shows this ride's own points of interest as markers.
class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({
    super.key,
    required this.points,
    this.interactive = false,
    this.avgSpeedKmh = 0,
    this.pois = const [],
    this.onTapPoi,
  });

  final List<TrackPoint> points;
  final bool interactive;
  final double avgSpeedKmh;
  final List<RidePointOfInterest> pois;
  final ValueChanged<RidePointOfInterest>? onTapPoi;

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
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(24),
          ),
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
          if (pois.isNotEmpty)
            MarkerLayer(
              markers: pois
                  .map(
                    (poi) => Marker(
                      point: LatLng(poi.lat, poi.lng),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: onTapPoi != null ? () => onTapPoi!(poi) : null,
                        child: const Icon(
                          Icons.photo_camera,
                          color: RedlColors.accent,
                          size: 22,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
