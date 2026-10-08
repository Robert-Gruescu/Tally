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
/// The app used to refuse any date past today, on the grounds that a future
/// date is almost always a typo. It is also the only way to write down the
/// rent you are about to pay, so the restriction is gone — and with it gone,
/// the balance can now contain money nobody has actually spent or received.
///
/// That is the intended behaviour: planning how the month ends is the reason
/// for entering it. What these pin is that it is never *silent* — the ledger
/// says which rows have not happened yet — and that it does not leak into the
/// two places where a future date would be a lie.
void main() {
  late AppDatabase db;
  late int food;
  late int salary;

  DateTime day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset, 12);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDefaultCategories(db);
    final categories = await db.allCategories();
    food = categories.firstWhere((c) => c.name == 'Mâncare').id;
    salary = categories.firstWhere((c) => c.name == 'Salariu').id;
  });

  tearDown(() => db.close());

  Future<void> add(int offset, int minor,
          {TxKind kind = TxKind.expense, int? category}) =>
      db.insertTxn(TransactionsCompanion.insert(
        amountMinor: minor,
        kind: kind,
        categoryId: category ?? (kind == TxKind.income ? salary : food),
        spentAt: day(offset),
      ));

  group('the balance looks ahead', () {
    test('a payment dated later this month counts', () async {
      // The point of entering it. Someone planning the month needs the figure
      // to include the rent they know is coming out.
      await add(0, 5000);
      await add(3, 120000);

      final range = DateRange.of(Period.month);
      final summary = await db
          .watchSummary(from: range.from, to: range.to)
          .first;

      expect(summary.expenseMinor, 125000);
    });

    test('income expected later counts the same way', () async {
      await add(5, 450000, kind: TxKind.income);

      final range = DateRange.of(Period.month);
      final summary = await db
          .watchSummary(from: range.from, to: range.to)
          .first;

      expect(summary.incomeMinor, 450000);
      expect(summary.balanceMinor, 450000);
    });

    test('it still lands in the right month, not this one', () async {
      // Two months out is outside the window and must stay outside it.
      await add(70, 99900);

      final range = DateRange.of(Period.month);
      final summary = await db
          .watchSummary(from: range.from, to: range.to)
          .first;

      expect(summary.expenseMinor, 0);
    });
  });

  group('what it must not touch', () {
    test('a future entry does not inflate the run of days', () async {
      // The streak counts back from today. An entry dated next week is not a
      // day anybody kept the habit on, and counting it would hand out a run
      // for work not done.
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

    test('a run already going is not extended by one', () async {
      await add(0, 1000);
      await add(-1, 1000);
      await add(1, 1000);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container.read(loggedDaysProvider.future);

      expect(container.read(streakProvider), 2);
    });
  });

  group('the ledger says so', () {
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
      // Disposing the scope cancels drift's streams, and cancelling one
      // schedules a timer. Done here so it has a frame to run in.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    testWidgets('a day ahead is marked, so the balance is not a surprise',
        (tester) async {
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
