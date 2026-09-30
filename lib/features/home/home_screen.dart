import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/backup.dart';
import '../../core/backup_folder.dart';
import '../../core/db/database.dart';
import '../../core/period.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/period_navigator.dart';
import '../../core/widgets/period_selector.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../recurring/pending_banner.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/transaction_tile.dart';
import 'weekly_chart.dart';

/// One flat list of day headers and transaction rows, so the whole ledger
/// scrolls in a single sliver instead of a list of nested lists.
sealed class _Row {
  const _Row();
}

class _DayHeader extends _Row {
  const _DayHeader(this.day, this.netMinor);
  final DateTime day;
  final int netMinor;
}

class _Entry extends _Row {
  const _Entry(this.entry, {required this.isLast});
  final TxnWithCategory entry;
  final bool isLast;
}

List<_Row> _group(List<TxnWithCategory> items) {
  final rows = <_Row>[];
  DateTime? currentDay;
  var dayStart = 0;

  for (final item in items) {
    final at = item.txn.spentAt.toLocal();
    final day = DateTime(at.year, at.month, at.day);

    if (day != currentDay) {
      if (currentDay != null) rows[dayStart] = _closeDay(rows, dayStart);
      currentDay = day;
      dayStart = rows.length;
      rows.add(_DayHeader(day, 0));
    }
    rows.add(_Entry(item, isLast: false));
  }
  if (currentDay != null) rows[dayStart] = _closeDay(rows, dayStart);

  // Mark the final row of each day so it can drop its separator.
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row is _Entry) {
      final last = i + 1 >= rows.length || rows[i + 1] is _DayHeader;
      if (last) rows[i] = _Entry(row.entry, isLast: true);
    }
  }
  return rows;
}

/// Sums the entries written after [start] into that day's header.
_DayHeader _closeDay(List<_Row> rows, int start) {
  final header = rows[start] as _DayHeader;
  var net = 0;
  for (var i = start + 1; i < rows.length; i++) {
    final row = rows[i];
    if (row is! _Entry) break;
    final txn = row.entry.txn;
    net += txn.kind == TxKind.income ? txn.amountMinor : -txn.amountMinor;
  }
  return _DayHeader(header.day, net);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final transactions = ref.watch(transactionsProvider);

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
                  const SizedBox(height: 28),
                  // Above the balance on purpose: an unanswered question means
                  // the number underneath is not yet the whole truth.
                  const PendingBanner(),
                  const _BalanceBlock(),
                  const SizedBox(height: 32),
                  const WeeklyChart(),
                  const SizedBox(height: 36),
                  Text(l10n.transactions, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Divider(color: money.hairline, height: 1),
                ],
              ),
            ),
          ),
          transactions.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 200)),
            error: (e, _) => SliverToBoxAdapter(
              child: SizedBox(height: 200, child: Center(child: Text('$e'))),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SliverToBoxAdapter(child: _EmptyState(l10n: l10n));
              }
              final rows = _group(items);
              return SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => switch (rows[i]) {
                  _DayHeader(:final day, :final netMinor) =>
                    _DayHeaderRow(day: day, netMinor: netMinor),
                  _Entry(:final entry, :final isLast) =>
                    TransactionTile(entry: entry, showSeparator: !isLast),
                },
              );
            },
          ),
          // Clears the add button and the navigation bar.
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// The balance is the hero and carries no uppercase kicker above it; the label
/// names the period in plain language instead, which the number cannot.
class _BalanceBlock extends ConsumerWidget {
  const _BalanceBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final period = ref.watch(periodProvider);
    final data = ref.watch(summaryProvider).valueOrNull ?? PeriodSummary.empty;
    final balance = data.balanceMinor;

    // A day picked from the chart renames the block, so the big number is
    // never labelled "luna aceasta" while showing one Tuesday.
    final picked = ref.watch(selectedDayProvider);
    final periodName = picked != null
        ? _dayName(context, picked)
        : switch (period) {
            Period.day => l10n.periodNameDay,
            Period.week => l10n.periodNameWeek,
            Period.month => l10n.periodNameMonth,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.balanceIn(periodName), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        MoneyText(
          minor: balance,
          currency: currency,
          signed: true,
          // Red only when there is income to have outspent. If the user logs
          // expenses alone the balance is negative by definition, and painting
          // it red every single day turns the warning into wallpaper.
          color: balance < 0 && data.incomeMinor > 0
              ? money.expense
              : theme.colorScheme.onSurface,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _FlowStat(
                label: l10n.income,
                minor: data.incomeMinor,
                color: money.income,
                currency: currency,
              ),
            ),
            Container(width: 1, height: 36, color: money.hairline),
            Expanded(
              child: _FlowStat(
                label: l10n.expenses,
                minor: data.expenseMinor,
                color: money.expense,
                currency: currency,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "vineri, 29 aug", or the friendlier word when it is close enough to now.
String _dayName(BuildContext context, DateTime day) {
  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  if (day == today) return l10n.periodNameDay;
  if (day == yesterday) return l10n.yesterday.toLowerCase();
  return DateFormat('EEEE, d MMM', 'ro_RO').format(day);
}

class _FlowStat extends StatelessWidget {
  const _FlowStat({
    required this.label,
    required this.minor,
    required this.color,
    required this.currency,
    this.alignEnd = false,
  });

  final String label;
  final int minor;
  final Color color;
  final String currency;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // A dot rather than an arrow: the label already says which
            // direction this is, so the mark only has to carry the colour.
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            // The label is one word, but one word set at twice the size no
            // longer fits half a narrow screen beside the dot. Allowed to
            // shrink rather than to push the row off the edge.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        MoneyText(
          minor: minor,
          currency: currency,
          style: theme.textTheme.titleMedium,
          // Zero carries no direction, so it stays neutral. Green nothing
          // reads as good news that has not happened.
          color: minor == 0
              ? theme.extension<MoneyColors>()!.muted
              : color,
          fractionScale: 0.76,
        ),
      ],
    );
  }
}

/// A dated rule across the ledger. Grouping by day is what turns a flat feed
/// into something you can scan for "what did Saturday cost me".
class _DayHeaderRow extends ConsumerWidget {
  const _DayHeaderRow({required this.day, required this.netMinor});

  final DateTime day;
  final int netMinor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);

    final today = DateRange.today();
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final String label;
    if (day == today) {
      label = l10n.today;
    } else if (day == yesterday) {
      label = l10n.yesterday;
    } else {
      final formatted = DateFormat('EEEE, d MMMM', 'ro_RO').format(day);
      label = formatted[0].toUpperCase() + formatted.substring(1);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: money.muted),
          ),
          MoneyText(
            minor: netMinor,
            currency: currency,
            signed: true,
            showCurrency: false,
            style: theme.textTheme.labelMedium,
            color: money.muted,
            fractionScale: 0.84,
          ),
        ],
      ),
    );
  }
}

/// The empty ledger, and the one moment it is worth asking about a backup.
///
/// A reinstalled app looks exactly like a new one: same empty list, same
/// zeroes. Android will not let it read what the previous installation left
/// behind, so if nobody asks, a folder full of the user's records sits on the
/// phone untouched while they start typing again from scratch.
///
/// The question is phrased so someone genuinely new can read it once and move
/// on, and it appears only while there is nothing recorded.
class _EmptyState extends ConsumerStatefulWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  ConsumerState<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends ConsumerState<_EmptyState> {
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _findBackup() async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = widget.l10n;
    final prefs = ref.read(preferencesProvider);

    final chosen = await BackupFolder.choose(prefs);
    if (chosen == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    final found = await BackupFolder.list(prefs);
    if (!mounted) return;
    setState(() => _busy = false);

    if (found.isEmpty) {
      // The folder is now remembered even so: tomorrow's snapshot goes there,
      // which is the other half of what this button is for.
      _toast(l10n.noBackupsInFolder);
      return;
    }

    final newest = found.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.foundBackups(found.length)),
        // Not the usual "everything you have now will be replaced": this
        // only ever runs while the ledger is empty, and warning someone
        // about losing nothing is how a dialog teaches them not to read.
        content: Text(l10n.restoreFoundBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.restoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final summary =
          await BackupFolder.restore(ref.read(databaseProvider), newest.uri);
      _toast(l10n.restoreDone(summary.transactions));
    } on BackupError catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Text(
            l10n.emptyTransactionsTitle,
            style: theme.textTheme.titleMedium?.copyWith(color: money.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.emptyTransactionsBody,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: () => showAddTransactionSheet(context),
            child: Text(l10n.addExpense),
          ),
          const SizedBox(height: 40),
          Divider(color: money.hairline, height: 1),
          const SizedBox(height: 24),
          Text(
            l10n.hadAppBefore,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.hadAppBeforeBody,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _busy ? null : _findBackup,
            child: Text(l10n.findMyBackup),
          ),
        ],
      ),
    );
  }
}
