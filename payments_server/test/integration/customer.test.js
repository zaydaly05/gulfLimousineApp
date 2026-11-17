// /api/end-trip and /api/pay-ticket against the Firebase emulators.
// Run with `npm run test:emulators`; skipped by plain `npm test`.
import { test, before } from 'node:test';
import assert from 'node:assert/strict';

const ready = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);

let db, endTrip, payTicket, idToken, uid;

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

before(async () => {
  if (!ready) return;
  ({ db } = await import('../../lib/firebase.js'));
  ({ default: endTrip } = await import('../../api/end-trip.js'));
  ({ default: payTicket } = await import('../../api/pay-ticket.js'));
  const r = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: `c${Date.now()}@test.dev`, password: 'secret123', returnSecureToken: true }) },
  ).then((x) => x.json());
  idToken = r.idToken;
  uid = r.localId;
});
const auth = () => ({ authorization: `Bearer ${idToken}` });

async function seedTrip(id, extra = {}) {
  await db().collection('cars').doc('car-trip').set({ name: 'BMW', current_odometer: 1000 });
  await db().collection('bookings').doc(id).set({
    userId: uid, user_email: 'x@test.dev', car_id: 'car-trip', carName: 'BMW',
    days: 2, total_amount: 3000, status: 'confirmed', tripStatus: 'in_progress',
    odometer: { startKm: 1000, startPhotoUrl: 'https://img/start.jpg' }, ...extra,
  });
}

test('end-trip: completes the booking and writes the extra-km bill', { skip: !ready }, async () => {
  await seedTrip('trip1');
  const res = await call(endTrip, { headers: auth(),
    body: { bookingId: 'trip1', endKm: 1300, photoUrl: 'https://img/end.jpg', photoPublicId: 'end' } });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.finalAmount, 3000 + 60 * 5);

  const b = (await db().collection('bookings').doc('trip1').get()).data();
  assert.equal(b.status, 'completed');
  assert.equal(b.tripStatus, 'completed');
  assert.equal(b.odometer.startKm, 1000);
  assert.equal(b.odometer.startPhotoUrl, 'https://img/start.jpg');
  assert.equal(b.odometer.endKm, 1300);
  assert.equal(b.odometer.endCapturedBy, uid);
  assert.deepEqual(b.kmAllowance, { kmPerDay: 120, allowedKm: 240, drivenKm: 300, extraKm: 60,
    extraKmRateEgp: 5, extraKmChargeEgp: 300 });
  assert.equal(b.final_amount, 3300);
  assert.equal(b.extraKmPaymentStatus, 'pending');

  const p = (await db().collection('payments').doc('extra_km_trip1').get()).data();
  assert.equal(p.amount, 300);
  assert.equal(p.method, 'extra_km');
  assert.equal(p.status, 'pending');
  assert.equal(p.userId, uid);
  assert.equal((await db().collection('cars').doc('car-trip').get()).data().current_odometer, 1300);

  const again = await call(endTrip, { headers: auth(), body: { bookingId: 'trip1', endKm: 1400 } });
  assert.equal(again.status, 409);
});

test('end-trip: no extra km means no payment record', { skip: !ready }, async () => {
  await seedTrip('trip2');
  const res = await call(endTrip, { headers: auth(), body: { bookingId: 'trip2', endKm: 1100 } });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.extraKmPaymentStatus, 'not_applicable');
  assert.equal((await db().collection('payments').doc('extra_km_trip2').get()).exists, false);
});

test('end-trip: refuses other customers, unsigned calls and km below pickup', { skip: !ready }, async () => {
  await seedTrip('trip3', { userId: 'someone-else', user_email: 'other@test.dev' });
  assert.equal((await call(endTrip, { headers: auth(), body: { bookingId: 'trip3', endKm: 1100 } })).status, 403);
  assert.equal((await call(endTrip, { body: { bookingId: 'trip3', endKm: 1100 } })).status, 401);
  await seedTrip('trip4');
  assert.equal((await call(endTrip, { headers: auth(), body: { bookingId: 'trip4', endKm: 999 } })).status, 400);
  assert.equal((await db().collection('bookings').doc('trip4').get()).data().status, 'confirmed');
});

async function seedTicket(id, extra = {}) {
  await db().collection('traffic_violations').doc(id).set({
    userId: uid, user_email: 'x@test.dev', rentalId: 'trip1', car_name: 'BMW',
    amount: 450, status: 'pending', ...extra,
  });
}

test('pay-ticket: card marks the ticket paid with one payment record', { skip: !ready }, async () => {
  await seedTicket('t1');
  const res = await call(payTicket, { headers: auth(), body: { violationId: 't1', paymentMethod: 'card' } });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const t = (await db().collection('traffic_violations').doc('t1').get()).data();
  assert.equal(t.status, 'paid');
  assert.equal(t.payment_method, 'card');
  assert.equal(t.paidBy, uid);
  assert.ok(t.paidAt);
  const p = (await db().collection('payments').doc('ticket_t1').get()).data();
  assert.equal(p.amount, 450);
  assert.equal(p.status, 'paid');
  assert.equal(p.violation_id, 't1');
  assert.equal(p.type, 'traffic_violation');

  assert.equal((await call(payTicket, { headers: auth(), body: { violationId: 't1', paymentMethod: 'card' } })).status, 409);
});

test('pay-ticket: cash stays pending, and paying later reuses the record', { skip: !ready }, async () => {
  await seedTicket('t2');
  const cash = await call(payTicket, { headers: auth(), body: { violationId: 't2', paymentMethod: 'cash' } });
  assert.equal(cash.status, 200, JSON.stringify(cash.body));
  assert.equal((await db().collection('traffic_violations').doc('t2').get()).data().status, 'pending');
  assert.equal((await db().collection('payments').doc('ticket_t2').get()).data().status, 'pending');

  const card = await call(payTicket, { headers: auth(), body: { violationId: 't2', paymentMethod: 'wallet' } });
  assert.equal(card.status, 200);
  const records = await db().collection('payments').where('violation_id', '==', 't2').get();
  assert.equal(records.size, 1);
  assert.equal(records.docs[0].data().status, 'paid');
});

test('pay-ticket: refuses someone else\'s ticket', { skip: !ready }, async () => {
  await seedTicket('t3', { userId: 'someone-else', user_email: 'other@test.dev' });
  assert.equal((await call(payTicket, { headers: auth(), body: { violationId: 't3', paymentMethod: 'card' } })).status, 403);
});
