import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'db/database.dart';

/// A snapshot the app takes of itself, without being asked.
///
/// Android's own Auto Backup was supposed to cover this, and it does not: it
/// depends on a system toggle the user may never have turned on, and when it
/// is off nothing at all is saved and nobody is told. That is the worst shape
/// a safety net can have.
///
/// So the app keeps its own. Once a day, on open, it writes a full snapshot
/// beside the database and keeps the last few. It costs a few tens of
/// kilobytes and asks nothing of the user.
///
/// What it protects against: a bad restore, a mistaken "delete everything", a
/// bug of mine, a month of entries wiped by accident. What it cannot protect
/// against is losing the phone, because the file lives on the phone. That
/// needs the copy to leave the device, which is a separate problem.
class AutoBackup {
  const AutoBackup._();

  static const _lastRunKey = 'auto_backup_last_run';
  static const _folder = 'backups';

  /// How often a snapshot is taken. Daily matches how often the numbers
  /// meaningfully change; more often would just churn the disk.
  static const interval = Duration(hours: 24);

  /// How many are kept. Seven means a mistake noticed a week later is still
  /// recoverable, at a cost of well under a megabyte.
  static const keep = 7;

  /// Writes a snapshot if the last one is older than [interval].
  ///
  /// Never throws: a failed snapshot must not stop the app from opening. It is
  /// a safety net, and a safety net that can crash the thing it protects is
  /// worse than none.
  static Future<File?> runIfDue(
    AppDatabase db,
    SharedPreferences prefs, {
    DateTime? now,
    bool force = false,
  }) async {
    final at = now ?? DateTime.now();

    if (!force) {
      final last = prefs.getInt(_lastRunKey);
      if (last != null) {
        final since = at.difference(DateTime.fromMillisecondsSinceEpoch(last));
        if (since < interval && !since.isNegative) return null;
      }
    }

    try {
      // Nothing to protect yet. Writing an empty snapshot would push a real
      // one out of the rotation later.
      if ((await db.allTransactions()).isEmpty) return null;

      final dir = await _directory();
      final stamp = DateFormat('yyyy-MM-dd-HHmm').format(at);
      final file = File('${dir.path}${Platform.pathSeparator}tally-auto-$stamp.json');

      await file.writeAsString(await Backup.buildBackupJson(db), flush: true);
      await prefs.setInt(_lastRunKey, at.millisecondsSinceEpoch);
      await _prune(dir);

      return file;
    } catch (_) {
      return null;
    }
  }

  /// The snapshots on disk, newest first.
  static Future<List<AutoBackupFile>> list() async {
    try {
      final dir = await _directory();
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.json'))
          .cast<File>()
          .toList();

      final entries = <AutoBackupFile>[];
      for (final file in files) {
        final stat = await file.stat();
        entries.add(AutoBackupFile(
          file: file,
          // The stamp in the name, not the file's modified time. Copying a
          // backup off the phone and back, or restoring the folder itself,
          // rewrites mtime and would silently reshuffle the history.
          takenAt: _stampOf(file.path) ?? stat.modified,
          sizeBytes: stat.size,
        ));
      }
      entries.sort((a, b) => b.takenAt.compareTo(a.takenAt));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  static Future<DateTime?> lastRun(SharedPreferences prefs) async {
    final value = prefs.getInt(_lastRunKey);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  static final _stampPattern =
      RegExp(r'tally-auto-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})\.json$');

  /// Reads the moment a snapshot was taken back out of its own file name.
  static DateTime? _stampOf(String path) {
    final match = _stampPattern.firstMatch(path.replaceAll(r'\', '/'));
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }

  static Future<Directory> _directory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Deletes everything past the newest [keep].
  static Future<void> _prune(Directory dir) async {
    final entries = await list();
    if (entries.length <= keep) return;
    for (final old in entries.skip(keep)) {
      try {
        await old.file.delete();
      } catch (_) {
        // A file that will not delete is not worth failing a backup over.
      }
    }
  }
}

class AutoBackupFile {
  const AutoBackupFile({
    required this.file,
    required this.takenAt,
    required this.sizeBytes,
  });

  final File file;
  final DateTime takenAt;
  final int sizeBytes;

  String get name => file.uri.pathSegments.last;

  /// How many transactions it holds, read from the file itself rather than
  /// remembered separately, so the number can never drift from the content.
  Future<int?> countTransactions() async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      final rows = decoded['transactions'];
      return rows is List ? rows.length : null;
    } catch (_) {
      return null;
    }
  }
}
