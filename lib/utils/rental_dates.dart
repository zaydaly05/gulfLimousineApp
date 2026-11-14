/// Date arithmetic shared by every booking / rental form.
class RentalDates {
  RentalDates._();

  /// Whole calendar days from [from] to [to], ignoring time of day.
  ///
  /// Computed in UTC so a daylight-saving change between the two dates
  /// (a 23h or 25h "day") cannot shift the result by one.
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
