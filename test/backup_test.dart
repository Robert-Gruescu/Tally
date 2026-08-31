import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/backup.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/core/recurrence_service.dart';

/// Backup is the one feature whose failure mode is losing a year of records.
/// A restore that silently drops rows, or one that wipes the database before
/// discovering the file is junk, is worse than having no restore at all.
void main() {
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

  Future<void> seedRows() async {
    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 4250,
      kind: TxKind.expense,
      categoryId: food,
      note: const Value('shaorma'),
      spentAt: DateTime(2026, 3, 10, 13, 5),
    ));
    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 125050,
      kind: TxKind.expense,
      categoryId: food,
      spentAt: DateTime(2026, 3, 11, 9),
    ));
    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 300000,
      kind: TxKind.income,
      categoryId: salary,
      spentAt: DateTime(2026, 3, 1, 10),
    ));
  }

  group('CSV', () {
    test('writes a header and one line per transaction', () async {
      await seedRows();
      final csv = await Backup.buildCsv(db);
      final lines = csv.trim().split('\n');

      expect(lines.first, 'data;tip;categorie;suma;nota');
      expect(lines, hasLength(4));
    });

    test('uses a comma as the decimal mark and no thousands separator',
        () async {
      await seedRows();
      final csv = await Backup.buildCsv(db);

      // 125050 bani is 1250,50 - and must not arrive as "1.250,50", which
      // would need quoting and confuses half the importers that read this.
      expect(csv, contains(';1250,50;'));
      expect(csv, contains(';42,50;'));
      expect(csv, isNot(contains('1.250')));
    });

    test('labels the direction in words', () async {
      await seedRows();
      final csv = await Backup.buildCsv(db);

      expect(csv, contains(';cheltuiala;'));
      expect(csv, contains(';venit;'));
    });

    test('quotes a note containing the separator', () async {
      await db.insertTxn(TransactionsCompanion.insert(
        amountMinor: 100,
        kind: TxKind.expense,
        categoryId: food,
        note: const Value('paine; lapte'),
        spentAt: DateTime(2026, 3, 10, 13),
      ));

      final csv = await Backup.buildCsv(db);
      expect(csv, contains('"paine; lapte"'));
    });

    test('an empty database still produces a header', () async {
      final csv = await Backup.buildCsv(db);
      expect(csv.trim(), 'data;tip;categorie;suma;nota');
    });
  });

  group('backup round trip', () {
    test('restores every row exactly', () async {
      await seedRows();
      final json = await Backup.buildBackupJson(db);
      final before = await db.allTransactions();

      // Wipe the way a fresh install would be, then put it back.
      await db.deleteAllTransactions();
      expect(await db.allTransactions(), isEmpty);

      final summary = await Backup.restoreFromJson(db, json);
      expect(summary.transactions, 3);
      expect(summary.categories, 12);

      final after = await db.allTransactions();
      expect(after, hasLength(3));
      for (var i = 0; i < before.length; i++) {
        expect(after[i].amountMinor, before[i].amountMinor);
        expect(after[i].kind, before[i].kind);
        expect(after[i].categoryId, before[i].categoryId);
        expect(after[i].note, before[i].note);
        expect(after[i].spentAt, before[i].spentAt);
      }
    });

    test('totals survive the trip', () async {
      await seedRows();
      final json = await Backup.buildBackupJson(db);
      await Backup.restoreFromJson(db, json);

      final summary = await db
          .watchSummary(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1))
          .first;
      expect(summary.expenseMinor, 129300);
      expect(summary.incomeMinor, 300000);
    });

    test('restoring replaces rather than appends', () async {
      await seedRows();
      final json = await Backup.buildBackupJson(db);

      await Backup.restoreFromJson(db, json);
      await Backup.restoreFromJson(db, json);

      // Restoring twice must not leave six rows behind.
      expect(await db.allTransactions(), hasLength(3));
    });

    test('a timestamp crosses timezones as the same instant', () async {
      await seedRows();
      final json = await Backup.buildBackupJson(db);
      await Backup.restoreFromJson(db, json);

      final restored = (await db.allTransactions())
          .firstWhere((t) => t.amountMinor == 4250);
      expect(restored.spentAt, DateTime(2026, 3, 10, 13, 5));
    });
  });

  group('recurring rules survive a backup', () {
    Future<void> seedRule() async {
      await db.insertRule(RecurringRulesCompanion.insert(
        amountMinor: 500000,
        kind: TxKind.income,
        categoryId: salary,
        dayOfMonth: 5,
        startsOn: DateTime(2026, 1, 1),
        note: const Value('salariu'),
      ));
      await RecurrenceService.materialize(db, now: DateTime(2026, 3, 10));
    }

    test('the rule itself comes back', () async {
      await seedRule();
      final json = await Backup.buildBackupJson(db);

      await Backup.restoreFromJson(db, json);

      final rules = await db.watchRules().first;
      expect(rules, hasLength(1));
      expect(rules.single.rule.amountMinor, 500000);
      expect(rules.single.rule.dayOfMonth, 5);
      expect(rules.single.rule.note, 'salariu');
    });

    test('answers already given are not asked again', () async {
      await seedRule();
      final pending = await db.watchPending().first;
      expect(pending, hasLength(3));

      await db.confirmOccurrence(pending[0].occurrence, pending[0].rule);
      await db.skipOccurrence(pending[1].occurrence.id);
      expect(await db.watchPending().first, hasLength(1));

      final json = await Backup.buildBackupJson(db);
      await Backup.restoreFromJson(db, json);

      // The whole point of backing up occurrences: a restore must not reopen
      // months the user has already settled.
      expect(await db.watchPending().first, hasLength(1));
      expect(await db.allTransactions(), hasLength(1));
    });

    test('a v1 backup still restores, just without rules', () async {
      await seedRule();
      // A file written before recurring rules existed.
      const legacy = '{"app":"tally","version":1,"categories":[],'
          '"transactions":[]}';

      final summary = await Backup.restoreFromJson(db, legacy);

      expect(summary.rules, 0);
      expect(await db.watchRules().first, isEmpty);
      expect(await db.watchPending().first, isEmpty);
    });

    test('the format version is stamped as 2', () async {
      final json = await Backup.buildBackupJson(db);
      expect(json, contains('"version": 2'));
    });
  });

  group('a bad file is refused before anything is touched', () {
    test('rejects text that is not JSON', () async {
      await seedRows();
      await expectLater(
        Backup.restoreFromJson(db, 'nu sunt json'),
        throwsA(isA<BackupError>()),
      );
      expect(await db.allTransactions(), hasLength(3));
    });

    test('rejects JSON from another app', () async {
      await seedRows();
      await expectLater(
        Backup.restoreFromJson(db, '{"app":"altceva","version":1}'),
        throwsA(isA<BackupError>()),
      );
      expect(await db.allTransactions(), hasLength(3));
    });

    test('rejects a newer format version', () async {
      await seedRows();
      await expectLater(
        Backup.restoreFromJson(
          db,
          '{"app":"tally","version":99,"categories":[],"transactions":[]}',
        ),
        throwsA(isA<BackupError>()),
      );
      expect(await db.allTransactions(), hasLength(3));
    });

    test('a half-valid file leaves the database untouched', () async {
      await seedRows();

      // Valid envelope, corrupt payload: the write happens in one transaction,
      // so this must roll back rather than leave the user with nothing.
      await expectLater(
        Backup.restoreFromJson(
          db,
          '{"app":"tally","version":1,"categories":[],'
              '"transactions":[{"id":"nu-i numar"}]}',
        ),
        throwsA(isA<BackupError>()),
      );

      expect(await db.allTransactions(), hasLength(3));
      expect(await db.countCategories(), 12);
    });
  });
}
