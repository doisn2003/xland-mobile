import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/bootstrap/bootstrap_app.dart';

void main() {
  testWidgets('foundation shell mounts without presentation or a backend', (
    tester,
  ) async {
    await tester.pumpWidget(const BootstrapApp());
    expect(find.text('XLand · Phase 1 bootstrap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
