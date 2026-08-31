import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_icons.dart';
import '../../core/db/database.dart';
import '../../core/money.dart';
import '../../core/period.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/period_navigator.dart';
import '../../core/widgets/period_selector.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import 'monthly_chart.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final totals = ref.watch(categoryTotalsProvider(TxKind.expense));
    final spent = ref.watch(summaryProvider).valueOrNull?.expenseMinor ?? 0;

    final items = totals.valueOrNull ?? const <CategoryTotal>[];

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PeriodSelector(),
                  const SizedBox(height: 4),
                  const PeriodNavigator(),
                  const SizedBox(height: 32),
                  if (spent == 0)
                    _StatsEmpty(l10n: l10n)
                  else ...[
                    const _Headline(),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 188,
                      child: _CategoryDonut(items: items, total: spent),
                    ),
                    const SizedBox(height: 36),
                  ],
                ],
              ),
            ),
          ),
          if (spent > 0)
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _CategoryRow(
                item: items[i],
                total: spent,
                isLast: i == items.length - 1,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    color: Theme.of(context).extension<MoneyColors>()!.hairline,
                    height: 1,
                  ),
                  const SizedBox(height: 32),
                  // Below the fold on purpose: the period you chose comes
                  // first, the year behind it second.
                  const MonthlyChart(),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// A total on its own says nothing. The comparison against the previous period
/// and the daily average are what turn a number into a judgement, and both are
/// near-free to compute.
class _Headline extends ConsumerWidget {
  const _Headline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final period = ref.watch(periodProvider);
    final range = ref.watch(dateRangeProvider);

    final spent = ref.watch(summaryProvider).valueOrNull?.expenseMinor ?? 0;
    final previousSpent =
        ref.watch(previousSummaryProvider).valueOrNull?.expenseMinor;

    final periodName = switch (period) {
      Period.day => l10n.periodNameDay,
      Period.week => l10n.periodNameWeek,
      Period.month => l10n.periodNameMonth,
    };

    // Elapsed days, not the full period: dividing this month's spending by 31
    // on the 3rd produces a flattering, useless average.
    final now = DateTime.now();
    final elapsed =
        range.contains(now) ? now.difference(range.from).inDays + 1 : range.dayCount;
    final average = spent ~/ (elapsed < 1 ? 1 : elapsed);

    double? change;
    if (previousSpent != null && previousSpent > 0) {
      change = (spent - previousSpent) / previousSpent * 100;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.spentIn(periodName), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        MoneyText(
          minor: spent,
          currency: currency,
          style: theme.textTheme.displayMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (change != null) ...[
              _Trend(change: change, money: money),
              const SizedBox(width: 14),
              Container(width: 1, height: 14, color: money.hairline),
              const SizedBox(width: 14),
            ],
            Text(
              l10n.dailyAverageValue(
                Money.format(average, currency: currency, showDecimals: false),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.change, required this.money});

  final double change;
  final MoneyColors money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Spending less is good news, so the colours invert relative to a stock
    // chart: down is green here.
    final up = change >= 0;
    final color = up ? money.expense : money.income;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          l10n.comparedToPrevious(change.abs().toStringAsFixed(0)),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _CategoryDonut extends ConsumerWidget {
  const _CategoryDonut({required this.items, required this.total});

  final List<CategoryTotal> items;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    // Past six slices a donut is unreadable, so the tail folds into one wedge.
    // The full ranking sits in the list underneath regardless.
    const maxSlices = 6;
    final visible = items.take(maxSlices).toList();
    final restMinor =
        items.skip(maxSlices).fold<int>(0, (s, e) => s + e.totalMinor);

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 72,
            startDegreeOffset: -90,
            sections: [
              for (final item in visible)
                PieChartSectionData(
                  value: item.totalMinor.toDouble(),
                  color: Color(item.category.colorValue),
                  radius: 16,
                  showTitle: false,
                ),
              if (restMinor > 0)
                PieChartSectionData(
                  value: restMinor.toDouble(),
                  color: money.muted.withValues(alpha: 0.32),
                  radius: 16,
                  showTitle: false,
                ),
            ],
          ),
          duration: Motion.of(context, Motion.chart),
          curve: Motion.ease,
        ),
        if (visible.isNotEmpty)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                visible.first.category.name,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.topCategoryShare(
                  (visible.first.totalMinor / total * 100).round().toString(),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.item,
    required this.total,
    required this.isLast,
  });

  final CategoryTotal item;
  final int total;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final color = Color(item.category.colorValue);
    final share = total == 0 ? 0.0 : item.totalMinor / total;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 14, 24, isLast ? 14 : 0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(iconFor(item.category.iconKey), size: 19, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.category.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${(share * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 14),
              MoneyText(
                minor: item.totalMinor,
                currency: currency,
                showCurrency: false,
                style: theme.textTheme.titleSmall,
                fractionScale: 0.8,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 3,
                backgroundColor: money.hairline,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsEmpty extends StatelessWidget {
  const _StatsEmpty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 16),
      child: Text(
        l10n.emptyChartBody,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
