import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import '../demo/prepared_media.dart';

/// Explicit single-attempt transport. Retrying a provider failure consumes quota.
class XlandMapTileProvider extends NetworkTileProvider {
  factory XlandMapTileProvider() => XlandMapTileProvider._(http.Client());
  XlandMapTileProvider._(this.client)
    : super(httpClient: client, attemptDecodeOfHttpErrorResponses: false);
  final http.Client client;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final origin = PreparedMedia.snapshot?.apiOrigin;
    if (origin != null) {
      final url =
          '${Uri.parse(origin).origin}/maps/tiles/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
      final asset = PreparedMedia.tile(url);
      if (asset != null) return AssetImage(asset);
    }
    return super.getImage(coordinates, options);
  }

  @override
  Future<void> dispose() async {
    client.close();
    await super.dispose();
  }
}
