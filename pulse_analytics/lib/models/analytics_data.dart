import 'dart:math';

/// Days of history kept per series: two full 365-day windows plus one baseline
/// point so net change and previous-period comparisons work for every range.
const int kHistory = 731;

class LocationShare {
  LocationShare(this.name, this.percent);
  String name;
  double percent;

  Map<String, dynamic> toJson() => {'name': name, 'percent': percent};
  factory LocationShare.fromJson(Map<String, dynamic> j) =>
      LocationShare(j['name'] as String, (j['percent'] as num).toDouble());
}

class WordCount {
  WordCount(this.word, this.count);
  String word;
  int count;

  Map<String, dynamic> toJson() => {'word': word, 'count': count};
  factory WordCount.fromJson(Map<String, dynamic> j) =>
      WordCount(j['word'] as String, (j['count'] as num).toInt());
}

class AnalyticsData {
  AnalyticsData({
    required this.topWords,
    required this.followers,
    required this.metrics,
    required this.male,
    required this.female,
    required this.ages,
    required this.locations,
    required this.hourly,
    required this.weekday,
    required this.viewerHourly,
    required this.viewerWeekday,
    required this.traffic,
    required this.queries,
    required this.dashMetrics,
  });

  /// Cumulative follower count per day, oldest first, length [kHistory].
  List<int> followers;

  /// Daily values per metric name, oldest first, length [kHistory] - 1.
  Map<String, List<int>> metrics;

  double male;
  double female;
  double get other => max(0, 100 - male - female);

  Map<String, double> ages;
  List<LocationShare> locations;
  List<int> hourly; // 24 values, active followers
  List<int> weekday; // 7 values, Mon..Sun

  /// Same shapes as [hourly] and [weekday], for the viewers tab.
  List<int> viewerHourly;
  List<int> viewerWeekday;

  /// Traffic source shares, shown once there are post views.
  List<LocationShare> traffic;

  /// Search queries with their traffic counts.
  List<WordCount> queries;

  /// Metrics that show "-" instead of a number on the overview.
  List<String> dashMetrics;

  /// Most frequent words in comments, highest count first.
  List<WordCount> topWords;

  Map<String, dynamic> toJson() => {
    'topWords': topWords.map((e) => e.toJson()).toList(),
    'followers': followers,
    'metrics': metrics,
    'male': male,
    'female': female,
    'ages': ages,
    'locations': locations.map((e) => e.toJson()).toList(),
    'hourly': hourly,
    'weekday': weekday,
    'viewerHourly': viewerHourly,
    'viewerWeekday': viewerWeekday,
    'traffic': traffic.map((e) => e.toJson()).toList(),
    'queries': queries.map((e) => e.toJson()).toList(),
    'dashMetrics': dashMetrics,
  };

  factory AnalyticsData.fromJson(Map<String, dynamic> j) => AnalyticsData(
    topWords: (j['topWords'] as List)
        .map((e) => WordCount.fromJson(e as Map<String, dynamic>))
        .toList(),
    followers: (j['followers'] as List).cast<int>(),
    metrics: (j['metrics'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List).cast<int>()),
    ),
    male: (j['male'] as num).toDouble(),
    female: (j['female'] as num).toDouble(),
    ages: (j['ages'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
    locations: (j['locations'] as List)
        .map((e) => LocationShare.fromJson(e as Map<String, dynamic>))
        .toList(),
    hourly: (j['hourly'] as List).cast<int>(),
    weekday: (j['weekday'] as List).cast<int>(),
    viewerHourly: (j['viewerHourly'] as List).cast<int>(),
    viewerWeekday: (j['viewerWeekday'] as List).cast<int>(),
    traffic: (j['traffic'] as List)
        .map((e) => LocationShare.fromJson(e as Map<String, dynamic>))
        .toList(),
    queries: (j['queries'] as List)
        .map((e) => WordCount.fromJson(e as Map<String, dynamic>))
        .toList(),
    dashMetrics: (j['dashMetrics'] as List).cast<String>(),
  );

  /// Starting figures: a brand-new account, so most numbers are zero.
  factory AnalyticsData.sample() {
    List<int> zeros(int n) => List.filled(n, 0);
    final metrics = <String, List<int>>{
      for (final k in const [
        'Post views',
        'Total play time',
        'Profile views',
        'Likes',
        'Comments',
        'Shares',
        'Saves',
        'New followers',
        'Est. rewards',
        'Total viewers',
        'New viewers',
      ])
        k: zeros(kHistory - 1),
    };
    // One profile view ten days before the latest day, so the previous 7-day
    // period has one more than the current one.
    metrics['Profile views']![kHistory - 1 - 10] = 1;
    return AnalyticsData(
      topWords: [],
      followers: List.filled(kHistory, 120),
      metrics: metrics,
      male: 56,
      female: 44,
      ages: {
        '18-24': 35.2,
        '25-34': 33.1,
        '35-44': 18.4,
        '45-54': 8.5,
        '55+': 4.8,
      },
      locations: [
        LocationShare('United States', 38.4),
        LocationShare('United Kingdom', 12.2),
        LocationShare('Canada', 8.6),
        LocationShare('Germany', 5.1),
        LocationShare('Australia', 3.4),
      ],
      hourly: [10, ...zeros(23)],
      weekday: [0, 0, 0, 0, 0, 0, 10],
      viewerHourly: zeros(24),
      viewerWeekday: zeros(7),
      traffic: [
        LocationShare('For You', 78.4),
        LocationShare('Personal profile', 9.1),
        LocationShare('Following', 6.0),
        LocationShare('Search', 3.2),
        LocationShare('Sound', 2.1),
        LocationShare('Hashtag', 1.2),
      ],
      queries: [],
      dashMetrics: ['Comments'],
    );
  }
}
