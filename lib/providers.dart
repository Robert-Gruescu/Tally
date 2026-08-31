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

/// How many whole periods back the user is looking. Zero is now, negative is
/// the past. The future is never offered: there is nothing recorded there.
final periodOffsetProvider = StateProvider<int>((ref) => 0);

/// Recomputed whenever the period or the offset changes. Deliberately not
/// cached across a midnight boundary; the app is rebuilt on resume, which is
/// when it matters.
final dateRangeProvider = Provider<DateRange>((ref) {
  return DateRange.shifted(
    ref.watch(periodProvider),
    ref.watch(periodOffsetProvider),
  );
});

/// True while the user is looking at the current period rather than a past one.
/// Anything labelled "the last seven days" only makes sense here.
final isCurrentPeriodProvider = Provider<bool>(
  (ref) => ref.watch(periodOffsetProvider) == 0,
);

/// One day picked out of the chart, or null for the whole period.
///
/// Tapping a bar drills into that day the way a step counter does: the chart
/// stays where it is, and everything around it, the totals and the list, narrow
/// to the day under your finger. Tapping the same bar again lets go.
final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// What the totals and the list actually cover: the tapped day if there is one,
/// otherwise the whole period.
///
/// The chart itself deliberately does not use this. It keeps drawing the full
/// period, because a chart that collapsed to a single bar when you touched it
/// would take away the thing you were reading.
final effectiveRangeProvider = Provider<DateRange>((ref) {
  final day = ref.watch(selectedDayProvider);
  if (day == null) return ref.watch(dateRangeProvider);
  return DateRange(day, DateTime(day.year, day.month, day.day + 1));
});

// --------------------------------------------------------------------- reads

/// Income, expense and balance for the selected period.
final summaryProvider = StreamProvider<PeriodSummary>((ref) {
  final range = ref.watch(effectiveRangeProvider);
  return ref.watch(databaseProvider).watchSummary(
        from: range.from,
        to: range.to,
      );
});

/// The same figures for the preceding period, so the UI can say "+18% fata de
/// luna trecuta" instead of showing a number with no reference point.
final previousSummaryProvider = StreamProvider<PeriodSummary>((ref) {
  // The step before whatever is on screen: the previous day when a day is
  // picked, the previous month when a month is.
  final range = ref.watch(effectiveRangeProvider).previous;
  return ref.watch(databaseProvider).watchSummary(
        from: range.from,
        to: range.to,
      );
});

final transactionsProvider = StreamProvider<List<TxnWithCategory>>((ref) {
  final range = ref.watch(effectiveRangeProvider);
  return ref.watch(databaseProvider).watchTransactions(
        from: range.from,
        to: range.to,
      );
});

/// The bars on Home.
///
/// At the present it is the trailing seven days, which is the useful framing
/// for "how am I doing right now". Once the user navigates back it becomes the
/// days of whatever window they are looking at, because a chart labelled "last
/// seven days" sitting under an August total would simply be wrong.
final dailyChartProvider = StreamProvider<List<DailyTotal>>((ref) {
  final range = ref.watch(isCurrentPeriodProvider)
      ? DateRange.lastSevenDays()
      : ref.watch(dateRangeProvider);
  return ref.watch(databaseProvider).watchDailyExpenses(
        from: range.from,
        to: range.to,
      );
});

final categoryTotalsProvider =
    StreamProvider.family<List<CategoryTotal>, TxKind>((ref, kind) {
  final range = ref.watch(effectiveRangeProvider);
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

/// The oldest transaction on record, which is as far back as walking makes
/// sense.
final firstTransactionDateProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(databaseProvider).watchFirstTransactionDate(),
);

/// Whether there is anything older than the window currently on screen.
final canGoBackProvider = Provider<bool>((ref) {
  final first = ref.watch(firstTransactionDateProvider).valueOrNull;
  // With no history at all, one step back is still allowed: it is how someone
  // reaches last month to enter something they forgot.
  if (first == null) return ref.watch(periodOffsetProvider) == 0;
  return ref.watch(dateRangeProvider).from.isAfter(first);
});

/// Income and expense for each of the last twelve calendar months, oldest
/// first. Independent of the period selector: it is the long view.
final monthlyTotalsProvider = StreamProvider<List<MonthTotal>>((ref) {
  final range = DateRange.lastMonths(12);
  return ref.watch(databaseProvider).watchMonthlyTotals(
        from: range.from,
        to: range.to,
      );
});

// ----------------------------------------------------------------- recurring

/// Salary and subscription rules, for the management screen.
final rulesProvider = StreamProvider<List<RuleWithCategory>>(
  (ref) => ref.watch(databaseProvider).watchRules(),
);

/// The questions waiting for a yes or no. Drives the banner on Home, so the
/// banner appears and disappears on its own as answers come in.
final pendingOccurrencesProvider = StreamProvider<List<PendingOccurrence>>(
  (ref) => ref.watch(databaseProvider).watchPending(),
);
