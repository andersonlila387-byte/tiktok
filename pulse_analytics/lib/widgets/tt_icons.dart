import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The solid icons TikTok Studio draws in its header (play, comment, share,
/// bookmark, "TikTok Studio" person) and the back arrow and close cross.
/// Painted from paths so they match the app's shapes exactly; Material and
/// Lucide have no icon with the same shapes.
enum TtIcon { play, heart, comment, share, bookmark, person, back, close }

class TtIconView extends StatelessWidget {
  const TtIconView(this.icon, {super.key, required this.color});

  final TtIcon icon;
  final Color color;

  /// Size of the drawing in logical pixels.
  static Size sizeOf(TtIcon icon) => switch (icon) {
    TtIcon.play => const Size(14, 14.5),
    TtIcon.heart => const Size(13.5, 12),
    TtIcon.comment => const Size(16, 15),
    TtIcon.share => const Size(16.5, 14),
    TtIcon.bookmark => const Size(10, 12.5),
    TtIcon.person => const Size(10, 9.5),
    TtIcon.back => const Size(18, 15),
    TtIcon.close => const Size(8.5, 8.5),
  };

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: sizeOf(icon),
      painter: _TtIconPainter(icon, color),
    );
  }
}

class _TtIconPainter extends CustomPainter {
  _TtIconPainter(this.icon, this.color);

  final TtIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    switch (icon) {
      case TtIcon.play:
        // Triangle with rounded corners: filled, then stroked with round joins.
        final path = Path()
          ..moveTo(1.3, 1.3)
          ..lineTo(1.3, size.height - 1.3)
          ..lineTo(size.width - 1.1, size.height / 2)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeJoin = StrokeJoin.round,
        );
      case TtIcon.heart:
        canvas.drawPath(_heart(size), fill);
      case TtIcon.comment:
        _comment(canvas, size, fill);
      case TtIcon.share:
        canvas.drawPath(_share(size), fill);
      case TtIcon.bookmark:
        canvas.drawPath(_bookmark(size), fill);
      case TtIcon.person:
        _person(canvas, size, fill);
      case TtIcon.back:
        final p = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = true;
        final cy = size.height / 2;
        canvas.drawLine(Offset(0.5, cy), Offset(size.width - 0.5, cy), p);
        canvas.drawLine(Offset(0.5, cy), Offset(7.8, cy - 7.2), p);
        canvas.drawLine(Offset(0.5, cy), Offset(7.8, cy + 7.2), p);
      case TtIcon.close:
        final p = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.butt
          ..isAntiAlias = true;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), p);
    }
  }

  Path _heart(Size s) {
    final w = s.width;
    final h = s.height;
    return Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * 0.1, h * 0.72, 0, h * 0.5, 0, h * 0.28)
      ..cubicTo(0, h * 0.1, w * 0.14, 0, w * 0.28, 0)
      ..cubicTo(w * 0.4, 0, w * 0.47, h * 0.08, w / 2, h * 0.2)
      ..cubicTo(w * 0.53, h * 0.08, w * 0.6, 0, w * 0.72, 0)
      ..cubicTo(w * 0.86, 0, w, h * 0.1, w, h * 0.28)
      ..cubicTo(w, h * 0.5, w * 0.9, h * 0.72, w / 2, h)
      ..close();
  }

  void _comment(Canvas canvas, Size s, Paint fill) {
    // A wide round bubble with a short tail, and three white dots.
    final body = Rect.fromLTWH(0, 0, s.width, s.height * 0.8);
    final path = Path()
      ..addOval(body)
      ..moveTo(s.width * 0.42, s.height * 0.72)
      ..lineTo(s.width * 0.55, s.height)
      ..lineTo(s.width * 0.72, s.height * 0.74)
      ..close();
    canvas.drawPath(path, fill);
    final dot = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;
    for (final fx in const [0.27, 0.5, 0.73]) {
      canvas.drawCircle(Offset(s.width * fx, s.height * 0.4), 1.0, dot);
    }
  }

  Path _share(Size s) {
    // Forward arrow: Material's "reply" shape mirrored, scaled to the box.
    final sx = s.width / 18;
    final sy = s.height / 15;
    Offset o(double x, double y) => Offset((x - 3) * sx, (y - 5) * sy);
    final path = Path()
      ..moveTo(o(14, 9).dx, o(14, 9).dy)
      ..lineTo(o(14, 5).dx, o(14, 5).dy)
      ..lineTo(o(21, 12).dx, o(21, 12).dy)
      ..lineTo(o(14, 19).dx, o(14, 19).dy)
      ..lineTo(o(14, 14.9).dx, o(14, 14.9).dy)
      ..cubicTo(
        o(9, 14.9).dx,
        o(9, 14.9).dy,
        o(5.5, 16.5).dx,
        o(5.5, 16.5).dy,
        o(3, 20).dx,
        o(3, 20).dy,
      )
      ..cubicTo(
        o(4, 15).dx,
        o(4, 15).dy,
        o(7, 10).dx,
        o(7, 10).dy,
        o(14, 9).dx,
        o(14, 9).dy,
      )
      ..close();
    return path;
  }

  Path _bookmark(Size s) {
    final w = s.width;
    final h = s.height;
    const r = 1.4;
    return Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h)
      ..lineTo(w / 2, h * 0.72)
      ..lineTo(0, h)
      ..close();
  }

  void _person(Canvas canvas, Size s, Paint fill) {
    // Head and shoulders, with a small star at the lower right.
    canvas.drawCircle(const Offset(3.4, 2.5), 2.4, fill);
    final shoulders = Path()
      ..moveTo(0, 9.2)
      ..lineTo(0, 7.6)
      ..quadraticBezierTo(0, 5.4, 2.3, 5.4)
      ..lineTo(4.5, 5.4)
      ..quadraticBezierTo(6.8, 5.4, 6.8, 7.6)
      ..lineTo(6.8, 9.2)
      ..close();
    canvas.drawPath(shoulders, fill);
    final star = Path();
    const c = Offset(7.6, 7.3);
    const outer = 2.6;
    const inner = 1.1;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, fill);
  }

  @override
  bool shouldRepaint(_TtIconPainter old) =>
      old.icon != icon || old.color != color;
}

/// The "TikTok Studio" app icon: black tile, TikTok note in white with a cyan
/// and a red edge, and a white strip labelled "Studio" under a cyan/red wave.
class StudioLogo extends StatelessWidget {
  const StudioLogo({super.key, this.size = 47});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.13),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter()),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    canvas.drawRect(Offset.zero & s, Paint()..color = Colors.black);

    // Wave: cyan on the left, red on the right, then the white strip.
    final wave = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.5, h * 0.66, w, h * 0.7)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0xFFFE2C55));
    final cyan = Path()
      ..moveTo(0, h * 0.73)
      ..quadraticBezierTo(w * 0.35, h * 0.69, w * 0.6, h * 0.69)
      ..lineTo(w * 0.6, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(cyan, Paint()..color = const Color(0xFF25F4EE));
    final strip = Path()
      ..moveTo(0, h * 0.755)
      ..quadraticBezierTo(w * 0.5, h * 0.69, w, h * 0.735)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(strip, Paint()..color = Colors.white);

    final tp = TextPainter(
      text: TextSpan(
        text: 'Studio',
        style: TextStyle(
          color: Colors.black,
          fontSize: w * 0.19,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.83));

    // The note, drawn three times: cyan (down-left), red (up-right), white.
    void note(Color c, Offset d) {
      final stroke = Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      canvas.save();
      canvas.translate(d.dx, d.dy);
      // Ring of the note head.
      canvas.drawCircle(Offset(w * 0.42, h * 0.5), w * 0.13, stroke);
      // Stem and flag.
      final stem = Path()
        ..moveTo(w * 0.57, h * 0.5)
        ..lineTo(w * 0.57, h * 0.2)
        ..cubicTo(w * 0.6, h * 0.3, w * 0.68, h * 0.34, w * 0.76, h * 0.34);
      canvas.drawPath(stem, stroke);
      canvas.restore();
    }

    note(const Color(0xFF25F4EE), Offset(-w * 0.025, w * 0.025));
    note(const Color(0xFFFE2C55), Offset(w * 0.025, -w * 0.02));
    note(Colors.white, Offset.zero);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}
