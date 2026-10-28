import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/discovery/cubit/filter_cubit.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/property_overview_tab.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

Map<String, Object?> sample() {
  final data = wireObject(
    jsonDecode(File('test/data/fixtures/c3_samples.json').readAsStringSync()),
  );
  return wireObject(wireObject(data['samples'])['Property']);
}

void main() {
  test(
    'legacy DTO remains readable and current addresses survive decoding',
    () {
      expect(mapProperty(sample()).oldAddress, isNull);
      final property = mapProperty({
        ...sample(),
        'communeCode': '06913',
        'communeName': 'Phường Hạ Long',
        'districtName': '',
        'provinceName': 'Thành phố Quảng Ninh',
        'addressDetail': 'Khu phố 1',
        'oldAddress': 'Phường Bạch Đằng, Hạ Long, Quảng Ninh',
        'category': 'industrial',
        'landType': 'other',
      });
      expect(
        property.locationLabel,
        'Khu phố 1, Phường Hạ Long, Thành phố Quảng Ninh',
      );
      expect(property.oldAddress, 'Phường Bạch Đằng, Hạ Long, Quảng Ninh');
      expect(property.category, PropertyCategory.industrial);
    },
  );
  test(
    'commune query is preserved by edits and cleared when province changes',
    () async {
      final cubit = FilterCubit(
        FakePropertyRepository(),
        initialFilter: const PropertyFilter(
          regions: [],
          areaBands: [],
          landTypes: [],
          savedOnly: false,
          sort: PropertySort.relevant,
          provinceCode: '22',
        ),
      );
      cubit.setCommuneCode('06913');
      cubit.setCategory(PropertyCategory.industrial);
      expect(propertyFilters(cubit.state.draftFilter)['communeCode'], '06913');
      cubit.setProvinceCode('01');
      expect(cubit.state.draftFilter.communeCode, isNull);
      await cubit.close();
    },
  );
  for (final oldAddress in <String?>[
    'Thị trấn Cái Rồng, huyện Vân Đồn, tỉnh Quảng Ninh',
    null,
  ]) {
    testWidgets(
      'overview displays optional old address: ${oldAddress != null}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final property = mapProperty({
          ...sample(),
          'communeCode': '07133',
          'communeName': 'Đặc khu Vân Đồn',
          'districtName': '',
          'provinceName': 'Thành phố Quảng Ninh',
          'oldAddress': oldAddress,
          'category': 'industrial',
          'landType': 'other',
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: PropertyOverviewTab(
                property: property,
                consultant: null,
                activeMediaIndex: 0,
                onMediaIndexChanged: (_) {},
                onNavigateToLegalTab: () {},
                showGallery: false,
              ),
            ),
          ),
        );
        expect(
          find.text('Địa chỉ cũ'),
          oldAddress == null ? findsNothing : findsOneWidget,
        );
        if (oldAddress != null) expect(find.text(oldAddress), findsOneWidget);
        expect(find.text('Đất công nghiệp'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
