import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../period.dart';
import '../theme.dart';

/// Three plain words with a rule sliding underneath.
///
/// Replaces `SegmentedButton`, whose outlined pill is the most recognisable
/// piece of stock Material chrome on the screen. A tab strip is also the
/// honest control here: these are views of the same data, not a set of options
/// being chosen.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  static const _periods = [Period.day, Period.week, Period.month];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final selected = ref.watch(periodProvider);

    final labels = {
      Period.day: l10n.periodDay,
      Period.week: l10n.periodWeek,
      Period.month: l10n.periodMonth,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / _periods.length;
        final index = _periods.indexOf(selected);

        return SizedBox(
          height: 44,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: money.hairline),
              ),
              AnimatedPositioned(
                duration: Motion.of(context, Motion.base),
                curve: Motion.ease,
                left: index * itemWidth,
                bottom: 0,
                width: itemWidth,
                child: Center(
                  child: Container(
                    // Sized to the word rather than the full column, so the
                    // rule reads as an underline and not a tab background.
                    width: itemWidth * 0.62,
                    height: 2,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final period in _periods)
                    Expanded(
                      child: Semantics(
                        selected: period == selected,
                        button: true,
                        child: InkWell(
                          onTap: () {
                            if (period == selected) return;
                            HapticFeedback.selectionClick();
                            ref.read(periodProvider.notifier).state = period;
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.of(context, Motion.fast),
                              curve: Motion.ease,
                              style: theme.textTheme.titleSmall!.copyWith(
                                color: period == selected
                                    ? theme.colorScheme.onSurface
                                    : money.muted,
                                fontWeight: period == selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              child: Text(labels[period]!),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
