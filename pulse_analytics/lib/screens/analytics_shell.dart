import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analytics_data.dart';
import '../providers/analytics_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/tt_icons.dart';
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
/// reach the admin screen. The title is centred on the screen, not in the
/// space left between the arrow and the pill.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.maybePop(context),
                child: const Padding(
                  padding: EdgeInsets.only(left: 15.5, right: 24),
                  child: TtIconView(TtIcon.back, color: Colors.black),
                ),
              ),
            ),
          ),
          GestureDetector(
            onLongPress: () => openAdmin(context),
            child: Text(
              'Video analysis',
              maxLines: 1,
              style: t(14.3, weight: FontWeight.w700),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 11),
              child: Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDEDED), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TtIconView(TtIcon.person, color: Colors.black),
                    const SizedBox(width: 3.1),
                    Text(
                      'TikTok Studio',
                      style: t(10, weight: FontWeight.w400),
                    ),
                  ],
                ),
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
    final stats = <(TtIcon, int)>[
      (TtIcon.play, post.views),
      (TtIcon.heart, post.likes),
      (TtIcon.comment, post.comments),
      (TtIcon.share, post.shares),
      (TtIcon.bookmark, post.saves),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12.75),
      child: Column(
        children: [
          VideoCover(
            url: post.thumbnailUrl,
            width: 70,
            height: 93.5,
            radius: 6,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3.5),
                child: Text(
                  '${plain(post.durationSec)}s',
                  style:
                      t(12, weight: FontWeight.w700, color: Colors.white)
                          .copyWith(
                            shadows: const [
                              Shadow(blurRadius: 3, color: Colors.black54),
                            ],
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7.5),
          Text(
            'Posted on ${postedOn(post.postedAt)}',
            style: t(10.05, color: const Color(0xFF555555)),
          ),
          const SizedBox(height: 13.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stats.length; i++)
                  Expanded(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        if (i > 0)
                          const Positioned(
                            left: 0,
                            top: 8.5,
                            child: SizedBox(
                              height: 17.5,
                              child: VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        Column(
                          children: [
                            SizedBox(
                              height: 20,
                              child: Center(
                                child: TtIconView(
                                  stats[i].$1,
                                  color: AppColors.statIcon,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7.5),
                            Text(
                              abbr(stats[i].$2),
                              style: t(
                                11.5,
                                color: AppColors.statNumber,
                                height: 1.2,
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
        ],
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate(this.controller);

  final TabController controller;

  @override
  double get minExtent => 34.25;

  @override
  double get maxExtent => 34.25;

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
          padding: const EdgeInsets.only(left: 13.5),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12.5),
          labelColor: AppColors.text,
          unselectedLabelColor: const Color(0xFF6C6C6C),
          labelStyle: t(12.5, weight: FontWeight.w700),
          unselectedLabelStyle: t(12.8, weight: FontWeight.w500),
          indicatorColor: AppColors.text,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.tab,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerColor: AppColors.tabDivider,
          dividerHeight: 1,
          tabs: [
            for (final tab in _AnalyticsShellState.tabs)
              Tab(text: tab, height: 33.25),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsDelegate old) => old.controller != controller;
}
