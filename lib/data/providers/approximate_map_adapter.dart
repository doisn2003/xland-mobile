import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/xland_domain.dart';

/// Provider boundary only. An approved endpoint factory/license is still needed.
/// The factory receives the public approximate location, never a parcel address.
final class ApproximateMapAdapter {
  const ApproximateMapAdapter({
    required this.client,
    this.endpoint,
    this.allowedHost,
    this.attribution = '',
    this.timeout = const Duration(seconds: 15),
  });
  final http.Client client;
  final Uri Function(ApproximateLocation)? endpoint;
  final String? allowedHost;
  final String attribution;
  final Duration timeout;

  Future<Uint8List> load(ApproximateLocation approximate) async {
    if (endpoint == null || allowedHost == null || attribution.trim().isEmpty) {
      throw const XlandFailure(
        code: FailureCode.featureNotEnabled,
        message: 'Chưa cấu hình nhà cung cấp bản đồ',
      );
    }
    if (approximate.radiusM <= 0 ||
        !approximate.latitude.isFinite ||
        !approximate.longitude.isFinite ||
        approximate.latitude.abs() > 90 ||
        approximate.longitude.abs() > 180) {
      throw ArgumentError('Public approximate location/radius required');
    }
    final uri = endpoint!(approximate);
    if (uri.scheme != 'https' ||
        uri.host != allowedHost ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw ArgumentError('Approved HTTPS map host required');
    }
    try {
      // Disable redirects so the approved host cannot redirect a key elsewhere.
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode == 429) {
        throw const XlandFailure(
          code: FailureCode.rateLimited,
          message: 'Bản đồ tạm đạt giới hạn sử dụng',
        );
      }
      if (response.statusCode != 200) {
        throw const XlandFailure(
          code: FailureCode.upstreamUnavailable,
          message: 'Không tải được bản đồ',
        );
      }
      final mime = response.headers['content-type']?.split(';').first.trim();
      if (!{'image/png', 'image/jpeg', 'image/webp'}.contains(mime)) {
        throw const FormatException('Unexpected map MIME');
      }
      const maximum = 5 * 1024 * 1024;
      if ((response.contentLength ?? 0) > maximum) {
        throw const FormatException('Map payload too large');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(timeout)) {
        if (bytes.length + chunk.length > maximum) {
          throw const FormatException('Map payload too large');
        }
        bytes.add(chunk);
      }
      if (bytes.isEmpty) throw const FormatException('Empty map payload');
      return bytes.takeBytes();
    } on TimeoutException {
      throw const XlandFailure(
        code: FailureCode.timeout,
        message: 'Tải bản đồ quá thời gian',
      );
    } on http.ClientException {
      throw const XlandFailure(
        code: FailureCode.offline,
        message: 'Không có kết nối bản đồ',
      );
    } on FormatException {
      throw const XlandFailure(
        code: FailureCode.upstreamUnavailable,
        message: 'Dữ liệu bản đồ không hợp lệ',
      );
    }
  }
}
