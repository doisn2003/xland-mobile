import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bootstrap/app_main.dart';
import 'data/demo/prepared_snapshot.dart';
import 'data/demo/prepared_media.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('XLAND_PREPARED_DEMO')) {
    throw StateError('Use the separate prepared-demo build configuration.');
  }
  final json = jsonDecode(
    await rootBundle.loadString('assets/prepared-demo/snapshot.json'),
  ) as Json;
  final snapshot = PreparedSnapshot.fromJson(json);
  PreparedMedia.snapshot = snapshot;
  runApp(XlandComposition(preparedSnapshot: snapshot));
}
