import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  addDays, allocate, availability, bookingSpan, cairoDay, cairoMidnight,
  fleetColors, holdsCars, isDay, overlaps, rentalDays, stillAvailable,
} from '../lib/fleet.js';

const car = { colors: [{ name: 'Black', count: 3 }, { name: 'White', count: 2 }] };
const span = { start: '2026-11-17', end: '2026-11-27' };
const booked = (extra) => ({ id: 'x', status: 'confirmed', pickupDay: '2026-11-20', returnDay: '2026-11-22', ...extra });

test('days', () => {
  assert.equal(isDay('2026-02-29'), false);
  assert.equal(isDay('2028-02-29'), true);
  assert.equal(rentalDays('2026-11-17', '2026-11-27'), 11); // both ends count
  assert.equal(rentalDays('2026-11-17', '2026-11-17'), 1);
  assert.equal(addDays('2026-12-31', 1), '2027-01-01');
  assert.equal(overlaps({ start: '2026-11-01', end: '2026-11-17' }, span), true); // shared day
  assert.equal(overlaps({ start: '2026-11-28', end: '2026-11-30' }, span), false);
});

test('Cairo days and midnights', () => {
  assert.equal(cairoDay(new Date('2026-11-16T22:30:00Z')), '2026-11-17'); // UTC+2 in winter
  assert.equal(cairoDay(cairoMidnight('2026-11-17')), '2026-11-17');
  assert.equal(cairoDay(cairoMidnight('2026-07-01')), '2026-07-01'); // summer time
});

test('legacy bookings: span from timestamps', () => {
  const ts = (iso) => ({ toDate: () => new Date(iso) });
  assert.deepEqual(
    bookingSpan({ pickupDate: ts('2026-11-16T22:00:00Z'), returnDate: ts('2026-11-18T22:00:00Z') }),
    { start: '2026-11-17', end: '2026-11-19' },
  );
  assert.deepEqual(bookingSpan({ startDate: ts('2026-11-16T22:00:00Z'), days: 3 }), { start: '2026-11-17', end: '2026-11-19' });
});

test('which bookings hold cars', () => {
  const now = new Date('2026-11-17T12:00:00Z');
  const fresh = { toDate: () => new Date('2026-11-17T11:50:00Z') };
  const stale = { toDate: () => new Date('2026-11-17T10:00:00Z') };
  assert.equal(holdsCars(booked({}), now), true);
  assert.equal(holdsCars(booked({ status: 'cancelled' }), now), false);
  assert.equal(holdsCars(booked({ status: 'completed' }), now), false);
  assert.equal(holdsCars(booked({ payment_status: 'rejected', status: 'pending' }), now), false);
  assert.equal(holdsCars(booked({ status: 'pending', payment_status: 'unpaid', createdAt: fresh }), now), true);
  assert.equal(holdsCars(booked({ status: 'pending', payment_status: 'unpaid', createdAt: stale }), now), false);
});

test('fleet colours', () => {
  assert.deepEqual(fleetColors(car), car.colors);
  assert.deepEqual(fleetColors({}), [{ name: '', count: 1 }]); // saved before colours
  assert.deepEqual(fleetColors({ ...car, available: false }), []);
});

test('availability subtracts overlapping bookings per colour', () => {
  const a = availability(car, [
    booked({ allocatedColors: [{ name: 'Black', count: 2 }] }),
    booked({ id: 'y', pickupDay: '2026-12-01', returnDay: '2026-12-02', allocatedColors: [{ name: 'White', count: 2 }] }), // other dates
    booked({ id: 'z', status: 'cancelled', allocatedColors: [{ name: 'White', count: 2 }] }),
  ], span);
  assert.deepEqual(a.colors, [
    { name: 'Black', total: 3, available: 1 },
    { name: 'White', total: 2, available: 2 },
  ]);
  assert.equal(a.totalAvailable, 3);
});

test('older bookings without colours reduce the total', () => {
  const a = availability(car, [booked({ quantity: 4 })], span);
  assert.equal(a.totalAvailable, 1);
  assert.equal(availability(car, [booked({})], span, { excludeId: 'x' }).totalAvailable, 5);
});

test('allocation follows the customer\'s colour priority, then whatever is free', () => {
  const a = { colors: [{ name: 'Black', available: 1 }, { name: 'White', available: 2 }, { name: 'Silver', available: 1 }], totalAvailable: 4 };
  assert.deepEqual(allocate(a, ['White', 'Black'], 2), [{ name: 'White', count: 2 }]);
  assert.deepEqual(allocate(a, ['Black', 'White'], 3), [{ name: 'Black', count: 1 }, { name: 'White', count: 2 }]);
  assert.deepEqual(allocate(a, ['Black'], 3), [{ name: 'Black', count: 1 }, { name: 'White', count: 2 }]);
  assert.deepEqual(allocate(a, ['Gold'], 1), [{ name: 'Black', count: 1 }]); // unknown preference ignored
  assert.equal(allocate(a, [], 5), null);
  assert.equal(allocate(a, [], 0), null);
  assert.equal(allocate({ ...a, totalAvailable: 2 }, [], 3), null); // capped by total
});

test('a lapsed hold is re-checked against newer bookings', () => {
  const mine = booked({ id: 'mine', status: 'pending', payment_status: 'unpaid', quantity: 2, allocatedColors: [{ name: 'White', count: 2 }] });
  assert.equal(stillAvailable(car, [mine], mine), true);
  const taken = booked({ id: 'other', allocatedColors: [{ name: 'White', count: 1 }] });
  assert.equal(stillAvailable(car, [mine, taken], mine), false);
});
