import 'package:flutter/widgets.dart';

/// Also applies to detail pages opened deeper in a comparison pane's navigator.
class PropertyComparisonScope extends InheritedWidget {
  const PropertyComparisonScope({super.key, required super.child});

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PropertyComparisonScope>() !=
      null;

  @override
  bool updateShouldNotify(PropertyComparisonScope oldWidget) => false;
}
