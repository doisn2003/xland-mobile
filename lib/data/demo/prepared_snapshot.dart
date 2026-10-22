import 'dart:convert';

import '../datasources/remote/api_transport.dart';
import '../../domain/failures/xland_failure.dart';

typedef Json = Map<String, Object?>;

/// Public content only. Authentication, inventory and mutations never use this.
final class PreparedSnapshot {
  PreparedSnapshot.fromJson(Json json)
    : preparedAt = DateTime.parse(json['preparedAt']! as String),
      apiOrigin = json['apiOrigin']! as String,
      entries = Map<String, Object?>.from(json['entries']! as Map),
      media = Map<String, Object?>.from(json['media']! as Map),
      tiles = Map<String, Object?>.from(json['tiles']! as Map) {
    if (json['version'] != 1) throw const FormatException('Snapshot version');
  }
  final DateTime preparedAt;
  final String apiOrigin;
  final Json entries, media, tiles;
  static const maxAge = Duration(hours: 36);

  static bool isPublic(String path) =>
      path == '/properties' ||
      path == '/properties/count' ||
      path == '/feed' ||
      path == '/events' ||
      path == '/clubs' ||
      path == '/catalog/locations' ||
      RegExp(r'^/properties/[^/]+(?:/(?:legal|area|area-map|share))?$')
          .hasMatch(path) ||
      RegExp(r'^/videos/[^/]+(?:/share)?$').hasMatch(path) ||
      RegExp(r'^/authors/[^/]+(?:/videos)?$').hasMatch(path) ||
      RegExp(r'^/consultants/[^/]+(?:/(?:videos|properties|reviews))?$')
          .hasMatch(path) ||
      RegExp(r'^/events/[^/]+(?:/share)?$').hasMatch(path) ||
      RegExp(r'^/clubs/[^/]+$').hasMatch(path);

  static bool isList(String path) =>
      const {'/properties', '/feed', '/events', '/clubs'}.contains(path) ||
      RegExp(r'^/(?:authors|consultants)/[^/]+/(?:videos|properties|reviews)$')
          .hasMatch(path);

  static String key(ApiRequest request) => request.path == '/properties/count'
      ? '/properties'
      : request.path == '/catalog/locations' &&
            request.query['provinceCode'] != null
      ? '${request.path}?provinceCode=${request.query['provinceCode']}'
      : request.path;

  static Json copy(Json value) => jsonDecode(jsonEncode(value)) as Json;

  ApiResponse project(ApiRequest request, Json stored, Json all) {
    final body = copy(stored);
    final data = body['data'];
    if (isList(key(request))) {
      var rows = (data! as List).cast<Json>().toList();
      final q = request.query;
      var selected = 0;
      if (key(request).endsWith('properties')) {
        bool chosen(String name) => q[name] != null && q[name]!.isNotEmpty;
        if (chosen('query')) {
          selected++;
          final text = q['query']!.trim().toLowerCase();
          rows = rows
              .where(
                (p) => [
                  'title',
                  'code',
                  'provinceName',
                  'districtName',
                ].any((k) => '${p[k]}'.toLowerCase().contains(text)),
              )
              .toList();
        }
        for (final pair in [
          ('regions', 'region'),
          ('category', 'category'),
          ('provinceCode', 'provinceCode'),
          ('districtCode', 'districtCode'),
          ('landTypes', 'landType'),
        ]) {
          if (!chosen(pair.$1)) continue;
          selected++;
          final values = q[pair.$1]!.split(',');
          rows = rows.where((p) => values.contains(p[pair.$2])).toList();
        }
        if (chosen('minPriceVnd') || chosen('maxPriceVnd')) selected++;
        if (chosen('minPriceVnd')) {
          rows = rows
              .where(
                (p) =>
                    BigInt.parse('${p['priceTotal']}') >=
                    BigInt.parse(q['minPriceVnd']!),
              )
              .toList();
        }
        if (chosen('maxPriceVnd')) {
          rows = rows
              .where(
                (p) =>
                    BigInt.parse('${p['priceTotal']}') <=
                    BigInt.parse(q['maxPriceVnd']!),
              )
              .toList();
        }
        if (chosen('areaBands')) {
          selected++;
          final bands = q['areaBands']!.split(',');
          rows = rows.where((p) {
            final area = double.parse('${p['areaM2']}');
            return bands.any(
              (b) => switch (b) {
                'below_100' => area < 100,
                'from_100_to_200' => area >= 100 && area <= 200,
                'above_200' => area > 200,
                _ => false,
              },
            );
          }).toList();
        }
        if (chosen('minRoadWidthM')) {
          selected++;
          rows = rows
              .where(
                (p) =>
                    p['roadWidthM'] != null &&
                    double.parse('${p['roadWidthM']}') >=
                        double.parse(q['minRoadWidthM']!),
              )
              .toList();
        }
        if (chosen('hasDocuments')) {
          selected++;
          rows = rows.where((p) {
            final legal = all['/properties/${p['id']}/legal'] as Json?;
            final documents = (legal?['data'] as Json?)?['documents'] as List?;
            return (documents?.isNotEmpty ?? false) ==
                (q['hasDocuments'] == 'true');
          }).toList();
        }
        if (q['savedOnly'] == 'true') {
          rows = rows.where((p) => p['isSaved'] == true).toList();
        }
        final sort = q['sort'];
        if (sort == 'price_asc' || sort == 'price_desc') {
          rows.sort((a, b) {
            final cmp = BigInt.parse('${a['priceTotal']}')
                .compareTo(BigInt.parse('${b['priceTotal']}'));
            return sort == 'price_desc' ? -cmp : cmp;
          });
        } else if (sort == 'area_asc') {
          rows.sort(
            (a, b) =>
                double.parse('${a['areaM2']}')
                    .compareTo(double.parse('${b['areaM2']}')),
          );
        } else {
          rows.sort(
            (a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}'),
          );
        }
      } else if (request.path == '/feed') {
        rows = rows.where((v) {
          final p = v['property'] as Json;
          return (q['region'] == null || p['region'] == q['region']) &&
              (q['category'] == null || p['category'] == q['category']);
        }).toList();
      } else if (request.path == '/events' && q['status'] != null) {
        rows = rows.where((e) => e['status'] == q['status']).toList();
      }
      if (request.path == '/properties/count') {
        return ApiResponse(
          statusCode: 200,
          body: {
            'data': {'total': rows.length, 'selectedCriteriaCount': selected},
          },
        );
      }
      final cursor = q['cursor'];
      final offset = cursor == null
          ? 0
          : int.tryParse(cursor.replaceFirst('prepared:', ''));
      final limit = int.tryParse(q['limit'] ?? '20') ?? 20;
      if (offset == null ||
          offset < 0 ||
          limit < 1 ||
          limit > 50 ||
          (cursor != null && !cursor.startsWith('prepared:'))) {
        throw const XlandFailure(
          code: FailureCode.invalidInput,
          message: 'Vui lòng tải lại danh sách.',
        );
      }
      final page = rows.skip(offset).take(limit).toList();
      final more = offset + page.length < rows.length;
      return ApiResponse(
        statusCode: 200,
        body: {
          'data': page,
          'meta': {
            'total': rows.length,
            'hasMore': more,
            'nextCursor': more ? 'prepared:${offset + page.length}' : null,
            'selectedCriteriaCount': selected,
          },
        },
      );
    }
    if (request.path.endsWith('/area') && request.query['category'] != null) {
      final area = body['data']! as Json;
      area['amenities'] = (area['amenities']! as List)
          .cast<Json>()
          .where((a) => a['category'] == request.query['category'])
          .toList();
    }
    return ApiResponse(statusCode: 200, body: body);
  }
}
