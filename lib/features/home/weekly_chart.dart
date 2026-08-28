import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// Seven bars, always ending today. Not a calendar week: a Monday-to-Sunday
/// chart shows one lonely bar on Monday morning. A trailing window always has
/// something to compare against.
class WeeklyChart extends ConsumerWidget {
  const WeeklyChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final days = ref.watch(weeklyExpensesProvider).valueOrNull ?? const [];

    final maxMinor =
        days.fold<int>(0, (m, d) => d.totalMinor > m ? d.totalMinor : m);
    final total = days.fold<int>(0, (s, d) => s + d.totalMinor);
    final hasData = maxMinor > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(l10n.lastSevenDays, style: theme.textTheme.titleMedium),
            if (hasData)
              MoneyText(
                minor: total,
                currency: currency,
                style: theme.textTheme.labelMedium,
                color: money.muted,
                fractionScale: 0.84,
              ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 116,
          child: hasData
              ? _Bars(days: days, maxMinor: maxMinor)
              : _ChartEmpty(message: l10n.emptyChartBody),
        ),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.days, required this.maxMinor});

  final List<DailyTotal> days;
  final int maxMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final ink = theme.colorScheme.onSurface;
    final today = DateTime.now();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        // Headroom so the tallest bar never touches the top edge.
        maxY: maxMinor * 1.2,
        barTouchData: BarTouchData(enabled: false),
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
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;

                return Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    // A single letter keeps seven labels legible on a narrow
                    // phone without rotating them.
                    DateFormat('EEEEE', 'ro_RO').format(day).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? ink : money.muted,
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
              barRods: [
                BarChartRodData(
                  // A day with no spending draws nothing. The baseline and
                  // the letter beneath it already hold the slot, and a stub
                  // small enough to mean "zero" just reads as a rendering
                  // artefact.
                  toY: days[i].totalMinor.toDouble(),
                  width: 18,
                  // A flat cap on empty days. A rounded one reads as a very
                  // small bar, which is a different claim than "no spending".
                  borderRadius: days[i].totalMinor == 0
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(top: Radius.circular(4)),
                  // Today at full ink, earlier days receding. The eye lands on
                  // "where am I now" before anything else.
                  color: days[i].totalMinor == 0
                      ? money.hairline
                      : ink.withValues(
                          alpha: i == days.length - 1 ? 1.0 : 0.28,
                        ),
                ),
              ],
            ),
        ],
      ),
      duration: Motion.of(context, Motion.chart),
      curve: Motion.ease,
    );
  }
}

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
