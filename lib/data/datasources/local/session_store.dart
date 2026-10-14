/// Token material belongs in data/platform secure storage, never UI entities.
abstract interface class SessionStore {
  Future<String?> readAccessToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}
