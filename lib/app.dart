import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auto_backup.dart';
import 'core/recurrence_service.dart';
import 'core/theme.dart';
import 'core/widgets/themed_backdrop.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/transactions/add_transaction_sheet.dart';
import 'l10n/gen/app_localizations.dart';
import 'providers.dart';

class TallyApp extends ConsumerWidget {
  const TallyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched rather than read: picking a theme has to repaint the whole app
    // behind the picker, so the choice is visible before it is confirmed.
    final flavor = ref.watch(flavorProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(flavor),
      // Pinned, not merely defaulted. Without this the phone's night setting
      // would fall back to `theme` anyway, but silently: anyone reading this
      // would have to know that `darkTheme` being absent is what does it.
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Wrapped around every route rather than around the shell, so a pushed
      // screen — the theme picker, the backups, the recurring rules — stands
      // on the same page as the one it came from instead of on a flat slab.
      builder: (context, child) =>
          ThemedBackdrop(flavor: flavor, child: child!),
      home: const RootShell(),
    );
  }
}

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;
  AppLifecycleListener? _lifecycle;

  static const _tabs = [HomeScreen(), StatsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    // Startup already generated what was due, but an app left open overnight
    // would otherwise not notice that it is now the 5th. Regenerating on
    // resume costs one query against a handful of rules.
    _lifecycle = AppLifecycleListener(
      onResume: () => RecurrenceService.materialize(ref.read(databaseProvider)),
      // Also on the way out, not only on the way in. Startup alone would mean
      // everything entered today waits until tomorrow's launch to be saved,
      // and the day you actually need the snapshot is the day you did not
      // reopen the app.
      onHide: _snapshotIfDue,
      onPause: _snapshotIfDue,
    );
  }

  /// Guarded by the same 24 hour interval, so backgrounding the app twenty
  /// times a day still writes at most one file.
  void _snapshotIfDue() {
    AutoBackup.runIfDue(
      ref.read(databaseProvider),
      ref.read(preferencesProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // IndexedStack keeps each tab's scroll position and stream subscriptions
      // alive, so switching back does not re-run every query.
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton(
              onPressed: () => showAddTransactionSheet(context),
              tooltip: l10n.addExpense,
              child: const Icon(Icons.add_rounded, size: 26),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: const Icon(Icons.pie_chart_rounded),
            label: l10n.navStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
