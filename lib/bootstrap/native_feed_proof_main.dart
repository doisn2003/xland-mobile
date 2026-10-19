// Observes B's current feed on native; does not replace B UI/lifecycle acceptance.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'dev_main.dart';

String _runKey = '';
void _record(Map<String, Object?> value) =>
    debugPrint('XLAND_C02 ${jsonEncode({'runKey': _runKey, ...value})}');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final input = jsonDecode(
    await File('/data/user/0/vn.xland.xland_mobile.cproof/files/c02-input.json')
        .readAsString(),
  ) as Map<String, Object?>;
  _runKey = input['runKey']! as String;
  runApp(const _FeedObserver(child: DevComposition()));
}

/// Observes actual VideoPlayer widgets mounted by B's real feed, no fake channel.
/// Logs platform decode/position/state; does not certify B route/settings behavior.
class _FeedObserver extends StatefulWidget {
  const _FeedObserver({required this.child});
  final Widget child;
  @override
  State<_FeedObserver> createState() => _FeedObserverState();
}

class _FeedObserverState extends State<_FeedObserver>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _capture('tick'),
    );
  }

  void _capture(String reason) {
    if (!mounted) return;
    final players = <VideoPlayerController>[];
    void visit(Element e) {
      final widget = e.widget;
      if (widget is VideoPlayer && !players.contains(widget.controller)) {
        players.add(widget.controller);
      }
      e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    _record({
      'mode': 'actual_feed',
      'reason': reason,
      'players': players
          .map(
            (p) => {
              'initialized': p.value.isInitialized,
              'playing': p.value.isPlaying,
              'volume': p.value.volume,
              'positionMs': p.value.position.inMilliseconds,
              'width': p.value.size.width,
              'height': p.value.size.height,
              'durationMs': p.value.duration.inMilliseconds,
              'hasError': p.value.hasError,
            },
          )
          .toList(),
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Future<void>.delayed(
      const Duration(milliseconds: 350),
      () => _capture(state.name),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
