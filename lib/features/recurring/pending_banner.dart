import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_icons.dart';
import '../../core/db/database.dart';
import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// The questions waiting at the top of Home.
///
/// The app asks rather than assuming, so a salary that did not arrive never
/// appears in the balance. The cost is one tap a month; the benefit is that
/// the numbers are never a guess.
///
/// Renders nothing at all when there is nothing to ask, so the common case
/// costs no vertical space.
class PendingBanner extends ConsumerWidget {
  const PendingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingOccurrencesProvider).valueOrNull;
    if (pending == null || pending.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        border: Border.all(color: money.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded, size: 17, color: money.muted),
                const SizedBox(width: 9),
                Text(
                  l10n.pendingCount(pending.length),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          for (var i = 0; i < pending.length; i++) ...[
            Divider(color: money.hairline, height: 1),
            _PendingRow(entry: pending[i]),
          ],
        ],
      ),
    );
  }
}

class _PendingRow extends ConsumerStatefulWidget {
  const _PendingRow({required this.entry});

  final PendingOccurrence entry;

  @override
  ConsumerState<_PendingRow> createState() => _PendingRowState();
}

class _PendingRowState extends ConsumerState<_PendingRow> {
  bool _answering = false;

  Future<void> _answer({required bool yes}) async {
    if (_answering) return;
    setState(() => _answering = true);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    final entry = widget.entry;

    if (yes) {
      await db.confirmOccurrence(entry.occurrence, entry.rule);
    } else {
      await db.skipOccurrence(entry.occurrence.id);
    }
    HapticFeedback.mediumImpact();

    // The row disappears with the stream, so the widget may already be gone.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(yes ? l10n.occurrenceConfirmed : l10n.occurrenceSkipped),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);

    final entry = widget.entry;
    final isIncome = entry.rule.kind == TxKind.income;
    final date = DateFormat('d MMMM', 'ro_RO').format(entry.occurrence.dueOn);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Icon(iconFor(entry.category.iconKey),
              size: 20, color: Color(entry.category.colorValue)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.rule.note?.isNotEmpty == true
                            ? entry.rule.note!
                            : entry.category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MoneyText(
                      minor: isIncome
                          ? entry.rule.amountMinor
                          : -entry.rule.amountMinor,
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
                const SizedBox(height: 2),
                Text(date, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // "Nu" first and quieter, "Da" filled: the common answer should be
          // the one that reads as the default, without hiding the other.
          _Answer(
            label: l10n.confirmNo,
            onTap: _answering ? null : () => _answer(yes: false),
            filled: false,
          ),
          const SizedBox(width: 6),
          _Answer(
            label: l10n.confirmYes,
            onTap: _answering ? null : () => _answer(yes: true),
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          // 44px tall including the padding: a target you can hit without
          // looking, which is the point of a one-tap answer.
          constraints: const BoxConstraints(minWidth: 46, minHeight: 38),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: filled ? theme.colorScheme.primary : null,
            border: filled ? null : Border.all(color: money.hairline),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: filled
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
