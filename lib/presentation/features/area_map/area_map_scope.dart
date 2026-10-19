import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../domain/maps/area_map.dart';

class AreaMapScope extends InheritedWidget {
  const AreaMapScope({
    super.key,
    required this.repository,
    required super.child,
    this.createTileProvider,
  });
  final AreaMapRepository repository;
  final TileProvider Function()? createTileProvider;
  static TileProvider tileProvider(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AreaMapScope>()
          ?.createTileProvider
          ?.call() ??
      NetworkTileProvider();
  static AreaMapRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AreaMapScope>()?.repository ??
      const UnconfiguredAreaMapRepository();
  @override
  bool updateShouldNotify(AreaMapScope oldWidget) =>
      repository != oldWidget.repository;
}
