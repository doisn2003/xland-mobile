import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/bootstrap/bootstrap_app.dart';

void main() {
  testWidgets('foundation shell mounts without presentation or a backend', (
    tester,
  ) async {
    await tester.pumpWidget(const BootstrapApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'XLand Foundation');
    expect(app.home, isA<Scaffold>());
    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.byType(Center), findsWidgets);
    expect(
      find.descendant(of: find.byType(SafeArea), matching: find.byType(Text)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
