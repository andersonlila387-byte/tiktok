import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/analytics_data.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/tab_page.dart';
import '../../widgets/ui.dart';
import 'overview_screen.dart' show ShareRow;

class ViewersScreen extends StatelessWidget {
  const ViewersScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final locations = [...post.locations]
      ..sort((a, b) => b.count.compareTo(a.count));
    return TabPage(
      children: [
        _TotalCard(post: post),
        _TypesCard(post: post),
        _GenderCard(post: post),
        TkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Age', info: false),
              if (post.agesTotal <= 0) ...[
                const SizedBox(height: 6),
                const BodyText(kNeedViewsNotice),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < kAgeGroups.length; i++)
                ShareRow(
                  label: post.agesTotal <= 0 ? '-' : kAgeGroups[i],
                  percent: post.agesTotal <= 0
                      ? null
                      : percentOf(post.ages[i], post.agesTotal),
                ),
            ],
          ),
        ),
        TkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Locations'),
              if (post.locationsTotal <= 0) ...[
                const SizedBox(height: 6),
                const BodyText(kNeedViewsNotice),
              ],
              const SizedBox(height: 12),
              if (post.locationsTotal <= 0)
                for (var i = 0; i < 5; i++)
                  const ShareRow(label: '-', percent: null)
              else
                for (final l in locations.take(5))
                  ShareRow(
                    label: l.name,
                    percent: percentOf(l.count, post.locationsTotal),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final change = post.viewersChange;
    final color = change > 0 ? AppColors.accent : AppColors.neutralDelta;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Total viewers'),
          const SizedBox(height: 8),
          Text(
            grouped(post.totalViewers),
            style: t(28, weight: FontWeight.w700, height: 1.1),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (change != 0) ...[
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    change > 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                change > 0 ? '+$change' : '$change',
                style: t(14, weight: FontWeight.w600, color: color),
              ),
              const SizedBox(width: 6),
              Text('(vs 1d ago)', style: t(14, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypesCard extends StatelessWidget {
  const _TypesCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final total = post.totalViewers;
    final newPct = percentOf(post.newViewers, total);
    final followerPct = percentOf(post.followerViewers, total);
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Viewer types'),
          const SizedBox(height: 14),
          _SplitBar(
            leftPct: total == 0 ? 0 : newPct,
            rightPct: total == 0 ? 0 : 100 - newPct,
            leftLabel: 'New viewers',
            rightLabel: 'Returning viewers',
          ),
          const SizedBox(height: 18),
          _SplitBar(
            leftPct: total == 0 ? 0 : 100 - followerPct,
            rightPct: total == 0 ? 0 : followerPct,
            leftLabel: 'Non-followers',
            rightLabel: 'Followers',
          ),
        ],
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.leftPct,
    required this.rightPct,
    required this.leftLabel,
    required this.rightLabel,
  });

  final int leftPct;
  final int rightPct;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    Widget bar(int pct, Color color) => Expanded(
      flex: pct,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    final empty = leftPct + rightPct == 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$leftPct%', style: t(14, weight: FontWeight.w500)),
            Text('$rightPct%', style: t(14, weight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        if (empty)
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.track,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          Row(
            children: [
              if (leftPct > 0) bar(leftPct, AppColors.accent),
              if (leftPct > 0 && rightPct > 0) const SizedBox(width: 3),
              if (rightPct > 0) bar(rightPct, AppColors.accentMid),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                leftLabel,
                overflow: TextOverflow.ellipsis,
                style: t(13.5),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                rightLabel,
                overflow: TextOverflow.ellipsis,
                style: t(13.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({required this.post});

  final Post post;

  static const _colors = [
    AppColors.accent,
    AppColors.accentMid,
    AppColors.accentLight,
  ];

  @override
  Widget build(BuildContext context) {
    final total = post.genderTotal;
    final empty = total <= 0;
    final rows = [
      Tally('Female', post.female),
      Tally('Male', post.male),
      Tally('Other', post.other),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Gender', info: false),
          if (empty) ...[
            const SizedBox(height: 6),
            const BodyText(kNeedViewsNotice),
          ],
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: CustomPaint(
                painter: _DonutPainter(
                  empty ? const [] : [for (final r in rows) r.count / total],
                  _colors,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(empty ? '-' : rows[i].name, style: t(14)),
                  ),
                  Text(
                    empty ? '-%' : '${percentOf(rows[i].count, total)}%',
                    style: t(14, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Half ring: grey when there is no data, otherwise one arc per share.
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.shares, this.colors);

  final List<double> shares;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    const stroke = 44.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height),
      radius: r - stroke / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (shares.isEmpty) {
      paint.color = const Color(0xFFE2E2E2);
      canvas.drawArc(rect, math.pi, math.pi, false, paint);
      return;
    }
    var start = math.pi;
    for (var i = 0; i < shares.length; i++) {
      final sweep = math.pi * shares[i];
      if (sweep <= 0) continue;
      paint.color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.shares.toString() != shares.toString();
}
