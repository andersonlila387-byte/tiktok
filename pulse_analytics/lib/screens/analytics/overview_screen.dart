import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/analytics_data.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/key_metrics.dart';
import '../../widgets/ui.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  static const keys = [
    'Post views',
    'Profile views',
    'Likes',
    'Comments',
    'Shares',
    'Est. rewards',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    final d = p.data;

    MetricTileData tile(String k) {
      final series = p.metricWindow(k);
      if (d.dashMetrics.contains(k)) {
        return MetricTileData(title: k, value: '-', delta: '-', series: series);
      }
      final total = p.metricTotal(k);
      final delta = overviewDelta(k, total, p.previousMetricTotal(k));
      return MetricTileData(
        title: k,
        value: formatMetric(k, total),
        delta: delta.text,
        up: delta.up,
        series: series,
      );
    }

    final hasViews = p.metricTotal('Post views') > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        KeyMetricsCard(
          key: ValueKey('overview-${p.rangeDays}-${p.endOffset}'),
          dates: p.windowDates,
          tiles: [for (final k in keys) tile(k)],
        ),
        _TrafficCard(shares: hasViews ? d.traffic : const []),
        _SearchCard(queries: hasViews ? d.queries : const []),
        if (!p.overviewNoteDismissed)
          NoteCard(
            title: 'Update to "For your inspiration"',
            body:
                'As part of our recent updates to improve the user '
                'experience, this section is now located in "TikTok Studio" '
                '> "Creation Inspiration".',
            onClose: p.dismissOverviewNote,
          ),
        const _PromoteCard(),
      ],
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.shares});

  final List<LocationShare> shares;

  @override
  Widget build(BuildContext context) {
    final empty = shares.isEmpty;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Traffic source'),
          if (empty) ...[
            const SizedBox(height: 6),
            const BodyText(
              "You'll be able to see this information once there's enough "
              'data for analysis.',
            ),
          ],
          const SizedBox(height: 14),
          for (var i = 0; i < (empty ? 6 : shares.length); i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          empty ? '-' : shares[i].name,
                          overflow: TextOverflow.ellipsis,
                          style: t(16.5, height: 1.2),
                        ),
                      ),
                      Text(
                        empty
                            ? '-%'
                            : '${shares[i].percent.toStringAsFixed(1)}%',
                        style: t(16.5, weight: FontWeight.w500, height: 1.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: empty ? 0 : (shares[i].percent / 100).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: AppColors.track,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.queries});

  final List<WordCount> queries;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Search queries'),
          const SizedBox(height: 6),
          if (queries.isEmpty)
            const BodyText(
              'Each search query has low traffic at the moment. Information '
              'will be available once at least 1 query has enough traffic.',
            )
          else
            for (final q in queries)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.word,
                        overflow: TextOverflow.ellipsis,
                        style: t(16.5),
                      ),
                    ),
                    Text(
                      grouped(q.count),
                      style: t(16.5, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _PromoteCard extends StatelessWidget {
  const _PromoteCard();

  @override
  Widget build(BuildContext context) {
    return TkCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Want more traffic?',
                  style: t(18, weight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 5),
                const BodyText('Use Promote to grow your audience.'),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 22, color: AppColors.text),
        ],
      ),
    );
  }
}
