/// Exact nonnegative decimal for m², metres and percentages; no locale format.
final class DecimalValue {
  DecimalValue(this.wireValue) {
    if (!RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]{1,6})?$').hasMatch(wireValue)) {
      throw const FormatException('Expected nonnegative decimal string');
    }
  }
  final String wireValue;
}
