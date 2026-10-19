import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/xland_domain.dart';

/// Uses the existing platform storage package with a separate, non-token key.
/// All operations share a queue so rapid patches cannot overwrite each other.
final class LocalGuestPreferencesRepository implements GuestPreferencesRepository {
  LocalGuestPreferencesRepository(this.storage);
  final FlutterSecureStorage storage;
  static const storageKey = 'xland.guest.preferences.v1';
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) async {
      try {
        return await operation();
      } catch (_) {
        throw const XlandFailure(
          code: FailureCode.internalError,
          message: 'Không thể lưu cài đặt trên thiết bị. Vui lòng thử lại.',
        );
      }
    });
    // A failed write must not poison subsequent retry/read operations.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<GuestPlaybackPreferences> _read() async {
    final raw = await storage.read(key: storageKey);
    if (raw == null) return const GuestPlaybackPreferences();
    try {
      final Object? value = jsonDecode(raw);
      if (value is Map<String, dynamic> && value['version'] == 1 &&
          value['feedAutoplay'] is bool && value['feedMutedByDefault'] is bool) {
        return GuestPlaybackPreferences(
          feedAutoplay: value['feedAutoplay'] as bool,
          feedMutedByDefault: value['feedMutedByDefault'] as bool,
        );
      }
    } on FormatException {
      // Malformed local data has no authority over playback or user identity.
    }
    return const GuestPlaybackPreferences();
  }

  @override
  Future<GuestPlaybackPreferences> read() => _serial(_read);

  @override
  Future<GuestPlaybackPreferences> update(GuestPreferenceUpdate input) => _serial(() async {
    final current = await _read();
    final next = GuestPlaybackPreferences(
      feedAutoplay: input.feedAutoplay ?? current.feedAutoplay,
      feedMutedByDefault: input.feedMutedByDefault ?? current.feedMutedByDefault,
    );
    await storage.write(key: storageKey, value: jsonEncode({
      'version': 1,
      'feedAutoplay': next.feedAutoplay,
      'feedMutedByDefault': next.feedMutedByDefault,
    }));
    return next;
  });

  @override
  Future<void> clear() => _serial(() => storage.delete(key: storageKey));
}
