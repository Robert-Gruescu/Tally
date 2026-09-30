import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/period.dart';
import 'package:tally/core/theme.dart';
import 'package:tally/features/stats/monthly_chart.dart';
import 'package:tally/l10n/gen/app_localizations.dart';
import 'package:tally/providers.dart';

/// The twelve-month chart is also a way in: each month is a button that moves
/// the whole app to it.
///
/// Both bugs pinned here were invisible on screen. The chart toggled on
/// `isInterestedForInteractions`, which is true for several events inside a
/// single tap, so every tap navigated twice; that happened to be idempotent
/// and so left no symptom, while the identical mistake in the daily chart made
/// it respond only to a long press. And it moved the window without letting go
/// of a day picked out of the daily chart, leaving September's Tuesday under a
/// heading that said July.
List<MonthTotal> _twelveMonths(DateTime now) {
  final first = DateTime(now.year, now.month - 11, 1);
  return [
    for (var i = 0; i < 12; i++)
      MonthTotal(
        month: DateTime(first.year, first.month + i, 1),
        // Every month carries something: an empty one draws no rod, and a rod
        // that is not there cannot be tapped.
        incomeMinor: 400000 + i * 1000,
        expenseMinor: 250000 + i * 1000,
      ),
  ];
}

Future<ProviderContainer> _pumpChart(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final months = _twelveMonths(DateTime.now());

  final container = ProviderContainer(overrides: [
    preferencesProvider.overrideWithValue(prefs),
    monthlyTotalsProvider.overrideWith((ref) => Stream.value(months)),
  ]);
  addTearDown(container.dispose);

  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ro'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: MonthlyChart(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Taps the bar group [index] of twelve, just above the baseline where a rod
/// is certain to be under the finger.
///
/// `BarChartAlignment.spaceAround` gives each of the twelve groups an equal
/// column with half a gap at either end, so group i sits at (i + 0.5)/12 of
/// the plot width. The bottom 26 logical pixels are reserved for the month
/// letters and are not part of the plot.
Future<void> _tapMonth(WidgetTester tester, int index) async {
  final chart = tester.getRect(find.byType(BarChart));
  const axisHeight = 26.0;

  await tester.tapAt(Offset(
    chart.left + chart.width * (index + 0.5) / 12,
    chart.bottom - axisHeight - 6,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a plain tap moves the app to that month', (tester) async {
    final container = await _pumpChart(tester);

    expect(container.read(periodOffsetProvider), 0);

    // The month before this one: one whole step back, whatever the calendar
    // does around it.
    await _tapMonth(tester, 10);

    expect(container.read(periodProvider), Period.month);
    expect(container.read(periodOffsetProvider), -1);
  });

  testWidgets('the oldest bar reaches eleven months back', (tester) async {
    final container = await _pumpChart(tester);

    await _tapMonth(tester, 0);

    expect(container.read(periodOffsetProvider), -11);
  });

  testWidgets('the current month is still a valid target', (tester) async {
    final container = await _pumpChart(tester);

    container.read(periodOffsetProvider.notifier).state = -5;
    await tester.pumpAndSettle();

    await _tapMonth(tester, 11);

    expect(container.read(periodOffsetProvider), 0);
  });

  testWidgets('opening a month lets go of a day picked elsewhere',
      (tester) async {
    final container = await _pumpChart(tester);

    // As if the user had tapped a bar on Home first. Carried into another
    // month it would filter every total to a day outside the window.
    container.read(selectedDayProvider.notifier).state = DateTime(2026, 9, 3);
    await tester.pumpAndSettle();

    await _tapMonth(tester, 10);

    expect(container.read(selectedDayProvider), isNull);
    expect(
      container.read(effectiveRangeProvider),
      container.read(dateRangeProvider),
    );
  });
}
