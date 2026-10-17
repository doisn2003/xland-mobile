import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:xland_mobile/data/demo/demo_asset_client.dart';

Future<void> main() async {
  final base = Platform.environment['XLAND_DEMO_BASE_URL'];
  if (base == null) {
    throw StateError('Start via server verify-demo-provider.mjs');
  }
  final client = http.Client();
  final demo = DemoAssetClient(client, Uri.parse(base));
  final dir = await Directory.systemTemp.createTemp('xland-synthetic-');
  final expiry = DateTime.now().add(const Duration(minutes: 1));
  try {
    final data = await demo.load(
      '/demo-guide.txt',
      mimeType: 'text/plain',
      expiresAt: expiry,
    );
    final file = File('${dir.path}/xland-demo-guide.txt');
    await file.writeAsBytes(data, flush: true);
    if (await file.readAsString() != String.fromCharCodes(data) ||
        !String.fromCharCodes(data).contains('XLAND DEMO ONLY')) {
      throw StateError('File readback differs');
    }
    await file.delete();
    if (await file.exists()) throw StateError('Demo file cleanup failed');
    final tone = await demo.load(
      '/demo-tone.wav',
      mimeType: 'audio/wav',
      expiresAt: expiry,
    );
    if (String.fromCharCodes(tone.take(4)) != 'RIFF') {
      throw StateError('Invalid demo media');
    }
    var errors = 0;
    for (final path in ['/expired', '/broken', '/missing']) {
      try {
        await demo.load(path, mimeType: 'text/plain', expiresAt: expiry);
      } on StateError {
        errors++;
      }
    }
    try {
      await demo.load(
        '/demo-guide.txt',
        mimeType: 'text/plain',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
    } on StateError {
      errors++;
    }
    try {
      await demo.load(
        '/demo-guide.txt',
        mimeType: 'application/pdf',
        expiresAt: expiry,
      );
    } on StateError {
      errors++;
    }
    try {
      await demo.load(
        '/demo-guide.txt',
        mimeType: 'text/plain',
        expiresAt: expiry,
        maxBytes: 1,
      );
    } on StateError {
      errors++;
    }
    if (errors != 6) throw StateError('Expected six failure scenarios');
    stdout.writeln(
      'PASS synthetic HTTP download/write/read/delete; WAV bytes; 6 errors. Player/native/public provider NOT VERIFIED.',
    );
  } finally {
    client.close();
    await dir.delete(recursive: true);
  }
}
