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

  /// Billable rental days. Both the pickup and the return day count, so a
  /// same-day rental is 1 day and 1 → 3 May is 3 days. Never less than 1.
  /// Used by every booking form (customer checkout and admin screens).
  static int rentalDays(DateTime pickup, DateTime returnDate) {
    final days = calendarDaysBetween(pickup, returnDate) + 1;
    return days < 1 ? 1 : days;
  }

  /// Return date for a rental of [days] billable days starting on [pickup].
  static DateTime returnDateFor(DateTime pickup, int days) =>
      DateTime(pickup.year, pickup.month, pickup.day + days - 1);
}
