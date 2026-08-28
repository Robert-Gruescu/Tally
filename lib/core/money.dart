import 'package:intl/intl.dart';

/// Money is handled in minor units (bani) end to end. Doubles only ever appear
/// at the edges: parsing what the user typed, and rendering.
class Money {
  const Money._();

  static const int minorPerMajor = 100;

  /// Parses free-form input into minor units. Accepts both decimal separators
  /// and ignores spaces and thousand separators, because people type "1.250,50"
  /// and "1250.5" interchangeably and neither should be rejected.
  ///
  /// Returns null when there is no parseable positive amount.
  static int? parse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    text = text.replaceAll(RegExp(r'[\s ]'), '');

    final lastComma = text.lastIndexOf(',');
    final lastDot = text.lastIndexOf('.');

    // Whichever separator comes last is the decimal one; anything earlier is
    // a thousands separator and gets dropped.
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        text = text.replaceAll('.', '').replaceFirst(',', '.');
      } else {
        text = text.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      // A lone comma is decimal unless it is grouping three digits.
      final tail = text.length - lastComma - 1;
      text = tail == 3 && text.indexOf(',') != lastComma
          ? text.replaceAll(',', '')
          : text.replaceFirst(',', '.');
    }

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return null;

    final value = double.tryParse(text);
    if (value == null || value <= 0 || !value.isFinite) return null;

    final minor = (value * minorPerMajor).round();
    return minor > 0 ? minor : null;
  }

  /// Formats minor units for display, e.g. `1.250,50 lei`.
  static String format(
    int minor, {
    required String currency,
    String locale = 'ro_RO',
    bool showDecimals = true,
  }) {
    final format = NumberFormat.currency(
      locale: locale,
      symbol: currency,
      decimalDigits: showDecimals ? 2 : 0,
    );
    return format.format(minor / minorPerMajor);
  }

  /// Formats without a currency symbol, for chart axes and dense tables.
  static String formatPlain(
    int minor, {
    String locale = 'ro_RO',
    bool showDecimals = true,
  }) {
    final format = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: showDecimals ? 2 : 0,
    );
    return format.format(minor / minorPerMajor);
  }

  /// A short form for chart labels: `1,2k` past a thousand.
  static String compact(int minor, {String locale = 'ro_RO'}) {
    final major = minor / minorPerMajor;
    if (major.abs() < 1000) return major.round().toString();
    return NumberFormat.compact(locale: locale).format(major);
  }
}
