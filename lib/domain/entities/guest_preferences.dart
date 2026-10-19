/// Device-local playback choices, independent of any signed-in account.
final class GuestPlaybackPreferences {
  const GuestPlaybackPreferences({
    this.feedAutoplay = true,
    this.feedMutedByDefault = false,
  });
  final bool feedAutoplay;
  final bool feedMutedByDefault;
}

final class GuestPreferenceUpdate {
  const GuestPreferenceUpdate({this.feedAutoplay, this.feedMutedByDefault});
  final bool? feedAutoplay;
  final bool? feedMutedByDefault;
}

abstract interface class GuestPreferencesRepository {
  Future<GuestPlaybackPreferences> read();
  Future<GuestPlaybackPreferences> update(GuestPreferenceUpdate input);
  Future<void> clear();
}
