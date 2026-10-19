import 'package:flutter/widgets.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

/// Provides [XlandDependencies] down the widget tree using pure Flutter [InheritedWidget].
class DependenciesScope extends InheritedWidget {
  const DependenciesScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final XlandDependencies dependencies;

  static XlandDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DependenciesScope>();
    assert(scope != null, 'No DependenciesScope found in context');
    return scope!.dependencies;
  }

  static XlandDependencies? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DependenciesScope>()?.dependencies;
  }

  @override
  bool updateShouldNotify(DependenciesScope oldWidget) {
    return dependencies != oldWidget.dependencies;
  }
}
