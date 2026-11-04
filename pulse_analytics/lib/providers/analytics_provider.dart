import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/analytics_data.dart';
import '../services/storage_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsProvider(
    this._storage, {
    this.requestedPostId,
    this.pollInterval = const Duration(seconds: 10),
  });

  final StorageService _storage;

  /// Which video to show (the `?v=` part of the link); null shows the newest.
  final String? requestedPostId;

  /// How often visitors look for figures the admin changed; null turns it off.
  final Duration? pollInterval;

  AnalyticsData? _data;
  Timer? _timer;
  Future<void> _saving = Future.value();
  int _unsaved = 0;

  /// Why the last save failed, shown in the admin screen; null when fine.
  String? syncError;

  bool get loading => _data == null;
  AnalyticsData get data => _data!;

  /// Video picked with "View other posts"; wins over the link's `?v=`.
  String? _selectedId;

  /// The video the visitor is looking at, or null when none was posted yet.
  Post? get post => data.byId(_selectedId ?? requestedPostId);

  /// Switches the page to another video ("View other posts").
  void selectPost(String id) {
    _selectedId = id;
    notifyListeners();
  }

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

  // -------------------------------------------------------------------- admin

  /// Adds [post] as the newest video.
  void addPost(Post post) {
    data.posts.insert(0, post);
    _commit();
  }

  /// Saves changes made to a post already in the list.
  void updatePost(Post post) {
    post.updatedAt = DateTime.now();
    final i = data.posts.indexWhere((p) => p.id == post.id);
    if (i < 0) {
      data.posts.insert(0, post);
    } else {
      data.posts[i] = post;
    }
    _commit();
  }

  void deletePost(String id) {
    data.posts.removeWhere((p) => p.id == id);
    _commit();
  }

  void setInspiration(String list, List<InspirationPost> items) {
    data.inspiration[list] = items;
    _commit();
  }
}
