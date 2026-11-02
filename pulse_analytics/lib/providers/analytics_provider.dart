import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/analytics_data.dart';
import '../services/storage_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsProvider(
    this._storage, {
    this.fixedToday,
    this.pollInterval = const Duration(seconds: 10),
  });

  static const ranges = [7, 28, 60, 365];

  final StorageService _storage;

  /// How often visitors look for figures the admin changed; null turns it off.
  final Duration? pollInterval;

  /// Overrides the calendar date (used by tests).
  final DateTime? fixedToday;
  AnalyticsData? _data;
  int rangeDays = 7;

  /// Days between the latest data day and the end of the visible window; only
  /// non-zero for a custom range.
  int endOffset = 0;
  bool customRange = false;

  /// Notices the user closed this session.
  bool overviewNoteDismissed = false;
  bool contentNoteDismissed = false;

  Timer? _timer;
  Future<void> _saving = Future.value();
  int _unsaved = 0;

  /// Why the last save failed, shown in the admin screen; null when fine.
  String? syncError;

  bool get loading => _data == null;
  AnalyticsData get data => _data!;

  Future<void> load() async {
    _data = await _storage.load() ?? AnalyticsData.sample();
    notifyListeners();
    final every = pollInterval;
    if (every != null) {
      _timer?.cancel();
      _timer = Timer.periodic(every, (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Picks up figures the admin saved from another device.
  Future<void> _refresh() async {
    // While our own edits are on their way, they are newer than the server.
    if (_unsaved > 0) return;
    final fresh = await _storage.poll();
    if (fresh == null || _unsaved > 0) return;
    _data = fresh;
    notifyListeners();
  }

  Future<bool> login(String pin) => _storage.login(pin);

  /// Throws [StorageException] if the server refuses the reset.
  Future<void> resetToSample() async {
    await _storage.clear();
    _data = AnalyticsData.sample();
    syncError = null;
    notifyListeners();
  }

  void setRange(int days) {
    rangeDays = days;
    endOffset = 0;
    customRange = false;
    notifyListeners();
  }

  /// Shows the inclusive [start]..[end] dates.
  void setCustomRange(DateTime start, DateTime end) {
    final last = lastDataDate;
    final e = DateTime(end.year, end.month, end.day);
    final s = DateTime(start.year, start.month, start.day);
    endOffset = max(0, last.difference(e).inDays);
    rangeDays = max(1, e.difference(s).inDays + 1);
    customRange = true;
    notifyListeners();
  }

  void dismissOverviewNote() {
    overviewNoteDismissed = true;
    notifyListeners();
  }

  void dismissContentNote() {
    contentNoteDismissed = true;
    notifyListeners();
  }

  void _commit() {
    notifyListeners();
    _unsaved++;
    _saving = _saving.then((_) async {
      try {
        await _storage.save(data);
        syncError = null;
      } on StorageException catch (e) {
        syncError = e.message;
      } finally {
        _unsaved--;
      }
      notifyListeners();
    });
  }

  DateTime get today {
    final now = fixedToday ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Newest day with data: analytics lag two days behind the calendar.
  DateTime get lastDataDate => today.subtract(const Duration(days: 2));

  /// Earliest start a custom range can use and still have a baseline day.
  DateTime get earliestDate =>
      lastDataDate.subtract(Duration(days: kHistory - 3));

  /// Dates for the visible window, oldest first.
  List<DateTime> get windowDates {
    final end = lastDataDate.subtract(Duration(days: endOffset));
    return List.generate(
      rangeDays,
      (i) => end.subtract(Duration(days: rangeDays - 1 - i)),
    );
  }

  // ---------------------------------------------------------------- followers

  int get _fEnd => data.followers.length - endOffset;

  List<int> get followerWindow =>
      data.followers.sublist(_fEnd - rangeDays, _fEnd);

  /// Change in followers on each day of the window.
  List<int> get netFollowerWindow {
    final f = data.followers;
    return [for (var i = _fEnd - rangeDays; i < _fEnd; i++) f[i] - f[i - 1]];
  }

  int get totalFollowers => data.followers[_fEnd - 1];

  int get netFollowers =>
      data.followers[_fEnd - 1] - data.followers[_fEnd - rangeDays - 1];

  int? get previousNetFollowers {
    final idx = _fEnd - 2 * rangeDays - 1;
    if (idx < 0) return null;
    return data.followers[_fEnd - rangeDays - 1] - data.followers[idx];
  }

  /// Follower count at the start of the window (what net is measured from).
  int get followersBaseline => data.followers[_fEnd - rangeDays - 1];

  void setTotalFollowers(int value) {
    final diff = value - data.followers[_fEnd - 1];
    data.followers = [for (final f in data.followers) max(0, f + diff)];
    _commit();
  }

  void setNetFollowers(int net) {
    final f = data.followers;
    final end = _fEnd;
    final baseIdx = end - rangeDays - 1;
    final last = f[end - 1];
    final baseOld = f[baseIdx];
    final baseNew = max(0, last - net);
    final shift = baseNew - baseOld;
    final next = List<int>.from(f);
    for (var i = 0; i < baseIdx; i++) {
      next[i] = max(0, f[i] + shift);
    }
    for (var i = baseIdx; i < end; i++) {
      final t = (i - baseIdx) / (end - 1 - baseIdx);
      final v = last == baseOld
          ? baseNew + (last - baseNew) * t
          : baseNew + (f[i] - baseOld) * (last - baseNew) / (last - baseOld);
      next[i] = max(0, v.round());
    }
    next[end - 1] = last;
    data.followers = next;
    _commit();
  }

  void setFollowerWindow(List<int> values) {
    final f = List<int>.from(data.followers);
    f.replaceRange(_fEnd - rangeDays, _fEnd, values.map((v) => max(0, v)));
    data.followers = f;
    _commit();
  }

  // ------------------------------------------------------------------ metrics

  int _mEnd(List<int> s) => s.length - endOffset;

  List<int> metricWindow(String key) {
    final s = data.metrics[key]!;
    final end = _mEnd(s);
    return s.sublist(end - rangeDays, end);
  }

  int metricTotal(String key) => metricWindow(key).fold(0, (a, b) => a + b);

  int? previousMetricTotal(String key) {
    final s = data.metrics[key]!;
    final end = _mEnd(s);
    if (end < 2 * rangeDays) return null;
    return s
        .sublist(end - 2 * rangeDays, end - rangeDays)
        .fold<int>(0, (a, b) => a + b);
  }

  void setMetricTotal(String key, int target) {
    target = max(0, target);
    final w = metricWindow(key);
    final sum = w.fold<int>(0, (a, b) => a + b);
    List<int> next;
    if (sum == 0) {
      next = List.filled(rangeDays, target ~/ rangeDays);
    } else {
      next = [for (final v in w) (v * target / sum).floor()];
    }
    next[next.length - 1] += target - next.fold<int>(0, (a, b) => a + b);
    setMetricWindow(key, next);
  }

  void setMetricWindow(String key, List<int> values) {
    final s = List<int>.from(data.metrics[key]!);
    final end = _mEnd(s);
    s.replaceRange(end - rangeDays, end, values.map((v) => max(0, v)));
    data.metrics[key] = s;
    _commit();
  }

  // ---------------------------------------------------------------- audiences

  void setGender(double male, double female) {
    male = male.clamp(0, 100).toDouble();
    female = female.clamp(0, 100 - male).toDouble();
    data.male = male;
    data.female = female;
    _commit();
  }

  void setAges(Map<String, double> ages) {
    data.ages = ages;
    _commit();
  }

  void setLocations(List<LocationShare> locations) {
    data.locations = locations;
    _commit();
  }

  void setTopWords(List<WordCount> words) {
    words.sort((a, b) => b.count.compareTo(a.count));
    data.topWords = words;
    _commit();
  }

  void setHourly(List<int> values) {
    data.hourly = values.map((v) => max(0, v)).toList();
    _commit();
  }

  void setWeekday(List<int> values) {
    data.weekday = values.map((v) => max(0, v)).toList();
    _commit();
  }
}
