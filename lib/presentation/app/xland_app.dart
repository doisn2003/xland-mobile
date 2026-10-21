import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/shell/main_navigation_shell.dart';
import '../gallery/component_gallery_page.dart';
import '../shared/di/dependencies_scope.dart';
import '../theme/theme.dart';
import '../features/property_detail/pages/property_detail_page.dart';
import '../features/feed/pages/shared_video_page.dart';
import '../features/events/pages/event_detail_page.dart';
import 'content_link.dart';

/// Presentation root application widget owned by Agent B.
/// Accepts domain repository dependencies via pure Dart constructor injection.
class XLandApp extends StatefulWidget {
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  const XLandApp({
    super.key,
    required this.dependencies,
    this.showGallery = false,
    this.showDeveloperTools = true,
  });

  final XlandDependencies dependencies;
  final bool showGallery;
  final bool showDeveloperTools;

  @override
  State<XLandApp> createState() => _XLandAppState();
}

class _XLandAppState extends State<XLandApp> {
  late final ValueNotifier<bool> _showGallery;

  @override
  void initState() {
    super.initState();
    _showGallery = ValueNotifier(widget.showGallery);
  }

  void _toggleGallery(bool show) {
    _showGallery.value = show;
  }

  @override
  void dispose() {
    _showGallery.dispose();
    super.dispose();
  }

  Widget _home() => ValueListenableBuilder<bool>(
    valueListenable: _showGallery,
    builder: (_, showGallery, _) => showGallery
        ? ComponentGalleryPage(onBack: () => _toggleGallery(false))
        : Builder(
            builder: (ctx) => MainNavigationShell(
              onOpenGallery: widget.showDeveloperTools
                  ? () => Navigator.of(ctx).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ComponentGalleryPage(),
                      ),
                    )
                  : null,
            ),
          ),
  );

  Route<void>? _contentRoute(RouteSettings settings) {
    if (settings.name == '/gallery' && widget.showDeveloperTools) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const ComponentGalleryPage(),
      );
    }
    final link = ContentLink.parse(settings.name);
    if (link == null) return null;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (link.kind) {
        ContentKind.properties => PropertyDetailPage(propertyId: link.id),
        ContentKind.videos => SharedVideoPage(videoId: link.id),
        ContentKind.events => EventDetailPage(eventId: link.id),
      },
    );
  }

  Route<void> _invalidLink(RouteSettings settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Liên kết không hợp lệ')),
      body: const Center(
        child: Text('Không tìm thấy nội dung từ liên kết này.'),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DependenciesScope(
      dependencies: widget.dependencies,
      child: BlocProvider(
        create: (_) => AuthCubit(
          widget.dependencies.account,
          extendedAuth: widget.dependencies.extendedAuth,
        )..checkSession(),
        child: MaterialApp(
          title: 'XLand',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          navigatorObservers: [XLandApp.routeObserver],
          // Always retain a home route under a cold-start link for Back.
          // Flutter forwards subsequent platform links to onGenerateRoute.
          onGenerateInitialRoutes: (name) => [
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/'),
              builder: (_) => _home(),
            ),
            if (name != '/')
              _contentRoute(RouteSettings(name: name)) ??
                  _invalidLink(RouteSettings(name: name)),
          ],
          onGenerateRoute: _contentRoute,
          onUnknownRoute: _invalidLink,
          routes: {
            '/': (_) => _home(),
            if (widget.showDeveloperTools)
              '/gallery': (context) => const ComponentGalleryPage(),
          },
        ),
      ),
    );
  }
}
