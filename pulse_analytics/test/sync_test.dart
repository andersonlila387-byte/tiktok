import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_analytics/models/analytics_data.dart';
import 'package:pulse_analytics/providers/analytics_provider.dart';
import 'package:pulse_analytics/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal stand-in for server/server.js with the same contract.
class FakeServer {
  Map<String, dynamic>? saved;
  int version = 0;

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (path == '/api/login') {
      final pin = (jsonDecode(r.body) as Map)['password'];
      return pin == '4321'
          ? http.Response(jsonEncode({'ok': true}), 200)
          : http.Response('{"error":"Incorrect PIN"}', 401);
    }
    if (r.method == 'GET') {
      final saved = this.saved;
      if (saved == null) return http.Response('{}', 404);
      final tag = '"$version"';
      if (r.headers['If-None-Match'] == tag) {
        return http.Response('', 304, headers: {'etag': tag});
      }
      return http.Response(
        jsonEncode({'updatedAt': version, 'data': saved}),
        200,
        headers: {'etag': tag},
      );
    }
    if (r.headers['Authorization'] != 'Bearer 4321') {
      return http.Response('{"error":"Admin sign-in required"}', 401);
    }
    if (r.method == 'PUT') {
      saved = (jsonDecode(r.body) as Map)['data'] as Map<String, dynamic>;
      version++;
      return http.Response('{}', 200, headers: {'etag': '"$version"'});
    }
    saved = null;
    return http.Response('{}', 200);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AnalyticsProvider providerFor(FakeServer s, {String? post}) =>
      AnalyticsProvider(
        ApiStorageService('http://x', client: MockClient(s.handle)),
        pollInterval: const Duration(milliseconds: 50),
        requestedPostId: post,
      );

  test('a post the admin adds reaches a visitor on another device', () async {
    final server = FakeServer();
    final admin = providerFor(server);
    final visitor = providerFor(server);
    await admin.load();
    await visitor.load();
    expect(visitor.post!.id, 'sample');

    expect(await admin.login('0000'), isFalse);
    expect(await admin.login('4321'), isTrue);
    final added = Post.blank()
      ..caption = 'My lion video'
      ..views = 39
      ..female = 5
      ..other = 2;
    admin.addPost(added);
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    expect(admin.syncError, isNull);
    expect(server.saved, isNotNull, reason: 'admin save reached server');
    // Newest post comes first, so the visitor now sees it.
    expect(visitor.post!.caption, 'My lion video');
    expect(visitor.post!.female, 5);
    expect(visitor.post!.other, 2);
    expect(visitor.post!.genderTotal, 7);

    // A link naming a post shows that one.
    final linked = providerFor(server, post: 'sample');
    await linked.load();
    expect(linked.post!.id, 'sample');

    // Editing and deleting are shared too.
    admin.updatePost(Post.fromJson(added.toJson())..likes = 6);
    admin.deletePost('sample');
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    expect(visitor.post!.likes, 6);
    expect(visitor.data.posts.length, 1);
    admin.dispose();
    visitor.dispose();
    linked.dispose();
  });

  test('old saved figures without posts load as an empty list', () {
    final data = AnalyticsData.fromJson({
      'followers': [1, 2],
    });
    expect(data.posts, isEmpty);
    expect(data.byId(null), isNull);
    expect(data.inspiration['trending'], isNotEmpty);
  });

  test('a server problem at login is not reported as a wrong PIN', () async {
    final p = AnalyticsProvider(
      ApiStorageService(
        'http://x',
        client: MockClient(
          (_) async => http.Response(
            '{"error":"Storage not configured: connect an Upstash Redis database."}',
            500,
          ),
        ),
      ),
      pollInterval: null,
    );
    await expectLater(
      p.login('1234'),
      throwsA(
        isA<StorageException>().having(
          (e) => e.message,
          'message',
          contains('Storage not configured'),
        ),
      ),
    );
  });

  test('saving without signing in is refused and reported', () async {
    final server = FakeServer();
    final p = providerFor(server);
    await p.load();
    p.addPost(Post.blank());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(p.syncError, contains('Sign in'));
    expect(server.saved, isNull);
    p.dispose();
  });

  test('reset clears the shared copy', () async {
    final server = FakeServer();
    final p = providerFor(server);
    await p.load();
    await p.login('4321');
    p.addPost(Post.blank());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.saved, isNotNull);
    await p.resetToSample();
    expect(server.saved, isNull);
    expect(p.data.posts.single.id, 'sample');
    p.dispose();
  });
}
