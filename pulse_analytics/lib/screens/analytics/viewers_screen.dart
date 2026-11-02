import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/analytics_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/active_times_card.dart';
import '../../widgets/insights_card.dart';
import '../../widgets/key_metrics.dart';
import '../../widgets/ui.dart';

/// Viewers need this many in the period before insights are shown.
const kMinViewersForInsights = 100;

class ViewersScreen extends StatelessWidget {
  const ViewersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    final d = p.data;

    MetricTileData tile(String k) {
      final total = p.metricTotal(k);
      final delta = viewerDelta(k, total, p.previousMetricTotal(k));
      return MetricTileData(
        title: k,
        value: formatMetric(k, total),
        delta: delta.text,
        up: delta.up,
        series: p.metricWindow(k),
      );
    }

    final viewers = p.metricTotal('Total viewers');
    final audience = viewers >= kMinViewersForInsights
        ? InsightsAudience(
            male: d.male,
            female: d.female,
            other: d.other,
            ages: d.ages,
            locations: d.locations,
          )
        : null;
    final hasActive =
        viewers > 0 &&
        (d.viewerHourly.any((v) => v > 0) || d.viewerWeekday.any((v) => v > 0));
    final firstDay = p.lastDataDate.subtract(const Duration(days: 4));

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        KeyMetricsCard(
          key: ValueKey('viewers-${p.rangeDays}-${p.endOffset}'),
          dates: p.windowDates,
          tiles: [tile('Total viewers'), tile('New viewers')],
        ),
        InsightsCard(
          title: 'Viewer insights',
          note:
              'Data is only available if there are at least '
              '$kMinViewersForInsights viewers for the selected time period.',
          audience: audience,
        ),
        ActiveTimesCard(
          key: ValueKey('viewer-times-${p.rangeDays}-${p.endOffset}'),
          hourly: d.viewerHourly,
          weekday: d.viewerWeekday,
          hasData: hasActive,
          subject: 'viewers',
          rangeDays: p.rangeDays,
          peakDate: firstDay,
          minDate: firstDay,
          maxDate: p.today,
        ),
        const _EmptyCard('Creators your viewers also watched'),
        const _EmptyCard('Posts your viewers also viewed'),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(title),
          const SizedBox(height: 6),
          const BodyText(
            "You'll be able to see this information once there's enough "
            'data for analysis.',
          ),
        ],
      ),
    );
  }
}
