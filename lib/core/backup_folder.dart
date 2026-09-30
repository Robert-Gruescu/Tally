import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'db/database.dart';

/// A folder on the phone, chosen once by the user, that outlives the app.
///
/// The snapshots in [AutoBackup] live in the app's private storage, which
/// Android deletes together with the app. They protect against a mistaken tap
/// and against a bug of mine; they do not protect against the thing the user
/// actually did, which was uninstall the app. A folder picked through the
/// system picker survives that, shows up in Files, and copies to a computer.
///
/// What it cannot do is restore itself. A freshly installed app has no
/// permission to read what its predecessor left behind, so after a reinstall
/// the user points at the folder once and the app takes it from there. That is
/// a platform rule, not a gap in this code; the only zero-tap path is Android's
/// own account backup, which the app already declares and which depends on a
/// switch in the user's system settings.
class BackupFolder {
  const BackupFolder._();

  static const _channel = MethodChannel('tally/backup_folder');
  static const _uriKey = 'backup_folder_uri';

  /// How many dated snapshots are kept in the chosen folder.
  ///
  /// Fewer than the seven kept internally: these exist to survive an
  /// uninstall, not to be a browsable history, and every extra file is another
  /// round trip through the document provider on a folder the user also sees.
  static const keep = 5;

  /// True on platforms where a document provider exists at all. Everywhere
  /// else every call below is a no-op rather than a crash, which is what keeps
  /// the widget tests running on the host machine.
  static Future<bool> _available() async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess', {'tree': ''}) != null;
    } on MissingPluginException {
      return false;
    } catch (_) {
      // The channel answered, which is all this asks.
      return true;
    }
  }

  // --------------------------------------------------------------- the folder

  /// The folder the user chose, or null if they never did.
  static String? configuredUri(SharedPreferences prefs) =>
      prefs.getString(_uriKey);

  /// Whether a folder is set and still writable.
  ///
  /// Both halves matter: the user can revoke the grant, move the folder to an
  /// SD card that is no longer mounted, or delete it outright, and a backup
  /// that quietly stopped happening is worse than one that never started.
  static Future<bool> isUsable(SharedPreferences prefs) async {
    final uri = configuredUri(prefs);
    if (uri == null) return false;
    try {
      return await _channel.invokeMethod<bool>('hasAccess', {'tree': uri}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system folder picker. Returns the folder's name once chosen,
  /// or null if the user backed out.
  static Future<String?> choose(SharedPreferences prefs) async {
    final String? uri;
    try {
      uri = await _channel.invokeMethod<String>('pickFolder');
    } catch (_) {
      return null;
    }
    if (uri == null) return null;

    await prefs.setString(_uriKey, uri);
    return await displayName(prefs) ?? uri;
  }

  /// The folder's name as the user would recognise it, for the settings row.
  static Future<String?> displayName(SharedPreferences prefs) async {
    final uri = configuredUri(prefs);
    if (uri == null) return null;
    try {
      return await _channel.invokeMethod<String>('displayName', {'tree': uri});
    } catch (_) {
      return null;
    }
  }

  /// Forgets the folder. The files already written stay where they are, which
  /// is the whole point of them.
  static Future<void> forget(SharedPreferences prefs) =>
      prefs.remove(_uriKey);

  // ------------------------------------------------------------------ writing

  /// Mirrors a snapshot into the chosen folder, if there is one.
  ///
  /// Never throws. This runs behind the daily snapshot and behind the app
  /// starting up; a folder the user has since deleted must not be able to stop
  /// either of them.
  static Future<bool> mirror(
    AppDatabase db,
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final uri = configuredUri(prefs);
    if (uri == null) return false;

    try {
      final at = now ?? DateTime.now();
      final stamp = '${at.year.toString().padLeft(4, '0')}-'
          '${at.month.toString().padLeft(2, '0')}-'
          '${at.day.toString().padLeft(2, '0')}';

      await _channel.invokeMethod('write', {
        'tree': uri,
        'name': 'tally-backup-$stamp.json',
        'content': await Backup.buildBackupJson(db),
      });
      await _prune(uri);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Writes a first snapshot, but only into a folder that holds none of ours.
  ///
  /// Choosing a folder must never overwrite what is in it. Someone pointing the
  /// app at a folder straight after reinstalling is there to get their records
  /// back, and the app at that moment holds either nothing or whatever stale
  /// copy the account backup restored. Writing that over their good file is
  /// the precise disaster this whole feature exists to prevent, and it is
  /// silent: the folder still has a file with today's date on it.
  ///
  /// So a folder with something in it is left strictly alone until either the
  /// daily snapshot comes round or the user asks for one by hand.
  static Future<bool> seedIfEmpty(
    AppDatabase db,
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    if ((await list(prefs)).isNotEmpty) return false;
    return mirror(db, prefs, now: now);
  }

  // ------------------------------------------------------------------ reading

  /// The backups sitting in the folder, newest first.
  static Future<List<FolderBackup>> list(SharedPreferences prefs) async {
    final uri = configuredUri(prefs);
    if (uri == null) return const [];
    return _listAt(uri);
  }

  static Future<List<FolderBackup>> _listAt(String tree) async {
    try {
      final rows = await _channel.invokeListMethod<Object?>('list', {'tree': tree});
      if (rows == null) return const [];

      final entries = [
        for (final row in rows.cast<Map<Object?, Object?>>())
          FolderBackup(
            uri: row['uri']! as String,
            name: row['name']! as String,
            modified: DateTime.fromMillisecondsSinceEpoch(
              (row['modified'] as int?) ?? 0,
            ),
            sizeBytes: (row['size'] as int?) ?? 0,
          ),
      ];
      // By the date in the name where there is one, the same way the internal
      // snapshots are sorted and for the same reason: copying a folder around
      // rewrites every modified time at once.
      entries.sort((a, b) {
        final byName = b.stampOrNull?.compareTo(a.stampOrNull ?? DateTime(0));
        if (byName != null && byName != 0) return byName;
        return b.modified.compareTo(a.modified);
      });
      return entries;
    } catch (_) {
      return const [];
    }
  }

  /// Reads one backup's contents.
  static Future<String?> read(String uri) async {
    try {
      return await _channel.invokeMethod<String>('read', {'uri': uri});
    } catch (_) {
      return null;
    }
  }

  /// Restores from a file in the folder.
  static Future<RestoreSummary> restore(AppDatabase db, String uri) async {
    final json = await read(uri);
    if (json == null) {
      throw const BackupError('Fișierul nu a putut fi citit din folder.');
    }
    return Backup.restoreFromJson(db, json);
  }

  static Future<void> _prune(String tree) async {
    final entries = await _listAt(tree);
    if (entries.length <= keep) return;
    for (final old in entries.skip(keep)) {
      try {
        await _channel.invokeMethod('delete', {'uri': old.uri});
      } catch (_) {
        // A file that will not delete is not worth failing a backup over.
      }
    }
  }

  // --------------------------------------------------- the system's own backup

  /// Opens the system page with the Google account backup switch.
  ///
  /// The app declares itself backup-eligible and always has; what it cannot do
  /// is turn the switch on. Only the user can, and only there.
  static Future<void> openSystemBackupSettings() async {
    try {
      await _channel.invokeMethod('openBackupSettings');
    } catch (_) {
      // Nothing useful to say if even Settings will not open.
    }
  }

  /// Whether this platform has a folder picker at all.
  static Future<bool> get supported => _available();
}

/// One backup file sitting in the user's folder.
class FolderBackup {
  const FolderBackup({
    required this.uri,
    required this.name,
    required this.modified,
    required this.sizeBytes,
  });

  final String uri;
  final String name;
  final DateTime modified;
  final int sizeBytes;

  static final _stampPattern = RegExp(r'tally-backup-(\d{4})-(\d{2})-(\d{2})\.json$');

  /// The date out of the file's own name, which survives being copied about.
  DateTime? get stampOrNull {
    final match = _stampPattern.firstMatch(name);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  DateTime get takenAt => stampOrNull ?? modified;

  /// True when all that is known is the day.
  ///
  /// The file name carries a date and no clock time, so [takenAt] comes back
  /// at midnight. Printing "29 septembrie, 00:00" would state a time that was
  /// never measured, and one that looks wrong to anyone who made the backup in
  /// the evening.
  bool get isDateOnly => stampOrNull != null;
}
