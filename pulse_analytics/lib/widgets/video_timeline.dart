import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/analytics_data.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'ui.dart';

/// The video cover with a play button, as shown above the retention and likes
/// charts.
class PlayableCover extends StatelessWidget {
  const PlayableCover({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: VideoCover(
        url: post.thumbnailUrl,
        width: 165,
        height: 264,
        radius: 4,
        child: const Center(
          child: Icon(
            Icons.play_arrow_rounded,
            size: 56,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 6, color: Colors.black38)],
          ),
        ),
      ),
    );
  }
}

/// Share of viewers still watching at [x] (0..1 through the video), shaped so
/// the average over the whole video is [avgPct].
double retentionAt(double x, double avgPct) {
  final a = (avgPct / 100).clamp(0.0, 1.0);
  if (a <= 0) return x <= 0 ? 1 : 0;
  final floor = a * 0.35;
  final target = ((a - floor) / (1 - floor)).clamp(0.001, 0.999);
  // (1 - e^-k) / k falls from 1 to 0 as k grows; find the k that hits target.
  var lo = 0.0001, hi = 400.0;
  for (var i = 0; i < 60; i++) {
    final k = (lo + hi) / 2;
    final mean = (1 - math.exp(-k)) / k;
    if (mean > target) {
      lo = k;
    } else {
      hi = k;
    }
  }
  final k = (lo + hi) / 2;
  return floor + (1 - floor) * math.exp(-k * x);
}

/// A line chart over the video's length with a draggable marker underneath.
class TimelineChart extends StatefulWidget {
  const TimelineChart({
    super.key,
    required this.durationSec,
    required this.curve,
    this.showPercent = false,
  });

  final double durationSec;

  /// Height (0..1) at each point (0..1) of the video.
  final double Function(double x) curve;

  /// Shows "(xx%)" next to the marker time, for the retention chart.
  final bool showPercent;

  @override
  State<TimelineChart> createState() => _TimelineChartState();
}

class _TimelineChartState extends State<TimelineChart> {
  double _x = 0;

  @override
  Widget build(BuildContext context) {
    final label = widget.showPercent
        ? '${clock(_x * widget.durationSec, pad: true)} '
              '(${(widget.curve(_x) * 100).round()}%)'
        : clock(_x * widget.durationSec, pad: true);
    return Column(
      children: [
        SizedBox(
          height: 70,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(widget.curve, _x, widget.showPercent),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: AppColors.track,
            inactiveTrackColor: AppColors.track,
            thumbColor: Colors.white,
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 11,
              elevation: 3,
              pressedElevation: 4,
            ),
          ),
          child: Slider(value: _x, onChanged: (v) => setState(() => _x = v)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: t(13, color: AppColors.muted)),
              Text(
                clock(widget.durationSec, pad: true),
                style: t(13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.curve, this.marker, this.labels);

  final double Function(double x) curve;
  final double marker;
  final bool labels;

  @override
  void paint(Canvas canvas, Size size) {
    const rightPad = 40.0;
    const top = 8.0;
    final w = size.width - rightPad - 11;
    final h = size.height - top - 4;
    const left = 11.0;
    Offset at(double x) => Offset(left + w * x, top + h * (1 - curve(x)));

    final grid = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    for (final (frac, text) in [(0.0, '100%'), (0.5, '50%')]) {
      final y = top + h * frac;
      _dashed(canvas, Offset(left, y), Offset(left + w + 6, y), grid);
      if (labels) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: t(12, color: AppColors.muted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(left + w + 10, y - tp.height / 2));
      }
    }

    const steps = 80;
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i <= steps; i++) {
      final p = at(i / steps);
      line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(left + w, top + h)
      ..lineTo(left, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.line.withValues(alpha: 0.18),
            AppColors.line.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.line,
    );

    final m = at(marker);
    canvas.drawCircle(m, 5, Paint()..color = Colors.white);
    canvas.drawCircle(
      m,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.line,
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 3.0, gap = 3.0;
    var x = a.dx;
    while (x < b.dx) {
      canvas.drawLine(
        Offset(x, a.dy),
        Offset(math.min(x + dash, b.dx), a.dy),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.marker != marker || old.curve != curve;
}
