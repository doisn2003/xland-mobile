import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';

void main() {
  test('event narrative extensions preserve existing JSONB descriptions and legacy payloads', () {
    final agenda = {
      'startsAt': '2026-10-25T12:30:00Z',
      'title': 'Đọc hiểu hồ sơ',
    };
    expect(mapAgendaItem(agenda).description, isNull);
    expect(
      mapAgendaItem({...agenda, 'description': 'Những điểm cần lưu ý'})
          .description,
      'Những điểm cần lưu ý',
    );
    final speaker = {
      'name': 'Minh Anh',
      'role': 'Điều phối',
      'avatarUrl': null,
    };
    expect(mapSpeaker(speaker).description, isNull);
    expect(
      mapSpeaker({...speaker, 'description': 'Chuyên viên tư vấn'}).description,
      'Chuyên viên tư vấn',
    );
    expect(
      () => mapAgendaItem({...agenda, 'description': 123}),
      throwsFormatException,
    );
  });
}
