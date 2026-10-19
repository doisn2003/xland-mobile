import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Flutter test reinstalls/uninstalls the dedicated package. Handoff must occur
/// after installation, and report extraction before its automatic cleanup.
Future<Map<String, Object?>> readW1Input() async {
  final file = File(
    '/data/user/0/vn.xland.xland_mobile.cproof/files/p3-w1-input.json',
  );
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (await file.exists()) {
      final input =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      debugPrint('P3_INPUT_READY');
      return input;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError(
    'Private native input handoff timed out; no credential printed',
  );
}

Future<void> writeW1Report(Map<String, Object?> report,{Duration hold=const Duration(seconds:3)}) async {
  await File(
    '/data/user/0/vn.xland.xland_mobile.cproof/files/p3-owner-report.json',
  ).writeAsString(jsonEncode(report));
  debugPrint('P3_REPORT_READY');
  await Future<void>.delayed(hold);
}
