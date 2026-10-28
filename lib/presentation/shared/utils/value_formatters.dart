import '../../../domain/xland_domain.dart';

String _groupDigits(String value) =>
    value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Locale formatting only; never converts exact domain values to double.
String formatDecimalValue(DecimalValue value) {
  final parts = value.wireValue.split('.');
  final fraction = parts.length > 1
      ? parts[1].replaceFirst(RegExp(r'0+$'), '')
      : '';
  return '${_groupDigits(parts[0])}${fraction.isEmpty ? '' : ',$fraction'}';
}

String formatMeasurement(DecimalValue? value, String unit) =>
    value == null ? 'Chưa cập nhật' : '${formatDecimalValue(value)} $unit';

String formatVndAmount(Vnd value) => '${_groupDigits(value.wireValue)} đ';

String formatResourceReference(String id) =>
    RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
        .hasMatch(id)
    ? id.substring(0, 8).toUpperCase()
    : id;

String formatCompactVnd(Vnd value) {
  final billion = BigInt.from(1000000000), million = BigInt.from(1000000);
  final divisor = value.amount >= billion
      ? billion
      : value.amount >= million
      ? million
      : null;
  if (divisor == null) return formatVndAmount(value);
  final scaled =
      (value.amount * BigInt.from(100) + divisor ~/ BigInt.two) ~/ divisor;
  final whole = scaled ~/ BigInt.from(100);
  final fraction = (scaled % BigInt.from(100))
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '${_groupDigits(whole.toString())}${fraction.isEmpty ? '' : ',$fraction'} ${divisor == billion ? 'tỷ' : 'triệu'}';
}

String formatLandType(LandType type) => switch (type) {
  LandType.residential => 'Đất ở',
  LandType.agricultural => 'Đất nông nghiệp',
  LandType.other => 'Khác',
};

String formatPropertyDirection(String? value) =>
    switch (value?.trim().toLowerCase()) {
      'north' || 'bắc' => 'Bắc',
      'south' || 'nam' => 'Nam',
      'east' || 'đông' => 'Đông',
      'west' || 'tây' => 'Tây',
      'northeast' || 'đông bắc' => 'Đông Bắc',
      'northwest' || 'tây bắc' => 'Tây Bắc',
      'southeast' || 'đông nam' => 'Đông Nam',
      'southwest' || 'tây nam' => 'Tây Nam',
      null || '' => 'Chưa cập nhật',
      _ => value!,
    };

String formatUpdatedAt(DateTime updatedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(updatedAt);
  if (elapsed.inMinutes < 1) return 'Vừa cập nhật';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} phút trước';
  if (elapsed.inHours < 24) return '${elapsed.inHours} giờ trước';
  return '${elapsed.inDays} ngày trước';
}

String formatPropertyCategory(PropertyCategory type) => switch (type) {
  PropertyCategory.residential => 'Đất ở',
  PropertyCategory.agricultural => 'Đất nông nghiệp',
  PropertyCategory.industrial => 'Đất công nghiệp',
  PropertyCategory.other => 'Khác',
};
