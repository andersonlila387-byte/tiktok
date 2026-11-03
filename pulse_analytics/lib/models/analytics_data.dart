/// A label with a count: a country, traffic source, search query or word.
class Tally {
  Tally(this.name, this.count);
  String name;
  int count;

  Map<String, dynamic> toJson() => {'name': name, 'count': count};
  factory Tally.fromJson(Map<String, dynamic> j) =>
      Tally(j['name'] as String, (j['count'] as num).toInt());
}

/// One entry in a "Creation Inspiration" list. [image] and [avatar] are an
/// address or an uploaded picture (a data: link); empty shows a placeholder.
class InspirationPost {
  InspirationPost(
    this.caption,
    this.likes,
    this.author, {
    this.image = '',
    this.avatar = '',
  });
  String caption;
  String likes;
  String author;
  String image;
  String avatar;

  Map<String, dynamic> toJson() => {
    'caption': caption,
    'likes': likes,
    'author': author,
    'image': image,
    'avatar': avatar,
  };
  factory InspirationPost.fromJson(Map<String, dynamic> j) => InspirationPost(
    j['caption'] as String,
    j['likes'] as String,
    j['author'] as String,
    image: j['image'] as String? ?? '',
    avatar: j['avatar'] as String? ?? '',
  );
}

const kAgeGroups = ['18-24', '25-34', '35-44', '45-54', '55+'];

/// Posts need this many views before TikTok shows audience breakdowns. The
/// admin can still fill the figures in earlier; empty ones show the notice.
const kViewsForInsights = 100;

/// Everything shown on one video's analytics page.
class Post {
  Post({
    required this.id,
    required this.caption,
    required this.thumbnailUrl,
    required this.postedAt,
    required this.updatedAt,
    this.durationSec = 30,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.playTimeSec = 0,
    this.avgWatchSec = 0,
    this.fullWatchPct = 0,
    this.newFollowers = 0,
    this.avgWatchedPct = 0,
    this.stopSec = 0,
    this.likePeakSec = 0,
    this.totalViewers = 0,
    this.viewersChange = 0,
    this.newViewers = 0,
    this.followerViewers = 0,
    this.male = 0,
    this.female = 0,
    this.other = 0,
    List<int>? ages,
    List<Tally>? locations,
    List<Tally>? traffic,
    List<Tally>? queries,
    List<Tally>? topWords,
  }) : ages = ages ?? List.filled(kAgeGroups.length, 0),
       locations = locations ?? [],
       traffic = traffic ?? [],
       queries = queries ?? [],
       topWords = topWords ?? [];

  String id;
  String caption;

  /// Address of the cover image; empty shows a plain placeholder.
  String thumbnailUrl;
  DateTime postedAt;

  /// When the admin last changed the figures (shown as "Updated on").
  DateTime updatedAt;
  double durationSec;

  int views, likes, comments, shares, saves;
  int playTimeSec;
  double avgWatchSec;
  double fullWatchPct;
  int newFollowers;

  /// Retention: average share of the video watched, the second where most
  /// viewers stopped, and the second where most viewers liked it.
  double avgWatchedPct;
  double stopSec;
  double likePeakSec;

  int totalViewers;
  int viewersChange;
  int newViewers;
  int followerViewers;

  int male, female, other;
  List<int> ages; // same order as [kAgeGroups]
  List<Tally> locations;
  List<Tally> traffic;
  List<Tally> queries;
  List<Tally> topWords;

  int get genderTotal => male + female + other;
  int get agesTotal => ages.fold(0, (a, b) => a + b);
  int get locationsTotal => locations.fold(0, (a, b) => a + b.count);
  int get trafficTotal => traffic.fold(0, (a, b) => a + b.count);

  int get returningViewers => (totalViewers - newViewers).clamp(0, totalViewers);
  int get nonFollowerViewers =>
      (totalViewers - followerViewers).clamp(0, totalViewers);

  Map<String, dynamic> toJson() => {
    'id': id,
    'caption': caption,
    'thumbnailUrl': thumbnailUrl,
    'postedAt': postedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'durationSec': durationSec,
    'views': views,
    'likes': likes,
    'comments': comments,
    'shares': shares,
    'saves': saves,
    'playTimeSec': playTimeSec,
    'avgWatchSec': avgWatchSec,
    'fullWatchPct': fullWatchPct,
    'newFollowers': newFollowers,
    'avgWatchedPct': avgWatchedPct,
    'stopSec': stopSec,
    'likePeakSec': likePeakSec,
    'totalViewers': totalViewers,
    'viewersChange': viewersChange,
    'newViewers': newViewers,
    'followerViewers': followerViewers,
    'male': male,
    'female': female,
    'other': other,
    'ages': ages,
    'locations': locations.map((e) => e.toJson()).toList(),
    'traffic': traffic.map((e) => e.toJson()).toList(),
    'queries': queries.map((e) => e.toJson()).toList(),
    'topWords': topWords.map((e) => e.toJson()).toList(),
  };

  factory Post.fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    List<Tally> tallies(String k) => [
      for (final e in (j[k] as List? ?? const []))
        Tally.fromJson(e as Map<String, dynamic>),
    ];
    final ages = [
      for (final e in (j['ages'] as List? ?? const [])) (e as num).toInt(),
    ];
    while (ages.length < kAgeGroups.length) {
      ages.add(0);
    }
    return Post(
      id: j['id'] as String,
      caption: j['caption'] as String? ?? '',
      thumbnailUrl: j['thumbnailUrl'] as String? ?? '',
      postedAt: DateTime.tryParse(j['postedAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      durationSec: d('durationSec'),
      views: i('views'),
      likes: i('likes'),
      comments: i('comments'),
      shares: i('shares'),
      saves: i('saves'),
      playTimeSec: i('playTimeSec'),
      avgWatchSec: d('avgWatchSec'),
      fullWatchPct: d('fullWatchPct'),
      newFollowers: i('newFollowers'),
      avgWatchedPct: d('avgWatchedPct'),
      stopSec: d('stopSec'),
      likePeakSec: d('likePeakSec'),
      totalViewers: i('totalViewers'),
      viewersChange: i('viewersChange'),
      newViewers: i('newViewers'),
      followerViewers: i('followerViewers'),
      male: i('male'),
      female: i('female'),
      other: i('other'),
      ages: ages,
      locations: tallies('locations'),
      traffic: tallies('traffic'),
      queries: tallies('queries'),
      topWords: tallies('topWords'),
    );
  }

  /// A blank post, ready for the admin to fill in.
  factory Post.blank() {
    final now = DateTime.now();
    return Post(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      caption: 'New video',
      thumbnailUrl: '',
      postedAt: DateTime(now.year, now.month, now.day, now.hour, now.minute),
      updatedAt: now,
      traffic: [
        for (final n in const [
          'For You',
          'Personal profile',
          'Following',
          'Search',
          'Sound',
          'Hashtag',
        ])
          Tally(n, 0),
      ],
    );
  }
}

class AnalyticsData {
  AnalyticsData({required this.posts, required this.inspiration});

  /// Newest first. Visitors see the first one unless the link names another.
  List<Post> posts;

  /// "trending", "similar" and "followers" lists for the Inspiration tab.
  Map<String, List<InspirationPost>> inspiration;

  Post? byId(String? id) {
    if (posts.isEmpty) return null;
    for (final p in posts) {
      if (p.id == id) return p;
    }
    return posts.first;
  }

  Map<String, dynamic> toJson() => {
    'posts': posts.map((e) => e.toJson()).toList(),
    'inspiration': inspiration.map(
      (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
    ),
  };

  factory AnalyticsData.fromJson(Map<String, dynamic> j) {
    final insp = (j['inspiration'] as Map<String, dynamic>?) ?? const {};
    final fresh = AnalyticsData.sample().inspiration;
    return AnalyticsData(
      posts: [
        for (final e in (j['posts'] as List? ?? const []))
          Post.fromJson(e as Map<String, dynamic>),
      ],
      inspiration: {
        for (final k in fresh.keys)
          k: insp[k] == null
              ? fresh[k]!
              : [
                  for (final e in insp[k] as List)
                    InspirationPost.fromJson(e as Map<String, dynamic>),
                ],
      },
    );
  }

  /// First-run content: one example video and generic inspiration lists.
  factory AnalyticsData.sample() {
    final now = DateTime.now();
    return AnalyticsData(
      posts: [
        Post(
          id: 'sample',
          caption: 'Sample video',
          thumbnailUrl: '',
          postedAt: DateTime(2024, 7, 3, 11, 52),
          updatedAt: now,
          durationSec: 55.87,
          views: 39,
          likes: 6,
          playTimeSec: 383,
          avgWatchSec: 8.5,
          fullWatchPct: 8.89,
          avgWatchedPct: 15,
          stopSec: 2,
          likePeakSec: 2,
          totalViewers: 28,
          viewersChange: 1,
          newViewers: 12,
          followerViewers: 0,
          traffic: [
            for (final n in const [
              'For You',
              'Personal profile',
              'Following',
              'Search',
              'Sound',
              'Hashtag',
            ])
              Tally(n, 0),
          ],
        ),
      ],
      inspiration: {
        'trending': [
          InspirationPost('Morning routine in 30 seconds #fyp', '6M', 'creator_one'),
          InspirationPost('Three quick tips for better lighting', '566.7K', 'studio.tips'),
          InspirationPost('Trying the viral recipe so you do not have to', '5.4M', 'kitchen.diary'),
          InspirationPost('A day in my life as a student', '2.5M', 'campus.life'),
          InspirationPost('Easy room makeover under budget', '440.4K', 'home.ideas'),
        ],
        'similar': [
          InspirationPost('Behind the scenes of a studio shoot', '88.2K', 'studio.tips'),
          InspirationPost('Quick workout you can do anywhere', '64.9K', 'fit.daily'),
          InspirationPost('Before and after makeover', '52.3K', 'home.ideas'),
        ],
        'followers': [
          InspirationPost('Pet reacts to a new toy', '120.5K', 'pet.world'),
          InspirationPost('Street style outfit check', '97.1K', 'style.walk'),
        ],
      },
    );
  }
}
