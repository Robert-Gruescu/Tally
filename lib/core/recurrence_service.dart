import 'db/database.dart';
import 'recurrence.dart';

/// Turns rules into questions.
///
/// Runs when the app starts and every time it comes back to the foreground.
/// Deliberately not a background job: no alarm, no `WorkManager`, no wake-up
/// permission, no battery cost. The trade is that a rule due on the 5th is
/// noticed the next time the app is opened rather than at midnight, which for
/// a ledger nobody reads at midnight is not a trade at all.
///
/// It is safe to call at any time and as often as needed: the work is
/// idempotent, guarded by the `(ruleId, dueOn)` unique key.
class RecurrenceService {
  const RecurrenceService._();

  /// Creates the missing pending occurrences and returns how many were added.
  ///
  /// [now] exists for tests; production always passes the real clock.
  static Future<int> materialize(AppDatabase db, {DateTime? now}) async {
    final today = _midnight(now ?? DateTime.now());
    final rules = await db.activeRules();
    var created = 0;

    for (final rule in rules) {
      // Catch-up: every date the rule was due between its start and today,
      // not just this month. Someone who last opened the app in March and
      // opens it in June is asked about March, April, May and June.
      final due = Recurrence.dueDatesBetween(
        dayOfMonth: rule.dayOfMonth,
        start: rule.startsOn,
        through: today,
      );
      if (due.isEmpty) continue;

      final already = await db.generatedDatesFor(rule.id);
      final missing = [
        for (final date in due)
          if (!already.contains(date))
            RecurringOccurrencesCompanion.insert(
              ruleId: rule.id,
              dueOn: date,
              status: OccurrenceStatus.pending,
            ),
      ];

      await db.addOccurrences(missing);
      created += missing.length;
    }

    return created;
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}
