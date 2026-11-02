import 'package:flutter/material.dart';

import 'screens/analytics_shell.dart';
import 'theme/app_theme.dart';

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Analytics',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Keep the phone layout when opened on a wide screen.
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFE9E9E9),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ClipRect(child: child),
          ),
        ),
      ),
      home: const AnalyticsShell(),
    );
  }
}
