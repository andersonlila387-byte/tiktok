import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 78, 32, 24),
      children: [
        const Center(
          child: SizedBox(
            width: 215,
            height: 110,
            child: CustomPaint(painter: _ElephantPainter()),
          ),
        ),
        const SizedBox(height: 46),
        Text(
          'Explore new LIVE Analytics',
          style: t(25, weight: FontWeight.w700, height: 1.2),
        ),
        const SizedBox(height: 48),
        _Feature(
          icon: const Icon(LucideIcons.squarePlay, size: 22),
          title: 'New location',
          body: TextSpan(
            children: [
              const TextSpan(
                text: 'Find LIVE Analytics and other features in ',
              ),
              TextSpan(
                text: 'Creator tools > LIVE Center',
                style: t(16, weight: FontWeight.w700, height: 1.2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _Feature(
          icon: const Icon(LucideIcons.calendar, size: 22),
          title: 'Longer time periods',
          body: const TextSpan(
            text: 'View up to 60 days of analytics to discover more trends',
          ),
        ),
        const SizedBox(height: 26),
        _Feature(
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: _BlockArrow()),
          ),
          title: 'Upgraded metrics',
          body: const TextSpan(
            text:
                'Learn about your engagement and how viewers are '
                'discovering your LIVE',
          ),
        ),
        const SizedBox(height: 56),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Go to LIVE Center',
              style: t(17.5, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final Widget icon;
  final String title;
  final TextSpan body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: icon),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t(18, weight: FontWeight.w600, height: 1.2)),
              const SizedBox(height: 6),
              Text.rich(
                body,
                style: t(16, color: AppColors.muted, height: 1.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Solid up arrow used for "Upgraded metrics".
class _BlockArrow extends CustomPainter {
  const _BlockArrow();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * .5, 0)
      ..lineTo(w * .98, h * .5)
      ..lineTo(w * .68, h * .5)
      ..lineTo(w * .68, h)
      ..lineTo(w * .32, h)
      ..lineTo(w * .32, h * .5)
      ..lineTo(w * .02, h * .5)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.text);
  }

  @override
  bool shouldRepaint(_BlockArrow old) => false;
}

/// Elephant presenting a chart on an easel.
class _ElephantPainter extends CustomPainter {
  const _ElephantPainter();

  static const _ink = Color(0xFF5237E6);
  static const _teal = Color(0xFF6FE4DF);
  static const _pink = Color(0xFFEE6A6E);

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 430 x 220 grid.
    canvas.scale(size.width / 430, size.height / 220);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    final fill = Paint()..color = _teal;

    // Sparkle.
    final spark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFD43B);
    canvas.drawLine(const Offset(18, 54), const Offset(18, 86), spark);
    canvas.drawLine(const Offset(2, 70), const Offset(34, 70), spark);

    // Easel legs and board.
    canvas.drawLine(const Offset(124, 160), const Offset(104, 208), stroke);
    canvas.drawLine(const Offset(146, 158), const Offset(160, 208), stroke);
    final board = Path()
      ..moveTo(94, 14)
      ..lineTo(194, 6)
      ..lineTo(200, 152)
      ..lineTo(92, 160)
      ..close();
    canvas.drawPath(board, stroke);
    final chart = Path()
      ..moveTo(66, 136)
      ..lineTo(106, 76)
      ..lineTo(130, 102)
      ..lineTo(166, 40);
    canvas.drawPath(chart, stroke);
    canvas.drawLine(const Offset(166, 40), const Offset(148, 46), stroke);
    canvas.drawLine(const Offset(166, 40), const Offset(168, 58), stroke);

    // Body and head as one outline.
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(236, 86, 148, 124),
          const Radius.circular(46),
        ),
      );
    final head = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(302, 62), width: 156, height: 104),
      );
    final elephant = Path.combine(PathOperation.union, body, head);

    // Trunk (tube) reaching toward the board.
    final trunk = Path()
      ..moveTo(240, 70)
      ..cubicTo(212, 82, 200, 104, 176, 102);
    canvas.drawPath(trunk, stroke..strokeWidth = 26);
    canvas.drawPath(
      trunk,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round
        ..color = _teal,
    );
    stroke.strokeWidth = 5;

    canvas.drawPath(elephant, fill);
    canvas.drawPath(elephant, stroke);

    // Ear.
    final ear = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(352, 96), width: 52, height: 78),
      );
    canvas.drawPath(ear, fill);
    canvas.drawPath(ear, stroke..strokeWidth = 4.5);
    stroke.strokeWidth = 5;

    // Closed eyes.
    for (final x in [268.0, 308.0]) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, 48), width: 22, height: 18),
        0.2,
        2.7,
        false,
        stroke..strokeWidth = 4,
      );
    }
    stroke.strokeWidth = 5;

    // Belly patch.
    final belly = Rect.fromCenter(
      center: const Offset(290, 160),
      width: 62,
      height: 54,
    );
    canvas.drawOval(belly, Paint()..color = _pink);
    canvas.drawOval(belly, stroke..strokeWidth = 4.5);
    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(280, 152), 5, dot);
    canvas.drawCircle(const Offset(299, 165), 4, dot);
    canvas.drawCircle(const Offset(282, 172), 3, dot);
    stroke.strokeWidth = 5;

    // Legs and tail.
    canvas.drawLine(const Offset(318, 196), const Offset(318, 210), stroke);
    final tail = Path()
      ..moveTo(382, 150)
      ..cubicTo(398, 148, 398, 164, 386, 166);
    canvas.drawPath(tail, stroke..strokeWidth = 4);
    stroke.strokeWidth = 5;

    // Motion lines.
    canvas.drawLine(const Offset(404, 60), const Offset(428, 55), stroke);
    canvas.drawLine(const Offset(406, 88), const Offset(422, 90), stroke);
    canvas.drawLine(const Offset(396, 112), const Offset(414, 122), stroke);
  }

  @override
  bool shouldRepaint(_ElephantPainter old) => false;
}
