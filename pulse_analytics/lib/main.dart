import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/analytics_provider.dart';
import 'services/storage_service.dart';

/// Server that stores the figures. By default the page's own origin, because
/// the server in `server/` also serves the web app; override with
/// `--dart-define=API_URL=https://example.com` when hosting them apart.
const _apiUrl = String.fromEnvironment('API_URL');

void main() {
  final base = _apiUrl.isNotEmpty ? _apiUrl : Uri.base.origin;
  runApp(
    ChangeNotifierProvider(
      create: (_) => AnalyticsProvider(ApiStorageService(base))..load(),
      child: const PulseApp(),
    ),
  );
}
