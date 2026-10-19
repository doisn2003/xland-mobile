import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Explicit single-attempt transport. Retrying a provider failure consumes quota.
class XlandMapTileProvider extends NetworkTileProvider {
  factory XlandMapTileProvider() => XlandMapTileProvider._(http.Client());
  XlandMapTileProvider._(this.client)
    : super(httpClient: client, attemptDecodeOfHttpErrorResponses: false);
  final http.Client client;
  @override
  Future<void> dispose() async {
    client.close();
    await super.dispose();
  }
}
