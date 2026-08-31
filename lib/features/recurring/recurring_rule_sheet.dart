import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_icons.dart';
import '../../core/db/database.dart';
import '../../core/money.dart';
import '../../core/recurrence_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/day_of_month_picker.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

Future<void> showRecurringRuleSheet(
  BuildContext context, {
  RuleWithCategory? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => RecurringRuleSheet(existing: existing),
  );
}

/// Creating or editing a salary, a subscription, a rent.
///
/// Deliberately shaped like the transaction sheet: same direction toggle, same
/// amount field, same category grid. One extra control, the day of the month,
/// and one different meaning: this describes what is *expected*, not what
/// happened.
class RecurringRuleSheet extends ConsumerStatefulWidget {
  const RecurringRuleSheet({super.key, this.existing});

  final RuleWithCategory? existing;

  @override
  ConsumerState<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

class _RecurringRuleSheetState extends ConsumerState<RecurringRuleSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();

  TxKind _kind = TxKind.income;
  int? _categoryId;
  int _dayOfMonth = 1;
  bool _isActive = true;
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.existing?.rule;
    if (rule == null) {
      // A new rule defaults to today's day: most people set one up on or near
      // the day it just happened.
      _dayOfMonth = DateTime.now().day;
      return;
    }

    _kind = rule.kind;
    _categoryId = rule.categoryId;
    _dayOfMonth = rule.dayOfMonth;
    _isActive = rule.isActive;
    _noteController.text = rule.note ?? '';

    final whole = rule.amountMinor ~/ Money.minorPerMajor;
    final fraction = rule.amountMinor % Money.minorPerMajor;
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
      _categoryId = null;
      _error = null;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);

    final minor = Money.parse(_amountController.text);
    if (_amountController.text.trim().isEmpty) {
      setState(() => _error = l10n.errorAmountRequired);
      _amountFocus.requestFocus();
      return;
    }
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

    final db = ref.read(databaseProvider);
    final note = _noteController.text.trim();
    final noteValue = Value(note.isEmpty ? null : note);
    final existing = widget.existing?.rule;

    if (existing != null) {
      // `startsOn` is never rewritten: it is what stops an edit from inventing
      // occurrences for months before the rule existed.
      await db.updateRule(existing.copyWith(
        amountMinor: minor,
        kind: _kind,
        categoryId: categoryId,
        note: noteValue,
        dayOfMonth: _dayOfMonth,
        isActive: _isActive,
      ));
    } else {
      await db.insertRule(RecurringRulesCompanion.insert(
        amountMinor: minor,
        kind: _kind,
        categoryId: categoryId,
        note: noteValue,
        dayOfMonth: _dayOfMonth,
        // Backdated to the first of this month, so a rule added on the 20th
        // for a day that already passed still asks about this month once.
        startsOn: DateTime(DateTime.now().year, DateTime.now().month, 1),
        isActive: Value(_isActive),
      ));
    }

    // Ask immediately if the new rule is already due, instead of waiting for
    // the next launch.
    await RecurrenceService.materialize(db);

    HapticFeedback.mediumImpact();
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.ruleSaved), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final money = Theme.of(context).extension<MoneyColors>()!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ruleDeleteTitle),
        content: Text(l10n.ruleDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: money.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(databaseProvider).deleteRule(widget.existing!.rule.id);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.ruleDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final categories = ref.watch(categoriesProvider(_kind)).valueOrNull ?? const [];

    final accent = _kind == TxKind.expense ? money.expense : money.income;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KindTabs(
                kind: _kind,
                onChanged: _selectKind,
                incomeLabel: l10n.addIncome,
                expenseLabel: l10n.addExpense,
                incomeColor: money.income,
                expenseColor: money.expense,
              ),
              const SizedBox(height: 26),

              // amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      focusNode: _amountFocus,
                      autofocus: !_isEditing,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        LengthLimitingTextInputFormatter(12),
                      ],
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      cursorColor: accent,
                      style: theme.textTheme.displayMedium?.copyWith(color: accent),
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        hintText: '0',
                        hintStyle: theme.textTheme.displayMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(currency,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: money.muted)),
                ],
              ),
              const SizedBox(height: 26),

              DayOfMonthPicker(
                day: _dayOfMonth,
                label: l10n.ruleDay,
                lastDayLabel: l10n.lastDayOfMonth,
                onChanged: (d) => setState(() => _dayOfMonth = d),
              ),
              const SizedBox(height: 24),

              _Categories(
                categories: categories,
                selectedId: _categoryId,
                onSelect: (id) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _categoryId = id;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 140,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: l10n.noteOptional,
                  counterText: '',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 6),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _isActive ? l10n.rulePauseAction : l10n.ruleResumeAction,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ],

              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: theme.colorScheme.onPrimary),
                      )
                    : Text(l10n.save),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: money.expense),
                  child: Text(l10n.delete),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTabs extends StatelessWidget {
  const _KindTabs({
    required this.kind,
    required this.onChanged,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.incomeColor,
    required this.expenseColor,
  });

  final TxKind kind;
  final ValueChanged<TxKind> onChanged;
  final String incomeLabel;
  final String expenseLabel;
  final Color incomeColor;
  final Color expenseColor;

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
        // Income first: a recurring rule is far more often a salary than a
        // subscription, and the default should be the common case.
        Row(children: [
          half(TxKind.income, incomeLabel, incomeColor),
          half(TxKind.expense, expenseLabel, expenseColor),
        ]),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({
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
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? theme.colorScheme.onSurface : money.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
