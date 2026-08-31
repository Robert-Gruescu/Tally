import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/core/recurrence.dart';
import 'package:tally/core/recurrence_service.dart';

/// Every subtle bug in a recurring feature is a date bug: the 31st of a month
/// with 30 days, the month boundary, the catch-up after a long absence, the
/// same salary landing twice. All of them are pinned here.
void main() {
  group('Recurrence.dueDateIn', () {
    test('keeps a day that exists', () {
      expect(Recurrence.dueDateIn(2026, 3, 15), DateTime(2026, 3, 15));
    });

    test('clamps the 31st to the end of a short month', () {
      expect(Recurrence.dueDateIn(2026, 4, 31), DateTime(2026, 4, 30));
      expect(Recurrence.dueDateIn(2026, 2, 31), DateTime(2026, 2, 28));
    });

    test('knows about leap years', () {
      // 2028 is a leap year; 2026 is not.
      expect(Recurrence.dueDateIn(2028, 2, 31), DateTime(2028, 2, 29));
      expect(Recurrence.daysInMonth(2028, 2), 29);
      expect(Recurrence.daysInMonth(2026, 2), 28);
    });

    test('clamping never spills into the next month', () {
      for (var month = 1; month <= 12; month++) {
        final due = Recurrence.dueDateIn(2026, month, 31);
        expect(due.month, month, reason: 'ziua 31 a sărit din luna $month');
      }
    });
  });

  group('Recurrence.dueDatesBetween', () {
    test('produces one date per month', () {
      final dates = Recurrence.dueDatesBetween(
        dayOfMonth: 5,
        start: DateTime(2026, 1, 1),
        through: DateTime(2026, 4, 30),
      );
      expect(dates, [
        DateTime(2026, 1, 5),
        DateTime(2026, 2, 5),
        DateTime(2026, 3, 5),
        DateTime(2026, 4, 5),
      ]);
    });

    test('excludes a due date before the rule started', () {
      // The rule starts on the 10th of January, after that month's 5th.
      final dates = Recurrence.dueDatesBetween(
        dayOfMonth: 5,
        start: DateTime(2026, 1, 10),
        through: DateTime(2026, 3, 31),
      );
      expect(dates, [DateTime(2026, 2, 5), DateTime(2026, 3, 5)]);
    });

    test('includes a due date falling exactly on the start', () {
      final dates = Recurrence.dueDatesBetween(
        dayOfMonth: 5,
        start: DateTime(2026, 1, 5),
        through: DateTime(2026, 1, 31),
      );
      expect(dates, [DateTime(2026, 1, 5)]);
    });

    test('excludes a due date still in the future', () {
      // Today is the 3rd; the 5th has not happened yet.
      final dates = Recurrence.dueDatesBetween(
        dayOfMonth: 5,
        start: DateTime(2026, 1, 1),
        through: DateTime(2026, 3, 3),
      );
      expect(dates, [DateTime(2026, 1, 5), DateTime(2026, 2, 5)]);
    });

    test('crosses a year boundary', () {
      final dates = Recurrence.dueDatesBetween(
        dayOfMonth: 20,
        start: DateTime(2026, 11, 1),
        through: DateTime(2027, 2, 28),
      );
      expect(dates, [
        DateTime(2026, 11, 20),
        DateTime(2026, 12, 20),
        DateTime(2027, 1, 20),
        DateTime(2027, 2, 20),
      ]);
    });

    test('the 31st still yields twelve dates in a year', () {
      final dates = Recurrence.dueDatesBetween(
        dayOfMonth: 31,
        start: DateTime(2026, 1, 1),
        through: DateTime(2026, 12, 31),
      );
      expect(dates, hasLength(12));
      expect(dates[1], DateTime(2026, 2, 28));
      expect(dates[3], DateTime(2026, 4, 30));
    });

    test('returns nothing when the window is inverted', () {
      expect(
        Recurrence.dueDatesBetween(
          dayOfMonth: 5,
          start: DateTime(2026, 6, 1),
          through: DateTime(2026, 1, 1),
        ),
        isEmpty,
      );
    });
  });

  group('RecurrenceService', () {
    late AppDatabase db;
    late int salary;
    late int subscriptions;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedDefaultCategories(db);
      final categories = await db.allCategories();
      salary = categories.firstWhere((c) => c.name == 'Salariu').id;
      subscriptions =
          categories.firstWhere((c) => c.name == 'Abonamente').id;
    });

    tearDown(() => db.close());

    Future<int> addRule({
      required int amountMinor,
      required int categoryId,
      required int dayOfMonth,
      required DateTime startsOn,
      TxKind kind = TxKind.income,
      bool isActive = true,
    }) =>
        db.insertRule(RecurringRulesCompanion.insert(
          amountMinor: amountMinor,
          kind: kind,
          categoryId: categoryId,
          dayOfMonth: dayOfMonth,
          startsOn: startsOn,
          isActive: Value(isActive),
        ));

    test('creates one pending question per elapsed month', () async {
      await addRule(
        amountMinor: 500000,
        categoryId: salary,
        dayOfMonth: 5,
        startsOn: DateTime(2026, 1, 1),
      );

      final created = await RecurrenceService.materialize(
        db,
        now: DateTime(2026, 3, 20),
      );

      expect(created, 3);
      final pending = await db.watchPending().first;
      expect(pending.map((p) => p.occurrence.dueOn), [
        DateTime(2026, 1, 5),
        DateTime(2026, 2, 5),
        DateTime(2026, 3, 5),
      ]);
    });

    test('nothing is created before the due day arrives', () async {
      await addRule(
        amountMinor: 500000,
        categoryId: salary,
        dayOfMonth: 25,
        startsOn: DateTime(2026, 3, 1),
      );

      final created = await RecurrenceService.materialize(
        db,
        now: DateTime(2026, 3, 24),
      );

      expect(created, 0);
      expect(await db.watchPending().first, isEmpty);
    });

    test('running twice does not ask the same question twice', () async {
      await addRule(
        amountMinor: 4999,
        categoryId: subscriptions,
        dayOfMonth: 10,
        startsOn: DateTime(2026, 1, 1),
        kind: TxKind.expense,
      );

      await RecurrenceService.materialize(db, now: DateTime(2026, 2, 15));
      final second =
          await RecurrenceService.materialize(db, now: DateTime(2026, 2, 15));

      // The duplicate guard: opening the app twice in a day must not produce
      // the subscription twice.
      expect(second, 0);
      expect(await db.watchPending().first, hasLength(2));
    });

    test('catches up after months without opening the app', () async {
      await addRule(
        amountMinor: 500000,
        categoryId: salary,
        dayOfMonth: 5,
        startsOn: DateTime(2026, 1, 1),
      );

      await RecurrenceService.materialize(db, now: DateTime(2026, 1, 10));
      expect(await db.watchPending().first, hasLength(1));

      await RecurrenceService.materialize(db, now: DateTime(2026, 6, 10));
      expect(await db.watchPending().first, hasLength(6));
    });

    test('an inactive rule stops producing questions', () async {
      final id = await addRule(
        amountMinor: 500000,
        categoryId: salary,
        dayOfMonth: 5,
        startsOn: DateTime(2026, 1, 1),
        isActive: false,
      );
      expect(id, isPositive);

      final created =
          await RecurrenceService.materialize(db, now: DateTime(2026, 6, 10));
      expect(created, 0);
    });

    test('a rule added today does not invent a year of back pay', () async {
      await addRule(
        amountMinor: 500000,
        categoryId: salary,
        dayOfMonth: 5,
        startsOn: DateTime(2026, 6, 1),
      );

      await RecurrenceService.materialize(db, now: DateTime(2026, 6, 20));
      expect(await db.watchPending().first, hasLength(1));
    });
  });

  group('answering a question', () {
    late AppDatabase db;
    late int salary;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedDefaultCategories(db);
      salary = (await db.allCategories())
          .firstWhere((c) => c.name == 'Salariu')
          .id;
      await db.insertRule(RecurringRulesCompanion.insert(
        amountMinor: 500000,
        kind: TxKind.income,
        categoryId: salary,
        dayOfMonth: 5,
        startsOn: DateTime(2026, 1, 1),
        note: const Value('salariu lunar'),
      ));
      await RecurrenceService.materialize(db, now: DateTime(2026, 2, 10));
    });

    tearDown(() => db.close());

    test('yes writes a real transaction dated to the due day', () async {
      final pending = await db.watchPending().first;
      final first = pending.first;

      await db.confirmOccurrence(first.occurrence, first.rule);

      final txns = await db.allTransactions();
      expect(txns, hasLength(1));
      expect(txns.single.amountMinor, 500000);
      expect(txns.single.kind, TxKind.income);
      expect(txns.single.note, 'salariu lunar');
      // Dated to the 5th, not to the day it was confirmed.
      expect(txns.single.spentAt, DateTime(2026, 1, 5));
    });

    test('an answered question stops being asked', () async {
      final pending = await db.watchPending().first;
      expect(pending, hasLength(2));

      await db.confirmOccurrence(pending[0].occurrence, pending[0].rule);
      await db.skipOccurrence(pending[1].occurrence.id);

      expect(await db.watchPending().first, isEmpty);
    });

    test('no leaves the books untouched', () async {
      final pending = await db.watchPending().first;
      await db.skipOccurrence(pending.first.occurrence.id);

      expect(await db.allTransactions(), isEmpty);
    });

    test('a later pass does not re-ask an answered month', () async {
      final pending = await db.watchPending().first;
      await db.skipOccurrence(pending.first.occurrence.id);

      await RecurrenceService.materialize(db, now: DateTime(2026, 2, 10));

      final still = await db.watchPending().first;
      expect(still, hasLength(1));
      expect(still.single.occurrence.dueOn, DateTime(2026, 2, 5));
    });

    test('deleting a rule keeps the money it already recorded', () async {
      final pending = await db.watchPending().first;
      await db.confirmOccurrence(pending.first.occurrence, pending.first.rule);

      final ruleId = pending.first.rule.id;
      await db.deleteRule(ruleId);

      // The rule is gone, the salary that actually arrived is not.
      expect(await db.watchRules().first, isEmpty);
      expect(await db.allTransactions(), hasLength(1));
      expect(await db.watchPending().first, isEmpty);
    });

    test('raising the amount does not rewrite what was already confirmed',
        () async {
      final pending = await db.watchPending().first;
      await db.confirmOccurrence(pending[0].occurrence, pending[0].rule);

      final rule = pending[0].rule;
      await db.updateRule(rule.copyWith(amountMinor: 600000));

      final txns = await db.allTransactions();
      expect(txns.single.amountMinor, 500000, reason: 'istoricul s-a rescris');

      // The question still open now carries the new amount.
      final stillPending = await db.watchPending().first;
      expect(stillPending.single.rule.amountMinor, 600000);
    });
  });

  /// The switch inside the transaction sheet creates a rule whose `startsOn`
  /// is the day after the transaction. These pin the consequence of that one
  /// line, which is the difference between a helpful feature and one that
  /// immediately asks about money the user has just entered by hand.
  group('a rule created alongside a transaction', () {
    late AppDatabase db;
    late int salary;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedDefaultCategories(db);
      salary =
          (await db.allCategories()).firstWhere((c) => c.name == 'Salariu').id;
    });

    tearDown(() => db.close());

    /// Mirrors what the sheet does on save: the row, then the rule starting
    /// the day after it.
    Future<void> addWithRule({
      required DateTime spentAt,
      required int dayOfMonth,
    }) async {
      await db.insertTxn(TransactionsCompanion.insert(
        amountMinor: 500000,
        kind: TxKind.income,
        categoryId: salary,
        spentAt: spentAt,
      ));
      await db.insertRule(RecurringRulesCompanion.insert(
        amountMinor: 500000,
        kind: TxKind.income,
        categoryId: salary,
        dayOfMonth: dayOfMonth,
        startsOn: DateTime(spentAt.year, spentAt.month, spentAt.day + 1),
      ));
    }

    test('does not ask about the month just entered by hand', () async {
      await addWithRule(spentAt: DateTime(2026, 3, 5), dayOfMonth: 5);

      await RecurrenceService.materialize(db, now: DateTime(2026, 3, 20));

      // March was entered manually; asking about it again would double it.
      expect(await db.watchPending().first, isEmpty);
      expect(await db.allTransactions(), hasLength(1));
    });

    test('asks from the following month onwards', () async {
      await addWithRule(spentAt: DateTime(2026, 3, 5), dayOfMonth: 5);

      await RecurrenceService.materialize(db, now: DateTime(2026, 5, 10));

      final pending = await db.watchPending().first;
      expect(pending.map((p) => p.occurrence.dueOn),
          [DateTime(2026, 4, 5), DateTime(2026, 5, 5)]);
    });

    test('a later day in the same month is still caught', () async {
      // Entered a receipt on the 3rd but the subscription bills on the 25th:
      // this month's 25th has not happened yet and must still be asked about.
      await addWithRule(spentAt: DateTime(2026, 3, 3), dayOfMonth: 25);

      await RecurrenceService.materialize(db, now: DateTime(2026, 3, 26));

      final pending = await db.watchPending().first;
      expect(pending, hasLength(1));
      expect(pending.single.occurrence.dueOn, DateTime(2026, 3, 25));
    });

    test('the last day of the month survives a short February', () async {
      await addWithRule(spentAt: DateTime(2026, 1, 31), dayOfMonth: 31);

      await RecurrenceService.materialize(db, now: DateTime(2026, 4, 30));

      final pending = await db.watchPending().first;
      expect(pending.map((p) => p.occurrence.dueOn), [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('the manual transaction is untouched by the rule', () async {
      await addWithRule(spentAt: DateTime(2026, 3, 5), dayOfMonth: 5);
      await RecurrenceService.materialize(db, now: DateTime(2026, 4, 10));

      final pending = await db.watchPending().first;
      await db.confirmOccurrence(pending.single.occurrence, pending.single.rule);

      final txns = await db.allTransactions();
      expect(txns, hasLength(2));
      expect(txns.first.spentAt, DateTime(2026, 3, 5));
      expect(txns.last.spentAt, DateTime(2026, 4, 5));
    });
  });
}
