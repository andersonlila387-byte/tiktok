import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/analytics_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'admin/admin_screen.dart';
import 'analytics/content_screen.dart';
import 'analytics/followers_screen.dart';
import 'analytics/inspiration_screen.dart';
import 'analytics/live_screen.dart';
import 'analytics/overview_screen.dart';
import 'analytics/viewers_screen.dart';

class AnalyticsShell extends StatefulWidget {
  const AnalyticsShell({super.key});

  @override
  State<AnalyticsShell> createState() => _AnalyticsShellState();
}

class _AnalyticsShellState extends State<AnalyticsShell>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    'Inspiration',
    'Overview',
    'Content',
    'Viewers',
    'Followers',
    'LIVE',
  ];

  /// Tabs that show data for a chosen period.
  static const _rangeTabs = {1, 2, 3, 4};

  late final TabController _controller = TabController(
    length: _tabs.length,
    vsync: this,
    initialIndex: 1,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 56,
        leadingWidth: 56,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft, size: 26),
          onPressed: () => Navigator.maybePop(context),
        ),
        // Long-press the title to reach the admin screen.
        title: GestureDetector(
          onLongPress: () => openAdmin(context),
          child: Text('Analytics', style: t(18, weight: FontWeight.w700)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.only(left: 5),
              labelPadding: const EdgeInsets.symmetric(horizontal: 10.5),
              labelColor: AppColors.text,
              unselectedLabelColor: AppColors.muted,
              labelStyle: t(16.5, weight: FontWeight.w600),
              unselectedLabelStyle: t(16.5, weight: FontWeight.w500),
              indicatorColor: AppColors.text,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              dividerColor: AppColors.border,
              dividerHeight: 1,
              tabs: [for (final tab in _tabs) Tab(text: tab, height: 45)],
            ),
          ),
        ),
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_rangeTabs.contains(_controller.index)) const RangeChips(),
                Expanded(
                  child: TabBarView(
                    controller: _controller,
                    children: const [
                      InspirationScreen(),
                      OverviewScreen(),
                      ContentScreen(),
                      ViewersScreen(),
                      FollowersScreen(),
                      LiveScreen(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
