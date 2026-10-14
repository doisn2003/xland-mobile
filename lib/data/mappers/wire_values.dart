import '../../domain/value_objects/vnd.dart';

Vnd parseVnd(Object? value) {
  if (value is! String) throw const FormatException('VND must be a string');
  return Vnd(value);
}

DateTime parseInstant(Object? value) {
  if (value is! String ||
      !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(value)) {
    throw const FormatException('Timestamp requires explicit UTC offset');
  }
  return DateTime.parse(value).toUtc();
}
