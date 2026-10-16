import '../../domain/value_objects/vnd.dart';

Vnd parseVnd(Object? value) {
  if (value is! String) throw const FormatException('VND must be a string');
  return Vnd(value);
}

DateTime parseInstant(Object? value) {
  if (value is! String) {
    throw const FormatException('Timestamp requires explicit UTC offset');
  }
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|([+-])(\d{2}):(\d{2}))$',
  ).firstMatch(value);
  if (match == null ||
      int.parse(match[2]!) > 23 ||
      int.parse(match[3]!) > 59 ||
      int.parse(match[4]!) > 59 ||
      (match[7] != null &&
          (int.parse(match[7]!) > 23 || int.parse(match[8]!) > 59))) {
    throw const FormatException('Timestamp requires explicit UTC offset');
  }
  parseDate(match[1]);
  return DateTime.parse(value).toUtc();
}

String parseDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Expected Gregorian date');
  }
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (date == null ||
      date.year < 1 ||
      date.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('Invalid Gregorian date');
  }
  return value;
}
