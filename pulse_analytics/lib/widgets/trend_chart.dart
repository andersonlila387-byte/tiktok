import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Vertical distance between two gridlines.
const double _stepHeight = 51;

({double minY, double maxY, double step}) _axis(List<int> values) {
  final hi = values.reduce(max);
  final lo = values.reduce(min);
  if (hi <= 0 && lo >= 0) return (minY: 0, maxY: 3, step: 1);
  if (lo < 0) {
    final top = max(hi, 0) * 1.15;
    final bottom = lo * 1.15;
    final step = max(1, ((top - bottom) / 3).ceil()).toDouble();
    return (
      minY: (bottom / step).floorToDouble() * step,
      maxY: (top / step).ceilToDouble() * step,
      step: step,
    );
  }
  final step = max(1, (hi * 1.15 / 3).ceil()).toDouble();
  // A flat line sits a little above the bottom edge instead of on it.
  return (minY: min(lo.toDouble(), step * 0.36), maxY: step * 3, step: step);
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.values, required this.dates});

  final List<int> values;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final n = values.length;
    final a = _axis(values);
    final plotHeight = (a.maxY - a.minY) / a.step * _stepHeight;
    const bottomReserved = 30.0;
    const rightReserved = 40.0;
    final tight = n > 14;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: plotHeight + bottomReserved,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: (n - 1).toDouble(),
            minY: a.minY,
            maxY: a.maxY,
            clipData: const FlClipData.none(),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                bottom: BorderSide(color: AppColors.grid, width: 1),
              ),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: a.step,
              checkToShowHorizontalLine: (v) => v > a.minY + a.step * 0.001,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.grid,
                strokeWidth: 1,
                dashArray: [3, 3],
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: rightReserved,
                  interval: a.step,
                  getTitlesWidget: (v, meta) {
                    // Only the round gridline values get a label.
                    final k = v / a.step;
                    if ((k - k.round()).abs() > 0.001 || v < a.minY) {
                      return const SizedBox.shrink();
                    }
                    if (v == 0) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      space: 0,
                      child: SizedBox(
                        width: rightReserved,
                        child: Text(
                          abbr(v),
                          textAlign: TextAlign.right,
                          style: t(14, color: AppColors.muted),
                        ),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: bottomReserved,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.round();
                    if (v != i || (i != 0 && i != n - 1)) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 8,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text(
                        shortDate(dates[i]),
                        style: t(14, color: AppColors.muted),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1F1F1F),
                fitInsideHorizontally: true,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${shortDate(dates[s.x.toInt()])}\n${grouped(s.y.round())}',
                      t(12, color: Colors.white),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < n; i++)
                    FlSpot(i.toDouble(), values[i].toDouble()),
                ],
                isCurved: true,
                curveSmoothness: 0.15,
                preventCurveOverShooting: true,
                color: AppColors.line,
                barWidth: 1.6,
                dotData: FlDotData(
                  show: !tight,
                  getDotPainter: (a, b, c, d) => FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeColor: AppColors.line,
                    strokeWidth: 1.4,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.line.withValues(alpha: 0.22),
                      AppColors.line.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
