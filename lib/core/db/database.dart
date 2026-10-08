import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Whether a transaction takes money out or brings it in.
///
/// Stored on both [Categories] and [Transactions]. The category copy drives
/// which chips the picker shows; the transaction copy is the source of truth
/// for every aggregate, so editing or archiving a category can never rewrite
/// history.
enum TxKind { expense, income }

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get kind => textEnum<TxKind>()();

  /// Key into `categoryIcons`, never a raw code point. Storing code points
  /// forces `--no-tree-shake-icons` and inflates the release bundle.
  TextColumn get iconKey => text().withLength(min: 1, max: 32)();
  IntColumn get colorValue => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('Txn')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Amount in minor units (bani), always positive. Direction lives in [kind].
  /// Never a double: 0.1 + 0.2 does not equal 0.3 and the monthly totals
  /// stop reconciling.
  IntColumn get amountMinor => integer()();
  TextColumn get kind => textEnum<TxKind>()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get note => text().nullable().withLength(max: 140)();

  /// The moment the money moved, in local time. Distinct from [createdAt]:
  /// users log yesterday's coffee today.
  DateTimeColumn get spentAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Whether the user has yet answered "did this actually happen?".
enum OccurrenceStatus { pending, confirmed, skipped }

/// A salary or a subscription: an amount expected on the same day each month.
///
/// The rule is a template, not history. Editing it changes what is expected
/// from now on and never rewrites transactions already recorded, because those
/// describe money that really moved.
@DataClassName('RecurringRule')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountMinor => integer()();
  TextColumn get kind => textEnum<TxKind>()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get note => text().nullable().withLength(max: 140)();

  /// 1..31. A 31 lands on the last day of a shorter month rather than spilling
  /// into the next one; see `Recurrence.dueDateIn`.
  IntColumn get dayOfMonth => integer()();

  /// Occurrences are never generated before this date, so adding a rule today
  /// does not invent a year of back-dated salary.
  DateTimeColumn get startsOn => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One expected date for one rule, and what the user decided about it.
///
/// This table is why the app can ask instead of assuming. Without it there
/// would be nowhere to record "no, the salary did not arrive in May", and the
/// question would come back every time the app opened.
@DataClassName('RecurringOccurrence')
class RecurringOccurrences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ruleId =>
      integer().references(RecurringRules, #id, onDelete: KeyAction.cascade)();

  /// Local midnight of the day the money was expected.
  DateTimeColumn get dueOn => dateTime()();
  TextColumn get status => textEnum<OccurrenceStatus>()();

  /// Set once confirmed. Nulled rather than cascaded if the user later deletes
  /// that transaction by hand, so the occurrence stays answered.
  IntColumn get transactionId =>
      integer().nullable().references(Transactions, #id, onDelete: KeyAction.setNull)();

  /// The duplicate guard. Opening the app twice in one day, or two catch-up
  /// passes racing, cannot produce the same salary twice.
  @override
  List<Set<Column>> get uniqueKeys => [
        {ruleId, dueOn},
      ];
}

/// A pending question, with everything the banner needs to render it.
class PendingOccurrence {
  const PendingOccurrence({
    required this.occurrence,
    required this.rule,
    required this.category,
  });

  final RecurringOccurrence occurrence;
  final RecurringRule rule;
  final Category category;
}

/// A rule with its category, for the management list.
class RuleWithCategory {
  const RuleWithCategory({required this.rule, required this.category});

  final RecurringRule rule;
  final Category category;
}

/// One row joined with its category, which is what every list and chart wants.
class TxnWithCategory {
  const TxnWithCategory({required this.txn, required this.category});

  final Txn txn;
  final Category category;
}

/// A category paired with its total over some period, for the donut and the
/// "where does the money go" report.
class CategoryTotal {
  const CategoryTotal({required this.category, required this.totalMinor});

  final Category category;
  final int totalMinor;
}

/// Income and expense totals for a period. Balance is derived, never stored.
class PeriodSummary {
  const PeriodSummary({required this.incomeMinor, required this.expenseMinor});

  static const empty = PeriodSummary(incomeMinor: 0, expenseMinor: 0);

  final int incomeMinor;
  final int expenseMinor;

  int get balanceMinor => incomeMinor - expenseMinor;
}

/// Income and expense for one calendar month, for the twelve-month history.
class MonthTotal {
  const MonthTotal({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  /// First day of the month, local time.
  final DateTime month;
  final int incomeMinor;
  final int expenseMinor;

  int get balanceMinor => incomeMinor - expenseMinor;
  bool get isEmpty => incomeMinor == 0 && expenseMinor == 0;
}

/// Expense total for a single calendar day, used by the 7-day bar chart.
class DailyTotal {
  const DailyTotal({required this.day, required this.totalMinor});

  final DateTime day;
  final int totalMinor;
}

@DriftDatabase(
  tables: [Categories, Transactions, RecurringRules, RecurringOccurrences],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tally'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          // v2 adds recurring rules. Existing rows are untouched: the two new
          // tables start empty, so a user upgrading sees exactly the data they
          // had, plus an empty "Plăți recurente" screen.
          if (from < 2) {
            await m.createTable(recurringRules);
            await m.createTable(recurringOccurrences);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_occurrences_status '
              'ON recurring_occurrences (status, due_on)',
            );
          }
        },
      );

  Future<void> _createIndexes() async {
    // Reads slow to a crawl without this once a user has a year of data;
    // every screen filters by date range.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_spent_at '
      'ON transactions (spent_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_occurrences_status '
      'ON recurring_occurrences (status, due_on)',
    );
  }

  // ---------------------------------------------------------------- categories

  Future<List<Category>> allCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();

  /// Active categories of one kind, ordered for the picker.
  Stream<List<Category>> watchCategories(TxKind kind) {
    return (select(categories)
          ..where((c) => c.kind.equalsValue(kind) & c.isArchived.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .watch();
  }

  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  Future<int> countCategories() async {
    final count = countAll();
    final row = await (selectOnly(categories)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Only money that has actually moved by [asOf].
  ///
  /// A row dated ahead is a plan, not a fact. It belongs in the ledger, where
  /// it is marked as still to come, and it must stay out of every total until
  /// its day arrives: a balance that already counts next week's rent is not a
  /// balance, it is a forecast wearing a balance's clothes.
  ///
  /// The cutoff is passed in rather than read from the clock here, so the
  /// tests can stand at a chosen moment and watch a row cross over.
  Expression<bool> _settled(DateTime? asOf) =>
      transactions.spentAt.isSmallerOrEqualValue(asOf ?? DateTime.now());

  // -------------------------------------------------------------- transactions

  Future<int> insertTxn(TransactionsCompanion txn) =>
      into(transactions).insert(txn);

  Future<bool> updateTxn(Txn txn) => update(transactions).replace(txn);

  Future<int> deleteTxn(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// Transactions in `[from, to)` with their category, newest first.
  ///
  /// Deliberately not filtered by [_settled]: the ledger is the one place a
  /// planned payment has to be visible, and it is marked there rather than
  /// hidden. Every total is filtered; this is not.
  Stream<List<TxnWithCategory>> watchTransactions({
    required DateTime from,
    required DateTime to,
    int? limit,
  }) {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..where(transactions.spentAt.isBiggerOrEqualValue(from) &
          transactions.spentAt.isSmallerThanValue(to))
      ..orderBy([
        OrderingTerm.desc(transactions.spentAt),
        OrderingTerm.desc(transactions.id),
      ]);

    if (limit != null) query.limit(limit);

    return query.watch().map(
          (rows) => rows
              .map((row) => TxnWithCategory(
                    txn: row.readTable(transactions),
                    category: row.readTable(categories),
                  ))
              .toList(),
        );
  }

  /// Income and expense totals over `[from, to)`, summed in SQL rather than
  /// pulled into Dart, so a year of rows costs one query.
  Stream<PeriodSummary> watchSummary({
    required DateTime from,
    required DateTime to,
    DateTime? asOf,
  }) {
    final total = transactions.amountMinor.sum();
    final query = selectOnly(transactions)
      ..addColumns([transactions.kind, total])
      ..where(transactions.spentAt.isBiggerOrEqualValue(from) &
          transactions.spentAt.isSmallerThanValue(to) &
          _settled(asOf))
      ..groupBy([transactions.kind]);

    return query.watch().map((rows) {
      var income = 0;
      var expense = 0;
      for (final row in rows) {
        // `selectOnly` hands back the raw stored value for an enum column, and
        // `textEnum` stores `Enum.name`. Comparing against the enum itself
        // silently never matches and every total comes back zero.
        final kind = row.read(transactions.kind);
        final sum = row.read(total) ?? 0;
        if (kind == TxKind.income.name) {
          income = sum;
        } else if (kind == TxKind.expense.name) {
          expense = sum;
        }
      }
      return PeriodSummary(incomeMinor: income, expenseMinor: expense);
    });
  }

  /// Totals per category over `[from, to)`, largest first. This is the query
  /// behind "pe ce cheltui cei mai multi bani".
  Stream<List<CategoryTotal>> watchCategoryTotals({
    required DateTime from,
    required DateTime to,
    required TxKind kind,
    DateTime? asOf,
  }) {
    final total = transactions.amountMinor.sum();
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..addColumns([total])
      ..where(transactions.kind.equalsValue(kind) &
          transactions.spentAt.isBiggerOrEqualValue(from) &
          transactions.spentAt.isSmallerThanValue(to) &
          _settled(asOf))
      ..groupBy([transactions.categoryId])
      ..orderBy([OrderingTerm.desc(total)]);

    return query.watch().map(
          (rows) => rows
              .map((row) => CategoryTotal(
                    category: row.readTable(categories),
                    totalMinor: row.read(total) ?? 0,
                  ))
              .toList(),
        );
  }

  /// Expense totals per day across `[from, to)`, with empty days filled in as
  /// zero so the bar chart keeps a stable axis.
  ///
  /// Bucketing happens in Dart rather than with SQLite's `date()`, which
  /// resolves a stored epoch in **UTC**. Any user east or west of Greenwich
  /// would see evening spending land on the wrong bar, and the range is only
  /// ever a handful of days, so the grouping is free.
  Stream<List<DailyTotal>> watchDailyExpenses({
    required DateTime from,
    required DateTime to,
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();
    final query = select(transactions)
      ..where((t) =>
          t.kind.equalsValue(TxKind.expense) &
          t.spentAt.isBiggerOrEqualValue(from) &
          t.spentAt.isSmallerThanValue(to) &
          t.spentAt.isSmallerOrEqualValue(cutoff));

    return query.watch().map((rows) {
      final byDay = <DateTime, int>{};
      for (final row in rows) {
        final local = row.spentAt.toLocal();
        final key = DateTime(local.year, local.month, local.day);
        byDay[key] = (byDay[key] ?? 0) + row.amountMinor;
      }

      final result = <DailyTotal>[];
      var cursor = DateTime(from.year, from.month, from.day);
      while (cursor.isBefore(to)) {
        result.add(DailyTotal(day: cursor, totalMinor: byDay[cursor] ?? 0));
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
      return result;
    });
  }

  /// Income and expense per calendar month across `[from, to)`, oldest first,
  /// with empty months filled in.
  ///
  /// Bucketed in Dart for the same reason the daily chart is: SQLite resolves a
  /// stored timestamp in UTC, so a transaction made late on the last evening of
  /// a month would be counted in the previous one for anyone east of Greenwich.
  Stream<List<MonthTotal>> watchMonthlyTotals({
    required DateTime from,
    required DateTime to,
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();
    final query = select(transactions)
      ..where((t) =>
          t.spentAt.isBiggerOrEqualValue(from) &
          t.spentAt.isSmallerThanValue(to) &
          t.spentAt.isSmallerOrEqualValue(cutoff));

    return query.watch().map((rows) {
      final income = <DateTime, int>{};
      final expense = <DateTime, int>{};

      for (final row in rows) {
        final local = row.spentAt.toLocal();
        final key = DateTime(local.year, local.month, 1);
        if (row.kind == TxKind.income) {
          income[key] = (income[key] ?? 0) + row.amountMinor;
        } else {
          expense[key] = (expense[key] ?? 0) + row.amountMinor;
        }
      }

      final result = <MonthTotal>[];
      var cursor = DateTime(from.year, from.month, 1);
      while (cursor.isBefore(to)) {
        result.add(MonthTotal(
          month: cursor,
          incomeMinor: income[cursor] ?? 0,
          expenseMinor: expense[cursor] ?? 0,
        ));
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
      return result;
    });
  }

  /// The local days inside `[from, to)` that carry at least one transaction.
  ///
  /// Feeds the run of consecutive days on Home. Deliberately about `spentAt`
  /// rather than when the row was typed: what it counts is whether the diary
  /// has a gap, which is the thing on screen and the thing a child can see
  /// themselves closing.
  ///
  /// Bucketed in Dart, like every other day query here, because SQLite
  /// resolves a stored timestamp in UTC.
  Stream<Set<DateTime>> watchLoggedDays({
    required DateTime from,
    required DateTime to,
  }) {
    final query = select(transactions)
      ..where((t) =>
          t.spentAt.isBiggerOrEqualValue(from) &
          t.spentAt.isSmallerThanValue(to));

    return query.watch().map((rows) {
      final days = <DateTime>{};
      for (final row in rows) {
        final local = row.spentAt.toLocal();
        days.add(DateTime(local.year, local.month, local.day));
      }
      return days;
    });
  }

  /// The distinct amounts most recently used in a category, newest first.
  /// Feeds the quick-amount chips: people spend the same numbers repeatedly.
  Future<List<int>> recentAmounts(int categoryId, {int limit = 3}) async {
    final query = selectOnly(transactions, distinct: true)
      ..addColumns([transactions.amountMinor])
      ..where(transactions.categoryId.equals(categoryId))
      ..orderBy([OrderingTerm.desc(transactions.spentAt)])
      ..limit(limit);

    final rows = await query.get();
    return rows
        .map((row) => row.read(transactions.amountMinor))
        .whereType<int>()
        .toList();
  }

  // ---------------------------------------------------------------- recurring

  Stream<List<RuleWithCategory>> watchRules() {
    final query = select(recurringRules).join([
      innerJoin(categories, categories.id.equalsExp(recurringRules.categoryId)),
    ])
      ..orderBy([
        OrderingTerm.asc(recurringRules.isActive.not()),
        OrderingTerm.asc(recurringRules.dayOfMonth),
      ]);

    return query.watch().map(
          (rows) => rows
              .map((row) => RuleWithCategory(
                    rule: row.readTable(recurringRules),
                    category: row.readTable(categories),
                  ))
              .toList(),
        );
  }

  Future<List<RecurringRule>> allRules() => select(recurringRules).get();

  Future<List<RecurringOccurrence>> allOccurrences() =>
      select(recurringOccurrences).get();

  Future<List<RecurringRule>> activeRules() =>
      (select(recurringRules)..where((r) => r.isActive.equals(true))).get();

  Future<int> insertRule(RecurringRulesCompanion rule) =>
      into(recurringRules).insert(rule);

  Future<bool> updateRule(RecurringRule rule) =>
      update(recurringRules).replace(rule);

  /// Removes a rule and its unanswered questions, but leaves every transaction
  /// it already produced. Those record money that moved; the rule only said it
  /// was going to.
  Future<void> deleteRule(int ruleId) {
    return transaction(() async {
      await (update(recurringOccurrences)
            ..where((o) => o.ruleId.equals(ruleId)))
          .write(const RecurringOccurrencesCompanion(
        transactionId: Value(null),
      ));
      await (delete(recurringOccurrences)..where((o) => o.ruleId.equals(ruleId)))
          .go();
      await (delete(recurringRules)..where((r) => r.id.equals(ruleId))).go();
    });
  }

  /// The questions waiting for an answer, oldest first.
  Stream<List<PendingOccurrence>> watchPending() {
    final query = select(recurringOccurrences).join([
      innerJoin(recurringRules,
          recurringRules.id.equalsExp(recurringOccurrences.ruleId)),
      innerJoin(categories, categories.id.equalsExp(recurringRules.categoryId)),
    ])
      ..where(recurringOccurrences.status.equalsValue(OccurrenceStatus.pending))
      ..orderBy([OrderingTerm.asc(recurringOccurrences.dueOn)]);

    return query.watch().map(
          (rows) => rows
              .map((row) => PendingOccurrence(
                    occurrence: row.readTable(recurringOccurrences),
                    rule: row.readTable(recurringRules),
                    category: row.readTable(categories),
                  ))
              .toList(),
        );
  }

  /// The dates already generated for a rule, so the catch-up pass knows what
  /// it can skip.
  Future<Set<DateTime>> generatedDatesFor(int ruleId) async {
    final rows = await (select(recurringOccurrences)
          ..where((o) => o.ruleId.equals(ruleId)))
        .get();
    return rows.map((o) => o.dueOn).toSet();
  }

  Future<void> addOccurrences(List<RecurringOccurrencesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      // `insertOrIgnore` leans on the (ruleId, dueOn) unique key: if two
      // catch-up passes overlap, the second one is a no-op instead of a
      // duplicate salary.
      b.insertAllOnConflictUpdate(recurringOccurrences, rows);
    });
  }

  /// Answers "yes": writes the real transaction and links it.
  Future<void> confirmOccurrence(
    RecurringOccurrence occurrence,
    RecurringRule rule,
  ) {
    return transaction(() async {
      final txnId = await into(transactions).insert(
        TransactionsCompanion.insert(
          amountMinor: rule.amountMinor,
          kind: rule.kind,
          categoryId: rule.categoryId,
          note: Value(rule.note),
          // The due date, not today: a salary confirmed three days late still
          // belongs to the day it was expected.
          spentAt: occurrence.dueOn,
        ),
      );
      await (update(recurringOccurrences)
            ..where((o) => o.id.equals(occurrence.id)))
          .write(RecurringOccurrencesCompanion(
        status: const Value(OccurrenceStatus.confirmed),
        transactionId: Value(txnId),
      ));
    });
  }

  /// Answers "no": the question is settled and never asked again.
  Future<void> skipOccurrence(int occurrenceId) {
    return (update(recurringOccurrences)..where((o) => o.id.equals(occurrenceId)))
        .write(const RecurringOccurrencesCompanion(
      status: Value(OccurrenceStatus.skipped),
    ));
  }

  /// The date of the oldest transaction, or null when there are none.
  ///
  /// Bounds how far back the app lets you walk: there is nothing recorded
  /// before it, and arrowing into empty years is a way to get lost, not a
  /// feature.
  Stream<DateTime?> watchFirstTransactionDate() {
    final earliest = transactions.spentAt.min();
    final query = selectOnly(transactions)..addColumns([earliest]);
    return query.watchSingleOrNull().map((row) => row?.read(earliest));
  }

  /// Wipes user data but keeps categories, for Settings.
  Future<void> deleteAllTransactions() => delete(transactions).go();

  /// Every row, oldest first. Used only by the exporter, which wants the whole
  /// history rather than one period.
  Future<List<Txn>> allTransactions() => (select(transactions)
        ..orderBy([(t) => OrderingTerm(expression: t.spentAt)]))
      .get();

  /// Replaces the entire contents of both tables with the contents of a
  /// backup, inside a single transaction.
  ///
  /// All-or-nothing on purpose: a restore that fails halfway would leave the
  /// user with neither their old data nor their new data, which is the worst
  /// outcome an app that holds a year of records can produce. Ids are
  /// preserved so the restored transactions still point at the right
  /// categories.
  Future<void> restoreFrom({
    required List<CategoriesCompanion> categoryRows,
    required List<TransactionsCompanion> txnRows,
    List<RecurringRulesCompanion> ruleRows = const [],
    List<RecurringOccurrencesCompanion> occurrenceRows = const [],
  }) {
    return transaction(() async {
      // Occurrences reference both other tables, so they go first. A restore
      // replaces the whole world; leaving stale questions behind would attach
      // them to transactions that no longer exist.
      await delete(recurringOccurrences).go();
      await delete(recurringRules).go();
      await delete(transactions).go();
      await delete(categories).go();
      await batch((b) {
        // Order matters: rules reference categories, occurrences reference
        // both rules and transactions.
        b.insertAll(categories, categoryRows);
        b.insertAll(transactions, txnRows);
        b.insertAll(recurringRules, ruleRows);
        b.insertAll(recurringOccurrences, occurrenceRows);
      });
    });
  }
}
