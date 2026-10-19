import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/shell/main_navigation_shell.dart';
import '../gallery/component_gallery_page.dart';
import '../shared/di/dependencies_scope.dart';
import '../theme/theme.dart';

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
  late bool _showGallery;

  @override
  void initState() {
    super.initState();
    _showGallery = widget.showGallery;
  }

  void _toggleGallery(bool show) {
    setState(() {
      _showGallery = show;
    });
  }

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
          home: _showGallery
              ? ComponentGalleryPage(onBack: () => _toggleGallery(false))
              : Builder(
                  builder: (ctx) => MainNavigationShell(
                    onOpenGallery: widget.showDeveloperTools
                        ? () {
                            Navigator.of(ctx).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ComponentGalleryPage(),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
          routes: {
            if (widget.showDeveloperTools)
              '/gallery': (context) => const ComponentGalleryPage(),
          },
        ),
      ),
    );
  }
}
