import 'package:flutter_test/flutter_test.dart';
import 'package:jive_money/utils/json_number.dart';

void main() {
  group('json_number helpers', () {
    test('asDouble parses string and num', () {
      expect(asDouble('123.45'), 123.45);
      expect(asDouble(123.45), 123.45);
      expect(asDouble(123), 123.0);
      expect(asDouble(null), isNull);
      expect(asDouble({}), isNull);
    });

    test('asDoubleOrZero defaults to 0.0', () {
      expect(asDoubleOrZero(''), 0.0);
      expect(asDoubleOrZero(null), 0.0);
      expect(asDoubleOrZero('7.5'), 7.5);
    });

    test('asInt parses string and num', () {
      expect(asInt('42'), 42);
      expect(asInt(42), 42);
      expect(asInt(42.9), 42);
      expect(asInt(null), isNull);
      expect(asInt({}), isNull);
    });
  });
}

