import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/analytics_data.dart';
import '../providers/analytics_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/ui.dart';
import 'admin/admin_screen.dart';
import 'analytics/engagement_screen.dart';
import 'analytics/inspiration_screen.dart';
import 'analytics/overview_screen.dart';
import 'analytics/viewers_screen.dart';

/// One video's analytics: a fixed top bar, a header that scrolls away, and a
/// tab bar that sticks under the top bar once the header has scrolled off.
class AnalyticsShell extends StatefulWidget {
  const AnalyticsShell({super.key});

  @override
  State<AnalyticsShell> createState() => _AnalyticsShellState();
}

class _AnalyticsShellState extends State<AnalyticsShell>
    with SingleTickerProviderStateMixin {
  static const tabs = ['Inspiration', 'Overview', 'Viewers', 'Engagement'];

  late final TabController _controller = TabController(
    length: tabs.length,
    vsync: this,
    initialIndex: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    final post = p.loading ? null : p.post;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
          children: [
            const ColoredBox(
              color: AppColors.topBar,
              child: SafeArea(bottom: false, child: _TopBar()),
            ),
            Expanded(
              child: p.loading
                  ? const Center(child: CircularProgressIndicator())
                  : post == null
                  ? const Center(
                      child: BodyText('No videos have been posted yet.'),
                    )
                  : _VideoPage(post: post, controller: _controller),
            ),
          ],
        ),
    );
  }
}

class _VideoPage extends StatelessWidget {
  const _VideoPage({required this.post, required this.controller});

  final Post post;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _VideoHeader(post: post)),
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverPersistentHeader(
            pinned: true,
            delegate: _TabsDelegate(controller),
          ),
        ),
      ],
      body: TabBarView(
        controller: controller,
        children: [
          const InspirationScreen(key: PageStorageKey('inspiration')),
          OverviewScreen(key: const PageStorageKey('overview'), post: post),
          ViewersScreen(key: const PageStorageKey('viewers'), post: post),
          EngagementScreen(key: const PageStorageKey('engagement'), post: post),
        ],
      ),
    );
  }
}

/// Back arrow, title and the "TikTok Studio" pill. Long-press the title to
/// reach the admin screen.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            padding: const EdgeInsets.symmetric(horizontal: 16),
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            onPressed: () => Navigator.maybePop(context),
          ),
          // The title sits in the middle of the space between the arrow and
          // the "TikTok Studio" label.
          Expanded(
            child: Center(
              child: GestureDetector(
                onLongPress: () => openAdmin(context),
                child: Text(
                  'Video analytics',
                  maxLines: 1,
                  style: t(15, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: AppColors.topBar,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Solid person with a small star, like TikTok's icon.
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.person, size: 14, color: AppColors.text),
                          Positioned(
                            right: -3,
                            bottom: -1,
                            child: Icon(
                              Icons.star,
                              size: 8,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TikTok Studio',
                      style: t(10.5, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cover, posting date and the five headline counts.
class _VideoHeader extends StatelessWidget {
  const _VideoHeader({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final stats = <(Widget, int)>[
      (const Icon(Icons.play_arrow, size: 40), post.views),
      (const Icon(Icons.favorite), post.likes),
      (const Icon(Icons.sms), post.comments),
      (Transform.flip(flipX: true, child: const Icon(Icons.reply)), post.shares),
      (const Icon(Icons.bookmark), post.saves),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 18),
      child: Column(
        children: [
          VideoCover(
            url: post.thumbnailUrl,
            width: 80,
            height: 107,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${plain(post.durationSec)}s',
                  style:
                      t(13, weight: FontWeight.w700, color: Colors.white)
                          .copyWith(
                            shadows: const [
                              Shadow(blurRadius: 3, color: Colors.black54),
                            ],
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Posted on ${postedOn(post.postedAt)}',
            style: t(13, color: const Color(0xFF6C6D72)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        indent: 6,
                        endIndent: 6,
                        color: AppColors.border,
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          IconTheme(
                            data: const IconThemeData(
                              size: 20,
                              color: Color(0xFF8A8B90),
                            ),
                            child: SizedBox(
                              height: 22,
                              child: OverflowBox(
                                maxHeight: 44,
                                child: Center(child: stats[i].$1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            abbr(stats[i].$2),
                            style: t(15, weight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate(this.controller);

  final TabController controller;

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.only(left: 15),
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          labelColor: AppColors.text,
          unselectedLabelColor: AppColors.muted,
          labelStyle: t(14, weight: FontWeight.w600),
          unselectedLabelStyle: t(14, weight: FontWeight.w500),
          indicatorColor: AppColors.text,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.tab,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerColor: AppColors.border,
          dividerHeight: 1,
          tabs: [
            for (final tab in _AnalyticsShellState.tabs)
              Tab(text: tab, height: 45),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsDelegate old) => old.controller != controller;
}
