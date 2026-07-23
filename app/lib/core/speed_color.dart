import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'models/track_point.dart';

/// Red below the reference (average) speed, green above it, with a smooth
/// gradient through yellow/amber right at the average - interpolated in
/// HSV so the transition reads as a natural heat-map rather than the
/// muddy brown a direct RGB red->green lerp would produce.
Color speedToColor(double speedKmh, double avgSpeedKmh) {
  if (avgSpeedKmh <= 0) return const Color(0xFF8E2430);
  final ratio = (speedKmh / avgSpeedKmh).clamp(0.0, 2.0);
  final hue = (ratio / 2.0) * 120.0; // 0=red, 60=yellow (at the average), 120=green
  return HSVColor.fromAHSV(1.0, hue, 0.75, 0.85).toColor();
}

/// Same red->green heat-map used for [speedToColor], applied to a 0-100
/// speeding score instead of a speed ratio (0=red, 100=green).
Color scoreToColor(int score) {
  final hue = (score.clamp(0, 100) / 100.0) * 120.0;
  return HSVColor.fromAHSV(1.0, hue, 0.75, 0.85).toColor();
}

/// Splits a route into one short [Polyline] per segment, each colored by
/// that segment's speed relative to [avgSpeedKmh]. Falls back to a single
/// flat-colored polyline when there's no usable speed data.
List<Polyline> speedColoredSegments(
  List<TrackPoint> points,
  double avgSpeedKmh, {
  double strokeWidth = 3,
}) {
  if (points.length < 2) return [];

  final hasSpeedData = avgSpeedKmh > 0 && points.any((p) => (p.speed ?? 0) > 0);
  if (!hasSpeedData) {
    return [
      Polyline(
        points: points.map((p) => LatLng(p.lat, p.lng)).toList(),
        color: const Color(0xFF8E2430),
        strokeWidth: strokeWidth,
      ),
    ];
  }

  final segments = <Polyline>[];
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final segmentSpeed = ((a.speed ?? 0) + (b.speed ?? 0)) / 2;
    segments.add(Polyline(
      points: [LatLng(a.lat, a.lng), LatLng(b.lat, b.lng)],
      color: speedToColor(segmentSpeed, avgSpeedKmh),
      strokeWidth: strokeWidth,
    ));
  }
  return segments;
}
