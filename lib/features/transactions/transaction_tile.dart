import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_icons.dart';
import '../../core/db/database.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import 'add_transaction_sheet.dart';

/// A single line in the ledger.
///
/// Expenses print in ink, not red. In a list where almost every row is an
/// expense, colouring them all red spends the alarm on the ordinary case and
/// leaves nothing for the balance going negative. Green marks income because
/// income is the exception worth spotting.
///
/// Tapping opens the same sheet that created the row, prefilled. Swiping left
/// deletes with an undo snackbar rather than a confirmation dialog: the action
/// is cheap to reverse, and a modal on every mis-swipe is far more annoying
/// than the rare undo.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.entry,
    this.showSeparator = true,
  });

  final TxnWithCategory entry;
  final bool showSeparator;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    final txn = entry.txn;

    await db.deleteTxn(txn.id);
    HapticFeedback.mediumImpact();

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.deleted),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () {
            // Re-inserted without its old id, which sqlite would otherwise be
            // free to have handed to a newer row.
            db.insertTxn(
              TransactionsCompanion.insert(
                amountMinor: txn.amountMinor,
                kind: txn.kind,
                categoryId: txn.categoryId,
                note: Value(txn.note),
                spentAt: txn.spentAt,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);

    final isIncome = entry.txn.kind == TxKind.income;
    final note = entry.txn.note;

    return Dismissible(
      key: ValueKey(entry.txn.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: money.expense.withValues(alpha: 0.10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Icon(
              Icons.delete_outline_rounded,
              color: money.expense,
              size: 22,
            ),
          ),
        ),
      ),
      onDismissed: (_) => _delete(context, ref),
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            InkWell(
              onTap: () => showAddTransactionSheet(context, existing: entry),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                child: Row(
                  children: [
                    // A bare glyph, not a tinted chip. Twenty rounded squares
                    // stacked down the page read as tiles; the icon alone keeps
                    // the list looking like a statement.
                    Icon(
                      iconFor(entry.category.iconKey),
                      size: 21,
                      color: Color(entry.category.colorValue),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.category.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    MoneyText(
                      minor: isIncome
                          ? entry.txn.amountMinor
                          : -entry.txn.amountMinor,
                      currency: currency,
                      showCurrency: false,
                      signed: !isIncome,
                      showPlus: isIncome,
                      style: theme.textTheme.titleSmall,
                      color: isIncome
                          ? money.income
                          : theme.colorScheme.onSurface,
                      fractionScale: 0.8,
                    ),
                  ],
                ),
              ),
            ),
            if (showSeparator)
              Padding(
                // Inset to the text column, so the rule reads as a list
                // separator rather than a full-width cut across the screen.
                padding: const EdgeInsets.only(left: 60),
                child: Divider(color: money.hairline, height: 1),
              ),
          ],
        ),
      ),
    );
  }
}
