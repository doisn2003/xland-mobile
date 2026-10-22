import 'prepared_snapshot.dart';

/// Installed only by main_demo.dart. HTTPS wire values stay unchanged.
abstract final class PreparedMedia {
  static PreparedSnapshot? snapshot;
  static String? asset(Uri url) {
    final item = snapshot?.media[url.toString()] as Json?;
    return item?['asset'] as String?;
  }

  static String? tile(String url) => snapshot?.tiles[url] as String?;
}
