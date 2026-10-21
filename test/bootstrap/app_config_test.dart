import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/bootstrap/app_config.dart';

void main() {
  test('environment label follows the resolved API, including Railway debug', () {
    expect(
      AppConfig.resolve(release: false, android: true).apiEnvironmentLabel,
      'API LOCAL',
    );
    for (final release in [false, true]) {
      expect(
        AppConfig.resolve(
          release: release,
          android: true,
          configuredApi: 'https://xland-server-production.up.railway.app/api/v1',
        ).apiEnvironmentLabel,
        'API RAILWAY',
      );
    }
    expect(
      AppConfig.resolve(
        release: false,
        android: true,
        configuredApi: 'https://api.xland.vn/api/v1',
      ).apiEnvironmentLabel,
      'API REMOTE',
    );
  });
  test(
    'release rejects local defaults, unsafe endpoints and demo overrides',
    () {
      for (final endpoint in [
        '',
        'http://api.xland.vn/api/v1',
        'https://localhost/api/v1',
        'https://api.xland.vn/',
        'https://secret@api.xland.vn/api/v1',
        'https://api.xland.vn/api/v1?key=secret',
        'https://api.xland.vn/api/v1#fragment',
      ]) {
        expect(
          () => AppConfig.resolve(
            release: true,
            android: true,
            configuredApi: endpoint,
          ),
          throwsStateError,
        );
      }
      expect(
        () => AppConfig.resolve(
          release: true,
          android: true,
          configuredApi: 'https://api.xland.vn/api/v1',
          demoMedia: 'http://localhost',
        ),
        throwsStateError,
      );
      expect(
        () => AppConfig.resolve(
          release: true,
          android: true,
          configuredApi: 'https://api.xland.vn/api/v1',
          reportMode: true,
        ),
        throwsStateError,
      );
      expect(
        AppConfig.resolve(
          release: true,
          android: true,
          configuredApi: 'https://api.xland.vn/api/v1',
        ).apiBaseUrl.host,
        'api.xland.vn',
      );
    },
  );
  test('debug retains the explicit emulator/loopback development paths', () {
    expect(
      AppConfig.resolve(release: false, android: true).apiBaseUrl.host,
      '10.0.2.2',
    );
    expect(
      AppConfig.resolve(release: false, android: false).apiBaseUrl.host,
      '127.0.0.1',
    );
    expect(
      () => AppConfig.resolve(
        release: false,
        android: true,
        configuredApi: 'http://external.example/api/v1',
      ),
      throwsStateError,
    );
  });
}
