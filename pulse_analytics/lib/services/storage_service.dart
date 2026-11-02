import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics_data.dart';

/// Where the figures live. The app talks to this interface only, so the
/// backend can change without touching screens.
abstract class StorageService {
  /// The saved figures, or null when nothing was saved yet.
  Future<AnalyticsData?> load();

  /// Figures saved by someone else since the last load, or null if unchanged.
  Future<AnalyticsData?> poll() async => null;

  /// Signs the admin in; later [save] and [clear] calls need it.
  Future<bool> login(String pin);

  /// Throws [StorageException] when the figures could not be saved.
  Future<void> save(AnalyticsData data);

  Future<void> clear();
}

class StorageException implements Exception {
  StorageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Keeps the figures in the browser only. Used by tests and as the offline
/// cache; the admin PIN is checked on the device.
class LocalStorageService extends StorageService {
  LocalStorageService({this.pin = '1234'});

  static const _key = 'analytics_data_v4';
  final String pin;

  @override
  Future<AnalyticsData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return AnalyticsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> login(String entered) async => entered == pin;

  @override
  Future<void> save(AnalyticsData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Shares one set of figures between the admin and every visitor through the
/// server in `server/`. The last copy received is cached on the device so the
/// dashboard still opens if the server cannot be reached.
class ApiStorageService extends StorageService {
  ApiStorageService(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final LocalStorageService _cache = LocalStorageService();

  String? _token;
  String? _etag;

  Uri get _uri => Uri.parse('$baseUrl/api/analytics');

  AnalyticsData _parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return AnalyticsData.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<AnalyticsData?> load() async {
    try {
      final res = await _client.get(_uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        _etag = null;
        return null;
      }
      if (res.statusCode != 200)
        throw StorageException('HTTP ${res.statusCode}');
      _etag = res.headers['etag'];
      final data = _parse(res.body);
      await _cache.save(data);
      return data;
    } catch (_) {
      return _cache.load();
    }
  }

  @override
  Future<AnalyticsData?> poll() async {
    try {
      final res = await _client
          .get(_uri, headers: {if (_etag != null) 'If-None-Match': _etag!})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      _etag = res.headers['etag'];
      final data = _parse(res.body);
      await _cache.save(data);
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> login(String pin) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw StorageException('Could not reach the server.');
    }
    if (res.statusCode == 200) {
      _token =
          (jsonDecode(res.body) as Map<String, dynamic>)['token'] as String;
      return true;
    }
    if (res.statusCode == 429) {
      throw StorageException('Too many attempts. Try again in a minute.');
    }
    return false;
  }

  Map<String, String> get _auth => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  String _error(http.Response res) {
    if (res.statusCode == 401) {
      _token = null;
      return 'Your admin session expired. Sign in again.';
    }
    try {
      return (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String;
    } catch (_) {
      return 'The server answered with HTTP ${res.statusCode}.';
    }
  }

  @override
  Future<void> save(AnalyticsData data) async {
    final http.Response res;
    try {
      res = await _client
          .put(_uri, headers: _auth, body: jsonEncode({'data': data.toJson()}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw StorageException('Could not reach the server. Change not saved.');
    }
    if (res.statusCode != 200) throw StorageException(_error(res));
    // Remember our own write so the next poll does not re-download it.
    _etag = res.headers['etag'] ?? _etag;
    await _cache.save(data);
  }

  @override
  Future<void> clear() async {
    final http.Response res;
    try {
      res = await _client
          .delete(_uri, headers: _auth)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw StorageException('Could not reach the server. Nothing was reset.');
    }
    if (res.statusCode != 200) throw StorageException(_error(res));
    _etag = null;
    await _cache.clear();
  }
}
