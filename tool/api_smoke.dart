import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _PrivateSession implements SessionStore {
  String? _token;
  @override
  Future<String?> readAccessToken() async => _token;
  @override
  Future<void> saveAccessToken({required String accessToken}) async {
    _token = accessToken;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

Future<void> main() async {
  final local = File('../xland-server/.env.local').readAsLinesSync();
  if (!local.first.startsWith('# XLAND_LOCAL_P2_GENERATED')) {
    throw StateError('Refuse unmanaged credential environment');
  }
  final config = <String, String>{};
  for (final line in local) {
    final index = line.indexOf('=');
    if (index > 0 && !line.startsWith('#')) {
      config[line.substring(0, index)] = line.substring(index + 1);
    }
  }
  final client = http.Client();
  final sessions = _PrivateSession();
  final gateway = RemoteGateway(
    HttpApiTransport(
      baseUrl: Uri.parse('http://127.0.0.1:3000/api/v1'),
      client: client,
      sessions: sessions,
      allowLocalHttp: true,
    ),
  );
  final account = RemoteAccountRepository(gateway, sessions);
  final properties = RemotePropertyRepository(gateway);
  try {
    const filter = PropertyFilter(
      regions: [],
      areaBands: [],
      landTypes: [],
      savedOnly: false,
      sort: PropertySort.relevant,
    );
    final list = await properties.search(filter, const PageQuery());
    if (list.total != 4) throw StateError('Canonical property count mismatch');
    final profile = await account.signIn(
      SignInInput(
        username: config['DEMO_USERNAME']!,
        password: config['DEMO_PASSWORD']!,
      ),
    );
    final property = list.page.items.firstWhere(
      (item) => item.code == 'XL-028',
    );
    await properties.setSaved(property.id, true);
    if (!(await properties.getProperty(property.id)).isSaved) {
      throw StateError('Save was not persisted');
    }
    if (!property.isSaved) await properties.setSaved(property.id, false);
    final legal = await properties.getLegal(property.id);
    final area = await properties.getArea(property.id);
    if (legal.verifiedCount != 4 ||
        legal.totalCount != 6 ||
        area.location.radiusM <= 0) {
      throw StateError('Domain mapping mismatch');
    }
    await account.signOut();
    stdout.writeln(
      'PASS Dart → HTTP → PostgreSQL: guest search, opaque login, save/read/restore, legal4/6, area fallback, logout; credential/token redacted; profile read=${profile.profile.id.isNotEmpty}.',
    );
  } finally {
    client.close();
  }
}
