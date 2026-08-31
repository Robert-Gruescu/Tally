import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/period_navigator.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// The daily bars on Home, and the way into a single day.
///
/// At the present it shows the trailing seven days rather than a calendar week:
/// a Monday-to-Sunday chart has one lonely bar on Monday morning, while a
/// trailing window always has something to compare against. Once the user
/// navigates into the past it shows the days of that window instead, because
/// "last seven days" is a claim about now.
///
/// Tapping a bar drills into that day: the bar lights up, the heading names it,
/// and the totals and the list underneath narrow to it. The chart itself stays
/// put, so the shape being read is never taken away. Tapping it again lets go.
class WeeklyChart extends ConsumerWidget {
  const WeeklyChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);

    final days = ref.watch(dailyChartProvider).valueOrNull ?? const [];
    final isCurrent = ref.watch(isCurrentPeriodProvider);
    final selected = ref.watch(selectedDayProvider);

    final maxMinor =
        days.fold<int>(0, (m, d) => d.totalMinor > m ? d.totalMinor : m);
    final total = days.fold<int>(0, (s, d) => s + d.totalMinor);
    final hasData = maxMinor > 0;

    // The heading doubles as the readout: it names the whole window normally,
    // and the tapped day while one is held.
    DailyTotal? picked;
    if (selected != null) {
      for (final entry in days) {
        if (entry.day == selected) {
          picked = entry;
          break;
        }
      }
    }

    final title = picked != null
        ? _dayLabel(context, picked.day)
        : isCurrent
            ? l10n.lastSevenDays
            : periodLabel(
                context,
                ref.watch(periodProvider),
                ref.watch(periodOffsetProvider),
                ref.watch(dateRangeProvider),
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: picked != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (picked != null) ...[
                    const SizedBox(width: 4),
                    // A way out that does not require finding the same bar
                    // again, which is hard when it is one of thirty-one.
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedDayProvider.notifier).state = null;
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: money.muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (hasData || picked != null)
              MoneyText(
                minor: picked?.totalMinor ?? total,
                currency: currency,
                style: theme.textTheme.labelMedium,
                color: picked != null ? money.expense : money.muted,
                fractionScale: 0.84,
              ),
          ],
        ),
        if (picked == null && hasData) ...[
          const SizedBox(height: 2),
          Text(
            l10n.dailyAverageValue(
              Money.format(
                total ~/ (days.isEmpty ? 1 : days.length),
                currency: currency,
                showDecimals: false,
              ),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 132,
          child: hasData
              ? _Bars(days: days, maxMinor: maxMinor, selected: selected)
              : _ChartEmpty(message: l10n.emptyChartBody),
        ),
      ],
    );
  }

  static String _dayLabel(BuildContext context, DateTime day) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    if (day == today) return l10n.today;
    if (day == yesterday) return l10n.yesterday;
    final text = DateFormat('EEEE, d MMM', 'ro_RO').format(day);
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _Bars extends ConsumerWidget {
  const _Bars({
    required this.days,
    required this.maxMinor,
    required this.selected,
  });

  final List<DailyTotal> days;
  final int maxMinor;
  final DateTime? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final ink = theme.colorScheme.onSurface;
    final today = DateTime.now();

    // Seven bars can be chunky; thirty-one cannot. Width and label density
    // both follow the count, so a month does not turn into a smear.
    final dense = days.length > 10;
    final barWidth = dense ? (250 / days.length).clamp(4.0, 10.0) : 18.0;
    final labelEvery = days.length > 20 ? 5 : (dense ? 2 : 1);

    void pick(int index) {
      if (index < 0 || index >= days.length) return;
      final day = days[index].day;
      HapticFeedback.selectionClick();
      // Tapping the day already held lets go of it, so one gesture both opens
      // and closes.
      ref.read(selectedDayProvider.notifier).state =
          selected == day ? null : day;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        // Headroom so the tallest bar never touches the top edge.
        maxY: maxMinor * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          // The library's own touch handling exists to pop a tooltip while a
          // finger is held down. The value labels here are permanent, so it
          // has nothing left to do and would only fight them.
          handleBuiltInTouches: false,
          // Thin bars in a month view are hard to hit dead on, so the target
          // reaches a little past the ink.
          touchExtraThreshold: const EdgeInsets.symmetric(horizontal: 8),
          touchTooltipData: BarTouchTooltipData(
            // The number rides above the bar with no bubble around it, the way
            // a step counter prints it.
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 4,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (rod.toY <= 0) return null;
              final day = days[groupIndex].day;
              return BarTooltipItem(
                Money.compact(days[groupIndex].totalMinor),
                theme.textTheme.labelSmall!.copyWith(
                  fontWeight:
                      day == selected ? FontWeight.w700 : FontWeight.w500,
                  color: day == selected ? money.expense : money.muted,
                ),
              );
            },
          ),
          touchCallback: (event, response) {
            // `isInterestedForInteractions` is true for several events inside
            // one gesture: a single tap produces a pan-down and a tap-down,
            // and toggling on each of them turned the selection on and then
            // straight back off. Only the end of the gesture counts, which
            // fires exactly once.
            if (event is! FlTapUpEvent && event is! FlLongPressEnd) return;
            final index = response?.spot?.touchedBarGroupIndex;
            if (index != null) pick(index);
          },
        ),
        // No grid and no background rails. Seven grey slabs behind seven bars
        // is chart furniture, not information; a single baseline is enough to
        // read the bars against.
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: money.hairline)),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final day = days[index].day;
                final isToday = _isToday(day, today);
                final isPicked = day == selected;

                // Thin out the labels rather than the bars: the shape of the
                // month stays complete, only the axis gets quieter. A picked
                // day always keeps its label.
                final isEdge = index == 0 || index == days.length - 1;
                if (dense &&
                    !isEdge &&
                    !isToday &&
                    !isPicked &&
                    index % labelEvery != 0) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    // A single letter keeps seven labels legible on a narrow
                    // phone; over a month the day number places them better.
                    dense
                        ? '${day.day}'
                        : DateFormat('EEEEE', 'ro_RO').format(day).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isPicked || isToday
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isPicked
                          ? theme.colorScheme.primary
                          : isToday
                              ? ink
                              : money.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              // Over about ten bars the numbers would collide into a smear, so
              // past that the axis carries the reading on its own.
              showingTooltipIndicators:
                  !dense && days[i].totalMinor > 0 ? const [0] : const [],
              barRods: [
                BarChartRodData(
                  // A day with no spending draws nothing. The baseline and the
                  // letter beneath it already hold the slot.
                  toY: days[i].totalMinor.toDouble(),
                  width: barWidth,
                  // A flat cap on empty days. A rounded one reads as a very
                  // small bar, which is a different claim than "no spending".
                  borderRadius: days[i].totalMinor == 0
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(top: Radius.circular(4)),
                  color: _barColour(days[i], ink, money, today),
                ),
              ],
            ),
        ],
      ),
      duration: Motion.of(context, Motion.chart),
      curve: Motion.ease,
    );
  }

  /// The picked day burns brightest; failing that, today does; everything else
  /// recedes so the eye has one place to land.
  Color _barColour(
    DailyTotal entry,
    Color ink,
    MoneyColors money,
    DateTime today,
  ) {
    if (entry.totalMinor == 0) return money.hairline;
    if (selected != null) {
      return entry.day == selected ? money.expense : ink.withValues(alpha: 0.2);
    }
    return ink.withValues(alpha: _isToday(entry.day, today) ? 1.0 : 0.28);
  }
}

bool _isToday(DateTime day, DateTime now) =>
    day.year == now.year && day.month == now.month && day.day == now.day;

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    // A dashed box would be a placeholder; a baseline with seven stubs is the
    // real chart, just empty. Nothing shifts when the first expense lands.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < 7; i++)
                  Container(width: 18, height: 3, color: money.hairline),
              ],
            ),
          ),
        ),
        Container(height: 1, color: money.hairline),
        const SizedBox(height: 12),
        Text(message, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
