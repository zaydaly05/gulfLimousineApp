import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/utils/rental_dates.dart';

void main() {
  group('RentalDates.calendarDaysBetween', () {
    test('same day is zero', () {
      expect(
        RentalDates.calendarDaysBetween(
          DateTime(2026, 5, 1, 9),
          DateTime(2026, 5, 1, 22),
        ),
        0,
      );
    });

    test('ignores the time of day', () {
      expect(
        RentalDates.calendarDaysBetween(
          DateTime(2026, 5, 1, 23, 59),
          DateTime(2026, 5, 2, 0, 1),
        ),
        1,
      );
    });

    test('counts across month and year boundaries', () {
      expect(
        RentalDates.calendarDaysBetween(
          DateTime(2026, 12, 30),
          DateTime(2027, 1, 2),
        ),
        3,
      );
    });

    test('a daylight-saving week is still seven days', () {
      // Egypt switches to summer time on the last Friday of April.
      expect(
        RentalDates.calendarDaysBetween(
          DateTime(2026, 4, 20),
          DateTime(2026, 4, 27),
        ),
        7,
      );
    });
  });
}
