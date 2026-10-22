import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../datasources/local/session_store.dart';
import '../datasources/remote/api_transport.dart';
import '../../domain/failures/xland_failure.dart';
import 'prepared_snapshot.dart';

abstract interface class PreparedStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class SecurePreparedStore implements PreparedStore {
  const SecurePreparedStore(this.storage);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

final class _OwnerContent {
  _OwnerContent(this.key, this.entries, this.dates);
  final String key;
  final Json entries;
  final Map<String, DateTime> dates;
  bool retired = false;
  int revision = 0;
}

/// Real write-through: no mutation, session or private response comes from disk.
/// Authenticated public caches are scoped to one opaque session using SHA-256.
final class PreparedTransport extends ChangeNotifier implements ApiTransport {
  PreparedTransport({
    required this.remote,
    required this.sessions,
    required this.snapshot,
    required this.store,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final ApiTransport remote;
  final SessionStore sessions;
  final PreparedSnapshot snapshot;
  final PreparedStore store;
  final DateTime Function() now;
  final Map<String, Future<_OwnerContent>> _owners = {};
  Future<void> _writes = Future<void>.value();
  int prepared = 0, total = 0;
  bool busy = false;
  String? preparationError;
  final _changes = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get contentChanges => _changes.stream;
  final Map<String, Future<void>> _refreshing = {};
  final Map<String, DateTime> _checked = {};
  String? syncError;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String _owner(String? token) => token == null
      ? 'guest'
      : sha256.convert(utf8.encode('${snapshot.apiOrigin}|$token')).toString();
  String _storageKey(String owner) => 'xland.prepared.public.v1.$owner';

  Future<_OwnerContent> _content(String? token) {
    final owner = _owner(token);
    return _owners.putIfAbsent(owner, () async {
      final entries = <String, Object?>{}, dates = <String, DateTime>{};
      if (token == null) {
        entries.addAll(snapshot.entries);
        for (final key in entries.keys) {
          dates[key] = snapshot.preparedAt;
        }
      }
      try {
        final raw = await store.read(_storageKey(owner));
        if (raw != null) {
          final value = jsonDecode(raw) as Json;
          if (value['version'] == 1 && value['origin'] == snapshot.apiOrigin) {
            final saved = value['entries']! as Json;
            for (final entry in saved.entries) {
              if (!PreparedSnapshot.isPublic(entry.key.split('?').first)) {
                continue;
              }
              final record = entry.value! as Json;
              final date = DateTime.parse(record['at']! as String);
              if (now().difference(date) <= PreparedSnapshot.maxAge) {
                entries[entry.key] = record['body'];
                dates[entry.key] = date;
              }
            }
          }
        }
      } catch (_) {
        // Corrupt public content cannot provide identity or authorize a write.
      }
      return _OwnerContent(owner, entries, dates);
    });
  }

  Future<void> _persist(_OwnerContent content) {
    final encoded = jsonEncode({
      'version': 1,
      'origin': snapshot.apiOrigin,
      'entries': {
        for (final e in content.entries.entries)
          e.key: {
            'at': content.dates[e.key]!.toIso8601String(),
            'body': e.value,
          },
      },
    });
    final result = _writes.then((_) async {
      if (!content.retired) {
        await store.write(_storageKey(content.key), encoded);
      }
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Json> _fetch(String key) async {
    final uri = Uri.parse(key), path = uri.path;
    if (!PreparedSnapshot.isList(path)) {
      return (await remote.send(
        ApiRequest(method: 'GET', path: path, query: uri.queryParameters),
      )).body;
    }
    final rows = <Object?>[];
    String? cursor;
    final seen = <String>{};
    do {
      final response = await remote.send(
        ApiRequest(
          method: 'GET',
          path: path,
          query: {
            if (path == '/feed') 'feedScope': 'recommended',
            'limit': '50',
            'cursor': ?cursor,
          },
        ),
      );
      rows.addAll(response.body['data']! as List);
      final meta = response.body['meta']! as Json;
      cursor = meta['hasMore'] == true ? meta['nextCursor'] as String? : null;
      if (cursor != null && !seen.add(cursor)) {
        throw const FormatException('Repeated cursor');
      }
    } while (cursor != null);
    return {
      'data': rows,
      'meta': {'total': rows.length, 'hasMore': false, 'nextCursor': null},
    };
  }

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final token = await sessions.readAccessToken();
    if (request.method != 'GET') {
      // Exactly once, with original body/key. Failed writes propagate unchanged.
      final response = await remote.send(request);
      if (response.statusCode < 400 &&
          await sessions.readAccessToken() == token) {
        try {
          await _acknowledge(request, response, await _content(token));
        } catch (_) {
          /* Cache errors cannot turn server success into a failed write. */
        }
      }
      return response;
    }
    if (!PreparedSnapshot.isPublic(request.path) ||
        (request.path == '/feed' &&
            request.query['feedScope'] == 'following') ||
        (request.query['savedOnly'] == 'true' && token == null)) {
      return remote.send(request);
    }
    final content = await _content(token), key = PreparedSnapshot.key(request);
    if (await sessions.readAccessToken() != token) return send(request);
    final cached = content.entries[key] as Json?, date = content.dates[key];
    if (cached != null &&
        date != null &&
        now().difference(date) <= PreparedSnapshot.maxAge) {
      final checkKey = '${content.key}|$key';
      if (!_checked.containsKey(checkKey) ||
          now().difference(_checked[checkKey]!) > const Duration(seconds: 10)) {
        unawaited(
          _refresh(key, token, content).catchError((Object _) {
            syncError =
                'Đang xem dữ liệu đã lưu. Chưa kết nối được để cập nhật.';
            notifyListeners();
          }),
        );
      }
      return snapshot.project(request, cached, content.entries);
    }
    final revision = content.revision, body = await _fetch(key);
    if (await sessions.readAccessToken() != token || content.retired) {
      throw const XlandFailure(
        code: FailureCode.unauthenticated,
        message: 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại.',
      );
    }
    if (content.revision != revision) return send(request);
    content.entries[key] = body;
    content.dates[key] = now();
    _checked['${content.key}|$key'] = now();
    try {
      await _persist(content);
    } catch (_) {
      /* Live read is still valid. */
    }
    return snapshot.project(request, body, content.entries);
  }

  Future<void> _refresh(String key, String? token, _OwnerContent content) {
    final checkKey = '${content.key}|$key';
    return _refreshing.putIfAbsent(checkKey, () async {
      try {
        final revision = content.revision;
        final body = await _fetch(key);
        if (content.retired ||
            content.revision != revision ||
            await sessions.readAccessToken() != token) {
          return;
        }
        final changed = jsonEncode(content.entries[key]) != jsonEncode(body);
        content.entries[key] = body;
        content.dates[key] = now();
        _checked[checkKey] = now();
        syncError = null;
        try {
          await _persist(content);
        } catch (_) {}
        if (changed && !_disposed) _changes.add({key});
      } finally {
        _refreshing.remove(checkKey);
      }
    });
  }

  /// Explicit refresh bypasses age checks and completes only after a live read.
  Future<void> refreshContent(String path) async {
    if (!PreparedSnapshot.isPublic(path)) return;
    final token = await sessions.readAccessToken(),
        content = await _content(token);
    final ongoing = _refreshing['${content.key}|$path'];
    if (ongoing != null) {
      try {
        await ongoing;
      } catch (_) {}
    }
    await _refresh(path, token, content);
  }

  Future<void> refreshRoots() async {
    try {
      await Future.wait(
        ['/feed', '/properties', '/events'].map(refreshContent),
      );
    } catch (_) {
      syncError = 'Đang xem dữ liệu đã lưu. Chưa kết nối được để cập nhật.';
      notifyListeners();
    }
  }

  Future<void> _acknowledge(
    ApiRequest request,
    ApiResponse response,
    _OwnerContent content,
  ) async {
    content.revision++;
    if (request.path.startsWith('/auth/')) {
      content.retired = true;
      _owners.remove(content.key);
      await _writes;
      await store.delete(_storageKey(content.key));
      return;
    }
    final social = RegExp(
      r'^/(properties|videos|events|authors)/([^/]+)/(saved|like|follow)$',
    ).firstMatch(request.path);
    if (social != null) {
      final value = response.body['data']! as Json;
      final field = switch (social[3]) {
        'like' => 'isLiked',
        'follow' => 'isFollowing',
        _ => 'isSaved',
      };
      void patch(Object? item) {
        if (item is List) {
          for (final v in item) {
            patch(v);
          }
        }
        if (item is Json) {
          if (item['id'] == social[2] && item.containsKey(field)) {
            item[field] = value['active'];
            if (field == 'isLiked' &&
                value['count'] != null &&
                item.containsKey('likeCount')) {
              item['likeCount'] = value['count'];
            }
          }
          for (final v in item.values) {
            patch(v);
          }
        }
      }

      for (final key in content.entries.keys.toList()) {
        final copy = PreparedSnapshot.copy(content.entries[key]! as Json);
        patch(copy);
        content.entries[key] = copy;
      }
    } else if (request.path.startsWith('/support-requests') ||
        request.path.startsWith('/me/settings') ||
        request.path.startsWith('/me/finance-plans') ||
        request.path.startsWith('/finance/')) {
      // These writes cannot change public catalogue content.
    } else {
      // Booking/payment/profile/comment writes may change public summaries.
      content.entries.clear();
      content.dates.clear();
    }
    try {
      await _persist(content);
    } catch (_) {
      /* Server success is not a cache failure. */
    }
  }

  /// Operator preparation before the meeting, using the current real account.
  Future<void> prepareAll() async {
    if (busy) return;
    busy = true;
    prepared = 0;
    preparationError = null;
    final token = await sessions.readAccessToken(),
        content = await _content(token);
    final paths = snapshot.entries.keys.toList();
    total = paths.length;
    notifyListeners();
    var next = 0;
    try {
      await Future.wait(
        List.generate(3, (_) async {
          while (next < paths.length) {
            final key = paths[next++];
            final body = await _fetch(key);
            if (await sessions.readAccessToken() != token || content.retired) {
              throw StateError('Account changed');
            }
            content.entries[key] = body;
            content.dates[key] = now();
            prepared++;
            notifyListeners();
          }
        }),
      );
      await _persist(content);
    } catch (_) {
      preparationError = 'Chưa tải đủ dữ liệu. Kiểm tra mạng và thử lại.';
      if (!content.retired) {
        try {
          await _persist(content);
        } catch (_) {}
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _changes.close();
    super.dispose();
  }
}
