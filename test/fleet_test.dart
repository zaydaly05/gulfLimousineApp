import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/models/fleet.dart';

void main() {
  test('reads colours and totals', () {
    final car = {
      'colors': [
        {'name': 'Black', 'count': 3},
        {'name': 'White', 'count': 2},
        {'name': '', 'count': 4}, // ignored: no name
        'junk',
      ],
    };
    expect(Fleet.colorsOf(car), const [
      FleetColor(name: 'Black', count: 3),
      FleetColor(name: 'White', count: 2),
    ]);
    expect(Fleet.totalOf(car), 5);
    expect(Fleet.summary(car), '5 cars · Black 3, White 2');
  });

  test('cars saved before colours count as one car', () {
    expect(Fleet.colorsOf({}), isEmpty);
    expect(Fleet.totalOf({}), 1);
    expect(Fleet.summary({}), '');
  });

  test('validation', () {
    expect(Fleet.validate(const [FleetColor(name: 'Black', count: 1)]), isNull);
    expect(
      Fleet.validate(const [
        FleetColor(name: 'Black', count: 1),
        FleetColor(name: 'black', count: 2),
      ]),
      contains('twice'),
    );
    expect(Fleet.validate(const [FleetColor(name: ' ', count: 1)]), isNotNull);
  });
}
