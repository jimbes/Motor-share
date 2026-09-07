import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/ride_chart_series.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';

/// One metric plotted against distance travelled, Strava-style: a titled
/// card with a hairline grid, a labelled axis on each side, and a value
/// readout on touch.
///
/// Deliberately one metric per chart. Speed and altitude share an x-axis
/// but nothing else, and stacking them on one plot would need a second
/// y-scale whose alignment is arbitrary - inventing a correlation the data
/// does not contain.
class RideMetricChart extends StatefulWidget {
  const RideMetricChart({
    super.key,
    required this.title,
    required this.series,
    required this.unit,
    required this.lineColor,
    this.decimals = 0,
    this.baselineAtZero = false,
    this.height = 170,
  });

  final String title;
  final RideChartSeries series;

  /// Appended to the value readout and the y-axis labels.
  final String unit;

  /// Must clear the chart surface: the brand accent itself sits at ~2:1 on
  /// these dark surfaces, which is unreadable as a 2px line. Its tint and
  /// the secondary ink both clear 7:1 - see the palette note in the PR.
  final Color lineColor;

  final int decimals;

  /// True for a magnitude that reads from nothing (speed), false for one
  /// where only the range matters (altitude, where a zero baseline would
  /// squash the whole profile into a flat line).
  final bool baselineAtZero;

  final double height;

  @override
  State<RideMetricChart> createState() => _RideMetricChartState();
}

class _RideMetricChartState extends State<RideMetricChart> {
  RideChartPoint? _touched;

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final spots = [
      for (final point in series.points) FlSpot(point.distanceKm, point.value),
    ];

    final minY = widget.baselineAtZero ? 0.0 : _paddedMin(series);
    final maxY = _paddedMax(series);
    final readout = _touched ?? series.points.last;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
      decoration: BoxDecoration(
        color: RedlColors.surface1,
        borderRadius: BorderRadius.circular(RedlRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title, style: RedlText.eyebrow(fontSize: 9)),
              // The point under the finger, falling back to the last one -
              // so the card always carries a value instead of only paying
              // off for riders who think to touch it.
              Text(
                '${readout.value.toStringAsFixed(widget.decimals)} ${widget.unit}',
                style: RedlText.statValue(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: widget.height,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: series.totalDistanceKm,
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _gridInterval(minY, maxY),
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: RedlColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: _gridInterval(minY, maxY),
                      getTitlesWidget: (value, meta) =>
                          value == meta.max ? const SizedBox.shrink() : _axisLabel(value.toStringAsFixed(0)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: _distanceInterval(series.totalDistanceKm),
                      getTitlesWidget: (value, meta) =>
                          _axisLabel('${value.toStringAsFixed(0)} km'),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => RedlColors.surface3,
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            '${spot.x.toStringAsFixed(1)} km',
                            RedlText.meta(color: RedlColors.textSecondary),
                          ),
                        )
                        .toList(),
                  ),
                  getTouchedSpotIndicator: (barData, indexes) => indexes
                      .map(
                        (_) => TouchedSpotIndicatorData(
                          const FlLine(color: RedlColors.textSecondary, strokeWidth: 1),
                          FlDotData(
                            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                              radius: 4,
                              color: widget.lineColor,
                              strokeWidth: 2,
                              strokeColor: RedlColors.surface1,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  touchCallback: (event, response) {
                    final index = response?.lineBarSpots?.firstOrNull?.spotIndex;
                    setState(() {
                      _touched = event.isInterestedForInteractions && index != null
                          ? series.points[index]
                          : null;
                    });
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.15,
                    preventCurveOverShooting: true,
                    color: widget.lineColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.lineColor.withValues(alpha: 0.22),
                          widget.lineColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _axisLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 4, right: 6),
    child: Text(
      text,
      // textMuted sits at ~2.3:1 on these surfaces - too low to read.
      style: RedlText.meta(fontSize: 9, color: RedlColors.textSecondary),
    ),
  );

  double _paddedMin(RideChartSeries series) {
    final span = series.maxValue - series.minValue;
    return series.minValue - (span == 0 ? 1 : span * 0.1);
  }

  double _paddedMax(RideChartSeries series) {
    final span = series.maxValue - series.minValue;
    return series.maxValue + (span == 0 ? 1 : span * 0.1);
  }

  /// Three or four gridlines - enough to read a value against, few enough
  /// to stay out of the curve's way.
  static double _gridInterval(double minY, double maxY) {
    final span = maxY - minY;
    return span <= 0 ? 1 : span / 3;
  }

  static double _distanceInterval(double totalKm) {
    if (totalKm <= 0) return 1;
    return totalKm / 4;
  }
}
