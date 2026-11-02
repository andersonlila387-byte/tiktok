import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      final pin = (jsonDecode(r.body) as Map)['pin'];
      return pin == '4321'
          ? http.Response(jsonEncode({'token': 't'}), 200)
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
    if (r.headers['Authorization'] != 'Bearer t') {
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

  AnalyticsProvider providerFor(FakeServer s) => AnalyticsProvider(
        ApiStorageService('http://x', client: MockClient(s.handle)),
        pollInterval: const Duration(milliseconds: 50),
        fixedToday: DateTime(2026, 11, 2),
      );

  test('admin edits reach a visitor on another device', () async {
    final server = FakeServer();
    final admin = providerFor(server);
    final visitor = providerFor(server);
    await admin.load();
    await visitor.load();
    expect(visitor.data.male, 56);

    expect(await admin.login('0000'), isFalse);
    expect(await admin.login('4321'), isTrue);
    admin.setGender(20, 5);
    admin.setMetricTotal('Likes', 22500);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(admin.syncError, isNull);
    expect(server.saved, isNotNull, reason: 'admin save reached server');
    expect(visitor.data.male, 20);
    expect(visitor.data.female, 5);
    expect(visitor.data.other, 75);
    expect(visitor.metricTotal('Likes'), 22500);
    expect(admin.syncError, isNull);

    // A fresh visit (e.g. after a refresh) loads the saved figures too.
    final reopened = providerFor(server);
    await reopened.load();
    expect(reopened.data.male, 20);
    admin.dispose();
    visitor.dispose();
    reopened.dispose();
  });

  test('a server problem at login is not reported as a wrong PIN', () async {
    final p = AnalyticsProvider(
      ApiStorageService('http://x',
          client: MockClient((_) async => http.Response(
              '{"error":"Storage not configured: connect an Upstash Redis database."}',
              500))),
      pollInterval: null,
    );
    await expectLater(
      p.login('1234'),
      throwsA(isA<StorageException>().having(
          (e) => e.message, 'message', contains('Storage not configured'))),
    );
  });

  test('saving without signing in is refused and reported', () async {
    final server = FakeServer();
    final p = providerFor(server);
    await p.load();
    p.setGender(30, 30);
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
    p.setGender(10, 10);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.saved, isNotNull);
    await p.resetToSample();
    expect(server.saved, isNull);
    expect(p.data.male, 56);
    p.dispose();
  });
}
