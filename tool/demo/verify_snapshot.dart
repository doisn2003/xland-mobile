import 'dart:convert';
import 'dart:io';

import 'package:xland_mobile/data/demo/prepared_snapshot.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';
import 'package:xland_mobile/data/maps/remote_area_map_repository.dart';

void main() {
  final file = File('assets/prepared-demo/snapshot.json');
  final snapshot = PreparedSnapshot.fromJson(
    jsonDecode(file.readAsStringSync()) as Json,
  );
  var parsed = 0;
  for (final entry in snapshot.entries.entries) {
    final path = entry.key.split('?').first,
        body = entry.value! as Json,
        data = body['data'];
    if (!PreparedSnapshot.isPublic(path)) {
      throw StateError('Non-public snapshot endpoint');
    }
    void each(Object? value, Object? Function(Object?) mapper) {
      if (value is List) {
        for (final item in value) {
          mapper(item);
          parsed++;
        }
      } else {
        mapper(value);
        parsed++;
      }
    }

    if (path == '/properties' ||
        RegExp(r'^/consultants/[^/]+/properties$').hasMatch(path)) {
      each(data, mapProperty);
    } else if (RegExp(r'^/properties/[^/]+$').hasMatch(path)) {
      each(data, mapProperty);
    } else if (path == '/feed' ||
        RegExp(r'^/(authors|consultants)/[^/]+/videos$').hasMatch(path) ||
        RegExp(r'^/videos/[^/]+$').hasMatch(path)) {
      each(data, mapFeedVideo);
    } else if (path.endsWith('/legal')) {
      each(data, mapLegalSummary);
    } else if (path.endsWith('/area')) {
      each(data, mapAreaInfo);
    } else if (path.endsWith('/area-map')) {
      mapAreaPresentation(
        data,
        path.split('/')[2],
        Uri.parse(snapshot.apiOrigin),
      );
      parsed++;
    } else if (path.startsWith('/catalog/')) {
      each(data, mapFilterCatalog);
    } else if (path.endsWith('/share')) {
      each(data, mapShareLink);
    } else if (RegExp(r'^/consultants/[^/]+$').hasMatch(path)) {
      each(data, mapConsultant);
    } else if (path.endsWith('/reviews')) {
      each(data, mapConsultantReview);
    } else if (RegExp(r'^/authors/[^/]+$').hasMatch(path)) {
      each(data, mapAuthorProfile);
    } else if (path == '/events' || RegExp(r'^/events/[^/]+$').hasMatch(path)) {
      each(data, mapXlandEvent);
    } else if (path == '/clubs' || RegExp(r'^/clubs/[^/]+$').hasMatch(path)) {
      each(data, mapClub);
    }
  }
  for (final raw in snapshot.media.values) {
    final item = raw! as Json, asset = item['asset']! as String;
    if (!asset.startsWith('assets/prepared-demo/media/') ||
        File(asset).lengthSync() != item['bytes']) {
      throw StateError('Invalid prepared asset');
    }
  }
  for (final raw in snapshot.tiles.values) {
    final asset = raw! as String;
    if (!asset.startsWith('assets/prepared-demo/tiles/') ||
        !File(asset).existsSync()) {
      throw StateError('Invalid tile');
    }
  }
  stdout.writeln(
    jsonEncode({
      'parsedWireRecords': parsed,
      'endpoints': snapshot.entries.length,
      'media': snapshot.media.length,
      'tiles': snapshot.tiles.length,
      'status': 'passed',
    }),
  );
}
