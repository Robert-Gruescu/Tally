import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/core/theme.dart';
import 'package:tally/features/home/home_screen.dart';
import 'package:tally/features/stats/stats_screen.dart';
import 'package:tally/l10n/gen/app_localizations.dart';
import 'package:tally/providers.dart';

/// The screens under the conditions that break layouts, rather than the ones
/// that flatter them.
///
/// Every overflow this project has had came from the same place: a `Row` whose
/// two halves are both allowed to take their natural width. It never shows on
/// the phone it was built on, because the numbers there are small and the font
/// is the default. It shows for the reader with a big balance, a long weekday
/// name, or enlarged text, and by then it is in their hands.
///
/// So the numbers here are deliberately unkind: six figures, and a system font
/// scaled to double, on the narrowest screen anyone still carries.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(320, 640),
  double textScale = 1.0,
  bool rich = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedDefaultCategories(db);
  addTearDown(db.close);

  if (rich) {
    final categories = await db.allCategories();
    final food = categories.firstWhere((c) => c.name == 'Mâncare').id;
    final home = categories.firstWhere((c) => c.name == 'Locuință').id;
    final salary = categories.firstWhere((c) => c.name == 'Salariu').id;

    final now = DateTime.now();
    // A Wednesday somewhere in the middle of the month, so the day header
    // renders a full weekday name rather than the short "Azi".
    final midMonth = DateTime(now.year, now.month, 15, 12);

    // Six figures: a salary and a rent, which is what the day header and the
    // balance have to hold side by side.
    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 1875050,
      kind: TxKind.income,
      categoryId: salary,
      note: const Value('Salariu lunar, cu bonusul de performanță inclus'),
      spentAt: midMonth,
    ));
    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 1299999,
      kind: TxKind.expense,
      categoryId: home,
      note: const Value('Chirie plus întreținere și utilități'),
      spentAt: midMonth,
    ));
    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 24575,
      kind: TxKind.expense,
      categoryId: food,
      spentAt: DateTime(now.year, now.month, now.day, 9),
    ));
  }

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
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
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Takes the screen back down while the test is still running.
///
/// Disposing a `ProviderScope` cancels drift's query streams, and cancelling
/// one schedules a zero-duration timer. Left to the framework's own teardown
/// there is nothing left to run it, and the test fails on a pending timer that
/// has nothing to do with the layout being measured. Unmounting here, inside
/// the body, gives the timer a frame to fire in.
Future<void> _takeDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('Acasă holds six figures at text scale $scale', (tester) async {
      await _pump(tester, const HomeScreen(), textScale: scale);
      expect(tester.takeException(), isNull);
      await _takeDown(tester);
    });

    testWidgets('Statistici holds six figures at text scale $scale',
        (tester) async {
      await _pump(tester, const StatsScreen(), textScale: scale);
      expect(tester.takeException(), isNull);
      await _takeDown(tester);
    });
  }

  testWidgets('Acasă survives an empty ledger', (tester) async {
    await _pump(tester, const HomeScreen(), rich: false);
    expect(tester.takeException(), isNull);
    await _takeDown(tester);
  });

  testWidgets('Statistici survives an empty ledger', (tester) async {
    await _pump(tester, const StatsScreen(), rich: false);
    expect(tester.takeException(), isNull);
    await _takeDown(tester);
  });
}
