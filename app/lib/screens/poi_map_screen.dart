import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/models/point_of_interest.dart';
import '../core/repositories/point_of_interest_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import 'ride_summary_screen.dart';

/// The community points-of-interest map (REDL project doc, section 8.3.3).
class PoiMapScreen extends StatefulWidget {
  const PoiMapScreen({super.key});

  @override
  State<PoiMapScreen> createState() => _PoiMapScreenState();
}

class _PoiMapScreenState extends State<PoiMapScreen> {
  final _mapController = MapController();
  List<PointOfInterest> _pois = [];
  LatLng _center = const LatLng(45.75, 4.85);

  @override
  void initState() {
    super.initState();
    _centerOnMe(refetch: true);
  }

  Future<void> _centerOnMe({bool refetch = false}) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _center = LatLng(position.latitude, position.longitude);
      _mapController.move(_center, 13);
    } catch (_) {
      // No location fix - stick with the default center.
    }
    if (refetch) await _loadAround(_center);
  }

  Future<void> _loadAround(LatLng center) async {
    // A generous fixed-size box around the center - simple and good enough
    // for a single screenful of the map; true clustering at low zoom is a
    // follow-up (no clustering dependency in this project yet).
    const delta = 0.3;
    try {
      final pois = await context
          .read<PointOfInterestRepository>()
          .inBoundingBox(
            south: center.latitude - delta,
            west: center.longitude - delta,
            north: center.latitude + delta,
            east: center.longitude + delta,
          );
      if (mounted) setState(() => _pois = pois);
    } catch (_) {
      // Non-fatal - the map just stays at whatever it last loaded.
    }
  }

  void _showDetail(PointOfInterest poi) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poi.photoUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    poi.photoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: RedlColors.surface2,
                      child: const Icon(Icons.broken_image_outlined, color: RedlColors.textMuted, size: 32),
                    ),
                  ),
                )
              else
                Container(
                  height: 120,
                  color: RedlColors.surface2,
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    color: RedlColors.textMuted,
                    size: 32,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RedlSpacing.screenPadding,
                  16,
                  RedlSpacing.screenPadding,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (poi.title != null && poi.title!.isNotEmpty) ...[
                      Text(poi.title!, style: RedlText.title(fontSize: 16)),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: RedlColors.surface4,
                          backgroundImage: poi.user.avatarUrl != null
                              ? NetworkImage(poi.user.avatarUrl!)
                              : null,
                          child: poi.user.avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 12,
                                  color: RedlColors.baseAlt,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(poi.user.name, style: RedlText.body(fontSize: 13)),
                        const SizedBox(width: 10),
                        Text(
                          '${poi.createdAt.day}/${poi.createdAt.month}/${poi.createdAt.year}',
                          style: RedlText.meta(),
                        ),
                      ],
                    ),
                    if (poi.ridePublished) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RideSummaryScreen.view(rideId: poi.rideId),
                            ),
                          );
                        },
                        child: Text(
                          l10n.poiMapViewRideAction,
                          style: RedlText.body(
                            fontSize: 13,
                            color: RedlColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.poiMapTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _loadAround(event.camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.besse.redl',
              ),
              MarkerLayer(
                markers: _pois
                    .map(
                      (poi) => Marker(
                        point: LatLng(poi.lat, poi.lng),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => _showDetail(poi),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: RedlColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: RedlColors.baseAlt,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          Positioned(
            right: RedlSpacing.screenPadding,
            bottom: 24,
            child: FloatingActionButton(
              backgroundColor: RedlColors.accent,
              tooltip: l10n.poiMapNearMeTooltip,
              onPressed: () => _centerOnMe(refetch: true),
              child: const Icon(Icons.my_location, color: RedlColors.baseAlt),
            ),
          ),
        ],
      ),
    );
  }
}
