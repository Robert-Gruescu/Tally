import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../money.dart';
import '../theme.dart';

/// Renders an amount the way a printed statement does: the whole units carry
/// the full weight and size, the bani and the currency step back.
///
/// This is the single detail that does the most work in the app. A flat
/// `1.250,50 lei` gives every glyph equal importance, so the eye has to read
/// the whole string to find the number. Demoting the fractional part lets the
/// magnitude land first and the precision stay available underneath.
///
/// Figures are tabular so a total never jitters sideways as it updates.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.minor,
    required this.currency,
    this.style,
    this.color,
    this.signed = false,
    this.showPlus = false,
    this.showCurrency = true,
    this.fractionScale = 0.54,
    this.textAlign,
    this.mutedCurrency = true,
  });

  /// Amount in minor units. May be negative when [signed] is set.
  final int minor;
  final String currency;

  /// Style for the whole-unit part. Falls back to `displayLarge`.
  final TextStyle? style;
  final Color? color;

  /// Prefixes an explicit minus. Colour alone is not a sign: it fails for
  /// red-green colour blindness and reads as positive at a glance.
  final bool signed;

  /// Marks positive amounts with an explicit `+`. Used where a row could be
  /// either direction and the reader should not have to infer it from colour.
  final bool showPlus;

  final bool showCurrency;

  /// How much smaller the bani and currency render, relative to the whole part.
  final double fractionScale;

  final TextAlign? textAlign;

  /// Renders the currency word in the muted text colour instead of the value
  /// colour. A red "lei" implies the currency itself is the bad news.
  final bool mutedCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final resolved = (style ?? theme.textTheme.displayLarge!).copyWith(
      color: color ?? style?.color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final negative = minor < 0;
    final absolute = minor.abs();
    final whole = absolute ~/ Money.minorPerMajor;
    final fraction = absolute % Money.minorPerMajor;

    final grouped = NumberFormat.decimalPattern('ro_RO').format(whole);
    final small = resolved.copyWith(
      fontSize: (resolved.fontSize ?? 16) * fractionScale,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: (color ?? resolved.color)?.withValues(alpha: 0.62),
    );

    return Text.rich(
      TextSpan(
        style: resolved,
        children: [
          if (signed && negative) const TextSpan(text: '−'),
          if (showPlus && !negative) const TextSpan(text: '+'),
          TextSpan(text: grouped),
          TextSpan(
            text: ',${fraction.toString().padLeft(2, '0')}',
            style: small,
          ),
          if (showCurrency)
            TextSpan(
              // A thin space before the currency, as a typesetter would
              // set it: a full word space makes the unit look detached.
              text: ' $currency',
              style: mutedCurrency ? small.copyWith(color: money.muted) : small,
            ),
        ],
      ),
      textAlign: textAlign,
      // The full amount, spoken as one value, instead of the visual pieces.
      semanticsLabel: '${negative ? 'minus ' : ''}'
          '${Money.format(absolute, currency: currency)}',
    );
  }
}
