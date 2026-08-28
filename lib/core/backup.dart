import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'db/database.dart';
import 'money.dart';

/// Export and restore.
///
/// The app keeps everything in one SQLite file on one phone. A lost or reset
/// device takes a year of records with it, and that is the failure an expense
/// tracker cannot come back from. Two formats, because they answer different
/// questions: CSV so the numbers can be opened in a spreadsheet, JSON so the
/// app can be put back exactly as it was.
class Backup {
  const Backup._();

  /// Bumped when the JSON shape changes. A restore refuses anything newer than
  /// it understands rather than guessing.
  static const formatVersion = 1;

  static const _appTag = 'tally';

  // ------------------------------------------------------------------- CSV

  /// Writes the full history as a spreadsheet file and returns its path.
  ///
  /// Semicolons separate the fields and the decimal mark is a comma, which is
  /// what a Romanian Excel expects. A UTF-8 BOM leads the file: without it
  /// Excel reads the bytes as its legacy codepage and every diacritic in
  /// "Mâncare" or "Sănătate" turns to mojibake.
  static Future<File> writeCsv(AppDatabase db) async => _write(
        'tally-export-${_stamp()}.csv',
        // The BOM, written as bytes rather than a character, so it survives
        // being concatenated with UTF-8 text.
        [0xEF, 0xBB, 0xBF, ...utf8.encode(await buildCsv(db))],
      );

  /// The spreadsheet text itself, split out from the file writing so it can be
  /// asserted on without a plugin-backed temporary directory.
  static Future<String> buildCsv(AppDatabase db) async {
    final categories = {for (final c in await db.allCategories()) c.id: c};
    final rows = await db.allTransactions();
    final date = DateFormat('yyyy-MM-dd HH:mm');

    final buffer = StringBuffer()
      ..writeln('data;tip;categorie;suma;nota');

    for (final txn in rows) {
      final category = categories[txn.categoryId]?.name ?? '';
      final kind = txn.kind == TxKind.income ? 'venit' : 'cheltuiala';
      final amount = Money.formatPlain(
        txn.amountMinor,
        // No thousands separator: a grouped "1.250,50" would need quoting and
        // trips up half the importers that read this file.
        locale: 'en_US',
      ).replaceAll(',', '').replaceAll('.', ',');

      buffer.writeln([
        date.format(txn.spentAt.toLocal()),
        kind,
        _escape(category),
        amount,
        _escape(txn.note ?? ''),
      ].join(';'));
    }

    return buffer.toString();
  }

  static String _escape(String value) {
    if (!value.contains(';') && !value.contains('"') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  // ------------------------------------------------------------------ JSON

  /// Writes a complete, restorable snapshot and returns its path.
  static Future<File> writeBackup(AppDatabase db) async => _write(
        'tally-backup-${_stamp()}.json',
        utf8.encode(await buildBackupJson(db)),
      );

  /// The snapshot text itself. Same split as [buildCsv], same reason.
  static Future<String> buildBackupJson(AppDatabase db) async {
    final payload = <String, Object?>{
      'app': _appTag,
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': [
        for (final c in await db.allCategories())
          {
            'id': c.id,
            'name': c.name,
            'kind': c.kind.name,
            'iconKey': c.iconKey,
            'colorValue': c.colorValue,
            'sortOrder': c.sortOrder,
            'isArchived': c.isArchived,
          },
      ],
      'transactions': [
        for (final t in await db.allTransactions())
          {
            'id': t.id,
            'amountMinor': t.amountMinor,
            'kind': t.kind.name,
            'categoryId': t.categoryId,
            'note': t.note,
            // Stored as UTC so a backup restored in another timezone still
            // refers to the same instant.
            'spentAt': t.spentAt.toUtc().toIso8601String(),
            'createdAt': t.createdAt.toUtc().toIso8601String(),
          },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Reads a backup file and replaces everything with its contents.
  ///
  /// Throws [BackupError] with a message meant for the user rather than a
  /// stack trace, because this runs behind a button in Settings.
  static Future<RestoreSummary> restore(AppDatabase db, File file) async =>
      restoreFromJson(db, await file.readAsString());

  /// Applies a backup given its text.
  static Future<RestoreSummary> restoreFromJson(
    AppDatabase db,
    String json,
  ) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupError('Fișierul nu este un backup Tally valid.');
    }

    if (decoded is! Map<String, Object?> || decoded['app'] != _appTag) {
      throw const BackupError('Fișierul nu este un backup Tally valid.');
    }

    final version = decoded['version'];
    if (version is! int || version > formatVersion) {
      throw const BackupError(
        'Backupul a fost creat de o versiune mai nouă a aplicației.',
      );
    }

    final rawCategories = decoded['categories'];
    final rawTransactions = decoded['transactions'];
    if (rawCategories is! List || rawTransactions is! List) {
      throw const BackupError('Backupul este incomplet.');
    }

    try {
      final categories = [
        for (final c in rawCategories.cast<Map<String, Object?>>())
          CategoriesCompanion.insert(
            id: Value(c['id']! as int),
            name: c['name']! as String,
            kind: TxKind.values.byName(c['kind']! as String),
            iconKey: c['iconKey']! as String,
            colorValue: c['colorValue']! as int,
            sortOrder: Value(c['sortOrder'] as int? ?? 0),
            isArchived: Value(c['isArchived'] as bool? ?? false),
          ),
      ];

      final transactions = [
        for (final t in rawTransactions.cast<Map<String, Object?>>())
          TransactionsCompanion.insert(
            id: Value(t['id']! as int),
            amountMinor: t['amountMinor']! as int,
            kind: TxKind.values.byName(t['kind']! as String),
            categoryId: t['categoryId']! as int,
            note: Value(t['note'] as String?),
            spentAt: DateTime.parse(t['spentAt']! as String).toLocal(),
            createdAt: Value(
              DateTime.parse(
                (t['createdAt'] ?? t['spentAt'])! as String,
              ).toLocal(),
            ),
          ),
      ];

      await db.restoreFrom(categoryRows: categories, txnRows: transactions);
      return RestoreSummary(
        categories: categories.length,
        transactions: transactions.length,
      );
    } on BackupError {
      rethrow;
    } catch (_) {
      throw const BackupError('Backupul pare deteriorat și nu a fost aplicat.');
    }
  }

  // ----------------------------------------------------------------- shared

  static String _stamp() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  static Future<File> _write(String name, List<int> bytes) async {
    // The temporary directory, not documents: these files exist to be handed
    // to the share sheet, and leaving copies behind in app storage would grow
    // without limit.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

class RestoreSummary {
  const RestoreSummary({required this.categories, required this.transactions});

  final int categories;
  final int transactions;
}

class BackupError implements Exception {
  const BackupError(this.message);

  final String message;

  @override
  String toString() => message;
}
