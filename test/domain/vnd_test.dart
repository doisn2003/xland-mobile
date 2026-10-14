import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/value_objects/vnd.dart';

void main() {
  test('exact money remains exact above JavaScript safe integer boundary', () {
    expect(Vnd('9007199254740993').wireValue, '9007199254740993');
    expect(Vnd.fromInt(350000).wireValue, '350000');
    expect(() => Vnd.fromInt(9007199254740992), throwsRangeError);
    expect(Vnd('2400000000').compareTo(Vnd('1800000000')), greaterThan(0));
  });
  test('rejects floats, negative, display and noncanonical money', () {
    for (final value in ['-1', '1.5', '2,4 tỷ', '01', '+1', ' 1']) {
      expect(() => Vnd(value), throwsFormatException);
    }
  });
}
