import 'package:flutter/widgets.dart';

import '../../../data/demo/prepared_transport.dart';

class PreparedContentScope extends InheritedNotifier<PreparedTransport> {
  const PreparedContentScope({
    super.key,
    required PreparedTransport controller,
    required super.child,
  }) : super(notifier: controller);
  static PreparedTransport? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PreparedContentScope>()
      ?.notifier;
}
