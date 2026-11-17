// End-to-end checks of both endpoints against the Firebase emulators, with
// Paymob's HTTP API stubbed. Run with `npm run test:emulators`; skipped by
// plain `npm test`.
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

const ready = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-gulf-limousine';
const SECRET = 'hmac-test-secret';

Object.assign(process.env, {
  PAYMOB_SECRET_KEY: 'sk_test_x',
  PAYMOB_PUBLIC_KEY: 'pk_test_y',
  PAYMOB_INTEGRATION_IDS: '111, 222',
  PAYMOB_CARD_INTEGRATION_ID: '111',
  PAYMOB_WALLET_INTEGRATION_ID: '222',
  PAYMOB_HMAC_SECRET: SECRET,
  PUBLIC_URL: 'https://pay.example.com',
});

let db, createIntention, webhook, hmacString, idToken, uid;

// Minimal stand-ins for Vercel's req/res.
function call(handler, { method = 'POST', headers = {}, body, query = {} }) {
  return new Promise((resolve) => {
    const res = {
      statusCode: 200, headers: {},
      setHeader(k, v) { this.headers[k] = v; },
      status(code) { this.statusCode = code; return this; },
      json(data) { resolve({ status: this.statusCode, body: data }); },
      send(data) { resolve({ status: this.statusCode, body: data }); },
      end() { resolve({ status: this.statusCode }); },
    };
    handler({ method, headers, body, query }, res);
  });
}

before(async () => {
  if (!ready) return;
  ({ db } = await import('../../lib/firebase.js'));
  ({ default: createIntention } = await import('../../api/create-intention.js'));
  ({ default: webhook } = await import('../../api/paymob-webhook.js'));
  ({ hmacString } = await import('../../lib/paymob.js'));

  const signUp = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: `u${Date.now()}@test.dev`, password: 'secret123', returnSecureToken: true }) },
  ).then((r) => r.json());
  idToken = signUp.idToken;
  uid = signUp.localId;
});

async function seedBooking(id, extra = {}) {
  await db().collection('cars').doc('car1').set({ price_per_day: 1500 });
  await db().collection('bookings').doc(id).set({
    userId: uid, user_email: 'x@test.dev', customerName: 'Omar Hassan', phone: '01012345678',
    car_id: 'car1', carName: 'BMW', days: 3, total_amount: 4500,
    status: 'pending', payment_method: 'paymob', payment_status: 'unpaid', ...extra,
  });
  await db().collection('payments').doc(`p_${id}`).set({ booking_id: id, status: 'unpaid' });
}

function callback(bookingId, overrides = {}) {
  const obj = {
    amount_cents: 450000, created_at: '2026-11-17T10:00:00.000000', currency: 'EGP',
    error_occured: false, has_parent_transaction: false, id: Math.floor(Math.random() * 1e9),
    integration_id: 222, is_3d_secure: false, is_auth: false, is_capture: false,
    is_refunded: false, is_standalone_payment: true, is_voided: false,
    order: { id: 99, merchant_order_id: `${bookingId}_1700000000000` }, owner: 1,
    pending: false, source_data: { pan: '01010101010', sub_type: 'wallet', type: 'wallet' },
    success: true, ...overrides,
  };
  const hmac = crypto.createHmac('sha512', SECRET).update(hmacString(obj)).digest('hex');
  return { obj, hmac };
}

test('create-intention: starts checkout with the server-side amount', { skip: !ready }, async () => {
  await seedBooking('BookingAAAA0001');
  let sent;
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    if (String(url).startsWith('https://accept.paymob.com')) {
      sent = JSON.parse(init.body);
      return new Response(JSON.stringify({ id: 'int_1', client_secret: 'csk_test_abc' }), { status: 201 });
    }
    return realFetch(url, init);
  };
  try {
    const res = await call(createIntention, {
      headers: { authorization: `Bearer ${idToken}` },
      body: { bookingId: 'BookingAAAA0001', amount: 1 }, // client amount is ignored
    });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal(res.body.checkoutUrl, 'https://accept.paymob.com/unifiedcheckout/?publicKey=pk_test_y&clientSecret=csk_test_abc');
    assert.equal(res.body.testMode, true);
    assert.equal(sent.amount, 450000);
    assert.deepEqual(sent.payment_methods, [111, 222]); // no method: every ID
    assert.equal(sent.notification_url, 'https://pay.example.com/api/paymob-webhook');
    assert.match(sent.special_reference, /^BookingAAAA0001_\d+$/);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('create-intention: refuses strangers, bad tokens and paid bookings', { skip: !ready }, async () => {
  await seedBooking('BookingAAAA0002', { userId: 'someone-else' });
  await seedBooking('BookingAAAA0003', { payment_status: 'paid' });
  const auth = { authorization: `Bearer ${idToken}` };
  assert.equal((await call(createIntention, { headers: { authorization: 'Bearer nope' }, body: { bookingId: 'BookingAAAA0001' } })).status, 401);
  assert.equal((await call(createIntention, { headers: auth, body: { bookingId: 'BookingAAAA0002' } })).status, 409);
  assert.equal((await call(createIntention, { headers: auth, body: { bookingId: 'BookingAAAA0003' } })).status, 409);
});

test('webhook: a signed success confirms the booking exactly once', { skip: !ready }, async () => {
  await seedBooking('BookingBBBB0001');
  const { obj, hmac } = callback('BookingBBBB0001');
  const first = await call(webhook, { body: { type: 'TRANSACTION', obj }, query: { hmac } });
  assert.equal(first.status, 200);
  const booking = (await db().collection('bookings').doc('BookingBBBB0001').get()).data();
  assert.equal(booking.payment_status, 'paid');
  assert.equal(booking.status, 'confirmed');
  assert.equal(booking.payment_reference, String(obj.id));
  assert.equal((await db().collection('payments').doc('p_BookingBBBB0001').get()).data().status, 'paid');

  // Paymob retries: same transaction again changes nothing and still 200.
  const again = await call(webhook, { body: { type: 'TRANSACTION', obj }, query: { hmac } });
  assert.equal(again.status, 200);
  const notes = await db().collection('users').doc(uid).collection('notifications')
    .where('bookingId', '==', 'BookingBBBB0001').get();
  assert.equal(notes.size, 1);
});

test('webhook: forged, underpaid and failed callbacks never confirm', { skip: !ready }, async () => {
  await seedBooking('BookingCCCC0001');
  const forged = callback('BookingCCCC0001');
  assert.equal((await call(webhook, { body: { type: 'TRANSACTION', obj: forged.obj }, query: { hmac: 'f'.repeat(128) } })).status, 401);

  const under = callback('BookingCCCC0001', { amount_cents: 100 });
  await call(webhook, { body: { type: 'TRANSACTION', obj: under.obj }, query: { hmac: under.hmac } });
  let booking = (await db().collection('bookings').doc('BookingCCCC0001').get()).data();
  assert.equal(booking.payment_status, 'failed');
  assert.equal(booking.status, 'pending');

  const failed = callback('BookingCCCC0001', { success: false });
  await call(webhook, { body: { type: 'TRANSACTION', obj: failed.obj }, query: { hmac: failed.hmac } });
  booking = (await db().collection('bookings').doc('BookingCCCC0001').get()).data();
  assert.equal(booking.status, 'pending');
});

test('webhook: a late failure never undoes a payment', { skip: !ready }, async () => {
  await seedBooking('BookingDDDD0001', { payment_status: 'paid', status: 'confirmed' });
  const failed = callback('BookingDDDD0001', { success: false });
  await call(webhook, { body: { type: 'TRANSACTION', obj: failed.obj }, query: { hmac: failed.hmac } });
  const booking = (await db().collection('bookings').doc('BookingDDDD0001').get()).data();
  assert.equal(booking.payment_status, 'paid');
});

test('create-intention: "Mobile Wallet" opens Paymob on the wallet only', { skip: !ready }, async () => {
  await seedBooking('BookingWWWW0001');
  let sent;
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    if (String(url).startsWith('https://accept.paymob.com')) {
      sent = JSON.parse(init.body);
      return new Response(JSON.stringify({ id: 'int_2', client_secret: 'csk_test_w' }), { status: 201 });
    }
    return realFetch(url, init);
  };
  try {
    const res = await call(createIntention, {
      headers: { authorization: `Bearer ${idToken}` },
      body: { bookingId: 'BookingWWWW0001', method: 'wallet' },
    });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.deepEqual(sent.payment_methods, [222]);
  } finally {
    globalThis.fetch = realFetch;
  }
});
