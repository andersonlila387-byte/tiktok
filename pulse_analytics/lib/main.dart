import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/analytics_provider.dart';
import 'services/storage_service.dart';

/// Server that stores the figures. By default the page's own origin, because
/// the server in `server/` also serves the web app; override with
/// `--dart-define=API_URL=https://example.com` when hosting them apart.
const _apiUrl = String.fromEnvironment('API_URL');

/// Where `node server/server.js` listens by default.
const _devServer = 'http://localhost:8080';

void main() {
  // Under `flutter run` the page is not served by our server, so look for it
  // on its usual local address.
  final base = _apiUrl.isNotEmpty
      ? _apiUrl
      : (kDebugMode ? _devServer : Uri.base.origin);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AnalyticsProvider(
        ApiStorageService(base),
        requestedPostId: Uri.base.queryParameters['v'],
      )..load(),
      child: const PulseApp(),
    ),
  );
}
