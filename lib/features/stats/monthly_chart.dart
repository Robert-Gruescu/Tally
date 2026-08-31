import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/period.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// A year at a glance: income and expense side by side for each month.
///
/// The period selector answers "how much this month"; this answers "is it
/// getting worse", which is the question a single period can never answer no
/// matter how you slice it.
///
/// Every month is also a way in: tapping one moves the whole app to it, which
/// beats pressing the back arrow eleven times.
class MonthlyChart extends ConsumerWidget {
  const MonthlyChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final months = ref.watch(monthlyTotalsProvider).valueOrNull ?? const [];

    if (months.isEmpty) return const SizedBox.shrink();

    final withData = months.where((m) => !m.isEmpty).toList();
    final maxMinor = months.fold<int>(
      0,
      (m, e) => [m, e.incomeMinor, e.expenseMinor].reduce((a, b) => a > b ? a : b),
    );

    // One month of data cannot show a trend, and a chart implying otherwise is
    // worse than a sentence saying so.
    if (withData.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.twelveMonths, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.noHistoryYet, style: theme.textTheme.bodySmall),
        ],
      );
    }

    final spent = withData.fold<int>(0, (s, m) => s + m.expenseMinor);
    final average = spent ~/ withData.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(l10n.twelveMonths, style: theme.textTheme.titleMedium),
            Row(
              children: [
                Text('${l10n.monthlyAverage} ', style: theme.textTheme.bodySmall),
                MoneyText(
                  minor: average,
                  currency: currency,
                  showCurrency: false,
                  style: theme.textTheme.labelMedium,
                  color: money.muted,
                  fractionScale: 0.84,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.twelveMonthsSub, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        _Legend(money: money),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: _Bars(months: months, maxMinor: maxMinor),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.money});

  final MoneyColors money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        );

    // Two series need a key. One does not, which is why the daily chart has
    // none.
    return Row(
      children: [
        item(money.income, l10n.income),
        const SizedBox(width: 18),
        item(money.expense, l10n.expenses),
      ],
    );
  }
}

class _Bars extends ConsumerWidget {
  const _Bars({required this.months, required this.maxMinor});

  final List<MonthTotal> months;
  final int maxMinor;

  /// Moves the whole app to the tapped month.
  void _open(WidgetRef ref, MonthTotal month) {
    final now = DateTime.now();
    final offset =
        (month.month.year - now.year) * 12 + (month.month.month - now.month);

    HapticFeedback.selectionClick();
    ref.read(periodProvider.notifier).state = Period.month;
    ref.read(periodOffsetProvider.notifier).state = offset.clamp(-120, 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final now = DateTime.now();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxMinor * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: money.hairline)),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            getTooltipItem: (_, _, _, _) => null,
          ),
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions) return;
            final index = response?.spot?.touchedBarGroupIndex;
            if (index == null || index < 0 || index >= months.length) return;
            _open(ref, months[index]);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= months.length) {
                  return const SizedBox.shrink();
                }
                final month = months[index].month;
                final isNow =
                    month.year == now.year && month.month == now.month;

                return Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    // One letter per month: twelve labels have to fit a phone.
                    DateFormat('MMMMM', 'ro_RO').format(month).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                      color: isNow ? theme.colorScheme.onSurface : money.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                _rod(months[i].incomeMinor, money.income),
                _rod(months[i].expenseMinor, money.expense),
              ],
            ),
        ],
      ),
      duration: Motion.of(context, Motion.chart),
      curve: Motion.ease,
    );
  }

  BarChartRodData _rod(int minor, Color color) => BarChartRodData(
        toY: minor.toDouble(),
        width: 7,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        color: color,
      );
}
