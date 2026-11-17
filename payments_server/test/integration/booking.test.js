// /api/availability and /api/book against the Firebase emulators.
// Run with `npm run test:emulators`; skipped by plain `npm test`.
import { test, before } from 'node:test';
import assert from 'node:assert/strict';

const ready = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);
delete process.env.PAYMOB_SECRET_KEY; // demo mode unless a test sets it

let db, book, availability, idToken, uid;

function call(handler, { headers = {}, body }) {
  return new Promise((resolve) => {
    const res = {
      statusCode: 200,
      setHeader() {},
      status(code) { this.statusCode = code; return this; },
      json(data) { resolve({ status: this.statusCode, body: data }); },
      end() { resolve({ status: this.statusCode }); },
    };
    handler({ method: 'POST', headers, body, query: {} }, res);
  });
}

const day = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const request = (extra = {}) => ({
  carId: 'fortuner', pickupDay: day(10), returnDay: day(12), quantity: 2,
  colorPreferences: ['White', 'Black'],
  pickupLocation: { lat: 30.05, lng: 31.24, address: 'Tahrir' },
  dropoffLocation: { lat: 30.0, lng: 31.2, address: 'Giza' },
  signatureUrl: 'https://res.cloudinary.com/delnnzcph/image/upload/sig.png',
  paymentMethod: 'cash', ...extra,
});

before(async () => {
  if (!ready) return;
  ({ db } = await import('../../lib/firebase.js'));
  ({ default: book } = await import('../../api/book.js'));
  ({ default: availability } = await import('../../api/availability.js'));
  const r = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: `b${Date.now()}@test.dev`, password: 'secret123', returnSecureToken: true }) },
  ).then((x) => x.json());
  idToken = r.idToken;
  uid = r.localId;
  await db().collection('users').doc(uid).set({ name: 'Omar Hassan', phone: '01012345678' });
});

async function resetFleet(colors = [{ name: 'Black', count: 3 }, { name: 'White', count: 2 }]) {
  const old = await db().collection('bookings').where('car_id', '==', 'fortuner').get();
  await Promise.all(old.docs.map((d) => d.ref.delete()));
  await db().collection('cars').doc('fortuner').set({ name: 'Fortuner', brand: 'Toyota', price_per_day: 1350, colors });
  await db().collection('config').doc('payments').set({});
}
const auth = () => ({ authorization: `Bearer ${idToken}` });

test('book: assigns colours by priority and prices on the server', { skip: !ready }, async () => {
  await resetFleet();
  const res = await call(book, { headers: auth(), body: request({ quantity: 3, colorPreferences: ['White'] }) });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.deepEqual(res.body.allocatedColors, [{ name: 'White', count: 2 }, { name: 'Black', count: 1 }]);
  const b = (await db().collection('bookings').doc(res.body.bookingId).get()).data();
  assert.equal(b.total_amount, 1350 * 3 * 3);
  assert.equal(b.quantity, 3);
  assert.equal(b.userId, uid);
  assert.equal(b.payment_status, 'pending');
  const p = await db().collection('payments').where('booking_id', '==', res.body.bookingId).get();
  assert.equal(p.size, 1);
});

test('availability reflects existing bookings for overlapping dates only', { skip: !ready }, async () => {
  await resetFleet();
  await call(book, { headers: auth(), body: request({ quantity: 2, colorPreferences: ['Black'] }) });
  const same = await call(availability, { headers: auth(), body: { carId: 'fortuner', pickupDay: day(11), returnDay: day(11) } });
  assert.equal(same.status, 200);
  assert.deepEqual(same.body.colors, [{ name: 'Black', total: 3, available: 1 }, { name: 'White', total: 2, available: 2 }]);
  assert.equal(same.body.totalAvailable, 3);
  const later = await call(availability, { headers: auth(), body: { carId: 'fortuner', pickupDay: day(20), returnDay: day(21) } });
  assert.equal(later.body.totalAvailable, 5);
});

test('book: refuses more cars than are free, and disabled payment methods', { skip: !ready }, async () => {
  await resetFleet([{ name: 'Black', count: 1 }]);
  const tooMany = await call(book, { headers: auth(), body: request({ quantity: 2 }) });
  assert.equal(tooMany.status, 409);
  assert.match(tooMany.body.error, /Only 1 car is free/);
  await db().collection('config').doc('payments').set({ methods: { cash: false } });
  const off = await call(book, { headers: auth(), body: request({ quantity: 1 }) });
  assert.equal(off.status, 409);
  assert.match(off.body.error, /not available/);
});

test('book: two customers racing for the last car, only one gets it', { skip: !ready }, async () => {
  await resetFleet([{ name: 'Black', count: 1 }]);
  const [a, b] = await Promise.all([
    call(book, { headers: auth(), body: request({ quantity: 1 }) }),
    call(book, { headers: auth(), body: request({ quantity: 1 }) }),
  ]);
  assert.deepEqual([a.status, b.status].sort(), [200, 409]);
  const held = await db().collection('bookings').where('car_id', '==', 'fortuner').get();
  assert.equal(held.size, 1);
});

test('book: signed-out callers are refused', { skip: !ready }, async () => {
  const res = await call(book, { headers: {}, body: request() });
  assert.equal(res.status, 401);
});
