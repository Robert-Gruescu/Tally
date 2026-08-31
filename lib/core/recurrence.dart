/// Date arithmetic for monthly recurring rules.
///
/// Kept free of the database and of Flutter so the rules that decide *when*
/// money is expected can be tested on their own. Every subtle bug in a
/// recurring feature lives in this file: the 31st of a month that has 30 days,
/// the month boundary, the catch-up after the app has not been opened.
class Recurrence {
  const Recurrence._();

  /// Days a user may choose. 29, 30 and 31 are allowed and clamped per month
  /// rather than forbidden, because "the last day" and "the 31st" are how
  /// people actually describe a salary date.
  static const minDay = 1;
  static const maxDay = 31;

  /// The number of days in [month] of [year], leap years included.
  ///
  /// Derived by stepping to the first of the next month and back one day,
  /// which is correct without a table of month lengths or a leap-year rule.
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// The date a rule falls due in one specific month.
  ///
  /// A rule set to the 31st is due on the 28th of February, the 30th of April
  /// and the 31st of May. Clamping down rather than spilling into the next
  /// month keeps one occurrence per month, which is the whole point of a
  /// monthly rule.
  static DateTime dueDateIn(int year, int month, int dayOfMonth) {
    final day = dayOfMonth.clamp(minDay, daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  /// Every date on which a rule was due in `[start, through]`, oldest first.
  ///
  /// Used to catch up: if the app has not been opened since March, opening it
  /// in June must produce March, April, May and June, not just June. Dates are
  /// local midnights, matching how the rest of the app buckets days.
  static List<DateTime> dueDatesBetween({
    required int dayOfMonth,
    required DateTime start,
    required DateTime through,
  }) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(through.year, through.month, through.day);
    if (to.isBefore(from)) return const [];

    final dates = <DateTime>[];
    var year = from.year;
    var month = from.month;

    // Walks month by month rather than day by day: a five-year gap costs sixty
    // iterations instead of eighteen hundred.
    while (true) {
      final due = dueDateIn(year, month, dayOfMonth);
      if (due.isAfter(to)) break;
      if (!due.isBefore(from)) dates.add(due);

      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
      // A rule cannot outrun its window; this only guards against a caller
      // passing a `through` far in the future by mistake.
      if (dates.length > 600) break;
    }

    return dates;
  }

  /// A short human label for a day of the month, in Romanian.
  ///
  /// Says "ultima zi" for 31 rather than the literal number, because that is
  /// what the rule actually does in a month with fewer days.
  static String dayLabel(int dayOfMonth) =>
      dayOfMonth >= maxDay ? 'ultima zi' : 'ziua $dayOfMonth';
}
