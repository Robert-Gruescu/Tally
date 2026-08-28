import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/money.dart';

void main() {
  group('Money.parse', () {
    test('accepts both decimal separators', () {
      expect(Money.parse('12,50'), 1250);
      expect(Money.parse('12.50'), 1250);
      expect(Money.parse('12'), 1200);
    });

    test('drops thousand separators', () {
      expect(Money.parse('1.250,50'), 125050);
      expect(Money.parse('1,250.50'), 125050);
      expect(Money.parse('1 250,50'), 125050);
    });

    test('rejects junk, zero and negatives', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('0'), isNull);
      expect(Money.parse('-5'), isNull);
    });

    test('rounds to the nearest ban', () {
      expect(Money.parse('12.999'), 1300);
    });
  });
}
