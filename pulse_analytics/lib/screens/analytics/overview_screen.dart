import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/analytics_data.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/metric_series.dart';
import '../../widgets/metric_chart.dart';
import '../../widgets/tab_page.dart';
import '../../widgets/ui.dart';
import '../../widgets/video_timeline.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return TabPage(
      children: [
        _KeyMetricsCard(post: post),
        _RetentionCard(post: post),
        _TallyCard(
          title: 'Traffic sources',
          tally: post.traffic,
          total: post.trafficTotal,
        ),
        _QueriesCard(queries: post.queries),
        const _PromoteCard(),
        const _OtherPostsCard(),
      ],
    );
  }
}

class _KeyMetricsCard extends StatefulWidget {
  const _KeyMetricsCard({required this.post});

  final Post post;

  @override
  State<_KeyMetricsCard> createState() => _KeyMetricsCardState();
}

String _seconds(double s) {
  if (s >= 3600) return '${plain(s / 3600, 1)}h';
  if (s >= 60) return '${(s / 60).round()}m';
  return '${s.round()}s';
}

/// Left-axis labels for the five tiles, in tile order.
final _axisFormats = <String Function(double)>[
  (v) => abbr(v),
  _seconds,
  (v) => '${plain(v, 1)}s',
  (v) => '${plain(v, 1)}%',
  (v) => abbr(v),
];

class _KeyMetricsCardState extends State<_KeyMetricsCard> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final tiles = [
      ('Video views', grouped(p.views)),
      ('Total play time', playTime(p.playTimeSec)),
      ('Average watch time', '${plain(p.avgWatchSec)}s'),
      ('Watched full video', '${plain(p.fullWatchPct)}%'),
      ('New followers', grouped(p.newFollowers)),
    ];
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Key metrics'),
          const SizedBox(height: 4),
          BodyText('Updated on ${numericDate(p.updatedAt)}.'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      child: Container(
                        width: w,
                        height: 76,
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                        decoration: BoxDecoration(
                          color: i == _selected
                              ? AppColors.selectedTile
                              : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: i == _selected
                                ? AppColors.accent
                                : AppColors.divider,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tiles[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t(13.5, height: 1.2),
                            ),
                            const Spacer(),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tiles[i].$2,
                                style: t(
                                  23,
                                  weight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (chartAvailable(p, DateTime.now())) ...[
            const SizedBox(height: 16),
            MetricChart(
              key: ValueKey('chart-${p.id}-$_selected'),
              series: metricSeries(p, _selected, DateTime.now()),
              format: _axisFormats[_selected],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F4),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const BodyText(
              'Data chart is only shown for 365 days from the date your '
              'video is posted.',
              color: Color(0xFF6C6D72),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetentionCard extends StatelessWidget {
  const _RetentionCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final hasData = post.avgWatchedPct > 0;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Retention rate'),
          const SizedBox(height: 10),
          if (hasData) ...[
            Text(
              'On average, viewers watched ${plain(post.avgWatchedPct)}% of '
              'your video.',
              style: t(15, weight: FontWeight.w500, height: 1.3),
            ),
            const SizedBox(height: 4),
            BodyText(
              'Most viewers stopped watching at ${clock(post.stopSec)}. Check '
              'out the moment in your video where most viewers lost interest.',
            ),
          ] else
            const BodyText(kNeedViewsNotice),
          const SizedBox(height: 14),
          PlayableCover(post: post),
          const SizedBox(height: 14),
          TimelineChart(
            durationSec: post.durationSec,
            showPercent: true,
            curve: (x) => retentionAt(x, post.avgWatchedPct),
          ),
        ],
      ),
    );
  }
}

/// Share per label as progress bars; grey "-" rows until there is data.
class _TallyCard extends StatelessWidget {
  const _TallyCard({
    required this.title,
    required this.tally,
    required this.total,
  });

  final String title;
  final List<Tally> tally;
  final int total;

  @override
  Widget build(BuildContext context) {
    final empty = total <= 0;
    final rows = empty ? 6 : tally.length;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(title),
          if (empty) ...[
            const SizedBox(height: 6),
            const BodyText(kNeedViewsNotice),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < rows; i++)
            ShareRow(
              label: empty ? '-' : tally[i].name,
              percent: empty ? null : percentOf(tally[i].count, total),
            ),
        ],
      ),
    );
  }
}

/// "Name ........ 42%" with a progress bar underneath.
class ShareRow extends StatelessWidget {
  const ShareRow({super.key, required this.label, required this.percent});

  final String label;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: t(14, height: 1.2),
                ),
              ),
              Text(
                percent == null ? '-%' : '$percent%',
                style: t(14, weight: FontWeight.w500, height: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent ?? 0) / 100,
              minHeight: 7,
              backgroundColor: AppColors.track,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueriesCard extends StatelessWidget {
  const _QueriesCard({required this.queries});

  final List<Tally> queries;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Search queries'),
          const SizedBox(height: 6),
          if (queries.isEmpty)
            const BodyText(kNeedViewsNotice)
          else
            for (final q in queries)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.name,
                        overflow: TextOverflow.ellipsis,
                        style: t(14),
                      ),
                    ),
                    Text(
                      grouped(q.count),
                      style: t(14, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Title, small grey line and an arrow at the right edge.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.title, required this.body, this.onTap});

  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TkCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: t(17, weight: FontWeight.w700, height: 1.2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.info,
                        size: 15,
                        color: Color(0xFF6C6D72),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  BodyText(body),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.text),
          ],
        ),
      ),
    );
  }
}

class _PromoteCard extends StatelessWidget {
  const _PromoteCard();

  @override
  Widget build(BuildContext context) => const _LinkCard(
    title: 'Want more traffic?',
    body: 'Use Promote to grow your audience.',
  );
}

/// Opens a list of every posted video so the visitor can switch to another.
class _OtherPostsCard extends StatelessWidget {
  const _OtherPostsCard();

  @override
  Widget build(BuildContext context) {
    return _LinkCard(
      title: 'View other posts',
      body: 'See the analytics of your other videos.',
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (sheet) {
          final p = context.read<AnalyticsProvider>();
          final posts = p.data.posts;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text('Your posts', style: t(17, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final post in posts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: VideoCover(
                      url: post.thumbnailUrl,
                      width: 40,
                      height: 54,
                      radius: 3,
                    ),
                    title: Text(
                      post.caption.isEmpty ? '(no caption)' : post.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t(15, weight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${grouped(post.views)} views · ${postedOn(post.postedAt)}',
                      style: t(13, color: AppColors.muted),
                    ),
                    trailing: post.id == p.post?.id
                        ? const Icon(LucideIcons.check, size: 18)
                        : null,
                    onTap: () {
                      p.selectPost(post.id);
                      Navigator.pop(sheet);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
