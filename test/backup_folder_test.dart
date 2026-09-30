import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/core/backup.dart';
import 'package:tally/core/backup_folder.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';

/// The copy of the user's records that outlives the app.
///
/// The snapshots inside the app go away with it, which is precisely the case
/// the user hit: uninstall, reinstall, everything gone. This folder is the
/// answer, and the things that can go wrong with it are all quiet ones — a
/// folder the user deleted, a grant they revoked, a write that fails at two in
/// the morning. None of them may crash, and none of them may pretend to have
/// worked.
///
/// The Android side is a method channel, so it is stood in for here by a fake
/// document provider: a map from file name to contents, behaving the way
/// `DocumentsContract` does, including answering a repeated create with the
/// existing document rather than a numbered copy.
class _FakeFolder {
  _FakeFolder(this.tree);

  final String tree;
  final Map<String, String> files = {};
  final Map<String, int> modified = {};

  /// Set to refuse everything, the way a revoked grant does.
  bool accessible = true;

  /// Counts writes, so a test can prove a snapshot was mirrored exactly once.
  int writes = 0;

  int _clock = 1000;

  Object? handle(MethodCall call) {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};

    switch (call.method) {
      case 'hasAccess':
        return accessible && args['tree'] == tree;

      case 'displayName':
        if (!accessible) throw PlatformException(code: 'gone');
        return 'Documente/Tally';

      case 'pickFolder':
        return tree;

      case 'write':
        if (!accessible) throw PlatformException(code: 'gone');
        writes++;
        final name = args['name']! as String;
        files[name] = args['content']! as String;
        modified[name] = _clock += 1000;
        return true;

      case 'list':
        if (!accessible) throw PlatformException(code: 'gone');
        return [
          for (final name in files.keys)
            {
              'uri': '$tree/$name',
              'name': name,
              'modified': modified[name] ?? 0,
              'size': files[name]!.length,
            },
        ];

      case 'read':
        final name = (args['uri']! as String).split('/').last;
        final content = files[name];
        if (content == null) throw PlatformException(code: 'missing');
        return content;

      case 'delete':
        final name = (args['uri']! as String).split('/').last;
        files.remove(name);
        modified.remove(name);
        return true;

      case 'openBackupSettings':
        return true;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tally/backup_folder');
  late _FakeFolder folder;
  late AppDatabase db;
  late SharedPreferences prefs;
  late int food;

  Future<void> useFolder() async {
    await BackupFolder.choose(prefs);
  }

  setUp(() async {
    folder = _FakeFolder('content://tree/primary%3ADocuments%2FTally');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => folder.handle(call));

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDefaultCategories(db);
    food = (await db.allCategories()).firstWhere((c) => c.name == 'Mâncare').id;

    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 4250,
      kind: TxKind.expense,
      categoryId: food,
      note: const Value('shaorma'),
      spentAt: DateTime(2026, 9, 20, 13),
    ));
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.close();
  });

  group('choosing a folder', () {
    test('nothing is configured to begin with', () {
      expect(BackupFolder.configuredUri(prefs), isNull);
    });

    test('choosing remembers it across restarts', () async {
      await useFolder();
      expect(BackupFolder.configuredUri(prefs), folder.tree);
      expect(await BackupFolder.isUsable(prefs), isTrue);
    });

    test('a revoked grant reads as unusable rather than as absent', () async {
      await useFolder();
      folder.accessible = false;

      // The distinction matters on screen: "you never chose one" and "the one
      // you chose is gone" need different words and different buttons.
      expect(BackupFolder.configuredUri(prefs), isNotNull);
      expect(await BackupFolder.isUsable(prefs), isFalse);
    });

    test('forgetting leaves the files where they are', () async {
      await useFolder();
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 29));

      await BackupFolder.forget(prefs);

      expect(BackupFolder.configuredUri(prefs), isNull);
      expect(folder.files, isNotEmpty);
    });
  });

  group('mirroring', () {
    test('writes a restorable snapshot into the folder', () async {
      await useFolder();
      expect(await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 29)), isTrue);

      expect(folder.files.keys, contains('tally-backup-2026-09-29.json'));
      final decoded = jsonDecode(folder.files.values.first) as Map<String, Object?>;
      expect(decoded['app'], 'tally');
      expect((decoded['transactions']! as List), hasLength(1));
    });

    test('does nothing, quietly, when no folder was ever chosen', () async {
      expect(await BackupFolder.mirror(db, prefs), isFalse);
      expect(folder.writes, 0);
    });

    test('a folder that has gone away fails without throwing', () async {
      await useFolder();
      folder.accessible = false;

      // This runs behind app startup. Throwing here would mean a deleted
      // folder stops the app from opening at all.
      expect(await BackupFolder.mirror(db, prefs), isFalse);
    });

    test('the same day overwrites rather than piling up copies', () async {
      await useFolder();
      final day = DateTime(2026, 9, 29);

      await BackupFolder.mirror(db, prefs, now: day);
      await db.insertTxn(TransactionsCompanion.insert(
        amountMinor: 9900,
        kind: TxKind.expense,
        categoryId: food,
        spentAt: DateTime(2026, 9, 29, 18),
      ));
      await BackupFolder.mirror(db, prefs, now: day);

      expect(folder.files, hasLength(1));
      final decoded = jsonDecode(folder.files.values.first) as Map<String, Object?>;
      expect((decoded['transactions']! as List), hasLength(2),
          reason: 'the second write must replace the first, not sit beside it');
    });

    test('keeps only the newest few', () async {
      await useFolder();
      for (var day = 1; day <= BackupFolder.keep + 4; day++) {
        await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, day));
      }

      expect(folder.files, hasLength(BackupFolder.keep));
      // The oldest are the ones that went.
      expect(folder.files.keys, isNot(contains('tally-backup-2026-09-01.json')));
      expect(folder.files.keys, contains('tally-backup-2026-09-09.json'));
    });
  });

  /// The failure this group exists for was found on an emulator, not on paper.
  ///
  /// The sequence: add a transaction, back it up to the folder, uninstall,
  /// reinstall. Android's account backup restored a stale copy, so the app
  /// came back holding fewer rows than the folder did. Pointing it at the
  /// folder to recover then wrote that stale state straight over the good
  /// file — four transactions replaced by three, silently, with today's date
  /// still on the filename.
  ///
  /// Choosing a folder is the one moment the user is most likely to be holding
  /// nothing and standing on top of everything they have.
  group('choosing a folder never destroys what is in it', () {
    test('a folder with a backup in it is left untouched', () async {
      await useFolder();
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 29));
      final before = folder.files['tally-backup-2026-09-29.json'];
      final writesBefore = folder.writes;

      // As if the app had just been reinstalled and come back with less.
      await db.deleteAllTransactions();

      expect(await BackupFolder.seedIfEmpty(db, prefs), isFalse);
      expect(folder.writes, writesBefore, reason: 'nothing may be written');
      expect(folder.files['tally-backup-2026-09-29.json'], before);
    });

    test('the backup still holds the rows after the folder is re-chosen',
        () async {
      await useFolder();
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 29));
      await db.deleteAllTransactions();

      await useFolder();
      await BackupFolder.seedIfEmpty(db, prefs);

      final found = await BackupFolder.list(prefs);
      final summary = await BackupFolder.restore(db, found.first.uri);
      expect(summary.transactions, 1,
          reason: 'the row must still be recoverable');
    });

    test('an empty folder does get a first snapshot', () async {
      await useFolder();

      // The other half: choosing a folder and finding it still empty reads as
      // "it did not work".
      expect(await BackupFolder.seedIfEmpty(db, prefs), isTrue);
      expect(folder.files, hasLength(1));
    });
  });

  group('finding a backup after a reinstall', () {
    test('lists what is in the folder, newest first', () async {
      await useFolder();
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 27));
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 29));
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 28));

      final found = await BackupFolder.list(prefs);
      expect(found.map((f) => f.takenAt), [
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 28),
        DateTime(2026, 9, 27),
      ]);
    });

    test('ordering comes from the name, not the modified time', () async {
      await useFolder();
      // Written out of order, which is what copying a folder onto a new phone
      // does to every modified timestamp at once.
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 29));
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 20));

      final found = await BackupFolder.list(prefs);
      expect(found.first.takenAt, DateTime(2026, 9, 29));
    });

    test('an empty folder is an empty list, not an error', () async {
      await useFolder();
      expect(await BackupFolder.list(prefs), isEmpty);
    });

    test('restoring brings the rows back into a wiped database', () async {
      await useFolder();
      await BackupFolder.mirror(db, prefs, now: DateTime(2026, 9, 29));

      // As if the app had been reinstalled: same folder, nothing recorded.
      await db.deleteAllTransactions();
      expect(await db.allTransactions(), isEmpty);

      final found = await BackupFolder.list(prefs);
      final summary = await BackupFolder.restore(db, found.first.uri);

      expect(summary.transactions, 1);
      final rows = await db.allTransactions();
      expect(rows.single.amountMinor, 4250);
      expect(rows.single.note, 'shaorma');
    });

    test('a file that cannot be read is refused in words, not a crash',
        () async {
      await useFolder();
      await expectLater(
        BackupFolder.restore(db, '${folder.tree}/nu-exista.json'),
        throwsA(isA<BackupError>()),
      );
    });

    test('junk in the folder leaves the database untouched', () async {
      await useFolder();
      folder.files['tally-backup-2026-09-29.json'] = 'nu sunt JSON';

      final found = await BackupFolder.list(prefs);
      await expectLater(
        BackupFolder.restore(db, found.first.uri),
        throwsA(isA<BackupError>()),
      );
      expect(await db.allTransactions(), hasLength(1));
    });
  });

  group('without a document provider', () {
    setUp(() {
      // Every desktop, and every test that does not install the fake.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('choosing simply returns nothing', () async {
      expect(await BackupFolder.choose(prefs), isNull);
    });

    test('mirroring is a no-op', () async {
      expect(await BackupFolder.mirror(db, prefs), isFalse);
    });

    test('listing is empty', () async {
      expect(await BackupFolder.list(prefs), isEmpty);
    });
  });
}
