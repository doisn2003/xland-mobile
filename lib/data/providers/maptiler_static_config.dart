import 'dart:math' as math;

import '../../domain/xland_domain.dart';

/// A-15 candidate. Pure URL factory, disabled until operator confirms licensed
/// plan, restricted key and attribution. No account/signup or network here.
final class MapTilerStaticConfig {
  MapTilerStaticConfig({
    required this.key,
    required this.licensedPlanConfirmed,
    this.mapId = 'streets-v4',
    this.width = 640,
    this.height = 400,
  });
  final String key;
  final bool licensedPlanConfirmed;
  final String mapId;
  final int width;
  final int height;
  static const attribution = '© MapTiler © OpenStreetMap contributors';
  Uri endpoint(ApproximateLocation location) {
    if (!licensedPlanConfirmed || key.trim().isEmpty) {
      throw const XlandFailure(
        code: FailureCode.featureNotEnabled,
        message: 'Chưa cấp cấu hình bản đồ được phép sử dụng',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(mapId) ||
        width < 1 ||
        width > 2048 ||
        height < 1 ||
        height > 2048 ||
        location.radiusM <= 0 ||
        !location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude.abs() > 85 ||
        location.longitude.abs() > 180) {
      throw ArgumentError(
        'Valid approximate area and static map dimensions required',
      );
    }
    // MapTiler static API uses a 512px tile pyramid. Fit the public radius with
    // padding; never add a parcel marker, address or exact-coordinate source.
    final resolution = 2 * location.radiusM / (math.min(width, height) * 0.75);
    final z =
        (math.log(
                  78271.516964 *
                      math.cos(location.latitude * math.pi / 180) /
                      resolution,
                ) /
                math.ln2)
            .floor()
            .clamp(0, 18);
    return Uri.https(
      'api.maptiler.com',
      '/maps/$mapId/static/${location.longitude},${location.latitude},$z/${width}x$height.png',
      {'key': key, 'attribution': 'bottomright'},
    );
  }
}
