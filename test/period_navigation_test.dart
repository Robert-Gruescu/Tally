import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/core/period.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/providers.dart';

/// Moving backwards through time.
///
/// The whole app was welded to "now" until this existed, and the arithmetic
/// that unwelds it is exactly the kind that breaks silently at month edges:
/// January minus one, a 31st that has no counterpart, a week that straddles
/// two months.
void main() {
  group('DateRange.shifted, by month', () {
    test('zero is the month containing today', () {
      final now = DateTime(2026, 8, 17);
      expect(DateRange.shifted(Period.month, 0, anchor: now),
          DateRange.of(Period.month, anchor: now));
    });

    test('one step back is the previous calendar month', () {
      final range =
          DateRange.shifted(Period.month, -1, anchor: DateTime(2026, 8, 17));
      expect(range.from, DateTime(2026, 7, 1));
      expect(range.to, DateTime(2026, 8, 1));
    });

    test('crosses into the previous year', () {
      final range =
          DateRange.shifted(Period.month, -1, anchor: DateTime(2026, 1, 15));
      expect(range.from, DateTime(2025, 12, 1));
      expect(range.to, DateTime(2026, 1, 1));
    });

    test('twelve steps back lands on the same month a year earlier', () {
      final range =
          DateRange.shifted(Period.month, -12, anchor: DateTime(2026, 8, 17));
      expect(range.from, DateTime(2025, 8, 1));
      expect(range.to, DateTime(2025, 9, 1));
    });

    test('stepping back from the 31st does not skip February', () {
      // Naive "minus thirty days" arithmetic from 31 March lands on 1 March and
      // skips February entirely. Stepping by whole months cannot.
      final range =
          DateRange.shifted(Period.month, -1, anchor: DateTime(2026, 3, 31));
      expect(range.from, DateTime(2026, 2, 1));
      expect(range.to, DateTime(2026, 3, 1));
    });

    test('consecutive steps tile without gap or overlap', () {
      final anchor = DateTime(2026, 8, 17);
      for (var i = -11; i < 0; i++) {
        final older = DateRange.shifted(Period.month, i, anchor: anchor);
        final newer = DateRange.shifted(Period.month, i + 1, anchor: anchor);
        expect(older.to, newer.from, reason: 'gaură între pasul $i și ${i + 1}');
      }
    });
  });

  group('DateRange.shifted, by week', () {
    test('one step back is the previous Monday to Sunday', () {
      // 2026-08-19 is a Wednesday.
      final range =
          DateRange.shifted(Period.week, -1, anchor: DateTime(2026, 8, 19));
      expect(range.from, DateTime(2026, 8, 10));
      expect(range.to, DateTime(2026, 8, 17));
      expect(range.from.weekday, DateTime.monday);
    });

    test('every step stays seven days long', () {
      for (var i = -20; i <= 0; i++) {
        final range =
            DateRange.shifted(Period.week, i, anchor: DateTime(2026, 8, 19));
        expect(range.dayCount, 7, reason: 'pasul $i');
        expect(range.from.weekday, DateTime.monday);
      }
    });

    test('crosses a month boundary without losing days', () {
      final range =
          DateRange.shifted(Period.week, -1, anchor: DateTime(2026, 9, 3));
      expect(range.from, DateTime(2026, 8, 24));
      expect(range.to, DateTime(2026, 8, 31));
    });
  });

  group('DateRange.shifted, by day', () {
    test('one step back is yesterday', () {
      final range =
          DateRange.shifted(Period.day, -1, anchor: DateTime(2026, 8, 1, 15));
      expect(range.from, DateTime(2026, 7, 31));
      expect(range.to, DateTime(2026, 8, 1));
    });

    test('handles the turn of the year', () {
      final range =
          DateRange.shifted(Period.day, -1, anchor: DateTime(2026, 1, 1, 9));
      expect(range.from, DateTime(2025, 12, 31));
    });
  });

  group('DateRange.lastMonths', () {
    test('twelve months ends with the current one', () {
      final range = DateRange.lastMonths(12, anchor: DateTime(2026, 8, 17));
      expect(range.from, DateTime(2025, 9, 1));
      expect(range.to, DateTime(2026, 9, 1));
    });

    test('crosses a year boundary', () {
      final range = DateRange.lastMonths(12, anchor: DateTime(2026, 2, 5));
      expect(range.from, DateTime(2025, 3, 1));
      expect(range.to, DateTime(2026, 3, 1));
    });
  });

  group('watchMonthlyTotals', () {
    late AppDatabase db;
    late int food;
    late int salary;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedDefaultCategories(db);
      final categories = await db.allCategories();
      food = categories.firstWhere((c) => c.name == 'Mâncare').id;
      salary = categories.firstWhere((c) => c.name == 'Salariu').id;
    });

    tearDown(() => db.close());

    Future<void> add({
      required int minor,
      required DateTime at,
      TxKind kind = TxKind.expense,
    }) =>
        db.insertTxn(TransactionsCompanion.insert(
          amountMinor: minor,
          kind: kind,
          categoryId: kind == TxKind.income ? salary : food,
          note: const Value(null),
          spentAt: at,
        ));

    test('separates income from expense, month by month', () async {
      await add(minor: 4250, at: DateTime(2026, 6, 10, 12));
      await add(minor: 1000, at: DateTime(2026, 6, 20, 12));
      await add(minor: 500000, at: DateTime(2026, 6, 5, 9), kind: TxKind.income);
      await add(minor: 2000, at: DateTime(2026, 7, 3, 12));

      final months = await db
          .watchMonthlyTotals(
            from: DateTime(2026, 6, 1),
            to: DateTime(2026, 8, 1),
          )
          .first;

      expect(months, hasLength(2));
      expect(months[0].month, DateTime(2026, 6, 1));
      expect(months[0].expenseMinor, 5250);
      expect(months[0].incomeMinor, 500000);
      expect(months[0].balanceMinor, 494750);
      expect(months[1].expenseMinor, 2000);
      expect(months[1].incomeMinor, 0);
    });

    test('fills empty months so the axis keeps twelve slots', () async {
      await add(minor: 100, at: DateTime(2026, 3, 10, 12));

      final months = await db
          .watchMonthlyTotals(
            from: DateTime(2025, 9, 1),
            to: DateTime(2026, 9, 1),
          )
          .first;

      expect(months, hasLength(12));
      expect(months.first.month, DateTime(2025, 9, 1));
      expect(months.last.month, DateTime(2026, 8, 1));
      expect(months.where((m) => m.isEmpty), hasLength(11));
    });

    test('a late evening on the last day stays in its own month', () async {
      // SQLite would resolve this in UTC and hand it to the previous month for
      // anyone east of Greenwich. The bucketing is done in Dart for this.
      await add(minor: 900, at: DateTime(2026, 6, 30, 23, 45));

      final months = await db
          .watchMonthlyTotals(
            from: DateTime(2026, 6, 1),
            to: DateTime(2026, 8, 1),
          )
          .first;

      expect(months[0].expenseMinor, 900);
      expect(months[1].expenseMinor, 0);
    });

    test('the very first instant of a month belongs to it', () async {
      await add(minor: 700, at: DateTime(2026, 7, 1));

      final months = await db
          .watchMonthlyTotals(
            from: DateTime(2026, 6, 1),
            to: DateTime(2026, 8, 1),
          )
          .first;

      expect(months[0].expenseMinor, 0);
      expect(months[1].expenseMinor, 700);
    });

    test('an empty history still returns the full window', () async {
      final months = await db
          .watchMonthlyTotals(
            from: DateTime(2025, 9, 1),
            to: DateTime(2026, 9, 1),
          )
          .first;

      expect(months, hasLength(12));
      expect(months.every((m) => m.isEmpty), isTrue);
    });
  });

  /// Tapping a bar narrows the totals to that day while the chart keeps
  /// drawing the whole window. These pin the wiring that makes that true.
  group('picking a day out of the chart', () {
    ProviderContainer make() => ProviderContainer(overrides: []);

    test('with nothing picked, the window is the period', () {
      final c = make();
      addTearDown(c.dispose);

      c.read(periodProvider.notifier).state = Period.month;
      expect(c.read(effectiveRangeProvider), c.read(dateRangeProvider));
    });

    test('picking a day narrows the window to exactly that day', () {
      final c = make();
      addTearDown(c.dispose);

      final day = DateTime(2026, 6, 17);
      c.read(selectedDayProvider.notifier).state = day;

      final range = c.read(effectiveRangeProvider);
      expect(range.from, day);
      expect(range.to, DateTime(2026, 6, 18));
      expect(range.dayCount, 1);
    });

    test('the comparison window becomes the day before', () {
      final c = make();
      addTearDown(c.dispose);

      c.read(selectedDayProvider.notifier).state = DateTime(2026, 6, 17);

      final previous = c.read(effectiveRangeProvider).previous;
      expect(previous.from, DateTime(2026, 6, 16));
      expect(previous.to, DateTime(2026, 6, 17));
    });

    test('letting go restores the whole period', () {
      final c = make();
      addTearDown(c.dispose);

      c.read(selectedDayProvider.notifier).state = DateTime(2026, 6, 17);
      c.read(selectedDayProvider.notifier).state = null;

      expect(c.read(effectiveRangeProvider), c.read(dateRangeProvider));
    });

    test('a picked day survives across the first of a month', () {
      final c = make();
      addTearDown(c.dispose);

      // The last day of a 31 day month: the next day is the 1st, not the 32nd.
      c.read(selectedDayProvider.notifier).state = DateTime(2026, 7, 31);
      expect(c.read(effectiveRangeProvider).to, DateTime(2026, 8, 1));
    });

    test('the chart window ignores the pick', () {
      final c = make();
      addTearDown(c.dispose);

      c.read(periodProvider.notifier).state = Period.month;
      final before = c.read(dateRangeProvider);
      c.read(selectedDayProvider.notifier).state = DateTime(2026, 6, 17);

      // Collapsing the chart to a single bar would take away the very thing
      // the user was reading when they tapped.
      expect(c.read(dateRangeProvider), before);
    });
  });

  /// Walking back stops at the oldest thing recorded. Empty years behind that
  /// are a way to get lost, not a feature.
  group('how far back the arrow goes', () {
    late AppDatabase db;
    late int food;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedDefaultCategories(db);
      food = (await db.allCategories())
          .firstWhere((c) => c.name == 'Mâncare')
          .id;
    });

    tearDown(() => db.close());

    Future<void> add(DateTime at) => db.insertTxn(
          TransactionsCompanion.insert(
            amountMinor: 1000,
            kind: TxKind.expense,
            categoryId: food,
            note: const Value(null),
            spentAt: at,
          ),
        );

    test('an empty history reports no first date', () async {
      expect(await db.watchFirstTransactionDate().first, isNull);
    });

    test('reports the oldest transaction, not the newest', () async {
      await add(DateTime(2026, 5, 20, 12));
      await add(DateTime(2026, 2, 3, 9));
      await add(DateTime(2026, 8, 1, 18));

      expect(
        await db.watchFirstTransactionDate().first,
        DateTime(2026, 2, 3, 9),
      );
    });

    test('the bound moves back when an older row is added', () async {
      await add(DateTime(2026, 5, 20, 12));
      expect(await db.watchFirstTransactionDate().first,
          DateTime(2026, 5, 20, 12));

      // Someone entering a receipt they forgot about extends the reachable
      // history, and the arrow has to notice.
      await add(DateTime(2025, 11, 4, 10));
      expect(await db.watchFirstTransactionDate().first,
          DateTime(2025, 11, 4, 10));
    });

    test('a window starting before the first row is the end of the road',
        () async {
      await add(DateTime(2026, 5, 20, 12));
      final first = await db.watchFirstTransactionDate().first;

      // The month holding the oldest row: its start is before that row, so
      // there is nothing older to walk to.
      final may = DateRange.of(Period.month, anchor: DateTime(2026, 5, 20));
      expect(may.from.isAfter(first!), isFalse);

      // The month after it still has somewhere to go.
      final june = DateRange.of(Period.month, anchor: DateTime(2026, 6, 10));
      expect(june.from.isAfter(first), isTrue);
    });
  });
}
