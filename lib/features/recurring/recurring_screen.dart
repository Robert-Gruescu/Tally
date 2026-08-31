import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_icons.dart';
import '../../core/db/database.dart';
import '../../core/recurrence.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import 'recurring_rule_sheet.dart';

/// Where salary and subscriptions are set up, reached from Settings.
///
/// Rules live here rather than beside ordinary transactions because they are
/// settings, not history: nothing on this screen is money that has moved.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const RecurringScreen(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final rules = ref.watch(rulesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurring)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showRecurringRuleSheet(context),
        tooltip: l10n.addRule,
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      body: rules.isEmpty
          ? _Empty(l10n: l10n)
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 110),
              itemCount: rules.length,
              separatorBuilder: (_, _) => Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Divider(color: money.hairline, height: 1),
              ),
              itemBuilder: (context, i) => _RuleRow(entry: rules[i]),
            ),
    );
  }
}

class _RuleRow extends ConsumerWidget {
  const _RuleRow({required this.entry});

  final RuleWithCategory entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);

    final rule = entry.rule;
    final isIncome = rule.kind == TxKind.income;
    final active = rule.isActive;

    final day = rule.dayOfMonth >= Recurrence.maxDay
        ? l10n.lastDayOfMonth
        : l10n.dayOfMonth(rule.dayOfMonth);

    return Opacity(
      // A paused rule stays visible but recedes, so it reads as "off" rather
      // than as something that failed to load.
      opacity: active ? 1 : 0.5,
      child: InkWell(
        onTap: () => showRecurringRuleSheet(context, existing: entry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 15),
          child: Row(
            children: [
              Icon(iconFor(entry.category.iconKey),
                  size: 21, color: Color(entry.category.colorValue)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.note?.isNotEmpty == true
                          ? rule.note!
                          : entry.category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? '${l10n.ruleDay} $day'
                          : '${l10n.rulePaused} · $day',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MoneyText(
                minor: isIncome ? rule.amountMinor : -rule.amountMinor,
                currency: currency,
                showCurrency: false,
                signed: !isIncome,
                showPlus: isIncome,
                style: theme.textTheme.titleSmall,
                color: isIncome ? money.income : theme.colorScheme.onSurface,
                fractionScale: 0.8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.recurringEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: money.muted),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.recurringEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
