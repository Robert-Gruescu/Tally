import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auto_backup.dart';
import '../../core/backup.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../recurring/recurring_screen.dart';
import 'auto_backup_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Guards the export and restore rows while a file is being written or read,
  /// so a double tap cannot start two restores over each other.
  bool _busy = false;
  DateTime? _lastAuto;

  @override
  void initState() {
    super.initState();
    _loadLastAuto();
  }

  Future<void> _loadLastAuto() async {
    final at = await AutoBackup.lastRun(ref.read(preferencesProvider));
    if (mounted) setState(() => _lastAuto = at);
  }

  /// "azi, 14:32" reads better than a full date for something that happens
  /// every day; older ones get the day name so they are still placeable.
  String _formatLast(BuildContext context, DateTime at) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time = DateFormat('HH:mm').format(at);

    if (day == today) return '${l10n.today.toLowerCase()}, $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return '${l10n.yesterday.toLowerCase()}, $time';
    }
    return DateFormat('d MMMM, HH:mm', 'ro_RO').format(at);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------------ export

  Future<void> _share(Future<File> Function() build) async {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);

    if ((await db.allTransactions()).isEmpty) {
      _toast(l10n.nothingToExport);
      return;
    }

    final file = await build();
    if (!mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: l10n.shareExportTitle,
      ),
    );
  }

  // ----------------------------------------------------------------- restore

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);

    // file_picker 12 exposes `pickFile` as a static returning a single result;
    // the older `FilePicker.platform.pickFiles(...)` instance API is gone.
    final picked = await FilePicker.pickFile(type: FileType.any);
    final path = picked?.path;
    if (path == null || !mounted) return;

    // The confirmation comes after the file is chosen, not before: asking
    // "are you sure" before the user has even picked anything is a dialog
    // about nothing.
    final confirmed = await _confirm(
      title: l10n.restoreConfirmTitle,
      body: l10n.restoreConfirmBody,
      action: l10n.restoreAction,
      destructive: false,
    );
    if (confirmed != true || !mounted) return;

    // A snapshot of what is about to be replaced. Restoring the wrong file is
    // the single easiest way to lose everything in this app, and the daily
    // rotation alone can be almost a day out of date when it happens.
    await AutoBackup.safetySnapshot(
      ref.read(databaseProvider),
      ref.read(preferencesProvider),
    );

    try {
      final summary =
          await Backup.restore(ref.read(databaseProvider), File(path));
      _toast(l10n.restoreDone(summary.transactions));
    } on BackupError catch (e) {
      _toast(e.message);
    }
  }

  // -------------------------------------------------------------------- wipe

  Future<void> _wipe() async {
    final l10n = AppLocalizations.of(context);

    // The one confirmation in the app: unlike deleting a single row, this is
    // not undoable.
    final confirmed = await _confirm(
      title: l10n.wipeConfirmTitle,
      body: l10n.wipeConfirmBody,
      action: l10n.delete,
      destructive: true,
    );
    if (confirmed != true) return;

    // Same reason as the restore above: the dialog says "definitiv", and it
    // still is as far as the ledger goes, but the snapshot means a mistaken
    // tap is recoverable from the backup list instead of being final.
    await AutoBackup.safetySnapshot(
      ref.read(databaseProvider),
      ref.read(preferencesProvider),
    );

    await ref.read(databaseProvider).deleteAllTransactions();
    _toast(l10n.wipeDone);
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
    required bool destructive,
  }) {
    final l10n = AppLocalizations.of(context);
    final money = Theme.of(context).extension<MoneyColors>()!;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: money.expense)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<void> _editCurrency() async {
    final l10n = AppLocalizations.of(context);
    final controller =
        TextEditingController(text: ref.read(currencyProvider));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.currency),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'RON', counterText: ''),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null) {
      await ref.read(currencyProvider.notifier).set(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final currency = ref.watch(currencyProvider);
    final flavor = ref.watch(flavorProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Text(l10n.navSettings, style: theme.textTheme.titleLarge),
          ),

          _SectionHeader(l10n.sectionData),
          _Row(
            icon: Icons.event_repeat_rounded,
            title: l10n.recurring,
            subtitle: l10n.recurringSub,
            onTap: () => Navigator.of(context).push(RecurringScreen.route()),
          ),
          _Row(
            icon: Icons.payments_outlined,
            title: l10n.currency,
            trailing: currency,
            onTap: _editCurrency,
          ),
          _Row(
            icon: Icons.table_chart_outlined,
            title: l10n.exportCsv,
            subtitle: l10n.exportCsvSub,
            enabled: !_busy,
            onTap: () => _run(() => _share(
                () => Backup.writeCsv(ref.read(databaseProvider)))),
          ),
          _Row(
            icon: Icons.archive_outlined,
            title: l10n.exportBackup,
            subtitle: l10n.exportBackupSub,
            enabled: !_busy,
            onTap: () => _run(() => _share(
                () => Backup.writeBackup(ref.read(databaseProvider)))),
          ),
          _Row(
            icon: Icons.settings_backup_restore_rounded,
            title: l10n.restoreBackup,
            subtitle: l10n.restoreBackupSub,
            enabled: !_busy,
            onTap: () => _run(_restore),
          ),
          _Row(
            icon: Icons.history_rounded,
            title: l10n.autoBackup,
            subtitle: _lastAuto == null
                ? l10n.autoBackupOn
                : l10n.autoBackupLast(_formatLast(context, _lastAuto!)),
            onTap: () async {
              await Navigator.of(context).push(AutoBackupScreen.route());
              if (mounted) _loadLastAuto();
            },
          ),

          _SectionHeader(l10n.sectionLook),
          _Row(
            // The chosen theme names itself in the trailing slot, so the row
            // says which crown is on without having to be opened.
            icon: flavor.emblem,
            title: l10n.themeTitle,
            subtitle: flavor.description,
            trailing: flavor.label,
            onTap: () => Navigator.of(context).push(ThemeScreen.route()),
          ),

          _SectionHeader(l10n.sectionApp),
          _Row(
            icon: Icons.delete_outline_rounded,
            title: l10n.wipeTitle,
            subtitle: l10n.wipeSub,
            color: money.expense,
            onTap: _wipe,
          ),
          _Row(
            icon: Icons.info_outline_rounded,
            title: l10n.appTitle,
            subtitle: l10n.appVersion('1.0.0'),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(l10n.privacyNote, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? color;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;
    final tint = color ?? theme.colorScheme.onSurface;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 15),
          child: Row(
            children: [
              Icon(icon, size: 21, color: color ?? money.muted),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500, color: tint),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: theme.textTheme.bodySmall),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: money.hairline),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
