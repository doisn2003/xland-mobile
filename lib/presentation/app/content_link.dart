/// Canonical public paths are shared by API, web pages and native deep links.
enum ContentKind { properties, videos, events }

final class ContentLink {
  const ContentLink(this.kind, this.id);
  final ContentKind kind;
  final String id;

  static const host = String.fromEnvironment(
    'XLAND_SHARE_HOST',
    defaultValue: 'xland-server-production.up.railway.app',
  );
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static ContentLink? parse(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasPort) return null;
    if (uri.hasScheme) {
      if (!(uri.scheme == 'https' && uri.host == host) &&
          !(uri.scheme == 'xland' && uri.host == 'share')) {
        return null;
      }
    } else if (uri.hasAuthority || !uri.path.startsWith('/')) {
      return null;
    }
    // Queries (e.g. campaign tags) never supply the content identity.
    final List<String> segments;
    try {
      segments = uri.pathSegments;
    } on FormatException {
      return null;
    }
    if (segments.length != 2 || !_uuid.hasMatch(segments[1])) return null;
    for (final kind in ContentKind.values) {
      if (kind.name == segments[0]) {
        return ContentLink(kind, segments[1].toLowerCase());
      }
    }
    return null;
  }
}
