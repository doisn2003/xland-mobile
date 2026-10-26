import '../../domain/maps/area_map.dart';
import '../../domain/failures/xland_failure.dart';
import '../repositories/remote_repositories.dart';

class RemoteAreaMapRepository implements AreaMapRepository {
  RemoteAreaMapRepository(
    this.gateway, {
    required this.apiBaseUrl,
    this.allowLocalHttp = false,
  });
  final RemoteGateway gateway;
  final Uri apiBaseUrl;
  final bool allowLocalHttp;
  @override
  Future<AreaMapPresentation> getAreaMap(String propertyId) async {
    if (!RegExp(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
        .hasMatch(propertyId)) {
      throw const XlandFailure(
        code: FailureCode.invalidInput,
        message: 'Mã lô đất không hợp lệ',
      );
    }
    return gateway.request(
      'AM01',
      'GET',
      '/properties/$propertyId/area-map',
      (value) => mapAreaPresentation(
        value,
        propertyId,
        apiBaseUrl,
        allowLocalHttp: allowLocalHttp,
      ),
    );
  }
}

AreaMapPresentation mapAreaPresentation(
  Object? raw,
  String propertyId,
  Uri apiBaseUrl, {
  bool allowLocalHttp = false,
}) {
  final data = _object(raw);
  if (!data.keys.toSet().containsAll({
    'propertyId',
    'availability',
    'publicArea',
    'areaLabel',
    'provider',
    'poiMode',
    'attribution',
    'notice',
    'externalAreaMapUrl',
    'externalDirectionsUrl',
    'tilePathTemplate',
  })) {
    throw const FormatException('Missing area map fields');
  }
  if (_string(data['propertyId']) != propertyId) {
    throw const FormatException('Area map property mismatch');
  }
  final availability = switch (_string(data['availability'])) {
    'ready' => AreaMapAvailability.ready,
    'unconfigured' => AreaMapAvailability.unconfigured,
    'invalid_area' => AreaMapAvailability.invalidArea,
    'unavailable' => AreaMapAvailability.unavailable,
    _ => throw const FormatException('Unknown area map capability'),
  };
  final label = data['areaLabel'] == null ? null : _string(data['areaLabel']);
  PublicMapArea? area;
  if (data['publicArea'] != null) {
    final a = _object(data['publicArea']);
    final id = _string(a['id']);
    final lat = _number(a['centerLatitude']),
        lng = _number(a['centerLongitude']);
    final radius = _integer(a['radiusM']), zoom = _integer(a['initialZoom']);
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id) ||
        a['precision'] != 'administrative_area' ||
        lat < 8 ||
        lat > 24 ||
        lng < 102 ||
        lng > 110 ||
        radius <= 0 ||
        radius > 100000 ||
        zoom < 6 ||
        zoom > 16 ||
        a['label'] != label) {
      throw const FormatException('Invalid administrative area');
    }
    area = PublicMapArea(
      id: id,
      label: _string(a['label']),
      latitude: lat,
      longitude: lng,
      radiusM: radius,
      initialZoom: zoom,
      checkedAt: _date(a['checkedAt']),
      sourceUpdatedAt: _date(a['sourceUpdatedAt']),
    );
  }
  Uri? googleLink(Object? value, bool directions) {
    if (value == null) return null;
    final uri = _https(value);
    final field = directions ? 'destination' : 'query';
    if (label == null ||
        uri.host != 'www.google.com' ||
        uri.port != 443 ||
        uri.path != (directions ? '/maps/dir/' : '/maps/search/') ||
        uri.queryParameters['api'] != '1' ||
        uri.queryParameters[field] != label ||
        uri.queryParametersAll.values.any((v) => v.length != 1) ||
        uri.queryParameters.keys.any((k) => !{'api', field}.contains(k))) {
      throw const FormatException('Invalid Google area link');
    }
    return uri;
  }

  final external = googleLink(data['externalAreaMapUrl'], false);
  final directions = googleLink(data['externalDirectionsUrl'], true);
  const attributionUrls = {
    'https://www.openstreetmap.org/copyright',
    'https://www.geoapify.com/',
  };
  final rawCredits = data['attribution'];
  if (rawCredits is! List<Object?>) {
    throw const FormatException('Invalid map attribution');
  }
  final credits = rawCredits
      .map((raw) {
        final a = _object(raw);
        final url = _https(a['url']);
        if (!attributionUrls.contains(url.toString())) {
          throw const FormatException('Unknown attribution');
        }
        return MapAttribution(_string(a['label']), url);
      })
      .toList(growable: false);
  String? tileUrl;
  if (availability == AreaMapAvailability.ready) {
    if (area == null ||
        data['provider'] != 'geoapify' ||
        data['poiMode'] != 'none' ||
        data['tilePathTemplate'] != '/maps/tiles/{z}/{x}/{y}.png' ||
        data['embedPageUrl'] != null ||
        !credits
            .map((c) => c.url.toString())
            .toSet()
            .containsAll(attributionUrls)) {
      throw const FormatException('Incomplete Geoapify map readiness');
    }
    final isLocal =
        allowLocalHttp &&
        !const bool.fromEnvironment('dart.vm.product') &&
        apiBaseUrl.scheme == 'http' &&
        {'localhost', '127.0.0.1', '10.0.2.2', '::1'}.contains(apiBaseUrl.host);
    if ((!isLocal && apiBaseUrl.scheme != 'https') ||
        apiBaseUrl.host.isEmpty ||
        apiBaseUrl.userInfo.isNotEmpty ||
        apiBaseUrl.hasQuery ||
        apiBaseUrl.hasFragment) {
      throw const FormatException('Unapproved map server');
    }
    tileUrl = '${apiBaseUrl.origin}/maps/tiles/{z}/{x}/{y}.png';
  } else if (data['provider'] != 'none' ||
      data['poiMode'] != 'none' ||
      data['tilePathTemplate'] != null ||
      data['embedPageUrl'] != null) {
    throw const FormatException('Disabled map contains active provider');
  }
  return AreaMapPresentation(
    propertyId: propertyId,
    availability: availability,
    notice: _string(data['notice']),
    area: area,
    areaLabel: label,
    tileUrlTemplate: tileUrl,
    externalAreaMapUrl: external,
    externalDirectionsUrl: directions,
    attributions: List.unmodifiable(credits),
    planning: _planning(
      data['planning'],
      tileUrl == null ? null : apiBaseUrl.origin,
    ),
  );
}

// Optional capability: malformed planning metadata never breaks the Geoapify map.
PlanningOverlay? _planning(Object? raw, String? origin) {
  if (raw == null) {
    return null; // Backward compatible with older API deployments.
  }
  String? region;
  try {
    final data = _object(raw);
    if (data['availability'] == 'not_supported') return null;
    final value = _string(data['region']);
    if (!{'ha-noi', 'hai-phong'}.contains(value)) return null;
    region = value;
    final availability = switch (_string(data['availability'])) {
      'ready' => PlanningAvailability.ready,
      'unconfigured' => PlanningAvailability.unconfigured,
      'unavailable' => PlanningAvailability.unavailable,
      _ => throw const FormatException('Invalid planning status'),
    };
    final notice = _string(data['notice']);
    if (availability != PlanningAvailability.ready) {
      if (data['source'] != null) {
        throw const FormatException('Inactive planning source');
      }
      return PlanningOverlay(
        availability: availability,
        region: region,
        notice: notice,
      );
    }
    if (origin == null) {
      throw const FormatException('Planning needs a base map');
    }
    final source = _object(data['source']);
    final revision = _string(source['revision']);
    final minZoom = _integer(source['minZoom']);
    final maxZoom = _integer(source['maxNativeZoom']);
    final path = '/maps/planning/$region/$revision/{z}/{x}/{y}.png';
    if (!RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$').hasMatch(revision) ||
        source['tilePathTemplate'] != path ||
        minZoom < 6 ||
        maxZoom > 19 ||
        minZoom > maxZoom) {
      throw const FormatException('Invalid planning tiles');
    }
    PlanningBounds? bounds;
    if (source['coverageBounds'] != null) {
      final rawBounds = source['coverageBounds'];
      if (rawBounds is! List<Object?> || rawBounds.length != 4) {
        throw const FormatException('Invalid coverage bounds');
      }
      final b = rawBounds.map(_number).toList(growable: false);
      if (b[0] < 8 ||
          b[2] > 24 ||
          b[1] < 102 ||
          b[3] > 110 ||
          b[0] >= b[2] ||
          b[1] >= b[3]) {
        throw const FormatException('Invalid coverage extent');
      }
      bounds = PlanningBounds(b[0], b[1], b[2], b[3]);
    }
    return PlanningOverlay(
      availability: availability,
      region: region,
      notice: notice,
      source: PlanningSource(
        label: _string(source['label']),
        sourceUrl: _https(source['sourceUrl']),
        legendUrl: source['legendUrl'] == null
            ? null
            : _https(source['legendUrl']),
        revision: revision,
        tileUrlTemplate: '$origin$path',
        minZoom: minZoom,
        maxNativeZoom: maxZoom,
        publishedAt: _date(source['publishedAt']),
        coverageBounds: bounds,
      ),
    );
  } on FormatException {
    if (region == null) return null;
    return PlanningOverlay(
      availability: PlanningAvailability.unavailable,
      region: region,
      notice:
          'Chưa tải được cấu hình lớp quy hoạch. Bản đồ nền vẫn sử dụng được.',
    );
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected map object');
  }
  return value;
}

String _string(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Expected map text');
  }
  return value;
}

double _number(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Expected finite number');
  }
  return value.toDouble();
}

int _integer(Object? value) {
  if (value is! int) throw const FormatException('Expected integer');
  return value;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  final text = _string(value), date = DateTime.tryParse(_string(value));
  if (date == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(text)) {
    throw const FormatException('Expected timestamp');
  }
  return date.toUtc();
}

Uri _https(Object? value) {
  final uri = Uri.tryParse(_string(value));
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException('Expected HTTPS URL');
  }
  return uri;
}
