enum AreaMapAvailability { ready, unconfigured, invalidArea, unavailable }

enum AreaMapCategory {
  all('all', 'Khu vực'),
  school('school', 'Trường học'),
  hospital('hospital', 'Bệnh viện'),
  park('park', 'Công viên');

  const AreaMapCategory(this.wire, this.label);
  final String wire;
  final String label;
}

final class PublicMapArea {
  const PublicMapArea({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.initialZoom,
    this.checkedAt,
    this.sourceUpdatedAt,
  });
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final int radiusM;
  final int initialZoom;
  final DateTime? checkedAt;
  final DateTime? sourceUpdatedAt;
}

final class MapAttribution {
  const MapAttribution(this.label, this.url);
  final String label;
  final Uri url;
}

final class AreaMapPresentation {
  const AreaMapPresentation({
    required this.propertyId,
    required this.availability,
    required this.notice,
    this.area,
    this.embedPageUrl,
    this.externalAreaMapUrl,
    this.externalDirectionsUrl,
    this.tileUrlTemplate,
    this.areaLabel,
    this.attributions = const [],
  });
  final String propertyId;
  final AreaMapAvailability availability;
  final String notice;
  final PublicMapArea? area;
  final Uri? embedPageUrl;
  final Uri? externalAreaMapUrl;
  final Uri? externalDirectionsUrl;
  final String? tileUrlTemplate;
  final String? areaLabel;
  final List<MapAttribution> attributions;
  bool get isReady =>
      availability == AreaMapAvailability.ready &&
      area != null &&
      tileUrlTemplate != null;
}

abstract interface class AreaMapRepository {
  Future<AreaMapPresentation> getAreaMap(String propertyId);
}

/// Safe composition fallback; never creates a map using the old property coordinates.
final class UnconfiguredAreaMapRepository implements AreaMapRepository {
  const UnconfiguredAreaMapRepository();
  @override
  Future<AreaMapPresentation> getAreaMap(String propertyId) async =>
      AreaMapPresentation(
        propertyId: propertyId,
        availability: AreaMapAvailability.unconfigured,
        notice:
            'Bản đồ chưa được cấu hình. '
            'Bản đồ khu vực không thể hiện vị trí lô đất.',
      );
}
