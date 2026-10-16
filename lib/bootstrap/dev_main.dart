import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/xland_domain.dart';
import '../data/datasources/local/secure_session_store.dart';
import '../data/datasources/remote/http_api_transport.dart';
import '../data/repositories/remote_repositories.dart';
import '../data/repositories/remaining_repositories.dart';
import '../presentation/app/xland_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DevComposition());
}

/// Explicit local API preview; does not replace P3 wiring/E2E acceptance.
class DevComposition extends StatefulWidget {
  const DevComposition({super.key});
  @override
  State<DevComposition> createState() => _DevCompositionState();
}

class _DevCompositionState extends State<DevComposition> {
  final _client = http.Client();
  late final XlandDependencies dependencies;
  @override
  void initState() {
    super.initState();
    const configured = String.fromEnvironment(
      'XLAND_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000/api/v1',
    );
    const sessions = SecureSessionStore(FlutterSecureStorage());
    final transport = HttpApiTransport(
      baseUrl: Uri.parse(configured),
      client: _client,
      sessions: sessions,
      allowLocalHttp: true,
    );
    final g = RemoteGateway(
      transport,
      availableOperations: const {
        'F01',
        'F02',
        'F03',
        'F04',
        'F05',
        'F06',
        'F07',
        'F08',
        'F09',
        'F10',
        'F11',
        'F12',
        'F13',
        'F14',
        'D01',
        'D02',
        'D03',
        'D04',
        'D05',
        'D06',
        'D07',
        'L01',
        'L02',
        'A01',
        'C01',
        'C02',
        'C03',
        'C04',
        'C05',
        'E01',
        'E02',
        'E03',
        'E04',
        'E05',
        'E06',
        'E07',
        'E08',
        'B01',
        'B02',
        'B03',
        'B04',
        'B05',
        'B06',
        'B07',
        'P01',
        'P02',
        'P03',
        'P04',
        'U01',
        'U03',
        'U04',
        'U05',
        'U06',
        'U07',
        'U08',
        'K01',
        'K02',
        'S01',
        'S02',
        'N01',
        'N02',
        'N03',
        'N04',
      },
    );
    dependencies = XlandDependencies(
      properties: RemotePropertyRepository(g),
      account: RemoteAccountRepository(g, sessions),
      feed: RemoteFeedRepository(g),
      consultants: RemoteConsultantRepository(g),
      events: RemoteEventRepository(g),
      bookings: RemoteBookingRepository(g),
      payments: RemotePaymentRepository(g),
      clubs: RemoteClubRepository(g),
      finance: RemoteFinanceRepository(g),
      support: RemoteSupportRepository(g),
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Banner(
      message: 'DEV · API LOCAL',
      location: BannerLocation.topEnd,
      child: XLandApp(dependencies: dependencies),
    ),
  );
}
