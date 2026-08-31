import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/core/auto_backup.dart';
import 'package:tally/core/backup.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';

import 'dart:io';

/// A fake documents directory, so the snapshots land in a temp folder instead
/// of needing a real device.
class _FakePaths extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePaths(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

/// The snapshot the app takes of itself once a day.
///
/// It exists because Android's own Auto Backup turned out to depend on a
/// system toggle that was off, with nothing said and nothing saved. These
/// tests hold the replacement to a stricter standard: it must never fail
/// loudly, never crowd the disk, and never overwrite good data with nothing.
void main() {
  late Directory root;
  late AppDatabase db;
  late SharedPreferences prefs;
  late int food;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tally_auto');
    PathProviderPlatform.instance = _FakePaths(root.path);

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDefaultCategories(db);
    food = (await db.allCategories()).firstWhere((c) => c.name == 'Mâncare').id;
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> addTxn([int amount = 4250]) => db.insertTxn(
        TransactionsCompanion.insert(
          amountMinor: amount,
          kind: TxKind.expense,
          categoryId: food,
          note: const Value('shaorma'),
          spentAt: DateTime(2026, 3, 10, 13),
        ),
      );

  test('writes a snapshot on the first run', () async {
    await addTxn();

    final file = await AutoBackup.runIfDue(db, prefs);

    expect(file, isNotNull);
    expect(await file!.exists(), isTrue);
    expect(await AutoBackup.list(), hasLength(1));
  });

  test('does not write again within the day', () async {
    await addTxn();
    final at = DateTime(2026, 3, 10, 9);

    await AutoBackup.runIfDue(db, prefs, now: at);
    final second = await AutoBackup.runIfDue(
      db,
      prefs,
      now: at.add(const Duration(hours: 5)),
    );

    expect(second, isNull);
    expect(await AutoBackup.list(), hasLength(1));
  });

  test('writes again once a day has passed', () async {
    await addTxn();
    final at = DateTime(2026, 3, 10, 9);

    await AutoBackup.runIfDue(db, prefs, now: at);
    final next = await AutoBackup.runIfDue(
      db,
      prefs,
      now: at.add(const Duration(hours: 25)),
    );

    expect(next, isNotNull);
    expect(await AutoBackup.list(), hasLength(2));
  });

  test('skips an empty database rather than saving nothing', () async {
    // An empty snapshot would push a real one out of the rotation later.
    final file = await AutoBackup.runIfDue(db, prefs);

    expect(file, isNull);
    expect(await AutoBackup.list(), isEmpty);
  });

  test('keeps only the newest seven', () async {
    await addTxn();

    for (var day = 1; day <= 12; day++) {
      await AutoBackup.runIfDue(db, prefs, now: DateTime(2026, 3, day, 9));
    }

    final files = await AutoBackup.list();
    expect(files, hasLength(AutoBackup.keep));
    // Newest first, and the rotation dropped the oldest five.
    expect(files.first.takenAt, DateTime(2026, 3, 12, 9));
    expect(files.last.takenAt, DateTime(2026, 3, 6, 9));
  });

  test('a snapshot restores the data it holds', () async {
    await addTxn(4250);
    await addTxn(1000);
    final file = await AutoBackup.runIfDue(db, prefs);

    await db.deleteAllTransactions();
    expect(await db.allTransactions(), isEmpty);

    final summary = await Backup.restore(db, file!);

    expect(summary.transactions, 2);
    final restored = await db.allTransactions();
    expect(restored.map((t) => t.amountMinor), containsAll([4250, 1000]));
  });

  test('reports how many transactions a snapshot holds', () async {
    await addTxn();
    await addTxn(999);
    await AutoBackup.runIfDue(db, prefs);

    final entry = (await AutoBackup.list()).single;
    expect(await entry.countTransactions(), 2);
  });

  test('force writes even when one was taken minutes ago', () async {
    await addTxn();
    final at = DateTime(2026, 3, 10, 9);

    await AutoBackup.runIfDue(db, prefs, now: at);
    final forced = await AutoBackup.runIfDue(
      db,
      prefs,
      now: at.add(const Duration(minutes: 1)),
      force: true,
    );

    expect(forced, isNotNull);
  });

  test('a broken directory does not stop the app from starting', () async {
    await addTxn();
    // A file where a directory should be: creating `backups/` under it cannot
    // succeed. Whatever the disk does, startup must survive it, because this
    // runs before the first frame and a thrown exception there is a black
    // screen. An empty path is not a valid stand-in: it resolves to the root
    // of the drive and quietly works.
    final blocker = File('${root.path}${Platform.pathSeparator}blocker');
    await blocker.writeAsString('not a directory');
    PathProviderPlatform.instance = _FakePaths(blocker.path);

    late Object? thrown;
    try {
      await AutoBackup.runIfDue(db, prefs);
      thrown = null;
    } catch (e) {
      thrown = e;
    }

    expect(thrown, isNull);
  });

  test('listing survives a missing folder', () async {
    final blocker = File('${root.path}${Platform.pathSeparator}blocker2');
    await blocker.writeAsString('not a directory');
    PathProviderPlatform.instance = _FakePaths(blocker.path);

    expect(await AutoBackup.list(), isEmpty);
  });
}
