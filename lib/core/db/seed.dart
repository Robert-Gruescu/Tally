import 'package:drift/drift.dart';

import 'database.dart';

/// Eight expense categories, four income. Few enough to fit on two rows without
/// scrolling, which is what keeps logging under three seconds. "Altele" on both
/// sides is load-bearing: without an escape hatch people stall on the first
/// purchase that does not fit and stop using the app.
///
/// Names are seeded once, in the user's language at install time, and then
/// owned by the user. They are deliberately not run through the localization
/// layer afterwards, so renaming a category is not silently undone.
const _seedCategories = <({
  String name,
  TxKind kind,
  String iconKey,
  int color,
})>[
  (name: 'Mâncare', kind: TxKind.expense, iconKey: 'food', color: 0xFFC0523F),
  (name: 'Transport', kind: TxKind.expense, iconKey: 'transport', color: 0xFF3E6B8A),
  (name: 'Locuință', kind: TxKind.expense, iconKey: 'home', color: 0xFF7A5C3E),
  (name: 'Cumpărături', kind: TxKind.expense, iconKey: 'shopping', color: 0xFF8A5A7A),
  (name: 'Distracție', kind: TxKind.expense, iconKey: 'fun', color: 0xFFB07A2E),
  (name: 'Sănătate', kind: TxKind.expense, iconKey: 'health', color: 0xFF4A8A7B),
  (name: 'Abonamente', kind: TxKind.expense, iconKey: 'subscriptions', color: 0xFF5B5F8A),
  (name: 'Altele', kind: TxKind.expense, iconKey: 'other', color: 0xFF6B6F73),
  (name: 'Salariu', kind: TxKind.income, iconKey: 'salary', color: 0xFF2E7D5B),
  (name: 'Freelancing', kind: TxKind.income, iconKey: 'freelance', color: 0xFF3E7D8A),
  (name: 'Cadouri', kind: TxKind.income, iconKey: 'gift', color: 0xFF8A6A3E),
  (name: 'Altele', kind: TxKind.income, iconKey: 'other', color: 0xFF6B6F73),
];

/// Inserts the starter categories the first time the database is opened.
/// Guarded by a count rather than a preferences flag, so a cleared app cache
/// cannot produce a second set of duplicates.
Future<void> seedDefaultCategories(AppDatabase db) async {
  if (await db.countCategories() > 0) return;

  await db.batch((batch) {
    for (var i = 0; i < _seedCategories.length; i++) {
      final c = _seedCategories[i];
      batch.insert(
        db.categories,
        CategoriesCompanion.insert(
          name: c.name,
          kind: c.kind,
          iconKey: c.iconKey,
          colorValue: c.color,
          sortOrder: Value(i),
        ),
      );
    }
  });
}
