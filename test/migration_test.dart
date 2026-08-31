import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/recurrence_service.dart';

/// The upgrade from v1 to v2, run against a database shaped the way a real
/// user's phone already is.
///
/// This is the only change in the project that can destroy data that exists.
/// A migration bug does not show up as a failed build; it shows up as someone
/// opening the app after an update and finding their year of records gone.
void main() {
  /// Builds a real v1 database file, then hands it to drift.
  ///
  /// The schema has to be written through a raw sqlite3 handle first: the
  /// moment drift opens a database at `user_version = 0` it runs `onCreate`
  /// and builds the current schema, which is exactly the upgrade path this
  /// test is trying not to take.
  Future<AppDatabase> openV1() async {
    final dir = await Directory.systemTemp.createTemp('tally_v1');
    final path = '${dir.path}${Platform.pathSeparator}tally.sqlite';
    addTearDown(() => dir.delete(recursive: true));

    final raw = sqlite3.open(path);
    raw.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0
      )''');
    raw.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        amount_minor INTEGER NOT NULL,
        kind TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories (id),
        note TEXT,
        spent_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )''');
    raw.execute(
      'CREATE INDEX idx_transactions_spent_at ON transactions (spent_at)',
    );
    raw.execute(
      "INSERT INTO categories (id, name, kind, icon_key, color_value, sort_order, is_archived) "
      "VALUES (1, 'Mâncare', 'expense', 'food', 12345, 0, 0), "
      "(2, 'Salariu', 'income', 'salary', 54321, 1, 0)",
    );
    raw.execute(
      'INSERT INTO transactions (id, amount_minor, kind, category_id, note, spent_at, created_at) '
      "VALUES (1, 4250, 'expense', 1, 'shaorma', 1772000000, 1772000000), "
      "(2, 500000, 'income', 2, NULL, 1772000000, 1772000000)",
    );
    // The marker that makes drift run onUpgrade instead of onCreate.
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    return AppDatabase.forTesting(NativeDatabase(File(path)));
  }

  test('upgrading keeps every existing row', () async {
    final db = await openV1();
    addTearDown(db.close);

    // Opening triggers the migration.
    final transactions = await db.allTransactions();

    expect(transactions, hasLength(2));
    expect(transactions.map((t) => t.amountMinor), containsAll([4250, 500000]));
    expect(await db.countCategories(), 2);

    final noteRow = transactions.firstWhere((t) => t.amountMinor == 4250);
    expect(noteRow.note, 'shaorma');
    expect(noteRow.kind, TxKind.expense);
  });

  test('the new tables exist and start empty', () async {
    final db = await openV1();
    addTearDown(db.close);

    expect(await db.allRules(), isEmpty);
    expect(await db.allOccurrences(), isEmpty);
    expect(await db.watchPending().first, isEmpty);
  });

  test('the schema version is written as 2', () async {
    final db = await openV1();
    addTearDown(db.close);

    await db.allTransactions();
    final row = await db
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(row.data.values.first, 2);
  });

  test('totals still compute after the upgrade', () async {
    final db = await openV1();
    addTearDown(db.close);

    final summary = await db
        .watchSummary(from: DateTime(2000), to: DateTime(2100))
        .first;
    expect(summary.expenseMinor, 4250);
    expect(summary.incomeMinor, 500000);
  });

  test('recurring works immediately on an upgraded database', () async {
    final db = await openV1();
    addTearDown(db.close);

    await db.insertRule(RecurringRulesCompanion.insert(
      amountMinor: 500000,
      kind: TxKind.income,
      categoryId: 2,
      dayOfMonth: 5,
      startsOn: DateTime(2026, 1, 1),
    ));
    await RecurrenceService.materialize(db, now: DateTime(2026, 2, 10));

    expect(await db.watchPending().first, hasLength(2));
    // The pre-existing transactions are still untouched alongside them.
    expect(await db.allTransactions(), hasLength(2));
  });

  test('the index the queries rely on survives', () async {
    final db = await openV1();
    addTearDown(db.close);

    await db.allTransactions();
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final names = rows.map((r) => r.data['name'] as String).toList();

    expect(names, contains('idx_transactions_spent_at'));
    expect(names, contains('idx_occurrences_status'));
  });
}
