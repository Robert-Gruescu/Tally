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
import 'package:tally/features/transactions/transaction_tile.dart';
import 'package:tally/l10n/gen/app_localizations.dart';
import 'package:tally/providers.dart';

/// Swipe-to-delete and its undo bar.
///
/// The undo bar is here because of a real defect found on a phone: Flutter
/// defaults `SnackBar.persist` to `action != null`, so any snack bar with a
/// button silently ignores its own `duration` and stays on screen forever.
/// These tests fail if that default ever creeps back in.
void main() {
  late AppDatabase db;
  late TxnWithCategory entry;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDefaultCategories(db);
    final food =
        (await db.allCategories()).firstWhere((c) => c.name == 'Mâncare');

    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 4250,
      kind: TxKind.expense,
      categoryId: food.id,
      note: const Value('shaorma'),
      spentAt: DateTime(2026, 3, 10, 13),
    ));
    final txn = (await db.allTransactions()).single;
    entry = TxnWithCategory(txn: txn, category: food);
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {bool screenReader = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ro'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: screenReader),
            child: Scaffold(
              body: ListView(children: [TransactionTile(entry: entry)]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeAway(WidgetTester tester) async {
    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('the row renders its category and note', (tester) async {
    await pump(tester);
    expect(find.text('Mâncare'), findsOneWidget);
    expect(find.text('shaorma'), findsOneWidget);
  });

  testWidgets('swiping deletes the row and offers undo', (tester) async {
    await pump(tester);
    await swipeAway(tester);

    expect(find.text('Tranzacție ștearsă'), findsOneWidget);
    expect(find.text('Anulează'), findsOneWidget);
    expect(await db.allTransactions(), isEmpty);
  });

  testWidgets('the undo bar goes away on its own', (tester) async {
    await pump(tester);
    await swipeAway(tester);
    expect(find.text('Tranzacție ștearsă'), findsOneWidget);

    // Past the five second duration. Without `persist: false` this bar sits
    // there indefinitely, covering the add button.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('Tranzacție ștearsă'), findsNothing);
    expect(find.text('Anulează'), findsNothing);
  });

  testWidgets('undo puts the transaction back', (tester) async {
    await pump(tester);
    await swipeAway(tester);

    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();

    final restored = await db.allTransactions();
    expect(restored, hasLength(1));
    expect(restored.single.amountMinor, 4250);
    expect(restored.single.note, 'shaorma');
    expect(restored.single.spentAt, DateTime(2026, 3, 10, 13));
  });

  testWidgets('with a screen reader the bar waits for an answer',
      (tester) async {
    await pump(tester, screenReader: true);
    await swipeAway(tester);

    await tester.pump(const Duration(seconds: 6));

    // Snatching the only undo away on a timer is exactly the case Flutter's
    // default was written for, so there it still holds.
    expect(find.text('Anulează'), findsOneWidget);
  });
}
