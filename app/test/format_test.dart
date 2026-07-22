import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/format.dart';

void main() {
  group('formatDistanceKm', () {
    test('shows two decimals under 10km', () {
      expect(formatDistanceKm(4.567), '4.57 km');
    });

    test('shows one decimal at or above 10km', () {
      expect(formatDistanceKm(45.67), '45.7 km');
    });
  });

  group('formatDuration', () {
    test('formats seconds only', () {
      expect(formatDuration(const Duration(seconds: 42)), '42s');
    });

    test('formats minutes and seconds', () {
      expect(formatDuration(const Duration(minutes: 5, seconds: 9)), '5m 09s');
    });

    test('formats hours and minutes, dropping seconds', () {
      expect(formatDuration(const Duration(hours: 2, minutes: 5, seconds: 30)), '2h 05m');
    });
  });

  group('formatSpeedKmh', () {
    test('rounds to whole km/h', () {
      expect(formatSpeedKmh(65.4), '65 km/h');
      expect(formatSpeedKmh(65.6), '66 km/h');
    });
  });

  group('formatRelativeDate', () {
    test('labels today', () {
      expect(formatRelativeDate(DateTime.now()), 'Today');
    });

    test('labels a date a week+ ago with month/day/year', () {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final result = formatRelativeDate(tenDaysAgo);
      expect(result, contains(tenDaysAgo.year.toString()));
    });
  });
}
