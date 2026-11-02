import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/analytics_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/active_times_card.dart';
import '../../widgets/insights_card.dart';
import '../../widgets/key_metrics.dart';

class FollowersScreen extends StatelessWidget {
  const FollowersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    final d = p.data;
    final net = p.netFollowers;
    final netDelta = overviewDelta(
      'Net followers',
      net,
      p.previousNetFollowers,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        KeyMetricsCard(
          key: ValueKey('followers-${p.rangeDays}-${p.endOffset}'),
          dates: p.windowDates,
          tiles: [
            MetricTileData(
              title: 'Total followers',
              value: grouped(p.totalFollowers),
              delta: 'All time',
              faintDelta: true,
              series: p.followerWindow,
            ),
            MetricTileData(
              title: 'Net followers',
              value: grouped(net),
              delta: netDelta.text,
              up: netDelta.up,
              series: p.netFollowerWindow,
            ),
          ],
        ),
        InsightsCard(
          title: 'Follower insights',
          audience: InsightsAudience(
            male: d.male,
            female: d.female,
            other: d.other,
            ages: d.ages,
            locations: d.locations,
          ),
        ),
        ActiveTimesCard(
          key: ValueKey('follower-times-${p.rangeDays}-${p.endOffset}'),
          hourly: d.hourly,
          weekday: d.weekday,
          hasData: d.hourly.any((v) => v > 0) || d.weekday.any((v) => v > 0),
          subject: 'followers',
          rangeDays: p.rangeDays,
          peakDate: p.today.subtract(const Duration(days: 1)),
          minDate: p.windowDates.first,
          maxDate: p.today,
        ),
      ],
    );
  }
}
