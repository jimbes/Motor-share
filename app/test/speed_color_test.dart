import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/models/track_point.dart';
import 'package:redl/core/speed_color.dart';

void main() {
  group('speedToColor', () {
    test('is red at zero speed relative to a positive average', () {
      final color = speedToColor(0, 60);
      expect(HSVColor.fromColor(color).hue, closeTo(0, 0.1));
    });

    test('is at the yellow midpoint exactly at the average', () {
      final color = speedToColor(60, 60);
      expect(HSVColor.fromColor(color).hue, closeTo(60, 0.1));
    });

    test('is green at or above double the average', () {
      final atDouble = speedToColor(120, 60);
      final beyondDouble = speedToColor(200, 60);
      expect(HSVColor.fromColor(atDouble).hue, closeTo(120, 0.1));
      expect(HSVColor.fromColor(beyondDouble).hue, closeTo(120, 0.1));
    });

    test('falls back to the brand accent when average speed is unknown', () {
      expect(speedToColor(50, 0), const Color(0xFF8E2430));
    });
  });

  group('scoreToColor', () {
    test('is red at a score of zero', () {
      expect(HSVColor.fromColor(scoreToColor(0)).hue, closeTo(0, 0.1));
    });

    test('is green at a perfect score of 100', () {
      expect(HSVColor.fromColor(scoreToColor(100)).hue, closeTo(120, 0.1));
    });

    test('is at the yellow midpoint at 50', () {
      expect(HSVColor.fromColor(scoreToColor(50)).hue, closeTo(60, 0.1));
    });

    test('clamps out-of-range scores', () {
      expect(HSVColor.fromColor(scoreToColor(-10)).hue, closeTo(0, 0.1));
      expect(HSVColor.fromColor(scoreToColor(150)).hue, closeTo(120, 0.1));
    });
  });

  group('speedColoredSegments', () {
    TrackPoint p(double lat, double lng, double speed) => TrackPoint(lat: lat, lng: lng, speed: speed);

    test('returns one segment per consecutive point pair', () {
      final points = [p(0, 0, 30), p(0, 1, 60), p(0, 2, 90)];
      final segments = speedColoredSegments(points, 60);
      expect(segments.length, 2);
    });

    test('falls back to a single flat polyline when there is no speed data', () {
      final points = [
        const TrackPoint(lat: 0, lng: 0),
        const TrackPoint(lat: 0, lng: 1),
        const TrackPoint(lat: 0, lng: 2),
      ];
      final segments = speedColoredSegments(points, 0);
      expect(segments.length, 1);
      expect(segments.first.points.length, 3);
    });

    test('returns nothing for fewer than two points', () {
      expect(speedColoredSegments([p(0, 0, 10)], 60), isEmpty);
      expect(speedColoredSegments([], 60), isEmpty);
    });
  });
}
