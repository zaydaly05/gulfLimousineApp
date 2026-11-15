import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/services/review_service.dart';

void main() {
  group('ReviewService.averageRating', () {
    test('uses the fallback when there are no ratings', () {
      expect(ReviewService.averageRating([], fallback: 4), 4);
    });

    test('averages numeric ratings', () {
      expect(ReviewService.averageRating([5, 4, 3], fallback: 1), 4);
    });

    test('counts missing ratings as zero', () {
      expect(ReviewService.averageRating([5, null], fallback: 1), 2.5);
    });
  });
}
