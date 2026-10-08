import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/core/period.dart';
import 'package:tally/core/theme.dart';
import 'package:tally/features/home/home_screen.dart';
import 'package:tally/l10n/gen/app_localizations.dart';
import 'package:tally/providers.dart';

/// Money that has not moved yet.
///
/// The date picker used to stop at today, on the grounds that a future date is
/// almost always a typo. It is also the only way to write down the rent you
/// are about to pay, so the restriction is gone.
///
/// The rule that replaced it: **a planned payment is in the ledger and out of
/// every total until its day arrives.** A balance that already counts next
/// week's rent is not a balance, it is a forecast wearing a balance's clothes
/// — and the first version of this shipped exactly that mistake.
///
/// So the row shows up immediately, marked, and crosses into the totals on the
/// day it is dated. These pin both halves.
void main() {
  late AppDatabase db;
  late int food;
  late int salary;

  DateTime day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset, 12);
  }

  /// A moment late on the day [offset] days from now, used as the cutoff.
  DateTime standingOn(int offset) {
    final d = day(offset);
    return DateTime(d.year, d.month, d.day, 23, 59);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDefaultCategories(db);
    final categories = await db.allCategories();
    food = categories.firstWhere((c) => c.name == 'Mâncare').id;
    salary = categories.firstWhere((c) => c.name == 'Salariu').id;
  });

  tearDown(() => db.close());

  Future<void> add(int offset, int minor, {TxKind kind = TxKind.expense}) =>
      db.insertTxn(TransactionsCompanion.insert(
        amountMinor: minor,
        kind: kind,
        categoryId: kind == TxKind.income ? salary : food,
        spentAt: day(offset),
      ));

  Future<PeriodSummary> summaryAt(DateTime asOf) {
    final range = DateRange.of(Period.month);
    return db
        .watchSummary(from: range.from, to: range.to, asOf: asOf)
        .first;
  }

  group('the balance is what has actually moved', () {
    test('a payment dated later this month is left out', () async {
      await add(0, 5000);
      await add(4, 120000);

      final summary = await summaryAt(standingOn(0));
      expect(summary.expenseMinor, 5000,
          reason: 'only the money that has gone');
    });

    test('income expected later is left out too', () async {
      await add(0, 5000);
      await add(6, 450000, kind: TxKind.income);

      final summary = await summaryAt(standingOn(0));
      expect(summary.incomeMinor, 0);
      expect(summary.balanceMinor, -5000);
    });

    test('it joins the balance on the day it is dated', () async {
      // The whole point. Nothing is re-entered and nothing is confirmed; the
      // row simply stops being in the future.
      await add(4, 120000);

      expect((await summaryAt(standingOn(3))).expenseMinor, 0,
          reason: 'the day before');
      expect((await summaryAt(standingOn(4))).expenseMinor, 120000,
          reason: 'the day itself');
    });

    test('a payment entered for today counts straight away', () async {
      await add(0, 7500);
      expect((await summaryAt(standingOn(0))).expenseMinor, 7500);
    });
  });

  group('every total agrees with the balance', () {
    test('the category ranking leaves it out', () async {
      await add(0, 5000);
      await add(4, 120000);

      final range = DateRange.of(Period.month);
      final totals = await db
          .watchCategoryTotals(
            from: range.from,
            to: range.to,
            kind: TxKind.expense,
            asOf: standingOn(0),
          )
          .first;

      expect(totals.single.totalMinor, 5000);
    });

    test('the twelve-month chart leaves it out', () async {
      await add(0, 5000);
      await add(4, 120000);

      final range = DateRange.lastMonths(12);
      final months = await db
          .watchMonthlyTotals(
            from: range.from,
            to: range.to,
            asOf: standingOn(0),
          )
          .first;

      expect(months.last.expenseMinor, 5000);
    });

    test('the daily chart leaves it out', () async {
      await add(0, 5000);
      await add(2, 120000);

      final today = DateRange.today();
      final days = await db
          .watchDailyExpenses(
            from: DateTime(today.year, today.month, today.day - 1),
            to: DateTime(today.year, today.month, today.day + 5),
            asOf: standingOn(0),
          )
          .first;

      expect(days.fold<int>(0, (s, d) => s + d.totalMinor), 5000);
    });
  });

  group('but the ledger shows it', () {
    test('the list carries it from the moment it is written', () async {
      // Out of the totals is not the same as hidden. Somebody who has just
      // entered next month's rent has to be able to see that it saved.
      await add(4, 120000);

      final range = DateRange.of(Period.month);
      final rows =
          await db.watchTransactions(from: range.from, to: range.to).first;

      expect(rows, hasLength(1));
      expect(rows.single.txn.amountMinor, 120000);
    });
  });

  group('what it must not touch', () {
    test('a future entry does not inflate the run of days', () async {
      await add(0, 1000);
      await add(4, 1000);
      await add(5, 1000);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container.read(loggedDaysProvider.future);

      expect(container.read(streakProvider), 1);
    });
  });

  group('the ledger says which rows have not happened', () {
    Future<void> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light(AppFlavor.princess),
          locale: const Locale('ro'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> takeDown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    testWidgets('a day ahead is marked', (tester) async {
      await add(2, 120000);
      await pump(tester);

      expect(find.text('urmează'), findsOneWidget);
      await takeDown(tester);
    });

    testWidgets('days that have happened carry no mark', (tester) async {
      await add(0, 4250);
      await add(-1, 1800);
      await pump(tester);

      expect(find.text('urmează'), findsNothing);
      await takeDown(tester);
    });

    testWidgets('tomorrow is named, not dated', (tester) async {
      await add(1, 3000);
      await pump(tester);

      expect(find.text('Mâine'), findsOneWidget);
      await takeDown(tester);
    });
  });
}
