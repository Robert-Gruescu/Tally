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

/// Expense total for a single calendar day, used by the 7-day bar chart.
class DailyTotal {
  const DailyTotal({required this.day, required this.totalMinor});

  final DateTime day;
  final int totalMinor;
}

@DriftDatabase(tables: [Categories, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tally'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          await m.createAll();
          // Reads slow to a crawl without this once a user has a year of data;
          // every screen filters by date range.
          await customStatement(
            'CREATE INDEX idx_transactions_spent_at '
            'ON transactions (spent_at)',
          );
        },
      );

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

  // -------------------------------------------------------------- transactions

  Future<int> insertTxn(TransactionsCompanion txn) =>
      into(transactions).insert(txn);

  Future<bool> updateTxn(Txn txn) => update(transactions).replace(txn);

  Future<int> deleteTxn(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// Transactions in `[from, to)` with their category, newest first.
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
  }) {
    final total = transactions.amountMinor.sum();
    final query = selectOnly(transactions)
      ..addColumns([transactions.kind, total])
      ..where(transactions.spentAt.isBiggerOrEqualValue(from) &
          transactions.spentAt.isSmallerThanValue(to))
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
  }) {
    final total = transactions.amountMinor.sum();
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..addColumns([total])
      ..where(transactions.kind.equalsValue(kind) &
          transactions.spentAt.isBiggerOrEqualValue(from) &
          transactions.spentAt.isSmallerThanValue(to))
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
  }) {
    final query = select(transactions)
      ..where((t) =>
          t.kind.equalsValue(TxKind.expense) &
          t.spentAt.isBiggerOrEqualValue(from) &
          t.spentAt.isSmallerThanValue(to));

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
  }) {
    return transaction(() async {
      await delete(transactions).go();
      await delete(categories).go();
      await batch((b) {
        b.insertAll(categories, categoryRows);
        b.insertAll(transactions, txnRows);
      });
    });
  }
}
