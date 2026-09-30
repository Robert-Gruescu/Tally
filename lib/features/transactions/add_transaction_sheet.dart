import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_icons.dart';
import '../../core/db/database.dart';
import '../../core/money.dart';
import '../../core/recurrence.dart';
import '../../core/recurrence_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/day_of_month_picker.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// The single entry point for logging money.
///
/// Everything here is arranged around one number: seconds-to-save. The
/// keyboard is already up, the amount already has focus, the date already says
/// today, and the category is one tap. Anything that adds a step costs
/// retention, because an expense tracker dies the moment logging feels like
/// work.
Future<void> showAddTransactionSheet(
  BuildContext context, {
  TxKind kind = TxKind.expense,
  TxnWithCategory? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddTransactionSheet(initialKind: kind, existing: existing),
  );
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialKind = TxKind.expense,
    this.existing,
  });

  final TxKind initialKind;

  /// When set, the sheet edits this row instead of creating a new one. Editing
  /// reuses the same sheet on purpose: a separate edit screen would be the same
  /// eight fields with a different bug surface.
  final TxnWithCategory? existing;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();

  late TxKind _kind = widget.initialKind;
  int? _categoryId;
  DateTime _date = DateTime.now();
  String? _error;
  List<int> _recentAmounts = const [];
  bool _saving = false;

  /// Set from inside the sheet rather than from Settings: the moment
  /// someone knows a payment repeats is the moment they are entering it.
  bool _repeats = false;
  late int _repeatDay = DateTime.now().day;
  bool _repeatDayTouched = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing?.txn;
    if (existing == null) return;

    _kind = existing.kind;
    _categoryId = existing.categoryId;
    _date = existing.spentAt;
    _noteController.text = existing.note ?? '';
    // Written without a thousands separator so the field round-trips through
    // `Money.parse` exactly as it was stored.
    final whole = existing.amountMinor ~/ Money.minorPerMajor;
    final fraction = existing.amountMinor % Money.minorPerMajor;
    _amountController.text = fraction == 0
        ? '$whole'
        : '$whole,${fraction.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _selectKind(TxKind kind) {
    if (kind == _kind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kind = kind;
      // Categories are per-kind, so the previous pick is meaningless now.
      _categoryId = null;
      _recentAmounts = const [];
      _error = null;
    });
  }

  Future<void> _selectCategory(int id) async {
    HapticFeedback.selectionClick();
    setState(() {
      _categoryId = id;
      _error = null;
    });

    // Most people spend the same handful of amounts in a category. Offering
    // them removes the typing step entirely on repeat purchases.
    final recent = await ref.read(databaseProvider).recentAmounts(id);
    if (mounted) setState(() => _recentAmounts = recent);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      // No future-dated spending: it is almost always a typo, and it corrupts
      // "this month" totals in a way that is hard for a user to diagnose.
      lastDate: DateTime.now(),
      locale: const Locale('ro'),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
        // The repeat day trails the transaction date until the user picks one
        // deliberately: a salary entered for the 5th repeats on the 5th.
        if (!_repeatDayTouched) _repeatDay = picked.day;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final raw = _amountController.text;

    if (raw.trim().isEmpty) {
      setState(() => _error = l10n.errorAmountRequired);
      _amountFocus.requestFocus();
      return;
    }

    final minor = Money.parse(raw);
    if (minor == null) {
      setState(() => _error = l10n.errorAmountInvalid);
      _amountFocus.requestFocus();
      return;
    }

    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _error = l10n.errorCategoryRequired);
      return;
    }

    setState(() => _saving = true);

    // Read off this context before the first await, so nothing below has to
    // reach through a widget that may already be gone. The overlay belongs to
    // the root navigator and outlives this sheet, which is what lets the burst
    // play over the list the entry has just landed in rather than over a sheet
    // on its way out.
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    final confetti = ref.read(flavorProvider).confetti;
    final accent = Theme.of(context).colorScheme.primary;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    final db = ref.read(databaseProvider);
    final note = _noteController.text.trim();
    final noteValue = Value(note.isEmpty ? null : note);
    final existing = widget.existing?.txn;

    if (existing != null) {
      // `createdAt` deliberately keeps its original value: it records when the
      // row was first entered, not when it was last touched.
      await db.updateTxn(
        existing.copyWith(
          amountMinor: minor,
          kind: _kind,
          categoryId: categoryId,
          note: noteValue,
          spentAt: _date,
        ),
      );
    } else {
      await db.insertTxn(
        TransactionsCompanion.insert(
          amountMinor: minor,
          kind: _kind,
          categoryId: categoryId,
          note: noteValue,
          spentAt: _date,
        ),
      );

      if (_repeats) {
        await db.insertRule(RecurringRulesCompanion.insert(
          amountMinor: minor,
          kind: _kind,
          categoryId: categoryId,
          note: noteValue,
          dayOfMonth: _repeatDay,
          // The day after this transaction, so the rule never asks about the
          // occurrence just entered by hand. A later day in the same month is
          // still caught: entering a receipt on the 3rd and setting the 25th
          // asks about the 25th of this month.
          startsOn: DateTime(_date.year, _date.month, _date.day + 1),
        ));
        await RecurrenceService.materialize(db);
      }
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;

    Navigator.of(context).pop();
    showCelebration(
      overlay,
      icon: confetti,
      colour: accent,
      reducedMotion: reducedMotion,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? l10n.savedChanges
              : _repeats
                  ? l10n.savedWithRule
                  : _kind == TxKind.expense
                      ? l10n.savedExpense
                      : l10n.savedIncome,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final categories = ref.watch(categoriesProvider(_kind));

    final accent = _kind == TxKind.expense ? money.expense : money.income;

    return Padding(
      // Lifts the sheet above the keyboard. Without this the save button sits
      // under the numeric pad and the flow stalls at the last step.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KindToggle(
                kind: _kind,
                onChanged: _selectKind,
                expenseLabel: l10n.addExpense,
                incomeLabel: l10n.addIncome,
                expenseColor: money.expense,
                incomeColor: money.income,
              ),
              const SizedBox(height: 28),
              _AmountField(
                controller: _amountController,
                focusNode: _amountFocus,
                currency: currency,
                accent: accent,
                autofocus: !_isEditing,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
              ),
              if (_recentAmounts.isNotEmpty) ...[
                const SizedBox(height: 14),
                _QuickAmounts(
                  amounts: _recentAmounts,
                  currency: currency,
                  onPick: (minor) {
                    HapticFeedback.selectionClick();
                    _amountController.text =
                        Money.formatPlain(minor, showDecimals: false);
                    setState(() => _error = null);
                  },
                ),
              ],
              const SizedBox(height: 28),
              categories.when(
                loading: () => const SizedBox(height: 176),
                error: (e, _) => SizedBox(
                  height: 176,
                  child: Center(child: Text('$e')),
                ),
                data: (items) => _CategoryPicker(
                  categories: items,
                  selectedId: _categoryId,
                  onSelect: _selectCategory,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 140,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: l10n.noteOptional,
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DateChip(date: _date, onTap: _pickDate, l10n: l10n),
                ],
              ),
              // Editing is deliberately excluded: turning an existing row
              // into a rule raises questions about the months before it, and
              // that answer belongs on the rules screen, not here.
              if (!_isEditing) ...[
                const SizedBox(height: 8),
                _RepeatToggle(
                  value: _repeats,
                  day: _repeatDay,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _repeats = v);
                  },
                  onDayChanged: (d) => setState(() {
                    _repeatDay = d;
                    _repeatDayTouched = true;
                  }),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                // Ink, not the money colour. The button is the action; the
                // amount and the toggle already carry the direction, and a red
                // primary button reads as "destructive".
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two words with a rule under the active one, matching the period tabs. The
/// colour of the rule is the only place direction is stated before you type.
class _KindToggle extends StatelessWidget {
  const _KindToggle({
    required this.kind,
    required this.onChanged,
    required this.expenseLabel,
    required this.incomeLabel,
    required this.expenseColor,
    required this.incomeColor,
  });

  final TxKind kind;
  final ValueChanged<TxKind> onChanged;
  final String expenseLabel;
  final String incomeLabel;
  final Color expenseColor;
  final Color incomeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    Widget half(TxKind value, String label, Color color) {
      final selected = value == kind;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            onTap: () => onChanged(value),
            child: SizedBox(
              height: 46,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.of(context, Motion.fast),
                        curve: Motion.ease,
                        style: theme.textTheme.titleSmall!.copyWith(
                          color: selected ? color : money.muted,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        child: Text(label),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: Motion.of(context, Motion.base),
                    curve: Motion.ease,
                    height: 2,
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(height: 1, color: money.hairline),
        ),
        Row(
          children: [
            half(TxKind.expense, expenseLabel, expenseColor),
            half(TxKind.income, incomeLabel, incomeColor),
          ],
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.currency,
    required this.accent,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String currency;
  final Color accent;

  /// New entries open straight onto the keypad. An edit does not: the amount is
  /// already there, and popping the keyboard over a filled form hides the
  /// category the user probably came to change.
  final bool autofocus;

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final numeral = theme.textTheme.displayMedium!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Accepts both separators: people type 12,50 and 12.50 and neither
            // should be swallowed by the keyboard.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(12),
            ],
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            cursorColor: accent,
            cursorWidth: 2,
            style: numeral.copyWith(color: accent),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: '0',
              hintStyle: numeral.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          currency,
          style: theme.textTheme.titleMedium?.copyWith(color: money.muted),
        ),
      ],
    );
  }
}

class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({
    required this.amounts,
    required this.currency,
    required this.onPick,
  });

  final List<int> amounts;
  final String currency;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      children: [
        for (final minor in amounts)
          ActionChip(
            onPressed: () => onPick(minor),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(Money.format(
              minor,
              currency: currency,
              showDecimals: minor % Money.minorPerMajor != 0,
            )),
          ),
      ],
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 6,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (context, i) {
        final category = categories[i];
        final color = Color(category.colorValue);
        final selected = category.id == selectedId;

        return Semantics(
          selected: selected,
          button: true,
          label: category.name,
          child: InkWell(
            onTap: () => onSelect(category.id),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Selection lands on the glyph, not on a filled tile behind
                // the whole cell. Eight tinted rectangles in a grid is the
                // stock "feature cards" shape and it fights the type.
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  curve: Motion.ease,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: selected ? 0.14 : 0.0),
                    border: Border.all(
                      color: selected ? color : money.hairline,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Icon(iconFor(category.iconKey), color: color, size: 21),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? theme.colorScheme.onSurface
                          : money.muted,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.onTap,
    required this.l10n,
  });

  final DateTime date;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    final label = isToday
        ? l10n.today
        : isYesterday
            ? l10n.yesterday
            : DateFormat('d MMM', 'ro_RO').format(date);

    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.calendar_today_rounded, size: 15),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );
  }
}


/// The "this happens every month" switch, with the day revealed only once it
/// is turned on.
///
/// Collapsed by default because most transactions are one-offs; an always-open
/// day strip would push the save button off a small screen for the common case.
class _RepeatToggle extends StatelessWidget {
  const _RepeatToggle({
    required this.value,
    required this.day,
    required this.onChanged,
    required this.onDayChanged,
  });

  final bool value;
  final int day;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int> onDayChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    final dayLabel = day >= Recurrence.maxDay
        ? l10n.lastDayOfMonth
        : l10n.dayOfMonth(day);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: value ? money.muted : money.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.event_repeat_rounded, size: 19, color: money.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.repeatsMonthly,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          value
                              ? l10n.repeatsFromNextMonth(dayLabel)
                              : l10n.repeatsMonthlyHint,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.base),
            curve: Motion.ease,
            alignment: Alignment.topCenter,
            child: value
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: DayOfMonthPicker(
                      day: day,
                      onChanged: onDayChanged,
                      lastDayLabel: l10n.lastDayOfMonth,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
