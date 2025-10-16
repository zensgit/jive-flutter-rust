/// JSON number helpers tolerant to backend Decimal-as-string or numeric.
///
/// Use these when decoding API responses where money fields are serialized
/// as strings (e.g., "123.45") or may come as numbers.

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double asDoubleOrZero(dynamic v) {
  return asDouble(v) ?? 0.0;
}

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

