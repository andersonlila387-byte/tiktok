import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pulse_analytics/app.dart';
import 'package:pulse_analytics/models/analytics_data.dart';
import 'package:pulse_analytics/providers/analytics_provider.dart';
import 'package:pulse_analytics/screens/admin/inspiration_editor_screen.dart';
import 'package:pulse_analytics/screens/admin/post_editor_screen.dart';
import 'package:pulse_analytics/services/storage_service.dart';
import 'package:pulse_analytics/widgets/metric_chart.dart';
import 'package:pulse_analytics/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _notice = 'Data will be shown when this video reaches 100 views.';

void main() {
  setUp(() {
    useBrandFont = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<AnalyticsProvider> pump(
    WidgetTester tester,
    Size size, {
    void Function(AnalyticsData)? seed,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = AnalyticsProvider(LocalStorageService(), pollInterval: null);
    await p.load();
    p.data.posts.first.postedAt = DateTime(2024, 7, 3, 11, 52);
    if (seed != null) seed(p.data);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const PulseApp()),
    );
    await tester.pumpAndSettle();
    return p;
  }

  Future<void> openTab(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.text(name).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).first);
    await tester.pumpAndSettle();
  }

  for (final w in [360.0, 390.0, 430.0]) {
    testWidgets('header and overview render at ${w.toInt()}px', (tester) async {
      await pump(tester, Size(w, 900));
      expect(find.text('Video analysis'), findsOneWidget);
      expect(find.text('TikTok Studio'), findsOneWidget);
      expect(find.text('55.87s'), findsOneWidget);
      expect(find.text('Posted on Jul 3, 2024, 11:52 AM'), findsOneWidget);
      for (final tab in ['Inspiration', 'Overview', 'Viewers', 'Engagement']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('Key metrics'), findsOneWidget);
      expect(find.text('Video views'), findsOneWidget);
      expect(find.text('0h:06m:23s'), findsOneWidget);
      expect(find.text('8.5s'), findsOneWidget);
      expect(find.text('8.89%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tab bar sticks under the top bar when the page scrolls', (
    tester,
  ) async {
    await pump(tester, const Size(390, 700));
    final tabs = find.text('Overview');
    final before = tester.getTopLeft(tabs).dy;
    expect(before, greaterThan(200), reason: 'tabs start below the header');

    await tester.drag(find.text('Key metrics'), const Offset(0, -600));
    await tester.pumpAndSettle();

    // The cover and counts have scrolled away; the tabs stayed put.
    expect(find.text('Posted on Jul 3, 2024, 11:52 AM'), findsNothing);
    final after = tester.getTopLeft(tabs).dy;
    expect(after, lessThan(90));
    expect(after, greaterThanOrEqualTo(56));
    expect(find.text('Overview').hitTestable(), findsOneWidget);
  });

  testWidgets('inspiration lists the trending posts', (tester) async {
    await pump(tester, const Size(390, 900));
    await openTab(tester, 'Inspiration');
    expect(find.text('Creation Inspiration'), findsOneWidget);
    expect(find.text('Trending posts'), findsOneWidget);
    expect(
      find.text('Post videos like these for possible virality.'),
      findsOneWidget,
    );
    expect(find.text('Fresh ingredients for dinner tonight #fyp'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('viewers shows notices until the admin adds figures', (
    tester,
  ) async {
    await pump(
      tester,
      const Size(390, 1200),
      seed: (d) => d.posts.first.totalViewers = 0,
    );
    await openTab(tester, 'Viewers');
    expect(find.text('Total viewers'), findsOneWidget);
    expect(find.text('Viewer types'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text(_notice), findsWidgets);
  });

  testWidgets('viewers shows admin-entered counts as percentages', (
    tester,
  ) async {
    await pump(
      tester,
      const Size(390, 1600),
      seed: (d) => d.posts.first
        ..totalViewers = 28
        ..viewersChange = 1
        ..newViewers = 12
        ..female = 5
        ..other = 2
        ..ages = [3, 2, 1, 1, 0],
    );
    await openTab(tester, 'Viewers');
    expect(find.text('28'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('(vs 1d ago)'), findsOneWidget);
    expect(find.text('43%'), findsWidgets); // new viewers 12 of 28
    expect(find.text('57%'), findsWidgets);
    expect(find.text('71%'), findsOneWidget); // 5 of 7 are female
    expect(find.text('29%'), findsNWidgets(2)); // other 2 of 7, age 2 of 7
    expect(find.text('Female'), findsOneWidget);
  });

  testWidgets('engagement shows the likes moment and top words', (
    tester,
  ) async {
    await pump(
      tester,
      const Size(390, 1200),
      seed: (d) => d.posts.first.topWords = [Tally('wow', 4)],
    );
    await openTab(tester, 'Engagement');
    expect(find.text('Top words used in comments'), findsOneWidget);
    expect(find.text('wow · 4'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
    expect(
      find.textContaining('Most viewers liked this video at 0:02.'),
      findsOneWidget,
    );
  });

  testWidgets('admin can add a post with numbers', (tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = AnalyticsProvider(LocalStorageService(), pollInterval: null);
    await p.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: PostEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> fill(String label, String text) async {
      final f = find.widgetWithText(TextField, label);
      await tester.ensureVisible(f);
      await tester.enterText(f, text);
    }

    await fill('Caption', 'Lions');
    await fill('Views', '39');
    await fill('Female', '5');
    await fill('Other', '2');
    await fill('Locations', 'Nigeria, 4\nGhana, 3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = p.data.posts.first;
    expect(saved.caption, 'Lions');
    expect(saved.views, 39);
    expect(saved.female, 5);
    expect(saved.other, 2);
    expect(saved.male, 0);
    expect(saved.locations.map((e) => e.name), ['Nigeria', 'Ghana']);
    expect(p.data.posts.length, 2);
  });

  testWidgets('admin can add an inspiration post and see uploaded pictures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = AnalyticsProvider(LocalStorageService(), pollInterval: null);
    await p.load();
    final before = p.data.inspiration['trending']!.length;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(
          home: InspirationEditorScreen(
            listKey: 'trending',
            title: 'Trending posts',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cover picture'), findsNWidgets(before));
    expect(find.text('Replace'), findsWidgets);

    await tester.tap(find.text('Add a post'));
    await tester.pumpAndSettle();
    final captions = find.widgetWithText(TextFormField, 'Caption');
    await tester.ensureVisible(captions.last);
    await tester.enterText(captions.last, 'Brand new post');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final list = p.data.inspiration['trending']!;
    expect(list.length, before + 1);
    expect(list.last.caption, 'Brand new post');
  });

  testWidgets('an uploaded picture shows on the video header', (tester) async {
    // A 1x1 transparent PNG, as an upload would be saved.
    const png =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    await pump(tester, const Size(390, 900), seed: (d) {
      d.posts.first.thumbnailUrl = png;
    });
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview shows a real chart for a recent post only', (
    tester,
  ) async {
    await pump(
      tester,
      const Size(390, 1400),
      seed: (d) => d.posts.first.postedAt = DateTime.now().subtract(
        const Duration(days: 3),
      ),
    );
    expect(find.byType(MetricChart), findsOneWidget);
    await tester.tap(find.text('Total play time'));
    await tester.pumpAndSettle();
    expect(find.byType(MetricChart), findsOneWidget);
    expect(
      find.textContaining('Data chart is only shown for 365 days'),
      findsOneWidget,
    );
  });

  testWidgets('no chart once the post is older than 365 days', (tester) async {
    await pump(tester, const Size(390, 1400));
    expect(find.byType(MetricChart), findsNothing);
    expect(
      find.textContaining('Data chart is only shown for 365 days'),
      findsOneWidget,
    );
  });

  testWidgets('promote card and view other posts switch the video', (
    tester,
  ) async {
    final p = await pump(
      tester,
      const Size(390, 2600),
      seed: (d) => d.posts.add(
        Post.blank()
          ..id = 'second'
          ..caption = 'Second video',
      ),
    );
    expect(find.text('Want more traffic?'), findsOneWidget);
    expect(find.text('Use Promote to grow your audience.'), findsOneWidget);
    expect(find.text('View other posts'), findsOneWidget);
    await tester.tap(find.text('View other posts'));
    await tester.pumpAndSettle();
    expect(find.text('Your posts'), findsOneWidget);
    await tester.tap(find.text('Second video'));
    await tester.pumpAndSettle();
    expect(p.post!.id, 'second');
  });

  testWidgets('a post from months ago still gets a chart', (tester) async {
    await pump(
      tester,
      const Size(390, 1400),
      seed: (d) {
        d.posts.first
          ..postedAt = DateTime.now().subtract(const Duration(days: 150))
          ..views = 39;
      },
    );
    expect(find.byType(MetricChart), findsOneWidget);
  });

  testWidgets('a recent post with no views still shows its chart', (
    tester,
  ) async {
    await pump(
      tester,
      const Size(390, 1400),
      seed: (d) {
        d.posts.first
          ..postedAt = DateTime.now().subtract(const Duration(days: 2))
          ..views = 0;
      },
    );
    expect(find.byType(MetricChart), findsOneWidget);
  });
}
