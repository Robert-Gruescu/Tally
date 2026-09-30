import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/db/database.dart';
import 'package:tally/core/db/seed.dart';
import 'package:tally/providers.dart';

/// The run of consecutive days with something written down.
///
/// The only number in the app whose job is encouragement rather than accuracy,
/// which is exactly why its edges need pinning. It is read first thing in the
/// morning, before anything has been entered, and it crosses month ends and
/// year ends like every other date calculation here — the two places this
/// project has already been bitten.
void main() {
  late AppDatabase db;
  late int food;

  /// Midnight today, the same anchor the provider uses.
  DateTime day(int daysAgo) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo, 12);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedDefaultCategories(db);
    food = (await db.allCategories()).firstWhere((c) => c.name == 'Mâncare').id;
  });

  tearDown(() => db.close());

  Future<void> log(int daysAgo) => db.insertTxn(
        TransactionsCompanion.insert(
          amountMinor: 1500,
          kind: TxKind.expense,
          categoryId: food,
          spentAt: day(daysAgo),
        ),
      );

  /// Builds a container and waits for the first value off the stream.
  Future<int> streak() async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(loggedDaysProvider.future);
    return container.read(streakProvider);
  }

  test('an empty ledger has no run', () async {
    expect(await streak(), 0);
  });

  test('one entry today is a run of one', () async {
    await log(0);
    expect(await streak(), 1);
  });

  test('today and yesterday make two', () async {
    await log(0);
    await log(1);
    expect(await streak(), 2);
  });

  test('several entries on one day still count as one day', () async {
    await log(0);
    await log(0);
    await log(0);
    expect(await streak(), 1);
  });

  test('a gap ends the run', () async {
    await log(0);
    await log(1);
    // nothing two days ago
    await log(3);
    await log(4);
    expect(await streak(), 2, reason: 'the older pair is behind a gap');
  });

  test('nothing today yet keeps yesterday_s run alive', () async {
    // The morning case. Counting from today alone would show every run as
    // broken until the first entry of the day, which punishes someone for
    // having been asleep.
    await log(1);
    await log(2);
    await log(3);
    expect(await streak(), 3);
  });

  test('a run that ended the day before yesterday is over', () async {
    await log(2);
    await log(3);
    expect(await streak(), 0);
  });

  test('the run crosses the end of a month', () async {
    // Ten days back from any date crosses a month boundary for a third of the
    // year, and month arithmetic is where this project has been wrong before.
    for (var i = 0; i <= 10; i++) {
      await log(i);
    }
    expect(await streak(), 11);
  });

  test('income counts as writing something down', () async {
    // The habit being encouraged is keeping the diary, not spending money.
    await db.insertTxn(TransactionsCompanion.insert(
      amountMinor: 500000,
      kind: TxKind.income,
      categoryId:
          (await db.allCategories()).firstWhere((c) => c.name == 'Salariu').id,
      spentAt: day(0),
    ));
    expect(await streak(), 1);
  });

  test('a long run is counted in full', () async {
    for (var i = 0; i < 40; i++) {
      await log(i);
    }
    expect(await streak(), 40);
  });

  test('entries older than the window do not extend the run', () async {
    // The query looks back 120 days. A run reaching the edge stops there
    // rather than reporting a number the query cannot support.
    for (var i = 0; i < 130; i++) {
      await log(i);
    }
    expect(await streak(), lessThanOrEqualTo(121));
    expect(await streak(), greaterThan(100));
  });
}
