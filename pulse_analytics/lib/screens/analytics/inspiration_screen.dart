import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class _Topic {
  const _Topic(this.title, this.count, this.trend, this.colors);
  final String title;
  final String count;

  /// Relative heights of the little trend line, oldest first.
  final List<double> trend;
  final List<Color> colors;
}

const _trending = [
  _Topic(
    "who won the super ballon d'or in 2026",
    '343.0M',
    [.1, .12, .2, .28, .4, .6, .9],
    [Color(0xFF8B6A55), Color(0xFF2B2420)],
  ),
  _Topic(
    'Motif pembunuhan Dwi Bagus Martono',
    '314.8M',
    [.08, .15, .25, .3, .55, .75, 1],
    [Color(0xFF50705A), Color(0xFF111A14)],
  ),
  _Topic(
    'Crowds Attempt to Enter 2026 Ballon d’Or',
    '281.7M',
    [.12, .1, .22, .3, .5, .7, .85],
    [Color(0xFF6E5646), Color(0xFF211A17)],
  ),
  _Topic(
    'CBS Sets Georgie and Mandy Season Premiere',
    '266.0M',
    [.05, .1, .18, .35, .45, .7, .95],
    [Color(0xFF9A7F5E), Color(0xFF3A2C20)],
  ),
  _Topic(
    'Ballon d\'Or 2026 Favorite to Win discussed',
    '191.7M',
    [.2, .22, .3, .45, .55, .8, .9],
    [Color(0xFF3A3A45), Color(0xFF0D0D12)],
  ),
  _Topic(
    'Crowds and Hooligans Disrupt Ballon d’Or',
    '164.8M',
    [.1, .14, .2, .3, .38, .6, .8],
    [Color(0xFFB98B6A), Color(0xFF2E2118)],
  ),
];

const _similar = [
  _Topic(
    'Behind the scenes of a studio shoot',
    '88.2M',
    [.1, .2, .3, .45, .5, .7, .9],
    [Color(0xFF5B6BA8), Color(0xFF14182B)],
  ),
  _Topic(
    'Three-step recipe in 30 seconds',
    '71.4M',
    [.15, .2, .25, .4, .6, .7, .85],
    [Color(0xFFB07A3A), Color(0xFF30200E)],
  ),
  _Topic(
    'Quick workout you can do anywhere',
    '64.9M',
    [.1, .18, .3, .35, .5, .65, .8],
    [Color(0xFF4F8E8C), Color(0xFF0F2423)],
  ),
  _Topic(
    'Before and after room makeover',
    '52.3M',
    [.2, .25, .3, .4, .55, .6, .75],
    [Color(0xFFA26478), Color(0xFF2A141B)],
  ),
];

const _followers = [
  _Topic(
    'Pet reacts to a new toy',
    '120.5M',
    [.1, .15, .3, .4, .6, .8, 1],
    [Color(0xFFB5764F), Color(0xFF2B190E)],
  ),
  _Topic(
    'Street style outfit check',
    '97.1M',
    [.12, .2, .26, .4, .5, .7, .9],
    [Color(0xFF7A5A8E), Color(0xFF1E1426)],
  ),
  _Topic(
    'Small business packing orders',
    '75.6M',
    [.1, .12, .28, .38, .52, .66, .82],
    [Color(0xFF55796B), Color(0xFF111E19)],
  ),
];

class InspirationScreen extends StatefulWidget {
  const InspirationScreen({super.key});

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen> {
  static const _tabs = ['Trending topics', 'Similar posts', 'Followers viewed'];
  static const _hints = [
    'Post on these topics for possible virality.',
    'Posts similar to yours that people are watching.',
    'Posts your followers have recently watched.',
  ];
  static const _lists = [_trending, _similar, _followers];

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final topics = _lists[_tab];
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _RingsPainter()),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creation Inspiration',
                      style: t(20, weight: FontWeight.w700, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    const BodyText('Discover your next big idea!'),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tabs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => PillChip(
                          _tabs[i],
                          i == _tab,
                          () => setState(() => _tab = i),
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    BodyText(_hints[_tab]),
                    const SizedBox(height: 4),
                    for (var i = 0; i < topics.length; i++)
                      _TopicRow(
                        topics[i],
                        i + 1,
                        divider: i < topics.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Faint concentric rings behind the top right of the card.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFF1F1F1);
    final c = Offset(size.width * 0.78, 34);
    for (var i = 1; i <= 7; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 26.0 * i, height: 18.0 * i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}

class _TopicRow extends StatelessWidget {
  const _TopicRow(this.topic, this.rank, {required this.divider});

  final _Topic topic;
  final int rank;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _RankBadge(rank),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t(17.5, weight: FontWeight.w600, height: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.flame,
                          size: 15,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(topic.count, style: t(16, color: AppColors.muted)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 26,
                          height: 13,
                          child: CustomPaint(painter: _Spark(topic.trend)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Thumb(topic.colors),
            ],
          ),
        ),
        if (divider) const Divider(height: 1, thickness: 1, indent: 28),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) {
    final (top, bottom, border, text) = switch (rank) {
      1 => (
        const Color(0xFFFBE27A),
        const Color(0xFFF1C24A),
        const Color(0xFFD9A52B),
        const Color(0xFF8A5A00),
      ),
      2 => (
        const Color(0xFFEDEDED),
        const Color(0xFFD6D6D6),
        const Color(0xFFBDBDBD),
        const Color(0xFF6E6E6E),
      ),
      3 => (
        const Color(0xFFF0C089),
        const Color(0xFFDD9B5A),
        const Color(0xFFBF7B3C),
        const Color(0xFF7A4A1E),
      ),
      _ => (
        const Color(0xFFF6F6F6),
        const Color(0xFFEDEDED),
        const Color(0xFFD7D7D7),
        const Color(0xFF9B9B9B),
      ),
    };
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Text(
        '$rank',
        style: t(12, weight: FontWeight.w800, color: text, height: 1),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.colors);

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 46,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: CustomPaint(painter: _Silhouette(colors.first)),
      ),
    );
  }
}

/// A soft head-and-shoulders shape so the placeholder reads as a video frame.
class _Silhouette extends CustomPainter {
  const _Silhouette(this.tone);

  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(size.width * .5, size.height * .36), 9, paint);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          size.width * .16,
          size.height * .55,
          size.width * .68,
          size.height * .5,
        ),
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_Silhouette old) => old.tone != tone;
}

class _Spark extends CustomPainter {
  const _Spark(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          size.height * (1 - values[i]),
        ),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCBCBCB), Color(0x00CBCBCB)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFB5B5B5),
    );
  }

  @override
  bool shouldRepaint(_Spark old) => false;
}
