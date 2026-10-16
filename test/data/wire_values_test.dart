import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/mappers/wire_values.dart';

void main() {
  test('offset is normalized to UTC instead of device timezone', () {
    expect(
      parseInstant('2026-11-07T14:00:00+07:00'),
      DateTime.utc(2026, 11, 7, 7),
    );
    expect(() => parseInstant('2026-11-07T14:00:00'), throwsFormatException);
  });
  test('API numeric money is rejected rather than silently rounded', () {
    expect(() => parseVnd(2400000000), throwsFormatException);
    expect(parseVnd('350000').wireValue, '350000');
  });
  test('dates reject normalized impossible days and invalid clock offsets', () {
    expect(parseDate('2028-02-29'), '2028-02-29');
    expect(() => parseDate('2026-02-29'), throwsFormatException);
    expect(() => parseInstant('2026-02-30T10:00:00Z'), throwsFormatException);
    expect(() => parseInstant('2026-11-07T24:00:00Z'), throwsFormatException);
    expect(
      () => parseInstant('2026-11-07T14:00:00+99:99'),
      throwsFormatException,
    );
  });
}
