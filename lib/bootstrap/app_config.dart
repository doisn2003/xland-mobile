/// Build-time configuration shared by the normal app entry point.
final class AppConfig {
  const AppConfig._(this.apiBaseUrl);
  final Uri apiBaseUrl;

  static const _localHosts = {'localhost', '127.0.0.1', '10.0.2.2', '::1'};

  String get apiEnvironmentLabel {
    if (_localHosts.contains(apiBaseUrl.host)) return 'API LOCAL';
    if (apiBaseUrl.host.endsWith('.up.railway.app')) return 'API RAILWAY';
    return 'API REMOTE';
  }

  factory AppConfig.resolve({
    required bool release,
    required bool android,
    String configuredApi = '',
    String demoMedia = '',
    bool reportMode = false,
  }) {
    if (release &&
        (configuredApi.isEmpty || demoMedia.isNotEmpty || reportMode)) {
      throw StateError(
        'Release requires an explicit API and no demo overrides',
      );
    }
    final uri = Uri.tryParse(
      configuredApi.isEmpty
          ? 'http://${android ? '10.0.2.2' : '127.0.0.1'}:3002/api/v1'
          : configuredApi,
    );
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(r'^/api/v1/?$').hasMatch(uri.path) ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                !release &&
                _localHosts.contains(uri.host))) ||
        (release && _localHosts.contains(uri.host))) {
      throw StateError('API must be HTTPS /api/v1; local HTTP is debug-only');
    }
    return AppConfig._(uri);
  }
}
