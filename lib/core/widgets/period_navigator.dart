import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../period.dart';
import '../theme.dart';

/// Moves the whole app one period back or forward.
///
/// Sits under the Azi / Săptămâna / Luna tabs, which choose the *size* of the
/// window; this chooses *which* window. Without it every screen was welded to
/// today, and "how much did I spend last month" had no answer.
///
/// Forward is disabled at the present, because there is nothing recorded in the
/// future and an arrow that does nothing is worse than one that is visibly
/// unavailable.
class PeriodNavigator extends ConsumerWidget {
  const PeriodNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final period = ref.watch(periodProvider);
    final offset = ref.watch(periodOffsetProvider);
    final range = ref.watch(dateRangeProvider);
    final canGoBack = ref.watch(canGoBackProvider);

    void move(int by) {
      final next = offset + by;
      if (next > 0) return;
      HapticFeedback.selectionClick();
      ref.read(periodOffsetProvider.notifier).state = next;
      ref.read(selectedDayProvider.notifier).state = null;
    }

    return Row(
      children: [
        _Arrow(
          icon: Icons.chevron_left_rounded,
          // Stops at the month of the first transaction. Past that there is
          // nothing to show, and an arrow that walks into empty years is a way
          // to get lost rather than a feature.
          onTap: canGoBack ? () => move(-1) : null,
          semanticLabel: 'Perioada anterioară',
          disabledColor: money.hairline,
        ),
        Expanded(
          child: GestureDetector(
            // Tapping the label returns to the present. Faster than arrowing
            // back from six months ago, and it is the only place someone
            // deep in the past reliably looks.
            onTap: offset == 0
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    ref.read(periodOffsetProvider.notifier).state = 0;
                    ref.read(selectedDayProvider.notifier).state = null;
                  },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  periodLabel(context, period, offset, range),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: offset == 0
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        _Arrow(
          icon: Icons.chevron_right_rounded,
          onTap: offset < 0 ? () => move(1) : null,
          semanticLabel: 'Perioada următoare',
          disabledColor: money.hairline,
        ),
      ],
    );
  }
}

/// Names the window in the words someone would use out loud.
///
/// "Luna trecută" beats "iulie 2026" for the step just behind, because that is
/// how the question is asked; anything older gets its real name, because "acum
/// cinci luni" is not something anyone can place.
String periodLabel(
  BuildContext context,
  Period period,
  int offset,
  DateRange range,
) {
  final l10n = AppLocalizations.of(context);

  switch (period) {
    case Period.day:
      if (offset == 0) return l10n.periodToday;
      if (offset == -1) return l10n.periodYesterday;
      return _capitalise(DateFormat('EEEE, d MMMM', 'ro_RO').format(range.from));

    case Period.week:
      if (offset == 0) return l10n.periodThisWeek;
      if (offset == -1) return l10n.periodLastWeek;
      final last = range.to.subtract(const Duration(days: 1));
      // "12 - 18 august" when the week sits inside one month, otherwise the
      // month is named on both ends.
      return range.from.month == last.month
          ? '${range.from.day} - ${DateFormat('d MMMM', 'ro_RO').format(last)}'
          : '${DateFormat('d MMM', 'ro_RO').format(range.from)} - '
              '${DateFormat('d MMM', 'ro_RO').format(last)}';

    case Period.month:
      if (offset == 0) return l10n.periodThisMonth;
      if (offset == -1) return l10n.periodLastMonth;
      // The year is only worth showing once the window leaves this one.
      final sameYear = range.from.year == DateTime.now().year;
      return _capitalise(
        DateFormat(sameYear ? 'LLLL' : 'LLLL yyyy', 'ro_RO').format(range.from),
      );
  }
}

String _capitalise(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.disabledColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Color? disabledColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          // 40 square: hit it with a thumb without aiming.
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 22,
            color: onTap == null
                ? (disabledColor ?? money.hairline)
                : money.muted,
          ),
        ),
      ),
    );
  }
}
