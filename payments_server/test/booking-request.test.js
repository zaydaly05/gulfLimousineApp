import { test } from 'node:test';
import assert from 'node:assert/strict';
import { enabledMethods, parseBookRequest, switchFor } from '../lib/booking-request.js';

const now = new Date('2026-11-17T10:00:00Z');
const base = {
  carId: 'car1', pickupDay: '2026-11-20', returnDay: '2026-11-22', quantity: 2,
  colorPreferences: ['White', 'Black', 'White', ''],
  pickupLocation: { lat: 30.05, lng: 31.24, address: 'Tahrir' },
  dropoffLocation: { lat: 30.0, lng: 31.2, address: 'Giza' },
  signatureUrl: 'https://res.cloudinary.com/delnnzcph/image/upload/sig.png',
  paymentMethod: 'cash',
};
const parse = (extra, paymobConfigured = true) => parseBookRequest({ ...base, ...extra }, { now, paymobConfigured });

test('a valid request is normalised', () => {
  const r = parse({});
  assert.equal(r.error, undefined);
  assert.equal(r.days, 3);
  assert.deepEqual(r.colorPreferences, ['White', 'Black']);
  assert.equal(r.status, 'pending');
  assert.equal(r.paymentStatus, 'pending');
  assert.equal(r.switchKey, 'cash');
});

test('payment states per method', () => {
  const t = parse({ paymentMethod: 'instapay', reference: '123456789012', payerPhone: '+20 101 234 5678' });
  assert.equal(t.paymentStatus, 'awaiting_verification');
  assert.equal(t.payerPhone, '01012345678');
  const w = parse({ paymentMethod: 'paymob', paymobMethod: 'wallet' });
  assert.deepEqual([w.status, w.paymentStatus, w.paymobMethod, w.switchKey], ['pending', 'unpaid', 'wallet', 'walletOnline']);
  // With Paymob set up, "card" is never the demo card that counts as paid.
  const c = parse({ paymentMethod: 'card' });
  assert.deepEqual([c.paymentMethod, c.paymentStatus, c.switchKey], ['paymob', 'unpaid', 'card']);
  const demo = parse({ paymentMethod: 'card' }, false);
  assert.deepEqual([demo.status, demo.paymentStatus], ['confirmed', 'paid']);
  assert.match(parse({ paymentMethod: 'paymob' }, false).error, /not set up/);
});

test('the app\'s checkbox agreement is accepted', () => {
  const r = parse({ signatureUrl: 'digital_signature_accepted' });
  assert.equal(r.error, undefined);
  assert.equal(r.signatureUrl, 'digital_signature_accepted');
});

test('bad requests are refused', () => {
  assert.match(parse({ pickupDay: '2026-11-10' }).error, /passed/);
  assert.match(parse({ returnDay: '2026-11-19' }).error, /after pickup/);
  assert.match(parse({ returnDay: '2028-01-01' }).error, /year ahead/);
  assert.match(parse({ quantity: 0 }).error, /1 to/);
  assert.match(parse({ quantity: 21 }).error, /1 to/);
  assert.match(parse({ pickupLocation: null }).error, /locations/);
  assert.match(parse({ signatureUrl: 'https://evil.example/sig.png' }).error, /agreement/);
  assert.match(parse({ signatureUrl: '' }).error, /agreement/);
  assert.match(parse({ signatureUrl: 'accepted' }).error, /agreement/);
  assert.match(parse({ paymentMethod: 'instapay', reference: '12', payerPhone: '01012345678' }).error, /transaction/);
  assert.match(parse({ paymentMethod: 'wallet', reference: '123456789', payerPhone: '0223456789' }).error, /mobile/);
  assert.match(parse({ paymentMethod: 'bitcoin' }).error, /payment method/);
});

test('admin switches default to on', () => {
  assert.deepEqual(enabledMethods(undefined), { card: true, walletOnline: true, walletTransfer: true, instapay: true, cash: true });
  assert.equal(enabledMethods({ methods: { cash: false } }).cash, false);
  assert.equal(switchFor('wallet'), 'walletTransfer');
  assert.equal(switchFor('paymob', 'card'), 'card');
});
