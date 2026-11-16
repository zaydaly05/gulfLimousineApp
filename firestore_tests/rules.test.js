// Security-rules tests for ../firestore.rules. Run with `npm test`, which
// starts the Firestore emulator (needs Java) and runs these with node:test.
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, addDoc, collection } from 'firebase/firestore';

let env;

const BOOKING = 'bookings/b1';
const base = { userId: 'u1', status: 'confirmed', total_amount: 1000, tripStatus: 'in_progress' };
// What the app writes when a customer records the return odometer.
const finalize = {
  odometer: { startKm: 0, endKm: 150 },
  kmAllowance: { extraKm: 30, extraKmChargeEgp: 150 },
  final_amount: 1150,
  extraKmPaymentStatus: 'pending',
  status: 'completed',
  tripStatus: 'completed',
  updatedAt: 1,
};

const customer = () => env.authenticatedContext('u1', { email: 'u1@example.com' }).firestore();
const stranger = () => env.authenticatedContext('u2', { email: 'u2@example.com' }).firestore();
const seed = (path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-gulf-limousine',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await seed('users/u1', { role: 'user' });
  await seed('users/u2', { role: 'user' });
});

// --- users: no self-promotion to admin ---
test('a user cannot make themselves admin', async () => {
  await assertFails(updateDoc(doc(customer(), 'users/u1'), { role: 'admin' }));
});
test('a user can update their own profile fields', async () => {
  await assertSucceeds(updateDoc(doc(customer(), 'users/u1'), { name: 'Ali' }));
});
test('a new user cannot create their profile as admin', async () => {
  const db = env.authenticatedContext('u3').firestore();
  await assertFails(setDoc(doc(db, 'users/u3'), { role: 'admin' }));
  await assertSucceeds(setDoc(doc(db, 'users/u3'), { role: 'user' }));
});

// --- bookings: ownership ---
test('a user cannot create a booking for someone else', async () => {
  await assertFails(addDoc(collection(stranger(), 'bookings'), { userId: 'u1' }));
});
test('a customer cannot delete their booking', async () => {
  await seed(BOOKING, base);
  await assertFails(deleteDoc(doc(customer(), BOOKING)));
});
test('another user cannot update a booking', async () => {
  await seed(BOOKING, base);
  await assertFails(updateDoc(doc(stranger(), BOOKING), { status: 'cancelled' }));
});

// --- bookings: engine lock and billing fields ---
test('a customer cannot clear the remote engine lock', async () => {
  await seed(BOOKING, { ...base, security: { isImmobilized: true } });
  await assertFails(updateDoc(doc(customer(), BOOKING), { security: { isImmobilized: false } }));
});
test('a customer can cancel', async () => {
  await seed(BOOKING, base);
  await assertSucceeds(
    updateDoc(doc(customer(), BOOKING), { status: 'cancelled', tripStatus: 'cancelled', cancelledAt: 1 }),
  );
});
test('a customer cannot set an arbitrary status', async () => {
  await seed(BOOKING, base);
  await assertFails(updateDoc(doc(customer(), BOOKING), { status: 'confirmed2' }));
});
test('a customer can record the return km as the app does', async () => {
  await seed(BOOKING, base);
  await assertSucceeds(updateDoc(doc(customer(), BOOKING), finalize));
});
test('a customer cannot under-report the final amount', async () => {
  await seed(BOOKING, base);
  await assertFails(updateDoc(doc(customer(), BOOKING), { ...finalize, final_amount: 1000 }));
});
test('a customer cannot mark their extra-km charge paid', async () => {
  await seed(BOOKING, base);
  await assertFails(updateDoc(doc(customer(), BOOKING), { ...finalize, extraKmPaymentStatus: 'paid' }));
  await seed(BOOKING, { ...base, ...finalize });
  await assertFails(updateDoc(doc(customer(), BOOKING), { extraKmPaymentStatus: 'paid' }));
});
test('a customer cannot change the final amount later', async () => {
  await seed(BOOKING, { ...base, ...finalize });
  await assertFails(updateDoc(doc(customer(), BOOKING), { final_amount: 1000 }));
});
test('a customer can submit a review flag', async () => {
  await seed(BOOKING, { ...base, status: 'completed' });
  await assertSucceeds(updateDoc(doc(customer(), BOOKING), { reviewed: true, rating: 5 }));
});

// --- payments ---
test('a user cannot create a payment for someone else', async () => {
  await assertFails(addDoc(collection(stranger(), 'payments'), { userId: 'u1', status: 'paid' }));
});
