import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/core/money.dart';
import 'package:tally/core/theme.dart';
import 'package:tally/features/transactions/add_transaction_sheet.dart';
import 'package:tally/l10n/gen/app_localizations.dart';
import 'package:tally/providers.dart';

/// The add sheet is the densest layout in the app: a grid of eight categories,
/// an oversized numeral field and a keyboard eating half the screen. Driving it
/// through the emulator turned out to be unreliable, so its layout is pinned
/// here instead, where a `RenderFlex overflowed` becomes a failing test.
Category _category(int id, String name, String iconKey) => Category(
      id: id,
      name: name,
      kind: TxKind.expense,
      iconKey: iconKey,
      colorValue: 0xFFB8422F,
      sortOrder: id,
      isArchived: false,
    );

final _categories = [
  _category(1, 'Mâncare', 'food'),
  _category(2, 'Transport', 'transport'),
  _category(3, 'Locuință', 'home'),
  _category(4, 'Cumpărături', 'shopping'),
  _category(5, 'Distracție', 'fun'),
  _category(6, 'Sănătate', 'health'),
  _category(7, 'Abonamente', 'subscriptions'),
  _category(8, 'Altele', 'other'),
];

TxnWithCategory _existing() => TxnWithCategory(
      txn: Txn(
        id: 7,
        amountMinor: 4250,
        kind: TxKind.expense,
        categoryId: 1,
        note: 'shaorma',
        spentAt: DateTime(2026, 8, 20, 13, 5),
        createdAt: DateTime(2026, 8, 20, 13, 6),
      ),
      category: _categories.first,
    );

Future<void> _pumpSheet(
  WidgetTester tester,
  Size size, {
  TxnWithCategory? existing,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // A real database in memory rather than a hand-written fake: saving actually
  // has to satisfy the foreign key, so a broken write fails the test.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedDefaultCategories(db);
  addTearDown(db.close);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        categoriesProvider(TxKind.expense)
            .overrideWith((ref) => Stream.value(_categories)),
        categoriesProvider(TxKind.income)
            .overrideWith((ref) => Stream.value(const <Category>[])),
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
        home: Scaffold(body: AddTransactionSheet(existing: existing)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lays out on a small phone without overflowing', (tester) async {
    // 360x640 logical pixels: smaller than anything still sold, which is the
    // point. If it fits here it fits everywhere.
    await _pumpSheet(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    for (final category in _categories) {
      expect(find.text(category.name), findsOneWidget);
    }
  });

  testWidgets('lays out on a tall phone without overflowing', (tester) async {
    await _pumpSheet(tester, const Size(412, 915));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows both directions and defaults to expense', (tester) async {
    await _pumpSheet(tester, const Size(412, 915));

    expect(find.text('Cheltuială'), findsOneWidget);
    expect(find.text('Venit'), findsOneWidget);
    expect(find.text('Salvează'), findsOneWidget);
    // The amount field starts empty, showing its hint.
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('refuses to save without an amount', (tester) async {
    await _pumpSheet(tester, const Size(412, 915));

    await tester.tap(find.text('Salvează'));
    await tester.pump();

    expect(find.text('Introdu o sumă'), findsOneWidget);
  });

  testWidgets('refuses to save without a category', (tester) async {
    await _pumpSheet(tester, const Size(412, 915));

    await tester.enterText(find.byType(TextField).first, '42,50');
    await tester.tap(find.text('Salvează'));
    await tester.pump();

    expect(find.text('Alege o categorie'), findsOneWidget);
  });

  group('editing an existing transaction', () {
    testWidgets('prefills the amount without a thousands separator',
        (tester) async {
      await _pumpSheet(tester, const Size(412, 915), existing: _existing());

      final field = tester.widget<TextField>(find.byType(TextField).first);
      // 4250 bani must come back as "42,50" and survive a round trip through
      // the parser untouched.
      expect(field.controller?.text, '42,50');
      expect(Money.parse(field.controller!.text), 4250);
    });

    testWidgets('prefills the note', (tester) async {
      await _pumpSheet(tester, const Size(412, 915), existing: _existing());
      expect(find.text('shaorma'), findsOneWidget);
    });

    testWidgets('does not steal focus onto the keyboard', (tester) async {
      await _pumpSheet(tester, const Size(412, 915), existing: _existing());

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.autofocus, isFalse);
    });

    testWidgets('a new entry still opens on the keypad', (tester) async {
      await _pumpSheet(tester, const Size(412, 915));

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.autofocus, isTrue);
    });

    testWidgets('saves without complaining, the category already being set',
        (tester) async {
      await _pumpSheet(tester, const Size(412, 915), existing: _existing());

      await tester.tap(find.text('Salvează'));
      await tester.pump();

      expect(find.text('Alege o categorie'), findsNothing);
      expect(find.text('Introdu o sumă'), findsNothing);
    });

    testWidgets('changing the direction clears the stale category',
        (tester) async {
      await _pumpSheet(tester, const Size(412, 915), existing: _existing());

      // "Mâncare" is an expense category; it cannot survive a switch to income.
      await tester.tap(find.text('Venit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvează'));
      await tester.pump();

      expect(find.text('Alege o categorie'), findsOneWidget);
    });
  });
}
