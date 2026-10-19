import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

void main() {
  group('Inputs & Form Validation', () {
    testWidgets('XLandTextField renders label, handles input, and displays validation error', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(AppSpacing.pageGutter),
              child: XLandTextField(
                controller: controller,
                label: 'Số tiền vốn tự có',
                hint: 'Ví dụ: 1.200.000.000',
                errorText: 'Vốn tự có không được nhỏ hơn 0',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Số tiền vốn tự có'), findsOneWidget);
      expect(find.text('Vốn tự có không được nhỏ hơn 0'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '1000000000');
      expect(controller.text, '1000000000');
    });

    testWidgets('CounterInput respects min/max bounds and updates value', (tester) async {
      int count = 2;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: CounterInput(
                  value: count,
                  min: 1,
                  max: 4,
                  onChanged: (newVal) => setState(() => count = newVal),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('2 người'), findsOneWidget);

      // Tap + button
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('3 người'), findsOneWidget);

      // Tap + button again to reach max
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('4 người'), findsOneWidget);

      // Tap + at max should not exceed 4
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('4 người'), findsOneWidget);

      // Tap - button twice
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(find.text('2 người'), findsOneWidget);
    });

    testWidgets('SearchField triggers onChanged and onFilterTap', (tester) async {
      String searchQuery = '';
      bool filterTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SearchField(
              onChanged: (val) => searchQuery = val,
              onFilterTap: () => filterTapped = true,
              hasActiveFilters: true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hòa Lạc');
      expect(searchQuery, 'Hòa Lạc');

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(filterTapped, isTrue);
    });
  });
}
