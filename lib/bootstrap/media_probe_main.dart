// Explicit web-only diagnostic entry point; never wired into the product app.
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

@JS('document.title')
external set _title(JSString value);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final VideoPlayerController player;
  String status = 'Checking synthetic video with real video_player...';
  @override
  void initState() {
    super.initState();
    const base = String.fromEnvironment(
      'XLAND_MEDIA_TEST_BASE',
      defaultValue: 'http://127.0.0.1:5560',
    );
    player = VideoPlayerController.networkUrl(
      Uri.parse('$base/demo-video.mp4'),
    );
    _verify(base);
  }

  Future<void> _verify(String base) async {
    try {
      await player.initialize().timeout(const Duration(seconds: 15));
      if (player.value.size.width != 360 ||
          player.value.duration.inSeconds != 4) {
        throw StateError('Unexpected decoded dimensions/duration');
      }
      if (!mounted) return;
      setState(() {});
      await player.setVolume(0);
      await player.play();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final position = await player.position;
      if (position == null || position <= Duration.zero) {
        throw StateError('Playback position did not advance');
      }
      await player.pause();
      if (player.value.isPlaying) throw StateError('Pause failed');
      await player.seekTo(const Duration(seconds: 2));
      final seek = await player.position;
      if (seek == null || seek.inMilliseconds < 1900) {
        throw StateError('Seek failed');
      }
      for (final path in ['/expired', '/broken']) {
        final failed = VideoPlayerController.networkUrl(
          Uri.parse('$base$path'),
        );
        try {
          try {
            await failed.initialize().timeout(const Duration(seconds: 10));
            throw StateError('Unavailable media unexpectedly initialized');
          } catch (_) {
            if (!failed.value.hasError) rethrow;
          }
        } finally {
          await failed.dispose();
        }
      }
      if (!mounted) return;
      setState(() {
        status =
            'PASS: decoded 360x640/4s; play advanced ${position.inMilliseconds}ms; pause; seek ${seek.inMilliseconds}ms; expired410 and unavailable503 errors. Feed/native NOT VERIFIED.';
      });
      _title = 'XLAND MEDIA PROBE PASS'.toJS;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        status = 'FAIL: $error';
      });
      _title = 'XLAND MEDIA PROBE FAIL'.toJS;
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('XLAND DEMO ONLY · media diagnostic')),
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
