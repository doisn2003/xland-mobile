// Debug-only native diagnostic. Never a production composition or feed proof.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../data/datasources/local/secure_session_store.dart';
import '../data/datasources/remote/api_transport.dart';
import '../data/datasources/remote/http_api_transport.dart';
import '../domain/failures/xland_failure.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _NativeProbe()));
}

class _NativeProbe extends StatefulWidget {
  const _NativeProbe();
  @override
  State<_NativeProbe> createState() => _NativeProbeState();
}

class _NativeProbeState extends State<_NativeProbe> {
  static const canary =
      'synthetic-native-storage-canary-closeout-not-a-real-token';
  final storage = const SecureSessionStore(FlutterSecureStorage());
  final client = http.Client();
  late final VideoPlayerController player;
  String status = 'Checking actual Android plugins...';

  @override
  void initState() {
    super.initState();
    player = VideoPlayerController.networkUrl(
      Uri.parse('http://10.0.2.2:5560/demo-video.mp4'),
    );
    _verify();
  }

  void _record(Map<String, Object?> result) {
    // Diagnostic contains only status/numbers; never token/credential bytes.
    debugPrint('XLAND_NATIVE_PROBE ${jsonEncode(result)}');
    if (mounted) {
      setState(() {
        status = jsonEncode(result);
      });
    }
  }

  Future<void> _verify() async {
    try {
      final before = await storage.readAccessToken();
      if (before == null) {
        await storage.saveAccessToken(accessToken: canary);
        if (await storage.readAccessToken() != canary) {
          throw StateError('Secure storage write/read failed');
        }
        _record({
          'phase': 'write',
          'actualNativeSecureStorage': true,
          'restartRequired': true,
        });
      } else {
        if (before != canary) {
          throw StateError('Unexpected private session; preserve for review');
        }
        final transport = HttpApiTransport(
          baseUrl: Uri.parse('http://10.0.2.2:3001/api/v1'),
          client: client,
          sessions: storage,
          allowLocalHttp: true,
        );
        var unauthorized = false;
        try {
          await transport.send(
            const ApiRequest(method: 'GET', path: '/auth/session'),
          );
        } on XlandFailure catch (e) {
          unauthorized = e.code == FailureCode.unauthenticated;
        }
        if (!unauthorized || await storage.readAccessToken() != null) {
          throw StateError('401 did not clear actual native storage');
        }
        await storage.saveAccessToken(accessToken: canary);
        await storage.clear();
        if (await storage.readAccessToken() != null) {
          throw StateError('Explicit clear failed');
        }
        _record({
          'phase': 'restart-read-and-delete',
          'actualNativeSecureStorage': true,
          'canaryPersistedAcrossForceStop': true,
          'invalidToken401Cleared': true,
          'explicitDeleteReadNull': true,
          'actualExpiredRevokedProof': false,
        });
      }
      await player.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {});
      await player.setVolume(0);
      await player.play();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final position = await player.position;
      if (position == null || position <= Duration.zero) {
        throw StateError('Native playback did not advance');
      }
      await player.pause();
      await player.seekTo(const Duration(seconds: 2));
      final seek = await player.position;
      if (seek == null || seek.inMilliseconds < 1900) {
        throw StateError('Native seek failed');
      }
      _record({
        'phase': 'player',
        'platform': 'Android emulator',
        'width': player.value.size.width,
        'height': player.value.size.height,
        'durationMs': player.value.duration.inMilliseconds,
        'advancedMs': position.inMilliseconds,
        'seekMs': seek.inMilliseconds,
        'paused': !player.value.isPlaying,
        'feedVerified': false,
      });
    } catch (error) {
      _record({
        'phase': 'failed',
        'errorType': error.runtimeType.toString(),
        'details': 'No private values logged; inspect target/config',
      });
    }
  }

  @override
  void dispose() {
    player.dispose();
    client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('XLAND DEMO ONLY · native diagnostic')),
    body: ListView(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(status)),
        if (player.value.isInitialized)
          SizedBox(
            height: 400,
            child: AspectRatio(
              aspectRatio: player.value.aspectRatio,
              child: VideoPlayer(player),
            ),
          ),
      ],
    ),
  );
}
