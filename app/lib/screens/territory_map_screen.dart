import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/models/territory.dart';
import '../core/repositories/territory_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';

/// Roughly matches TerritoryGrid's server-side cell size (see
/// motor-share-back app/Services/TerritoryGrid.php) - only used here to draw
/// a square around each cell's returned center point.
const _cellHalfSizeMeters = 158.0;
const _metersPerDegreeLat = 111320.0;

List<LatLng> _cellCorners(double centerLat, double centerLng) {
  final dLat = _cellHalfSizeMeters / _metersPerDegreeLat;
  final metersPerDegreeLng =
      _metersPerDegreeLat * math.cos(centerLat * math.pi / 180);
  final dLng = _cellHalfSizeMeters / metersPerDegreeLng;

  return [
    LatLng(centerLat - dLat, centerLng - dLng),
    LatLng(centerLat - dLat, centerLng + dLng),
    LatLng(centerLat + dLat, centerLng + dLng),
    LatLng(centerLat + dLat, centerLng - dLng),
  ];
}

/// The territory conquest map (REDL project doc, section 8.3.2). Cells are
/// drawn as squares (see TerritoryGrid) rather than true H3 hexagons - no H3
/// library available on the backend host.
class TerritoryMapScreen extends StatefulWidget {
  const TerritoryMapScreen({super.key});

  @override
  State<TerritoryMapScreen> createState() => _TerritoryMapScreenState();
}

class _TerritoryMapScreenState extends State<TerritoryMapScreen> {
  final _mapController = MapController();
  List<Territory> _territories = [];
  LatLng _center = const LatLng(45.75, 4.85);

  @override
  void initState() {
    super.initState();
    _centerOnMe();
  }

  Future<void> _centerOnMe() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _center = LatLng(position.latitude, position.longitude);
      _mapController.move(_center, 15);
    } catch (_) {
      // No location fix - stick with the default center.
    }
    await _loadAround(_center);
  }

  Future<void> _recenterOnMine() async {
    final mine = _territories.where((t) => t.isMine);
    if (mine.isEmpty) return;
    final avgLat =
        mine.map((t) => t.centerLat).reduce((a, b) => a + b) / mine.length;
    final avgLng =
        mine.map((t) => t.centerLng).reduce((a, b) => a + b) / mine.length;
    _mapController.move(LatLng(avgLat, avgLng), 15);
  }

  Future<void> _loadAround(LatLng center) async {
    const delta = 0.03;
    try {
      final territories = await context
          .read<TerritoryRepository>()
          .inBoundingBox(
            south: center.latitude - delta,
            west: center.longitude - delta,
            north: center.latitude + delta,
            east: center.longitude + delta,
          );
      if (mounted) setState(() => _territories = territories);
    } catch (_) {
      // Non-fatal - the map just stays at whatever it last loaded.
    }
  }

  Color _fillColor(Territory territory) {
    if (territory.isMine) return RedlColors.accent.withValues(alpha: 0.25);
    if (territory.ownerUserId != null) {
      return RedlColors.textSecondary.withValues(alpha: 0.15);
    }
    return Colors.transparent;
  }

  Color _borderColor(Territory territory) {
    if (territory.isMine) return RedlColors.accent;
    if (territory.ownerUserId != null) return RedlColors.textSecondary;
    return RedlColors.textMuted.withValues(alpha: 0.4);
  }

  void _showDetail(Territory territory) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              RedlSpacing.screenPadding,
              20,
              RedlSpacing.screenPadding,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.territorySheetOwnerLabel, style: RedlText.eyebrow()),
                const SizedBox(height: 6),
                Text(
                  territory.isMine
                      ? l10n.territoryLegendMine
                      : territory.ownerUserId != null
                      ? '#${territory.ownerUserId}'
                      : l10n.territorySheetFreeLabel,
                  style: RedlText.title(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ownedCount = _territories.where((t) => t.isMine).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.territoryMapTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _loadAround(event.camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.besse.redl',
              ),
              PolygonLayer(
                polygons: _territories
                    .map(
                      (t) => Polygon(
                        points: _cellCorners(t.centerLat, t.centerLng),
                        color: _fillColor(t),
                        borderColor: _borderColor(t),
                        borderStrokeWidth: 1.5,
                      ),
                    )
                    .toList(),
              ),
              MarkerLayer(
                markers: _territories
                    .map(
                      (t) => Marker(
                        point: LatLng(t.centerLat, t.centerLng),
                        width: _cellHalfSizeMeters * 2 / 20,
                        height: _cellHalfSizeMeters * 2 / 20,
                        child: GestureDetector(
                          onTap: () => _showDetail(t),
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          Positioned(
            top: RedlSpacing.screenPadding,
            left: RedlSpacing.screenPadding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: RedlColors.base.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.territoriesOwnedCountLabel(ownedCount),
                style: RedlText.statValue(
                  fontSize: 14,
                  color: RedlColors.accent,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: RedlSpacing.screenPadding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: RedlColors.base.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendRow(
                    color: RedlColors.accent,
                    label: l10n.territoryLegendMine,
                  ),
                  const SizedBox(height: 4),
                  _LegendRow(
                    color: RedlColors.textSecondary,
                    label: l10n.territoryLegendOthers,
                  ),
                  const SizedBox(height: 4),
                  _LegendRow(
                    color: RedlColors.textMuted,
                    label: l10n.territoryLegendFree,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 96,
            left: RedlSpacing.screenPadding,
            child: FloatingActionButton(
              backgroundColor: RedlColors.accent,
              tooltip: l10n.recenterOnMyTerritoriesTooltip,
              onPressed: _recenterOnMine,
              child: const Icon(Icons.hexagon, color: RedlColors.baseAlt),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: RedlText.body(fontSize: 11, color: RedlColors.baseAlt),
        ),
      ],
    );
  }
}
