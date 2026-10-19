/// Token material belongs in data/platform secure storage, never UI entities.
abstract interface class SessionStore {
  Future<String?> readAccessToken();
  Future<void> saveAccessToken({required String accessToken});
  Future<void> clear();
  /// Compare and delete atomically with respect to token saves on this store.
  Future<void> clearIfMatches({required String accessToken});
}

abstract interface class SessionInvalidationSource {
  Stream<void> get sessionInvalidations;
}
