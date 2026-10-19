import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/shared/utils/value_formatters.dart';

void main() {
  test('measurements strip storage precision and use Vietnamese separators',(){
    expect(formatMeasurement(DecimalValue('150.000000'),'m²'),'150 m²');
    expect(formatMeasurement(DecimalValue('1234.125000'),'m²'),'1.234,125 m²');
    expect(formatMeasurement(null,'m'),'Chưa cập nhật');
  });
  test('compact prices use decimal commas and retain fractional millions',(){
    expect(formatCompactVnd(Vnd('2700000000')),'2,7 tỷ');
    expect(formatCompactVnd(Vnd('10796711')),'10,8 triệu');
    expect(formatVndAmount(Vnd('9007199254740993')),'9.007.199.254.740.993 đ');
  });
}
