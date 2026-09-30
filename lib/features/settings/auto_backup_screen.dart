import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auto_backup.dart';
import '../../core/backup.dart';
import '../../core/backup_folder.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// Everything that stands between the user and losing their records, in the
/// order of how much it actually protects them.
///
/// Three layers, and they are deliberately shown as three rather than hidden
/// behind one reassuring word:
///
///  - the folder they choose, which survives uninstalling the app;
///  - the account backup, the only one that comes back by itself;
///  - the daily snapshots inside the app, which cover a mistaken tap and
///    nothing more, because Android deletes them with the app.
///
/// The screen is blunt about which is which. A backup nobody understands is a
/// backup nobody checks, and the invisible one here turned out to be switched
/// off for a year without saying so.
class AutoBackupScreen extends ConsumerStatefulWidget {
  const AutoBackupScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AutoBackupScreen());

  @override
  ConsumerState<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends ConsumerState<AutoBackupScreen> {
  late Future<List<AutoBackupFile>> _snapshots;
  bool _busy = false;

  String? _folderName;
  bool _folderUsable = false;
  List<FolderBackup> _folderFiles = const [];

  @override
  void initState() {
    super.initState();
    _snapshots = AutoBackup.list();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final prefs = ref.read(preferencesProvider);
    final usable = await BackupFolder.isUsable(prefs);
    final name = await BackupFolder.displayName(prefs);
    final files = usable ? await BackupFolder.list(prefs) : const <FolderBackup>[];
    if (!mounted) return;
    setState(() {
      _folderUsable = usable;
      _folderName = name;
      _folderFiles = files;
    });
  }

  void _reloadSnapshots() =>
      setState(() => _snapshots = AutoBackup.list());

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------------ folder

  Future<void> _chooseFolder() async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = AppLocalizations.of(context);
    final prefs = ref.read(preferencesProvider);
    final chosen = await BackupFolder.choose(prefs);

    if (chosen != null) {
      // Only into an empty folder. Writing one immediately is what stops
      // "I chose a folder and nothing happened", but it must never be what
      // replaces a backup that was already sitting there.
      await BackupFolder.seedIfEmpty(ref.read(databaseProvider), prefs);
    }

    if (!mounted) return;
    setState(() => _busy = false);
    await _loadFolder();
    if (chosen != null && mounted) _toast(l10n.autoBackupDone);
  }

  // ----------------------------------------------------------------- restore

  Future<void> _restoreFrom(Future<RestoreSummary> Function() run) async {
    final l10n = AppLocalizations.of(context);
    final money = Theme.of(context).extension<MoneyColors>()!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: money.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.restoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Going back to last Tuesday should not throw away today. One more
    // snapshot first, so the list itself is always a round trip.
    await AutoBackup.safetySnapshot(
      ref.read(databaseProvider),
      ref.read(preferencesProvider),
    );

    try {
      final summary = await run();
      if (!mounted) return;
      _toast(l10n.restoreDone(summary.transactions));
      Navigator.of(context).pop();
    } on BackupError catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  Future<void> _backupNow() async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = AppLocalizations.of(context);
    final file = await AutoBackup.runIfDue(
      ref.read(databaseProvider),
      ref.read(preferencesProvider),
      force: true,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    _reloadSnapshots();
    await _loadFolder();
    if (mounted) {
      _toast(file == null ? l10n.nothingToExport : l10n.autoBackupDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.autoBackup)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _Card(
              title: l10n.autoBackupWarnTitle,
              body: l10n.autoBackupWarnBody,
              money: money,
            ),
          ),

          // ---------------------------------------------------- the folder
          _SectionHeader(l10n.folderBackup, money: money),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(l10n.folderBackupWhy, style: theme.textTheme.bodySmall),
          ),
          if (_folderName != null && !_folderUsable)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _Card(
                title: l10n.folderBackupLost,
                body: l10n.folderBackupLostBody,
                money: money,
                alarming: true,
              ),
            ),
          _Tile(
            icon: Icons.folder_outlined,
            title: _folderUsable && _folderName != null
                ? _folderName!
                : l10n.folderBackupNone,
            subtitle: _folderUsable
                ? (_folderFiles.isEmpty
                    ? l10n.folderBackupEmpty
                    : l10n.foundBackups(_folderFiles.length))
                : null,
            action: _folderUsable ? l10n.folderBackupChange : l10n.folderBackupPick,
            enabled: !_busy,
            onTap: _chooseFolder,
          ),
          for (final entry in _folderFiles)
            _BackupRow(
              label: _when(context, entry.takenAt, dateOnly: entry.isDateOnly),
              detail: entry.name,
              onRestore: () => _restoreFrom(
                () => BackupFolder.restore(ref.read(databaseProvider), entry.uri),
              ),
            ),

          // ------------------------------------------------ google account
          _SectionHeader(l10n.googleBackup, money: money),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: Text(l10n.googleBackupBody, style: theme.textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: OutlinedButton(
              onPressed: BackupFolder.openSystemBackupSettings,
              child: Text(l10n.googleBackupOpen),
            ),
          ),

          // ------------------------------------------- snapshots in the app
          _SectionHeader(l10n.autoBackup, money: money),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: OutlinedButton(
              onPressed: _busy ? null : _backupNow,
              child: Text(l10n.autoBackupNow),
            ),
          ),
          FutureBuilder<List<AutoBackupFile>>(
            future: _snapshots,
            builder: (context, snapshot) {
              final files = snapshot.data ?? const <AutoBackupFile>[];
              if (files.isEmpty &&
                  snapshot.connectionState == ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
                  child: Column(
                    children: [
                      Text(
                        l10n.autoBackupEmptyTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: money.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.autoBackupEmptyBody,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final entry in files)
                    _BackupRow(
                      label: _when(context, entry.takenAt),
                      detail: entry.name,
                      countOf: entry.countTransactions,
                      onRestore: () => _restoreFrom(
                        () => Backup.restore(
                          ref.read(databaseProvider),
                          entry.file,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _when(BuildContext context, DateTime at, {bool dateOnly = false}) {
  final text = DateFormat(
    dateOnly ? 'EEEE, d MMMM' : 'EEEE, d MMMM, HH:mm',
    'ro_RO',
  ).format(at);
  return text[0].toUpperCase() + text.substring(1);
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.body,
    required this.money,
    this.alarming = false,
  });

  final String title;
  final String body;
  final MoneyColors money;
  final bool alarming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = alarming ? money.expense : money.hairline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: tint),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: alarming ? money.expense : null),
          ),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {required this.money});

  final String label;
  final MoneyColors money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: money.muted),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: money.hairline),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.action,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String action;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: Row(
            children: [
              Icon(icon, size: 21, color: money.muted),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({
    required this.label,
    required this.detail,
    required this.onRestore,
    this.countOf,
  });

  final String label;
  final String detail;
  final VoidCallback onRestore;
  final Future<int?> Function()? countOf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Column(
      children: [
        Divider(color: money.hairline, height: 1, indent: 24, endIndent: 24),
        InkWell(
          onTap: onRestore,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 20, color: money.muted),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      if (countOf == null)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        )
                      else
                        FutureBuilder<int?>(
                          future: countOf!(),
                          builder: (context, snapshot) => Text(
                            snapshot.data == null
                                ? detail
                                : l10n.autoBackupCount(snapshot.data!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: money.hairline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
