import 'package:flutter/material.dart';

/// Temporary Phase 1 shell; replaced by constructor wiring after B/A review.
class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'XLand Foundation',
    home: Scaffold(
      body: SafeArea(child: Center(child: Text('XLand · Phase 1 bootstrap'))),
    ),
  );
}
