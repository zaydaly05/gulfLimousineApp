import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  bookingIdFromReference, integrationIdsFor, payableProblem, specialReferenceFor, splitName, toCents,
} from '../lib/booking.js';

const booking = {
  userId: 'u1', payment_method: 'paymob', status: 'pending',
  payment_status: 'unpaid', total_amount: 4500, days: 3, car_id: 'c1',
};
const car = { price_per_day: 1500 };

test('an unpaid online booking of the caller is payable', () => {
  assert.equal(payableProblem(booking, 'u1', car), null);
  assert.equal(payableProblem({ ...booking, payment_status: 'failed' }, 'u1', car), null);
});

test('everything else is refused', () => {
  assert.match(payableProblem(undefined, 'u1', car), /not found/);
  assert.match(payableProblem(booking, 'u2', car), /another account/);
  assert.match(payableProblem({ ...booking, payment_method: 'cash' }, 'u1', car), /not an online/);
  assert.match(payableProblem({ ...booking, status: 'cancelled' }, 'u1', car), /no longer/);
  assert.match(payableProblem({ ...booking, payment_status: 'paid' }, 'u1', car), /already/);
  assert.match(payableProblem({ ...booking, total_amount: 0 }, 'u1', car), /no amount/);
});

test('a booking cheaper than the car\'s price is refused', () => {
  assert.match(payableProblem({ ...booking, total_amount: 100 }, 'u1', car), /price has changed/);
  assert.equal(payableProblem({ ...booking, total_amount: 100 }, 'u1', null) === null, true);
});

test('references round-trip to the booking id', () => {
  const ref = specialReferenceFor('AbCdEf1234567890', 1700000000000);
  assert.equal(ref, 'AbCdEf1234567890_1700000000000');
  assert.equal(bookingIdFromReference(ref), 'AbCdEf1234567890');
  assert.equal(bookingIdFromReference('../users_1'), null);
  assert.equal(bookingIdFromReference(undefined), null);
});

test('amounts and names are converted for Paymob', () => {
  assert.equal(toCents(19.99), 1999);
  assert.equal(toCents(4500), 450000);
  assert.deepEqual(splitName('Omar Hassan Ali'), { firstName: 'Omar', lastName: 'Hassan Ali' });
  assert.deepEqual(splitName('Omar'), { firstName: 'Omar', lastName: 'NA' });
  assert.deepEqual(splitName(''), { firstName: 'Customer', lastName: 'NA' });
});

test('checkout offers only the chosen method when its ID is configured', () => {
  const env = { PAYMOB_INTEGRATION_IDS: '111, 222', PAYMOB_CARD_INTEGRATION_ID: '111', PAYMOB_WALLET_INTEGRATION_ID: ' 222 ' };
  assert.deepEqual(integrationIdsFor('card', env), [111]);
  assert.deepEqual(integrationIdsFor('wallet', env), [222]);
  assert.deepEqual(integrationIdsFor(null, env), [111, 222]);
  // Not configured (or malformed): fall back to every ID.
  assert.deepEqual(integrationIdsFor('wallet', { PAYMOB_INTEGRATION_IDS: '111,222' }), [111, 222]);
  assert.deepEqual(integrationIdsFor('card', { PAYMOB_INTEGRATION_IDS: '111', PAYMOB_CARD_INTEGRATION_ID: 'abc' }), [111]);
});

test('the expected price includes how many cars were booked', () => {
  assert.equal(payableProblem({ ...booking, quantity: 2, total_amount: 9000 }, 'u1', car), null);
  assert.match(payableProblem({ ...booking, quantity: 2, total_amount: 4500 }, 'u1', car), /price has changed/);
});
