// Debug native proof entrypoint; build only with -PxlandNativeProof=true.
// Input lives in the dedicated app sandbox, never in source/build defines/logs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../data/datasources/local/secure_session_store.dart';
import '../data/datasources/remote/api_transport.dart';
import '../data/datasources/remote/http_api_transport.dart';
import '../data/repositories/remote_repositories.dart';
import '../domain/xland_domain.dart';

const _canary = 'XLAND C02 synthetic canary, never a real session';
String _runKey = '';
void _record(Map<String, Object?> value) =>
    debugPrint('XLAND_C02 ${jsonEncode({'runKey': _runKey, ...value})}');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final input = jsonDecode(
      await File(
        '/data/user/0/vn.xland.xland_mobile.cproof/files/c02-input.json',
      ).readAsString(),
    ) as Map<String, Object?>;
    _runKey = input['runKey']! as String;
    final mode = input['mode']! as String;
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('XLAND DEMO ONLY · C native proof')),
        ),
      ),
    );
    final sessions = SecureSessionStore(const FlutterSecureStorage());
    if (mode == 'write') {
      if (await sessions.readAccessToken() != null) {
        throw StateError('Preserve unexpected private session');
      }
      await sessions.saveAccessToken(accessToken: _canary);
      if (await sessions.readAccessToken() != _canary) {
        throw StateError('Canary write/read failed');
      }
      _record({'mode': mode, 'actualNativeWriteRead': true});
    } else if (mode == 'restart_read_delete') {
      if (await sessions.readAccessToken() != _canary) {
        throw StateError('Restart canary mismatch');
      }
      await sessions.clear();
      if (await sessions.readAccessToken() != null) {
        throw StateError('Delete did not persist');
      }
      _record({'mode': mode, 'restartRead': true, 'deleteReadNull': true});
    } else if (mode == 'unavailable') {
      final unavailable = SecureSessionStore(
        FlutterSecureStorage(
          aOptions: AndroidOptions.biometric(
            enforceBiometrics: true,
            resetOnError: false,
            storageNamespace: 'xland_c02_auth_required',
          ),
        ),
      );
      var guarded = false;
      try {
        await unavailable.saveAccessToken(accessToken: _canary);
      } on XlandFailure catch (error) {
        guarded = error.code == FailureCode.internalError;
      }
      _record({'mode': mode, 'actualNoEnrollmentGuarded': guarded});
      if (!guarded) await unavailable.clear();
    } else if (mode == 'player') {
      final player = VideoPlayerController.networkUrl(
        Uri.parse('http://10.0.2.2:5562/demo-video.mp4'),
      );
      try {
        await player.initialize().timeout(const Duration(seconds: 20));
        await player.setVolume(0);
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        final position = await player.position;
        if (position == null || position.inMilliseconds < 500) {
          throw StateError('Native decode/play did not advance');
        }
        await player.pause();
        await player.seekTo(const Duration(seconds: 2));
        final seek = await player.position;
        if (seek == null || seek.inMilliseconds < 1900) {
          throw StateError('Native seek failed');
        }
        _record({
          'mode': mode,
          'width': player.value.size.width,
          'height': player.value.size.height,
          'durationMs': player.value.duration.inMilliseconds,
          'advancedMs': position.inMilliseconds,
          'paused': !player.value.isPlaying,
          'seekMs': seek.inMilliseconds,
          'actualFeedProof': false,
        });
      } finally {
        await player.dispose();
      }
      for (final path in ['/expired', '/broken']) {
        final broken = VideoPlayerController.networkUrl(
          Uri.parse('http://10.0.2.2:5562$path'),
        );
        var rejected = false;
        try {
          await broken.initialize().timeout(const Duration(seconds: 20));
        } catch (_) {
          rejected = true;
        } finally {
          await broken.dispose();
        }
        _record({
          'mode': 'player_source_error',
          'path': path,
          'actualNativeRejected': rejected,
          'actualFeedProof': false,
        });
        if (!rejected) throw StateError('Native source error was not rejected');
      }
    } else {
      final client = http.Client();
      try {
        final base = Uri.parse(input['apiBaseUrl']! as String);
        if (base.host != '10.0.2.2' || base.scheme != 'http') {
          throw StateError('Only owned emulator-loopback test API allowed');
        }
        final transport = HttpApiTransport(
          baseUrl: base,
          client: client,
          sessions: sessions,
          allowLocalHttp: true,
        );
        final account = RemoteAccountRepository(
          RemoteGateway(transport),
          sessions,
        );
        if (mode == 'login') {
          if (await sessions.readAccessToken() != null) {
            throw StateError('Preserve unexpected private session');
          }
          await account.signIn(
            SignInInput(
              username: input['username']! as String,
              password: input['password']! as String,
            ),
          );
          final valid = await transport.send(
            const ApiRequest(method: 'GET', path: '/auth/session'),
          );
          _record({
            'mode': mode,
            'status': valid.statusCode,
            'nativeTokenStored': await sessions.readAccessToken() != null,
          });
        } else if (mode == 'read_valid') {
          if (await sessions.readAccessToken() == null) {
            throw StateError('Expected persisted native test session');
          }
          final valid = await transport.send(
            const ApiRequest(method: 'GET', path: '/auth/session'),
          );
          _record({
            'mode': mode,
            'status': valid.statusCode,
            'restartSessionRead': true,
          });
        } else if (mode == 'logout') {
          await account.signOut();
          _record({
            'mode': mode,
            'nativeReadNull': await sessions.readAccessToken() == null,
          });
        } else if (mode == 'read_401') {
          if (await sessions.readAccessToken() == null) {
            throw StateError('Expected persisted native test session');
          }
          var unauthorized = false;
          try {
            await transport.send(
              const ApiRequest(method: 'GET', path: '/auth/session'),
            );
          } on XlandFailure catch (error) {
            unauthorized = error.code == FailureCode.unauthenticated;
          }
          final cleared = await sessions.readAccessToken() == null;
          if (!unauthorized || !cleared) {
            throw StateError('401 native clear failed');
          }
          _record({
            'mode': mode,
            'reason': input['reason'],
            'status': 401,
            'nativeReadNull': cleared,
          });
        } else {
          throw StateError('Unknown native proof mode');
        }
      } finally {
        client.close();
      }
    }
  } catch (error) {
    _record({
      'mode': 'failed',
      'type': error.runtimeType.toString(),
      'privateValuesRedacted': true,
    });
  }
}
