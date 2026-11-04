import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/metric_series.dart';

/// Daily line chart for one Overview metric: grid lines with value labels on
/// the left, first and last date underneath.
class MetricChart extends StatelessWidget {
  const MetricChart({super.key, required this.series, required this.format});

  final MetricSeries series;

  /// Text for a value on the left axis.
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(painter: _Painter(series, format)),
    );
  }
}

double _niceMax(double v) {
  if (v <= 0) return 1;
  var step = 1.0;
  while (step * 10 < v) {
    step *= 10;
  }
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (step * m >= v) return step * m;
  }
  return step * 10;
}

class _Painter extends CustomPainter {
  _Painter(this.series, this.format);

  final MetricSeries series;
  final String Function(double) format;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0, bottom = 22.0, top = 8.0;
    final w = size.width - left - 6;
    final h = size.height - bottom - top;
    final values = series.values;
    final max = _niceMax(values.fold<double>(0, (a, b) => a > b ? a : b));

    final grid = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = top + h * (1 - frac);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: format(max * frac),
          style: t(11, color: AppColors.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 6);
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    Offset at(int i) => Offset(
      left + (values.length == 1 ? 0 : w * i / (values.length - 1)),
      top + h * (1 - (values[i] / max).clamp(0.0, 1.0)),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
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
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.line,
    );

    final dates = series.dates;
    for (final (i, align) in [(0, 0.0), (dates.length - 1, 1.0)]) {
      final tp = TextPainter(
        text: TextSpan(
          text: shortDate(dates[i]),
          style: t(11, color: AppColors.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = align == 0 ? left : left + w - tp.width;
      tp.paint(canvas, Offset(x, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(_Painter old) =>
      old.series != series || old.format != format;
}
