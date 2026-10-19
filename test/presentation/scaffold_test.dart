import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

void main() {
  group('XLandScaffold & Responsive Layouts', () {
    testWidgets('XLandScaffold renders body and sticky footer correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: XLandScaffold(
            appBar: const XLandAppBar(title: 'Tiêu đề kiểm tra'),
            stickyFooter: StickyActionBar(
              child: PrimaryButton(
                label: 'Xác nhận đặt lịch',
                onPressed: () {},
              ),
            ),
            body: const Center(child: Text('Nội dung chính')),
          ),
        ),
      );

      expect(find.text('Tiêu đề kiểm tra'), findsOneWidget);
      expect(find.text('Nội dung chính'), findsOneWidget);
      expect(find.text('Xác nhận đặt lịch'), findsOneWidget);
      expect(find.byType(StickyActionBar), findsOneWidget);
    });

    for (final width in [360.0, 390.0, 430.0]) {
      testWidgets('Foundation layout does not overflow at width $width and text scale 1.3', (tester) async {
        tester.view.physicalSize = Size(width * 2, 850 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 850),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: XLandScaffold(
                appBar: const XLandAppBar(
                  title: 'Hồ sơ pháp lý Hòa Lạc XL-028',
                  showBack: true,
                ),
                stickyFooter: StickyActionBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlineButton(
                          label: 'Tải hồ sơ',
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Đặt lịch thực địa',
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(AppSpacing.pageGutter),
                  children: [
                    const DemoDataNotice(),
                    const SizedBox(height: AppSpacing.s12),
                    const InfoNotice(
                      title: 'Đã đối chiếu 4/6 mục',
                      message: 'Phạm vi kiểm tra bao gồm giấy chứng nhận, quyền bán, thửa đất và tiếp cận.',
                      variant: NoticeVariant.info,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    XLandCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const StatusBadge(text: 'Nguồn HĐQT', variant: StatusBadgeVariant.source),
                          const SizedBox(height: AppSpacing.s8),
                          Text('Đất nền KCN Hòa Lạc', style: AppTypography.cardTitle),
                          const SizedBox(height: AppSpacing.s4),
                          const PriceText(priceVnd: '2.400.000.000 đ', unitText: '(20 triệu/m²)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layout must not overflow at width $width with 1.3 text scale');
      });
    }
  });
}
