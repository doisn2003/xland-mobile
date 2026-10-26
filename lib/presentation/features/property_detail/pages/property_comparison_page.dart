import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/xland_domain.dart';
import '../../../theme/theme.dart';
import '../widgets/property_comparison_scope.dart';
import 'property_detail_page.dart';

/// Each pane owns its routes, detail Cubit, tab selection, gallery and scroll.
class PropertyComparisonPage extends StatefulWidget {
  PropertyComparisonPage({super.key, required this.first, required this.second})
    : assert(first.id != second.id);
  final Property first;
  final Property second;

  @override
  State<PropertyComparisonPage> createState() => _PropertyComparisonPageState();
}

class _PropertyComparisonPageState extends State<PropertyComparisonPage> {
  final _navigators = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];
  late final Future<void> _orientationRequest;
  int _activePane = 0;

  @override
  void initState() {
    super.initState();
    _orientationRequest = _orient([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _orient(List<DeviceOrientation> orientations) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
    } on PlatformException {
      /* The rotated layout also supports devices that deny orientation locks. */
    }
  }

  @override
  void dispose() {
    // XLand normally leaves orientation to the OS. Restore that policy even if
    // this route was closed before its landscape request completed.
    unawaited(_orientationRequest.then((_) => _orient([])));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    resizeToAvoidBottomInset: false,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) => RotatedBox(
          // Native phones rotate through SystemChrome. This keeps a horizontal
          // comparison available on web or on systems that ignore that request.
          quarterTurns:
              bounds.maxWidth < 600 && bounds.maxHeight > bounds.maxWidth
              ? 1
              : 0,
          child: Column(
            children: [
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                Container(
                  color: AppColors.brandPrimary,
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('close-comparison'),
                        tooltip: 'Đóng so sánh',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'So sánh lô đất',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(
                          Icons.vertical_split_outlined,
                          color: AppColors.onPrimary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                key: const ValueKey('comparison-panes'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _pane(0, widget.first)),
                    const VerticalDivider(
                      width: 2,
                      thickness: 2,
                      color: AppColors.border,
                    ),
                    Expanded(child: _pane(1, widget.second)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _pane(int index, Property property) => ClipRect(
    key: ValueKey('comparison-pane-$index'),
    child: Listener(
      onPointerDown: (_) {
        if (_activePane != index) setState(() => _activePane = index);
      },
      child: LayoutBuilder(
        builder: (context, bounds) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(bounds.maxWidth, bounds.maxHeight),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: HeroControllerScope.none(
            child: NavigatorPopHandler<Object?>(
              enabled: _activePane == index,
              onPopWithResult: (result) {
                if (_activePane == index) {
                  _navigators[index].currentState?.pop(result);
                }
              },
              child: PropertyComparisonScope(
                child: Navigator(
                  key: _navigators[index],
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    settings: RouteSettings(name: '/compare/${property.id}'),
                    builder: (_) => PropertyDetailPage(
                      propertyId: property.id,
                      comparisonPane: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
