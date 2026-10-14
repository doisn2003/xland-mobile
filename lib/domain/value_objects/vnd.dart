/// Exact integer VND, serialized as a base-10 string even on Flutter web.
final class Vnd implements Comparable<Vnd> {
  Vnd(String value) : amount = _parse(value);

  /// Convenience for small fixture values; large money must use a string.
  factory Vnd.fromInt(int value) {
    if (value > 9007199254740991) {
      throw RangeError('Use a decimal string above the web safe integer limit');
    }
    return Vnd(value.toString());
  }
  final BigInt amount;

  static BigInt _parse(String value) {
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) {
      throw const FormatException('VND must be a nonnegative integer string');
    }
    return BigInt.parse(value);
  }

  String get wireValue => amount.toString();
  @override
  int compareTo(Vnd other) => amount.compareTo(other.amount);
  @override
  bool operator ==(Object other) => other is Vnd && amount == other.amount;
  @override
  int get hashCode => amount.hashCode;
  @override
  String toString() => wireValue;
}
