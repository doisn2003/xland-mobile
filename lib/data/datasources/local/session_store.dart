/// Token material belongs in data/platform secure storage, never UI entities.
abstract interface class SessionStore {
  Future<String?> readAccessToken();
  Future<void> saveAccessToken({required String accessToken});
  Future<void> clear();
}
