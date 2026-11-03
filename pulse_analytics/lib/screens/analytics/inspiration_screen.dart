import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/analytics_data.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_upload.dart';
import '../../widgets/tab_page.dart';
import '../../widgets/ui.dart';

class InspirationScreen extends StatefulWidget {
  const InspirationScreen({super.key});

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen>
    with AutomaticKeepAliveClientMixin {
  static const _tabs = ['Trending posts', 'Similar posts', 'Followers viewed'];
  static const _keys = ['trending', 'similar', 'followers'];
  static const _hints = [
    'Post videos like these for possible virality.',
    'Posts similar to yours that people are watching.',
    'Posts your followers have recently watched.',
  ];

  int _tab = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final posts =
        context.watch<AnalyticsProvider>().data.inspiration[_keys[_tab]] ??
        const <InspirationPost>[];
    return TabPage(
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(3),
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
                      style: t(18, weight: FontWeight.w700, height: 1.2),
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    BodyText(_hints[_tab]),
                    const SizedBox(height: 12),
                    for (var i = 0; i < posts.length; i++)
                      _PostRow(posts[i], i + 1),
                    const SizedBox(height: 4),
                    const _MoreButton(),
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

class _PostRow extends StatelessWidget {
  const _PostRow(this.post, this.rank);

  final InspirationPost post;
  final int rank;

  /// Stable colour pair per post, so the placeholder cover keeps its look.
  List<Color> get _colors {
    final h = post.caption.hashCode.abs() % 360;
    return [
      HSLColor.fromAHSL(1, h.toDouble(), 0.30, 0.45).toColor(),
      HSLColor.fromAHSL(1, h.toDouble(), 0.35, 0.14).toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            _RankBadge(rank),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 66,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _colors,
                  ),
                  image: post.image.trim().isEmpty
                      ? null
                      : DecorationImage(
                          image: pictureProvider(post.image),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    post.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t(15, weight: FontWeight.w500, height: 1.25),
                  ),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.heart,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.likes,
                        style: t(14, color: AppColors.muted),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: _colors.first,
                        backgroundImage: post.avatar.trim().isEmpty
                            ? null
                            : pictureProvider(post.avatar),
                        onBackgroundImageError: post.avatar.trim().isEmpty
                            ? null
                            : (_, _) {},
                        child: post.avatar.trim().isNotEmpty
                            ? null
                            : Text(
                                post.author.isEmpty
                                    ? ''
                                    : post.author[0].toUpperCase(),
                                style: t(
                                  10,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(14, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      width: 18,
      height: 18,
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
        style: t(11, weight: FontWeight.w800, color: text, height: 1),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.lightbulb, size: 17),
          const SizedBox(width: 6),
          Text('Get more inspiration', style: t(15, weight: FontWeight.w500)),
        ],
      ),
    );
  }
}
