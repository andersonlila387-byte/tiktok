import 'dart:math' as math;

import '../models/analytics_data.dart';

/// Days after which TikTok stops showing the daily chart.
const kChartDays = 365;

/// Daily values drawn on the Overview chart, oldest first.
class MetricSeries {
  MetricSeries(this.dates, this.values);
  final List<DateTime> dates;
  final List<double> values;
}

int _seed(String text) {
  var h = 17;
  for (final c in text.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Whole days between the posting date and [today].
int daysSincePosted(Post post, DateTime today) {
  final posted = DateTime(
    post.postedAt.year,
    post.postedAt.month,
    post.postedAt.day,
  );
  final now = DateTime(today.year, today.month, today.day);
  return now.difference(posted).inDays;
}

/// True while the video is recent enough for the daily chart.
bool chartAvailable(Post post, DateTime today) {
  final d = daysSincePosted(post, today);
  return d >= 0 && d <= kChartDays;
}

/// A believable day-by-day shape for the [metric] tile (0 views, 1 total play
/// time, 2 average watch time, 3 watched full video, 4 new followers) that adds
/// up to the figures the admin entered. The same post always gives the same
/// curve, so it does not change between visits or devices.
MetricSeries metricSeries(Post post, int metric, DateTime today) {
  final since = math.max(0, daysSincePosted(post, today));
  // The whole life of the video so far (at least a week), up to the limit.
  final n = math.min(math.max(since + 1, 7), kChartDays + 1);
  final base = DateTime(today.year, today.month, today.day);
  final dates = [
    for (var i = 0; i < n; i++) base.subtract(Duration(days: n - 1 - i)),
  ];
  final rnd = math.Random(_seed('${post.id}:$metric'));
  // One random wobble per day since posting, oldest first.
  final wobble = [for (var k = 0; k <= since; k++) rnd.nextDouble()];
  // Most views arrive in the first days and fade away.
  final weight = [
    for (var k = 0; k <= since; k++)
      math.exp(-k / 3.5) * (0.75 + 0.5 * wobble[k]) + 0.02,
  ];
  final total = weight.fold<double>(0, (a, b) => a + b);
  // Age in days of each plotted day (negative before the video existed).
  final ages = [for (var i = 0; i < n; i++) since - (n - 1 - i)];

  List<double> spread(double amount) => [
    for (final k in ages) k < 0 ? 0 : amount * weight[k] / total,
  ];

  switch (metric) {
    case 0:
      return MetricSeries(dates, spread(post.views.toDouble()));
    case 1:
      return MetricSeries(dates, spread(post.playTimeSec.toDouble()));
    case 4:
      return MetricSeries(dates, spread(post.newFollowers.toDouble()));
    default:
      final level = metric == 2 ? post.avgWatchSec : post.fullWatchPct;
      return MetricSeries(dates, [
        for (final k in ages) k < 0 ? 0 : level * (0.9 + 0.2 * wobble[k]),
      ]);
  }
}
