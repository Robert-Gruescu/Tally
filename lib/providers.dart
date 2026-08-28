import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/db/database.dart';
import 'core/period.dart';

/// Both are supplied by `main` through `ProviderScope.overrides`, so the app
/// never renders against a half-open database and no screen has to handle a
/// loading state that only exists for a few milliseconds at startup.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main'),
);

// ------------------------------------------------------------------ settings

const _currencyKey = 'currency_symbol';
const _defaultCurrency = 'lei';

/// The currency symbol is user data, not a constant. Hardcoding "lei" is what
/// makes an app unpublishable outside one country later.
class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier(this._prefs)
      : super(_prefs.getString(_currencyKey) ?? _defaultCurrency);

  final SharedPreferences _prefs;

  Future<void> set(String symbol) async {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return;
    state = trimmed;
    await _prefs.setString(_currencyKey, trimmed);
  }
}

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>(
  (ref) => CurrencyNotifier(ref.watch(preferencesProvider)),
);

// -------------------------------------------------------------------- period

final periodProvider = StateProvider<Period>((ref) => Period.month);

/// Recomputed whenever the period changes. Deliberately not cached across a
/// midnight boundary; the app is rebuilt on resume, which is when it matters.
final dateRangeProvider = Provider<DateRange>(
  (ref) => DateRange.of(ref.watch(periodProvider)),
);

// --------------------------------------------------------------------- reads

/// Income, expense and balance for the selected period.
final summaryProvider = StreamProvider<PeriodSummary>((ref) {
  final range = ref.watch(dateRangeProvider);
  return ref.watch(databaseProvider).watchSummary(
        from: range.from,
        to: range.to,
      );
});

/// The same figures for the preceding period, so the UI can say "+18% fata de
/// luna trecuta" instead of showing a number with no reference point.
final previousSummaryProvider = StreamProvider<PeriodSummary>((ref) {
  final range = ref.watch(dateRangeProvider).previous;
  return ref.watch(databaseProvider).watchSummary(
        from: range.from,
        to: range.to,
      );
});

final transactionsProvider = StreamProvider<List<TxnWithCategory>>((ref) {
  final range = ref.watch(dateRangeProvider);
  return ref.watch(databaseProvider).watchTransactions(
        from: range.from,
        to: range.to,
      );
});

/// Always seven bars ending today, independent of the period selector, so the
/// chart axis does not reflow when the user switches tabs.
final weeklyExpensesProvider = StreamProvider<List<DailyTotal>>((ref) {
  final range = DateRange.lastSevenDays();
  return ref.watch(databaseProvider).watchDailyExpenses(
        from: range.from,
        to: range.to,
      );
});

final categoryTotalsProvider =
    StreamProvider.family<List<CategoryTotal>, TxKind>((ref, kind) {
  final range = ref.watch(dateRangeProvider);
  return ref.watch(databaseProvider).watchCategoryTotals(
        from: range.from,
        to: range.to,
        kind: kind,
      );
});

final categoriesProvider =
    StreamProvider.family<List<Category>, TxKind>((ref, kind) {
  return ref.watch(databaseProvider).watchCategories(kind);
});
