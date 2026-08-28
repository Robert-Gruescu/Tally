import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/core/period.dart';

/// The data layer carries every number the user sees, and two of its bugs
/// survived until they were spotted by eye on an emulator: totals silently
/// coming back as zero, and a day's spending landing on the wrong bar. Both
/// are pinned here.
void main() {
  late AppDatabase db;
  late int food;
  late int transport;
  late int salary;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDefaultCategories(db);

    final categories = await db.allCategories();
    food = categories.firstWhere((c) => c.name == 'Mâncare').id;
    transport = categories.firstWhere((c) => c.name == 'Transport').id;
    salary = categories.firstWhere((c) => c.name == 'Salariu').id;
  });

  tearDown(() => db.close());

  Future<void> add({
    required int minor,
    required int categoryId,
    required DateTime at,
    TxKind kind = TxKind.expense,
    String? note,
  }) =>
      db.insertTxn(
        TransactionsCompanion.insert(
          amountMinor: minor,
          kind: kind,
          categoryId: categoryId,
          note: Value(note),
          spentAt: at,
        ),
      );

  group('seed', () {
    test('creates eight expense and four income categories', () async {
      final all = await db.allCategories();
      expect(all.where((c) => c.kind == TxKind.expense), hasLength(8));
      expect(all.where((c) => c.kind == TxKind.income), hasLength(4));
    });

    test('running twice does not duplicate', () async {
      await seedDefaultCategories(db);
      expect(await db.countCategories(), 12);
    });
  });

  group('watchSummary', () {
    test('separates income from expense', () async {
      final day = DateTime(2026, 3, 10, 12);
      await add(minor: 4250, categoryId: food, at: day);
      await add(minor: 1000, categoryId: transport, at: day);
      await add(
        minor: 300000,
        categoryId: salary,
        at: day,
        kind: TxKind.income,
      );

      final summary = await db
          .watchSummary(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
          .first;

      // The regression: `textEnum` stores `Enum.name`, and comparing the raw
      // read against the enum itself silently matched nothing, so every total
      // came back zero.
      expect(summary.expenseMinor, 5250);
      expect(summary.incomeMinor, 300000);
      expect(summary.balanceMinor, 294750);
    });

    test('an empty period reports zero rather than failing', () async {
      final summary = await db
          .watchSummary(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
          .first;

      expect(summary.expenseMinor, 0);
      expect(summary.incomeMinor, 0);
    });

    test('the range excludes its end instant', () async {
      // Half-open `[from, to)`: a transaction at exactly midnight belongs to
      // the month starting there, never to the one ending there.
      await add(minor: 999, categoryId: food, at: DateTime(2026, 4, 1));

      final march = await db
          .watchSummary(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
          .first;
      final april = await db
          .watchSummary(from: DateTime(2026, 4, 1), to: DateTime(2026, 5, 1))
          .first;

      expect(march.expenseMinor, 0);
      expect(april.expenseMinor, 999);
    });

    test('the last second of a day is still counted', () async {
      // The classic off-by-one: a range built with 23:59:59 drops this row.
      await add(
        minor: 500,
        categoryId: food,
        at: DateTime(2026, 3, 31, 23, 59, 59, 999),
      );

      final summary = await db
          .watchSummary(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
          .first;

      expect(summary.expenseMinor, 500);
    });
  });

  group('watchDailyExpenses', () {
    test('buckets by local day, not UTC', () async {
      // Late evening local time falls on the previous UTC day for anyone east
      // of Greenwich. Grouping with SQLite's `date()` put this on yesterday's
      // bar; grouping in Dart keeps it where the user spent it.
      final lateEvening = DateTime(2026, 3, 10, 23, 30);
      await add(minor: 2500, categoryId: food, at: lateEvening);

      final days = await db
          .watchDailyExpenses(
            from: DateTime(2026, 3, 8),
            to: DateTime(2026, 3, 11),
          )
          .first;

      final tenth = days.firstWhere((d) => d.day == DateTime(2026, 3, 10));
      expect(tenth.totalMinor, 2500);
      expect(days.where((d) => d.totalMinor > 0), hasLength(1));
    });

    test('fills empty days with zero so the axis stays stable', () async {
      await add(minor: 100, categoryId: food, at: DateTime(2026, 3, 9, 10));

      final days = await db
          .watchDailyExpenses(
            from: DateTime(2026, 3, 8),
            to: DateTime(2026, 3, 15),
          )
          .first;

      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 3, 8));
      expect(days.last.day, DateTime(2026, 3, 14));
      expect(days.map((d) => d.totalMinor).toList(),
          [0, 100, 0, 0, 0, 0, 0]);
    });

    test('sums several transactions on the same day', () async {
      final day = DateTime(2026, 3, 9);
      await add(minor: 100, categoryId: food, at: day.add(const Duration(hours: 9)));
      await add(minor: 250, categoryId: transport, at: day.add(const Duration(hours: 18)));

      final days = await db
          .watchDailyExpenses(from: day, to: DateTime(2026, 3, 10))
          .first;

      expect(days.single.totalMinor, 350);
    });

    test('income never appears on the spending chart', () async {
      final day = DateTime(2026, 3, 9, 10);
      await add(minor: 500000, categoryId: salary, at: day, kind: TxKind.income);

      final days = await db
          .watchDailyExpenses(from: DateTime(2026, 3, 9), to: DateTime(2026, 3, 10))
          .first;

      expect(days.single.totalMinor, 0);
    });
  });

  group('watchCategoryTotals', () {
    test('ranks categories by spend, largest first', () async {
      final day = DateTime(2026, 3, 10, 12);
      await add(minor: 1000, categoryId: transport, at: day);
      await add(minor: 4250, categoryId: food, at: day);
      await add(minor: 1750, categoryId: food, at: day);

      final totals = await db
          .watchCategoryTotals(
            from: DateTime(2026, 3, 1),
            to: DateTime(2026, 4, 1),
            kind: TxKind.expense,
          )
          .first;

      expect(totals, hasLength(2));
      expect(totals.first.category.name, 'Mâncare');
      expect(totals.first.totalMinor, 6000);
      expect(totals.last.totalMinor, 1000);
    });

    test('asking for income does not return expense categories', () async {
      final day = DateTime(2026, 3, 10, 12);
      await add(minor: 4250, categoryId: food, at: day);

      final totals = await db
          .watchCategoryTotals(
            from: DateTime(2026, 3, 1),
            to: DateTime(2026, 4, 1),
            kind: TxKind.income,
          )
          .first;

      expect(totals, isEmpty);
    });
  });

  group('writes', () {
    test('a stream re-emits when a row is inserted', () async {
      final stream = db.watchSummary(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 4, 1),
      );

      // This is the whole reactive premise: nothing re-reads, and yet the
      // second value arrives.
      final values = <int>[];
      final sub = stream.listen((s) => values.add(s.expenseMinor));

      await pumpEventQueue();
      await add(minor: 4250, categoryId: food, at: DateTime(2026, 3, 10, 12));
      await pumpEventQueue();

      await sub.cancel();
      expect(values, containsAllInOrder([0, 4250]));
    });

    test('editing changes the totals', () async {
      await add(minor: 4250, categoryId: food, at: DateTime(2026, 3, 10, 12));
      final row = (await db
              .watchTransactions(
                  from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
              .first)
          .single
          .txn;

      await db.updateTxn(row.copyWith(amountMinor: 999));

      final summary = await db
          .watchSummary(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
          .first;
      expect(summary.expenseMinor, 999);
    });

    test('a category in use cannot be deleted out from under its rows',
        () async {
      await add(minor: 4250, categoryId: food, at: DateTime(2026, 3, 10, 12));

      // `KeyAction.restrict` plus `PRAGMA foreign_keys = ON`. Without both,
      // the history would quietly lose its category.
      expect(
        () => (db.delete(db.categories)..where((c) => c.id.equals(food))).go(),
        throwsA(anything),
      );
    });

    test('deleting all transactions keeps the categories', () async {
      await add(minor: 4250, categoryId: food, at: DateTime(2026, 3, 10, 12));
      await db.deleteAllTransactions();

      expect(await db.countCategories(), 12);
      final summary = await db
          .watchSummary(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
          .first;
      expect(summary.expenseMinor, 0);
    });

    test('recentAmounts offers the newest distinct amounts', () async {
      await add(minor: 1200, categoryId: food, at: DateTime(2026, 3, 1, 10));
      await add(minor: 2500, categoryId: food, at: DateTime(2026, 3, 5, 10));
      await add(minor: 800, categoryId: food, at: DateTime(2026, 3, 9, 10));

      final recent = await db.recentAmounts(food);
      expect(recent.first, 800);
      expect(recent, hasLength(3));
    });
  });

  group('DateRange', () {
    test('a week starts on Monday', () {
      // 2026-03-11 is a Wednesday.
      final week = DateRange.of(Period.week, anchor: DateTime(2026, 3, 11, 15));
      expect(week.from, DateTime(2026, 3, 9));
      expect(week.to, DateTime(2026, 3, 16));
    });

    test('a month spans the calendar month', () {
      final month = DateRange.of(Period.month, anchor: DateTime(2026, 2, 17));
      expect(month.from, DateTime(2026, 2, 1));
      expect(month.to, DateTime(2026, 3, 1));
    });

    test('the previous month steps by month, not by days', () {
      final march = DateRange.of(Period.month, anchor: DateTime(2026, 3, 20));
      expect(march.previous.from, DateTime(2026, 2, 1));
      expect(march.previous.to, DateTime(2026, 3, 1));
    });

    test('the last seven days always has seven', () {
      final range = DateRange.lastSevenDays();
      expect(range.dayCount, 7);
    });
  });
}
