/// The period selector that drives every screen.
enum Period { day, week, month }

/// A half-open local-time interval `[from, to)`.
///
/// Half-open matters: a closed range built with `23:59:59` silently drops
/// anything logged in the last second of a day, and comparing against
/// `endOfDay` is the classic off-by-one in reporting code.
class DateRange {
  const DateRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  int get dayCount => to.difference(from).inDays;

  bool contains(DateTime moment) =>
      !moment.isBefore(from) && moment.isBefore(to);

  /// The equivalent window immediately before this one, for "vs. last month".
  DateRange get previous {
    switch (dayCount) {
      case 1:
        return DateRange(_shiftDays(from, -1), from);
      case 7:
        return DateRange(_shiftDays(from, -7), from);
      default:
        // Calendar months differ in length, so step by month, not by days.
        final start = DateTime(from.year, from.month - 1, 1);
        return DateRange(start, from);
    }
  }

  static DateTime _shiftDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Midnight today, in local time.
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The range for [period] containing [anchor] (defaults to now).
  ///
  /// Weeks start Monday, matching Romanian and ISO convention rather than the
  /// US Sunday default that `DateTime.weekday` arithmetic invites.
  static DateRange of(Period period, {DateTime? anchor}) {
    final base = anchor ?? DateTime.now();
    final day = DateTime(base.year, base.month, base.day);

    switch (period) {
      case Period.day:
        return DateRange(day, _shiftDays(day, 1));
      case Period.week:
        final monday = _shiftDays(day, -(day.weekday - DateTime.monday));
        return DateRange(monday, _shiftDays(monday, 7));
      case Period.month:
        final first = DateTime(day.year, day.month, 1);
        return DateRange(first, DateTime(day.year, day.month + 1, 1));
    }
  }

  /// The trailing seven days ending tonight, for the home chart. Distinct from
  /// `Period.week`: this one always has seven bars, even mid-week.
  static DateRange lastSevenDays({DateTime? anchor}) {
    final end = _shiftDays(today(), 1);
    return DateRange(_shiftDays(end, -7), end);
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}
