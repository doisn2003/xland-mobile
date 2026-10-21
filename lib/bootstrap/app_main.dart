import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/xland_domain.dart';
import '../domain/maps/area_map.dart';
import '../data/maps/remote_area_map_repository.dart';
import '../data/maps/map_tile_provider.dart';
import '../presentation/features/area_map/area_map_scope.dart';
import '../data/datasources/local/secure_session_store.dart';
import '../data/datasources/remote/http_api_transport.dart';
import '../data/repositories/remote_repositories.dart';
import '../data/auth/remote_extended_auth_repository.dart';
import '../data/auth/google_identity_client.dart';
import '../data/repositories/remaining_repositories.dart';
import '../data/repositories/local_guest_preferences_repository.dart';
import '../data/demo/demo_media_repositories.dart';
import '../presentation/app/xland_app.dart';
import 'app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XlandComposition());
}

/// Shared application composition; release configuration cannot fall back to local API.
class XlandComposition extends StatefulWidget {
  const XlandComposition({super.key});
  @override
  State<XlandComposition> createState() => _XlandCompositionState();
}

class _XlandCompositionState extends State<XlandComposition> {
  final _client = http.Client();
  late final XlandDependencies dependencies;
  late final AreaMapRepository areaMaps;
  @override
  void initState() {
    super.initState();
    const configured = String.fromEnvironment('XLAND_API_BASE_URL');
    final config = AppConfig.resolve(
      release: kReleaseMode,
      android: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      configuredApi: configured,
      demoMedia: const String.fromEnvironment('XLAND_DEMO_MEDIA_BASE_URL'),
      reportMode: const bool.fromEnvironment('XLAND_REPORT_MODE'),
    );
    final sessions = SecureSessionStore(const FlutterSecureStorage());
    final transport = HttpApiTransport(
      baseUrl: config.apiBaseUrl,
      client: _client,
      sessions: sessions,
      allowLocalHttp: !kReleaseMode,
    );
    const demoMedia = String.fromEnvironment('XLAND_DEMO_MEDIA_BASE_URL');
    const demoScenario = String.fromEnvironment(
      'XLAND_DEMO_MEDIA_SCENARIO',
      defaultValue: 'normal',
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
        'F15',
        'F16',
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
        'AM01',
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
        'EXT-L-CAP',
        'EXT-L-PHONE-REQUEST',
        'EXT-L-SESSION',
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
    final overlay = demoMedia.isEmpty
        ? null
        : DemoMediaOverlay(
            Uri.parse(demoMedia),
            scenario: demoScenario,
            reportMode: const bool.fromEnvironment('XLAND_REPORT_MODE'),
          );
    final account = RemoteAccountRepository(g, sessions);
    const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    final extendedAuth = RemoteExtendedAuthRepository(
      gateway: g,
      sessions: sessions,
      coordinator: account.authCoordinator,
      google: NativeGoogleIdentityClient(
        serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
        clientId: googleClientId.isEmpty ? null : googleClientId,
      ),
    );
    areaMaps = RemoteAreaMapRepository(
      g,
      apiBaseUrl: config.apiBaseUrl,
      allowLocalHttp: !kReleaseMode,
    );
    dependencies = XlandDependencies(
      properties: RemotePropertyRepository(g),
      account: account,
      extendedAuth: extendedAuth,
      feed: overlay == null
          ? RemoteFeedRepository(g)
          : DemoMediaFeedRepository(RemoteFeedRepository(g), overlay),
      consultants: overlay == null
          ? RemoteConsultantRepository(g)
          : DemoMediaConsultantRepository(
              RemoteConsultantRepository(g),
              overlay,
            ),
      events: RemoteEventRepository(g),
      bookings: RemoteBookingRepository(g),
      payments: RemotePaymentRepository(g),
      clubs: RemoteClubRepository(g),
      finance: RemoteFinanceRepository(g),
      support: RemoteSupportRepository(g),
      guestPreferences: LocalGuestPreferencesRepository(
        const FlutterSecureStorage(),
      ),
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AreaMapScope(
    createTileProvider: XlandMapTileProvider.new,
    repository: areaMaps,
    child: kReleaseMode || const bool.fromEnvironment('XLAND_REPORT_MODE')
        ? XLandApp(dependencies: dependencies, showDeveloperTools: false)
        : Directionality(
            textDirection: TextDirection.ltr,
            child: Banner(
              message:
                  const String.fromEnvironment('XLAND_DEMO_MEDIA_BASE_URL')
                      .isEmpty
                  ? 'DEV · API LOCAL'
                  : 'DEV · SYNTHETIC MEDIA',
              location: BannerLocation.topEnd,
              child: XLandApp(dependencies: dependencies),
            ),
          ),
  );
}
