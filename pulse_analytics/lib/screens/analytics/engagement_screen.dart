import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/analytics_data.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/tab_page.dart';
import '../../widgets/ui.dart';
import '../../widgets/video_timeline.dart';

class EngagementScreen extends StatelessWidget {
  const EngagementScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final words = [...post.topWords]
      ..sort((a, b) => b.count.compareTo(a.count));
    final peak = post.durationSec <= 0
        ? 0.0
        : (post.likePeakSec / post.durationSec).clamp(0.0, 1.0);
    return TabPage(
      children: [
        TkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Top words used in comments'),
              const SizedBox(height: 4),
              if (words.isEmpty)
                const BodyText(
                  'Top word insights are not ready yet. Please check back '
                  'later.',
                )
              else ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in words)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${w.name} · ${grouped(w.count)}',
                          style: t(14, weight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        TkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Likes'),
              const SizedBox(height: 12),
              if (post.likes > 0) ...[
                BodyText(
                  'Most viewers liked this video at ${clock(post.likePeakSec)}. '
                  'Check out the moment where most viewers liked your video.',
                ),
                const SizedBox(height: 14),
                PlayableCover(post: post),
                const SizedBox(height: 14),
                TimelineChart(
                  durationSec: post.durationSec,
                  curve: (x) =>
                      0.06 + 0.94 * math.exp(-math.pow((x - peak) / 0.1, 2)),
                ),
              ] else
                const BodyText(kNeedViewsNotice),
            ],
          ),
        ),
      ],
    );
  }
}
