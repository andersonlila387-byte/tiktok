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
    TtIcon.play => const Size(13.5, 14.5),
    TtIcon.heart => const Size(13.5, 12),
    TtIcon.comment => const Size(16, 15),
    TtIcon.share => const Size(16.5, 15.5),
    TtIcon.bookmark => const Size(10, 12.5),
    TtIcon.person => const Size(9.77, 8.85),
    TtIcon.back => const Size(17, 13.5),
    TtIcon.close => const Size(7.5, 7.5),
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
          ..moveTo(2.3, 1.3)
          ..lineTo(2.3, size.height - 1.3)
          ..lineTo(size.width - 0.1, size.height / 2)
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
        canvas.drawLine(Offset(0.5, cy), Offset(7.0, cy - 6.5), p);
        canvas.drawLine(Offset(0.5, cy), Offset(7.0, cy + 6.5), p);
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

  /// WithIcons "user-star-solid" (MIT, github.com/withevergrow/withicons):
  /// head, shoulders and a star at the lower right, the shape TikTok Studio's
  /// button shows. Artwork spans x 1..22.23 and y 2.76..22 of a 24 box.
  void _person(Canvas canvas, Size s, Paint fill) {
    final k = s.height / 19.24;
    canvas.save();
    canvas.scale(k, k);
    canvas.translate(-1, -2.76);
    for (final d in _userStarSolid) {
      canvas.drawPath(_svgPath(d)..fillType = PathFillType.evenOdd, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TtIconPainter old) =>
      old.icon != icon || old.color != color;
}

/// The official TikTok Studio app icon (the App Store artwork), with the
/// rounded corners the app shows it with.
class StudioLogo extends StatelessWidget {
  const StudioLogo({super.key, this.size = 47});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.13),
      child: Image.asset(
        'assets/brand/studio_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

const _userStarSolid = [
  'm7.92 2.79l-1.04.25l-.8.38l-.56.39l-.72.72l-.5.75l-.38.96l-.14.8V8l.2.96l.3.72l.53.8l.63.65l.8.55l.88.36l1.04.2l.96-.03l.96-.23l.88-.42l.79-.6l.57-.64l.51-.88l.28-.8l.11-.64l.03-.48l-.03-.56l-.14-.72l-.38-.96l-.54-.8l-.73-.72l-.63-.41l-.96-.4l-1.04-.19ZM5.6 14.08l-.72.17l-.48.17l-.64.31l-.56.37l-.87.82l-.33.42l-.38.62l-.28.64l-.21.72l-.11.72l-.02.48l.03 1.68l.17.4l.32.27L2 22l.48-.13l.32-.27l.13-.24l.08-.32l.11-.04h6.16l.12-.04l.06-.08l.04-.16v-4.64l.05-.08l.29-.06l.2-.1l.31-.32l.08-.16l.07-.32l-.1-.48l-.32-.37l-.24-.13l-.24-.05L6.48 14Z',
  'm16.96 11.75l-.32.16l-.23.25l-1.01 2.16l-.12.05l-2.08.23l-.4.12l-.24.17l-.21.31l-.08.32l.05.4l.24.39l1.6 1.48l.08.12l-.46 2.41l.04.24l.1.24l.29.32l.19.1l.32.08l.4-.06l2.16-1.18l2 1.14l.4.1l.32-.04l.24-.11l.24-.21l.14-.22l.09-.32l-.03-.4l-.42-2.08l.06-.12l1.74-1.64l.17-.4l-.04-.48l-.26-.4l-.41-.24l-2.4-.29l-1.09-2.27l-.27-.24l-.24-.1l-.32-.04Z',
];

/// Builds a [Path] from SVG path data made of straight segments
/// (M, L, H, V, Z, absolute or relative), as the icon above uses.
Path _svgPath(String d) {
  final tokens = RegExp(r'[MmLlHhVvZz]|-?(?:\d+\.?\d*|\.\d+)')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  var cmd = 'M';
  var i = 0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'[A-Za-z]').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        x = next();
        y = next();
        sx = x;
        sy = y;
        path.moveTo(x, y);
        cmd = 'L';
      case 'm':
        x += next();
        y += next();
        sx = x;
        sy = y;
        path.moveTo(x, y);
        cmd = 'l';
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'l':
        x += next();
        y += next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'h':
        x += next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'v':
        y += next();
        path.lineTo(x, y);
      case 'Z' || 'z':
        path.close();
        x = sx;
        y = sy;
    }
  }
  return path;
}
