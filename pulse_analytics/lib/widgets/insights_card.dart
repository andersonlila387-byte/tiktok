import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/analytics_data.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Audience breakdown behind Gender / Age / Locations chips. A null [audience]
/// shows the empty placeholder used when there is not enough data.
class InsightsCard extends StatefulWidget {
  const InsightsCard({
    super.key,
    required this.title,
    required this.audience,
    this.note,
  });

  final String title;
  final InsightsAudience? audience;
  final String? note;

  @override
  State<InsightsCard> createState() => _InsightsCardState();
}

class InsightsAudience {
  const InsightsAudience({
    required this.male,
    required this.female,
    required this.other,
    required this.ages,
    required this.locations,
  });

  final double male;
  final double female;
  final double other;
  final Map<String, double> ages;
  final List<LocationShare> locations;
}

class _InsightsCardState extends State<InsightsCard> {
  static const _tabs = ['Gender', 'Age', 'Locations'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final a = widget.audience;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(widget.title),
          if (widget.note != null) ...[
            const SizedBox(height: 4),
            BodyText(widget.note!),
          ],
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  SquareChip(
                    _tabs[i],
                    i == _tab,
                    () => setState(() => _tab = i),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_tab == 0) _Gender(a) else if (_tab == 1) _Bars(_ageRows(a)),
          if (_tab == 2) _Bars(_locationRows(a)),
        ],
      ),
    );
  }

  List<(String, double?)> _ageRows(InsightsAudience? a) => a == null
      ? [for (var i = 0; i < 5; i++) ('-', null)]
      : [for (final e in a.ages.entries) (e.key, e.value)];

  List<(String, double?)> _locationRows(InsightsAudience? a) => a == null
      ? [for (var i = 0; i < 5; i++) ('-', null)]
      : [for (final l in a.locations) (l.name, l.percent)];
}

const _dotColors = [
  AppColors.accent,
  AppColors.accentMid,
  AppColors.accentLight,
];

class _Gender extends StatelessWidget {
  const _Gender(this.a);

  final InsightsAudience? a;

  @override
  Widget build(BuildContext context) {
    final values = a == null ? null : [a!.male, a!.female, a!.other];
    const labels = ['Male', 'Female', 'Other'];
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 177,
            height: 90,
            child: CustomPaint(painter: _HalfDonut(values)),
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
          SizedBox(
            height: 43,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _dotColors[i],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    values == null ? '-' : labels[i],
                    style: t(16.5, height: 1.2),
                  ),
                ),
                Text(
                  values == null ? '-%' : '${_pct(values[i])}%',
                  style: t(16.5, weight: FontWeight.w500, height: 1.2),
                ),
                if (values != null && i == 2) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.text,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _pct(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

class _HalfDonut extends CustomPainter {
  _HalfDonut(this.values);

  final List<double>? values;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 25.0;
    final radius = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height - 1),
      radius: radius,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final v = values;
    final total = v?.fold<double>(0, (a, b) => a + b) ?? 0;
    if (v == null || total <= 0) {
      paint.color = const Color(0xFFE4E4E4);
      canvas.drawArc(rect, pi, pi, false, paint);
      return;
    }
    // Segments are butt-ended; a thin white line separates neighbours.
    var start = pi;
    for (var i = 0; i < v.length; i++) {
      final sweep = v[i] / total * pi;
      if (sweep <= 0) continue;
      paint.color = _dotColors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
    final sep = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6;
    var angle = pi;
    for (var i = 0; i < v.length - 1; i++) {
      angle += v[i] / total * pi;
      if (v[i] <= 0) continue;
      final c = rect.center;
      canvas.drawLine(
        c + Offset(cos(angle), sin(angle)) * (radius - stroke / 2),
        c + Offset(cos(angle), sin(angle)) * (radius + stroke / 2),
        sep,
      );
    }
  }

  @override
  bool shouldRepaint(_HalfDonut old) =>
      old.values.toString() != values.toString();
}

/// Label + percentage over a thin bar (age and location rows).
class _Bars extends StatelessWidget {
  const _Bars(this.rows);

  final List<(String, double?)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.$1,
                        overflow: TextOverflow.ellipsis,
                        style: t(16.5, height: 1.2),
                      ),
                    ),
                    Text(
                      r.$2 == null
                          ? '-%'
                          : (r.$2! > 0 && r.$2! < 1
                                ? '<1%'
                                : '${_pct(r.$2!)}%'),
                      style: t(16.5, weight: FontWeight.w500, height: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ((r.$2 ?? 0) / 100).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: AppColors.track,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
