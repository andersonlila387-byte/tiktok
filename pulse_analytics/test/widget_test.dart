import 'dart:ui' show Size;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pulse_analytics/app.dart';
import 'package:pulse_analytics/providers/analytics_provider.dart';
import 'package:pulse_analytics/services/storage_service.dart';
import 'package:pulse_analytics/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    useBrandFont = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<AnalyticsProvider> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = AnalyticsProvider(LocalStorageService(),
        pollInterval: null,
        fixedToday: DateTime(2026, 11, 2))
      ..load();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: p,
      child: const PulseApp(),
    ));
    await tester.pumpAndSettle();
    return p;
  }

  /// The scrollable page that contains [anchor].
  Finder pageOf(String anchor) => find
      .ancestor(of: find.text(anchor), matching: find.byType(Scrollable))
      .first;

  Future<void> openTab(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.text(name).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).first);
    await tester.pumpAndSettle();
  }

  for (final w in [360.0, 390.0, 430.0]) {
    testWidgets('overview renders at ${w.toInt()}px', (tester) async {
      await pump(tester, Size(w, 900));
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Key metrics'), findsOneWidget);
      expect(find.text('Oct 25 - Oct 31'), findsOneWidget);
      expect(find.text('Post views'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
      expect(find.text('-1 (-100%)'), findsOneWidget);
      expect(find.text(r'+$0.00'), findsOneWidget);
    });
  }

  testWidgets('overview lower cards and dismissable note', (tester) async {
    await pump(tester, const Size(390, 900));
    final list = pageOf('Key metrics');
    await tester.scrollUntilVisible(find.text('Want more traffic?'), 300,
        scrollable: list);
    expect(find.text('Traffic source'), findsOneWidget);
    expect(find.text('Search queries'), findsOneWidget);
    expect(find.text('Update to "For your inspiration"'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('Update to "For your inspiration"'), findsNothing);
  });

  testWidgets('inspiration lists trending topics', (tester) async {
    await pump(tester, const Size(390, 900));
    await openTab(tester, 'Inspiration');
    expect(find.text('Creation Inspiration'), findsOneWidget);
    expect(find.text('Trending topics'), findsOneWidget);
    expect(find.text("who won the super ballon d'or in 2026"), findsOneWidget);
    expect(find.text('343.0M'), findsOneWidget);
    // The period chips only belong to the data tabs.
    expect(find.text('7 days'), findsNothing);
  });

  testWidgets('content shows the empty state', (tester) async {
    await pump(tester, const Size(390, 900));
    await openTab(tester, 'Content');
    expect(find.text('Update to “Posts”'), findsOneWidget);
    expect(find.text('Your top posts'), findsOneWidget);
    expect(find.text('Most views'), findsOneWidget);
    expect(find.text('No top posts'), findsOneWidget);
  });

  testWidgets('viewers show placeholders without data', (tester) async {
    await pump(tester, const Size(390, 900));
    await openTab(tester, 'Viewers');
    expect(find.text('Total viewers'), findsOneWidget);
    expect(find.text('0 (0%)'), findsNWidgets(2));
    expect(find.text('Viewer insights'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Posts your viewers also viewed'), 300,
        scrollable: pageOf('Viewer insights'));
    expect(find.text('Most active times'), findsOneWidget);
    expect(find.text('Oct 27'), findsOneWidget);
    expect(
      find.text('Information will be displayed when there is enough data.'),
      findsOneWidget,
    );
  });

  testWidgets('followers show totals, gender and active times',
      (tester) async {
    await pump(tester, const Size(390, 900));
    await openTab(tester, 'Followers');
    expect(find.text('Total followers'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('Follower insights'), findsOneWidget);
    expect(find.text('56%'), findsOneWidget);
    expect(find.text('44%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Most active times'), 300,
        scrollable: pageOf('Follower insights'));
    expect(
      find.text('Over the past 7 days, most of your followers were active on '
          'Nov 1 at 12am.'),
      findsOneWidget,
    );
    expect(find.text('10 followers'), findsOneWidget);
  });

  testWidgets('live tab explains the move', (tester) async {
    await pump(tester, const Size(390, 1400));
    await openTab(tester, 'LIVE');
    expect(find.text('Explore new LIVE Analytics'), findsOneWidget);
    expect(find.text('New location'), findsOneWidget);
    expect(find.text('Go to LIVE Center'), findsOneWidget);
  });

  testWidgets('range chips change the window', (tester) async {
    final p = await pump(tester, const Size(390, 900));
    await tester.tap(find.text('28 days'));
    await tester.pumpAndSettle();
    expect(p.rangeDays, 28);
    await tester.tap(find.text('60 days'));
    await tester.pumpAndSettle();
    expect(p.rangeDays, 60);
    p.setRange(365);
    await tester.pumpAndSettle();
    expect(p.followerWindow.length, 365);
    expect(p.previousMetricTotal('Likes'), isNotNull);
  });

  testWidgets('custom range ends on the chosen day', (tester) async {
    final p = await pump(tester, const Size(390, 900));
    p.setCustomRange(DateTime(2026, 10, 1), DateTime(2026, 10, 10));
    await tester.pumpAndSettle();
    expect(p.customRange, isTrue);
    expect(p.rangeDays, 10);
    expect(p.windowDates.first, DateTime(2026, 10, 1));
    expect(p.windowDates.last, DateTime(2026, 10, 10));
    expect(p.followerWindow.length, 10);
  });

  testWidgets('admin needs the PIN and then edits figures', (tester) async {
    final p = await pump(tester, const Size(390, 900));
    await tester.longPress(find.text('Analytics'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();
    expect(find.text('Metrics'), findsOneWidget);

    await tester.tap(find.text('Likes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '22500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(p.metricTotal('Likes'), 22500);
  });

  testWidgets('editing figures updates them', (tester) async {
    final p = await pump(tester, const Size(390, 900));
    p.setMetricTotal('Likes', 22500);
    expect(p.metricTotal('Likes'), 22500);
    p.setTotalFollowers(12345);
    expect(p.totalFollowers, 12345);
    expect(p.followerWindow.last, 12345);
    final total = p.totalFollowers;
    p.setNetFollowers(50);
    expect(p.netFollowers, 50);
    expect(p.totalFollowers, total);
  });
}
