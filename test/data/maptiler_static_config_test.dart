import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/providers/maptiler_static_config.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

const area = ApproximateLocation(
  latitude: 21,
  longitude: 105.5,
  radiusM: 2000,
  label: 'DEMO approximate',
);
void main() {
  test('unlicensed/missing key cannot enable candidate map', () {
    expect(
      () => MapTilerStaticConfig(
        key: 'synthetic',
        licensedPlanConfirmed: false,
      ).endpoint(area),
      throwsA(isA<XlandFailure>()),
    );
    expect(
      () => MapTilerStaticConfig(
        key: '',
        licensedPlanConfirmed: true,
      ).endpoint(area),
      throwsA(isA<XlandFailure>()),
    );
  });
  test('approved factory uses public center, attribution, documented lon/lat path; no parcel marker', () {
    final u = MapTilerStaticConfig(
      key: 'SYNTHETIC_TEST_KEY',
      licensedPlanConfirmed: true,
    ).endpoint(area);
    expect(u.scheme, 'https');
    expect(u.host, 'api.maptiler.com');
    expect(u.path, contains('/static/105.5,21.0,'));
    expect(u.queryParameters['attribution'], 'bottomright');
    expect(u.queryParameters.containsKey('markers'), isFalse);
  });
  test('invalid style/dimension rejected before network', () {
    expect(
      () => MapTilerStaticConfig(
        key: 'synthetic',
        licensedPlanConfirmed: true,
        mapId: '../private',
      ).endpoint(area),
      throwsArgumentError,
    );
    expect(
      () => MapTilerStaticConfig(
        key: 'synthetic',
        licensedPlanConfirmed: true,
        width: 2049,
      ).endpoint(area),
      throwsArgumentError,
    );
  });
}
