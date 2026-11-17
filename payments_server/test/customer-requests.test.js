import { test } from 'node:test';
import assert from 'node:assert/strict';
import { billableDays, kmBill } from '../lib/km-billing.js';
import {
  checkEndTrip, checkPayTicket, ownedBy, parseEndTrip, parsePayTicket,
} from '../lib/customer-requests.js';

const who = { uid: 'u1', email: 'Omar@Test.dev' };

test('km bill matches the app: 120 km/day included, 5 EGP per extra km', () => {
  assert.deepEqual(kmBill(1000, 1400, 3), {
    kmPerDay: 120, allowedKm: 360, drivenKm: 400, extraKm: 40,
    extraKmRateEgp: 5, extraKmChargeEgp: 200,
  });
  assert.equal(kmBill(1000, 1100, 1).extraKm, 0);
  assert.equal(kmBill(0, 0, 1).extraKmChargeEgp, 0);
});

test('billable days are whole and clamped like the rules', () => {
  assert.equal(billableDays(undefined), 1);
  assert.equal(billableDays('3'), 1);
  assert.equal(billableDays(0), 1);
  assert.equal(billableDays(2.9), 2);
  assert.equal(billableDays(99999), 3650);
});

test('ownership by uid or case-insensitive email', () => {
  assert.ok(ownedBy({ userId: 'u1' }, who));
  assert.ok(ownedBy({ user_email: 'omar@test.dev' }, who));
  assert.ok(!ownedBy({ userId: 'u2', user_email: 'x@test.dev' }, who));
  assert.ok(!ownedBy({ user_email: '' }, { uid: 'u1', email: '' }));
});

test('end-trip request parsing', () => {
  assert.equal(parseEndTrip({ bookingId: 'b1', endKm: 10 }).endKm, 10);
  assert.ok(parseEndTrip({ bookingId: 'b1', endKm: 10.5 }).error);
  assert.ok(parseEndTrip({ bookingId: 'b1', endKm: '10' }).error);
  assert.ok(parseEndTrip({ bookingId: 'b/1', endKm: 10 }).error);
  assert.ok(parseEndTrip({ bookingId: 'b1', endKm: 10, photoUrl: 'http://x' }).error);
  assert.ok(parseEndTrip(null).error);
});

test('end-trip checks', () => {
  const started = { userId: 'u1', status: 'confirmed', odometer: { startKm: 500 } };
  assert.deepEqual(checkEndTrip(started, who, 600), { startKm: 500 });
  assert.equal(checkEndTrip(null, who, 600).status, 404);
  assert.equal(checkEndTrip({ ...started, userId: 'u2' }, who, 600).status, 403);
  assert.equal(checkEndTrip({ ...started, odometer: null }, who, 600).status, 409);
  assert.equal(checkEndTrip({ ...started, odometer: { startKm: 500, endKm: 600 } }, who, 700).status, 409);
  assert.equal(checkEndTrip({ ...started, status: 'cancelled' }, who, 600).status, 409);
  assert.equal(checkEndTrip(started, who, 499).status, 400);
});

test('pay-ticket parsing: cash stays pending, other methods are paid', () => {
  assert.deepEqual(parsePayTicket({ violationId: 'v1', paymentMethod: 'cash' }),
    { violationId: 'v1', paymentMethod: 'cash', paid: false });
  assert.equal(parsePayTicket({ violationId: 'v1', paymentMethod: 'card' }).paid, true);
  assert.ok(parsePayTicket({ violationId: 'v1', paymentMethod: 'bitcoin' }).error);
  assert.ok(parsePayTicket({ paymentMethod: 'card' }).error);
});

test('pay-ticket checks', () => {
  assert.deepEqual(checkPayTicket({ userId: 'u1', status: 'pending', amount: 300 }, who), { amount: 300 });
  assert.equal(checkPayTicket({ userId: 'u1', status: 'paid', amount: 300 }, who).status, 409);
  assert.equal(checkPayTicket({ userId: 'u2', status: 'pending' }, who).status, 403);
  assert.equal(checkPayTicket(null, who).status, 404);
});
