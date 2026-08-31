import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auto_backup.dart';
import '../../core/backup.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// The snapshots the app took of itself, and the way back from one.
///
/// Deliberately visible rather than hidden machinery: a backup nobody can see
/// is a backup nobody trusts, and the whole reason this exists is that the
/// invisible one turned out to be off.
class AutoBackupScreen extends ConsumerStatefulWidget {
  const AutoBackupScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AutoBackupScreen());

  @override
  ConsumerState<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends ConsumerState<AutoBackupScreen> {
  late Future<List<AutoBackupFile>> _files;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _files = AutoBackup.list();
  }

  void _reload() => setState(() => _files = AutoBackup.list());

  Future<void> _backupNow() async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final file = await AutoBackup.runIfDue(
      ref.read(databaseProvider),
      ref.read(preferencesProvider),
      force: true,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    _reload();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(file == null ? l10n.nothingToExport : l10n.autoBackupDone),
      ));
  }

  Future<void> _restore(AutoBackupFile entry) async {
    final l10n = AppLocalizations.of(context);
    final money = Theme.of(context).extension<MoneyColors>()!;
    final messenger = ScaffoldMessenger.of(context);

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

    try {
      final summary =
          await Backup.restore(ref.read(databaseProvider), entry.file);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.restoreDone(summary.transactions))),
      );
      Navigator.of(context).pop();
    } on BackupError catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.autoBackup)),
      body: FutureBuilder<List<AutoBackupFile>>(
        future: _files,
        builder: (context, snapshot) {
          final files = snapshot.data ?? const <AutoBackupFile>[];

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: money.hairline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.autoBackupWarnTitle,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(l10n.autoBackupWarnBody,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: OutlinedButton(
                  onPressed: _busy ? null : _backupNow,
                  child: Text(l10n.autoBackupNow),
                ),
              ),
              if (files.isEmpty && snapshot.connectionState == ConnectionState.done)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
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
                ),
              for (final entry in files) _BackupRow(
                entry: entry,
                onRestore: () => _restore(entry),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.entry, required this.onRestore});

  final AutoBackupFile entry;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    final when = DateFormat('EEEE, d MMMM, HH:mm', 'ro_RO').format(entry.takenAt);
    final label = when[0].toUpperCase() + when.substring(1);

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
                      Text(label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      FutureBuilder<int?>(
                        future: entry.countTransactions(),
                        builder: (context, snapshot) => Text(
                          snapshot.data == null
                              ? entry.name
                              : l10n.autoBackupCount(snapshot.data!),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: money.hairline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
