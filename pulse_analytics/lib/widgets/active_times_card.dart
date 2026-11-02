import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'ui.dart';

/// "Most active times" card with Hours / Days chips, a day picker and a bar
/// chart. With [hasData] false it shows the empty state instead.
class ActiveTimesCard extends StatefulWidget {
  const ActiveTimesCard({
    super.key,
    required this.hourly,
    required this.weekday,
    required this.hasData,
    required this.subject,
    required this.rangeDays,
    required this.peakDate,
    required this.minDate,
    required this.maxDate,
    this.startDate,
  });

  final List<int> hourly;
  final List<int> weekday;
  final bool hasData;

  /// Plural noun for the sentence and tooltip: "followers" or "viewers".
  final String subject;
  final int rangeDays;

  /// Day the sentence calls out, e.g. the busiest day.
  final DateTime peakDate;
  final DateTime minDate;
  final DateTime maxDate;

  /// Day shown first; defaults to [peakDate].
  final DateTime? startDate;

  @override
  State<ActiveTimesCard> createState() => _ActiveTimesCardState();
}

class _ActiveTimesCardState extends State<ActiveTimesCard> {
  bool _byHour = true;
  late DateTime _date = widget.startDate ?? widget.peakDate;
  int? _picked;

  List<int> get _values => _byHour ? widget.hourly : widget.weekday;

  int get _peak {
    final v = _values;
    return v.indexOf(v.reduce(max));
  }

  bool get _canPrev => _date.isAfter(widget.minDate);
  bool get _canNext => _date.isBefore(widget.maxDate);

  void _shift(int days) =>
      setState(() => _date = _date.add(Duration(days: days)));

  String get _sentence {
    if (!widget.hasData) {
      return 'Information will be displayed when there is enough data.';
    }
    final head =
        'Over the past ${widget.rangeDays} days, '
        'most of your ${widget.subject} were active on ';
    return _byHour
        ? '$head${shortDate(widget.peakDate)} at ${clockLabel(_peak)}.'
        : '$head${weekdayLong[_peak]}s.';
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.hasData ? (_picked ?? _peak) : null;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Most active times'),
          const SizedBox(height: 14),
          Row(
            children: [
              SquareChip(
                'Hours',
                _byHour,
                () => setState(() {
                  _byHour = true;
                  _picked = null;
                }),
              ),
              const SizedBox(width: 8),
              SquareChip(
                'Days',
                !_byHour,
                () => setState(() {
                  _byHour = false;
                  _picked = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.hasData)
            Text(_sentence, style: t(16.5, height: 1.25))
          else
            const SizedBox.shrink(),
          if (widget.hasData) const SizedBox(height: 14),
          _DayPicker(
            label: shortDate(_date),
            onPrev: _canPrev ? () => _shift(-1) : null,
            onNext: _canNext ? () => _shift(1) : null,
          ),
          if (!widget.hasData) ...[
            const SizedBox(height: 8),
            BodyText(_sentence),
          ],
          const SizedBox(height: 14),
          _BarChart(
            values: _values,
            byHour: _byHour,
            empty: !widget.hasData,
            selected: selected,
            subject: widget.subject,
            onSelect: (i) => setState(() => _picked = i),
          ),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.label, this.onPrev, this.onNext});

  final String label;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, VoidCallback? onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 32,
        child: onTap == null
            ? null
            : Icon(icon, size: 20, color: AppColors.text),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        arrow(LucideIcons.chevronLeft, onPrev),
        SizedBox(
          width: 110,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: t(16.5, weight: FontWeight.w500),
          ),
        ),
        arrow(LucideIcons.chevronRight, onNext),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.byHour,
    required this.empty,
    required this.selected,
    required this.subject,
    required this.onSelect,
  });

  final List<int> values;
  final bool byHour;
  final bool empty;
  final int? selected;
  final String subject;
  final ValueChanged<int> onSelect;

  static const _left = 5.0;
  static const _top = 12.0;
  static const _labels = 30.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final right = empty ? 6.0 : 29.0;
        final plotW = c.maxWidth - _left - right;
        const plotH = 130.0;
        final n = values.length;
        final maxVal = values.reduce(max);
        final step = max(1, (maxVal * 1.1 / 4).ceil());
        final slot = byHour ? plotW / n : plotW / n;
        double centerOf(int i) =>
            byHour ? _left + 4 + slot * i : _left + slot * (i + 0.5);
        final barW = byHour ? 8.0 : 16.0;

        Widget? tooltip;
        final sel = selected;
        if (sel != null && !empty) {
          final barTop = _top + plotH - values[sel] / (step * 4) * plotH;
          final name = byHour ? clockLabel(sel) : weekdayLong[sel];
          final noun = values[sel] == 1
              ? subject.substring(0, subject.length - 1)
              : subject;
          const w = 112.0;
          var left = centerOf(sel) + barW / 2 + 10;
          if (left + w > c.maxWidth) left = centerOf(sel) - barW / 2 - 10 - w;
          tooltip = Positioned(
            left: left,
            top: barTop + 12,
            child: Container(
              width: w,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t(14.5, height: 1.25)),
                  const SizedBox(height: 6),
                  Text('${values[sel]} $noun', style: t(14.5, height: 1.25)),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: empty
              ? null
              : (d) {
                  final i = ((d.localPosition.dx - _left) / slot).floor();
                  onSelect(i.clamp(0, n - 1));
                },
          child: SizedBox(
            width: c.maxWidth,
            height: _top + plotH + _labels,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(c.maxWidth, _top + plotH + _labels),
                  painter: _BarPainter(
                    values: values,
                    byHour: byHour,
                    empty: empty,
                    left: _left,
                    top: _top,
                    plotW: plotW,
                    plotH: plotH,
                    step: step,
                    centerOf: centerOf,
                    barW: barW,
                  ),
                ),
                ?tooltip,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.values,
    required this.byHour,
    required this.empty,
    required this.left,
    required this.top,
    required this.plotW,
    required this.plotH,
    required this.step,
    required this.centerOf,
    required this.barW,
  });

  final List<int> values;
  final bool byHour;
  final bool empty;
  final double left, top, plotW, plotH, barW;
  final int step;
  final double Function(int) centerOf;

  static const _hourLabels = {
    0: '12a',
    4: '4a',
    8: '8a',
    12: '12p',
    16: '4p',
    20: '8p',
  };

  void _text(Canvas canvas, String s, Offset anchor, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: t(14, color: AppColors.muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawParagraphAt(tp, anchor, right: right);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final x0 = left, x1 = left + plotW, base = top + plotH;
    final grid = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;

    // Dashed gridlines above a solid baseline: four labelled levels, or three
    // unlabelled ones in the empty state.
    final levels = empty ? 3 : 4;
    for (var k = 1; k <= levels; k++) {
      final y = base - plotH / levels * k;
      for (var x = x0; x < x1; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 3, x1), y), grid);
      }
      if (!empty) {
        _text(canvas, '${step * k}', Offset(size.width, y), right: true);
      }
    }
    if (!empty) _text(canvas, '0', Offset(size.width, base), right: true);
    canvas.drawLine(Offset(x0, base), Offset(x1, base), grid);

    final bar = Paint()..color = AppColors.accent;
    if (!empty) {
      for (var i = 0; i < values.length; i++) {
        if (values[i] <= 0) continue;
        final h = values[i] / (step * 4) * plotH;
        final cx = centerOf(i);
        canvas.drawRect(Rect.fromLTWH(cx - barW / 2, base - h, barW, h), bar);
      }
    }

    // Ticks and labels along the bottom.
    final tick = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    if (byHour) {
      _hourLabels.forEach((h, label) {
        final cx = centerOf(h);
        canvas.drawLine(Offset(cx, base), Offset(cx, base + 5), tick);
        _text(canvas, label, Offset(cx, base + 8), right: false);
      });
    } else {
      for (var i = 0; i < 7; i++) {
        final cx = centerOf(i);
        canvas.drawLine(Offset(cx, base), Offset(cx, base + 5), tick);
        _text(canvas, weekdayNames[i], Offset(cx, base + 8));
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true;
}

extension on Canvas {
  /// Draws [tp] with its horizontal center at [anchor], or its right edge
  /// there and its vertical center on it when [right] is set.
  void drawParagraphAt(TextPainter tp, Offset anchor, {bool right = false}) {
    if (right) {
      tp.paint(this, Offset(anchor.dx - tp.width, anchor.dy - tp.height / 2));
    } else {
      tp.paint(this, Offset(anchor.dx - tp.width / 2, anchor.dy));
    }
  }
}
