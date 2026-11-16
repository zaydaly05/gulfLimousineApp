// Security-rules tests for ../firestore.rules. Run with `npm test`, which
// starts the Firestore emulator (needs Java) and runs these with node:test.
//
// Each "app ..." test replays a write the Flutter app really makes, so a
// rule that is too strict fails here before it breaks the app.
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  addDoc,
  getDoc,
  collection,
  serverTimestamp,
} from 'firebase/firestore';

let env;

const BOOKING = 'bookings/b1';
const EMAIL = 'u1@example.com';
const base = {
  userId: 'u1',
  user_email: EMAIL,
  status: 'confirmed',
  total_amount: 1000,
  days: 1,
  tripStatus: 'assigned',
};
const started = { ...base, tripStatus: 'in_progress', odometer: { startKm: 1000 } };
// What BookingService.recordEndKmAndFinalize writes for 150 km in 1 day:
// 120 km included, 30 extra x 5 EGP = 150 EGP.
const finalize = {
  odometer: { startKm: 1000, endKm: 1150 },
  kmAllowance: {
    kmPerDay: 120,
    allowedKm: 120,
    drivenKm: 150,
    extraKm: 30,
    extraKmRateEgp: 5,
    extraKmChargeEgp: 150,
  },
  final_amount: 1150,
  extraKmPaymentStatus: 'pending',
  status: 'completed',
  tripStatus: 'completed',
};
// Each real write also stamps updatedAt with the server time.
const finalizeWrite = () => ({ ...finalize, updatedAt: serverTimestamp() });

const customer = () =>
  env.authenticatedContext('u1', { email: EMAIL }).firestore();
const stranger = () =>
  env.authenticatedContext('u2', { email: 'u2@example.com' }).firestore();
const admin = () =>
  env.authenticatedContext('admin', { email: 'a@example.com' }).firestore();
const seed = (path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-gulf-limousine',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await seed('users/u1', { role: 'user', email: EMAIL });
  await seed('users/u2', { role: 'user', email: 'u2@example.com' });
  await seed('users/admin', { role: 'admin' });
});

// ---------------------------------------------------------------- users
test('a user cannot make themselves admin', async () => {
  await assertFails(updateDoc(doc(customer(), 'users/u1'), { role: 'admin' }));
});
test('app: a user updates their own profile fields', async () => {
  await assertSucceeds(updateDoc(doc(customer(), 'users/u1'), { name: 'Ali', phone: '010' }));
});
test('a new user cannot create their profile as admin', async () => {
  const db = env.authenticatedContext('u3', { email: 'u3@example.com' }).firestore();
  await assertFails(setDoc(doc(db, 'users/u3'), { role: 'admin' }));
});
test('app: email sign-up profile (email case may differ)', async () => {
  const db = env.authenticatedContext('u3', { email: 'u3@example.com' }).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'users/u3'), {
      name: 'New',
      email: 'U3@Example.com',
      phone: '',
      role: 'user',
      auth_provider: 'email',
      profile_completed: false,
      created_at: serverTimestamp(),
    }),
  );
});
test('a user cannot set their profile email to someone else', async () => {
  await assertFails(updateDoc(doc(customer(), 'users/u1'), { email: 'victim@example.com' }));
});
test('a user cannot mark the profile complete without ID photos', async () => {
  await assertFails(updateDoc(doc(customer(), 'users/u1'), { profile_completed: true }));
});
test('app: complete profile with ID photos', async () => {
  await assertSucceeds(
    setDoc(
      doc(customer(), 'users/u1'),
      {
        national_id: '123',
        phone: '010',
        phone_number: '010',
        national_id_url: 'https://res.cloudinary.com/x/a.jpg',
        national_id_public_id: 'a',
        license_id_url: 'https://res.cloudinary.com/x/b.jpg',
        license_id_public_id: 'b',
        profile_completed: true,
      },
      { merge: true },
    ),
  );
});

// ------------------------------------------------------ booking creation
const newBooking = {
  userId: 'u1',
  user_email: EMAIL,
  userName: 'Ali',
  customerName: 'Ali',
  phone: '010',
  car_id: 'c1',
  car_name: 'Car',
  carName: 'Car',
  brand: 'Kia',
  days: 3,
  price_per_day: 1500,
  total_amount: 4500,
  status: 'confirmed',
  payment_method: 'card',
  payment_reference: null,
  tripStatus: 'pending',
  createdAt: serverTimestamp(),
};
test('app: checkout creates a booking', async () => {
  await assertSucceeds(addDoc(collection(customer(), 'bookings'), newBooking));
});
test('a booking cannot be created for someone else', async () => {
  await assertFails(addDoc(collection(stranger(), 'bookings'), newBooking));
});
test('a booking cannot be underpriced', async () => {
  await assertFails(
    addDoc(collection(customer(), 'bookings'), { ...newBooking, total_amount: 0 }),
  );
  await assertFails(
    addDoc(collection(customer(), 'bookings'), {
      ...newBooking,
      price_per_day: 0,
      total_amount: 0,
    }),
  );
});
test('a booking cannot be created already completed or with evidence fields', async () => {
  await assertFails(
    addDoc(collection(customer(), 'bookings'), { ...newBooking, status: 'completed' }),
  );
  await assertFails(
    addDoc(collection(customer(), 'bookings'), {
      ...newBooking,
      pickupVideo: { publicId: 'someone-elses-video' },
    }),
  );
});
test('a booking cannot be planted under another customer\'s email', async () => {
  await assertFails(
    addDoc(collection(customer(), 'bookings'), {
      ...newBooking,
      user_email: 'victim@example.com',
    }),
  );
});

// ------------------------------------------------- booking: who and what
test('a customer cannot delete their booking', async () => {
  await seed(BOOKING, base);
  await assertFails(deleteDoc(doc(customer(), BOOKING)));
});
test('another user cannot update a booking', async () => {
  await seed(BOOKING, base);
  await assertFails(updateDoc(doc(stranger(), BOOKING), { status: 'cancelled' }));
});
test('a customer cannot clear the remote engine lock', async () => {
  await seed(BOOKING, { ...base, security: { isImmobilized: true } });
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { security: { isImmobilized: false } }),
  );
});
test('a customer cannot move the tracked car location', async () => {
  await seed(BOOKING, started);
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { liveLocation: { lat: 30, lng: 31 } }),
  );
});

// ------------------------------------------------------ booking: status
test('app: a customer cancels a confirmed booking', async () => {
  await seed(BOOKING, base);
  await assertSucceeds(
    updateDoc(doc(customer(), BOOKING), {
      status: 'cancelled',
      tripStatus: 'cancelled',
      cancelledAt: serverTimestamp(),
    }),
  );
});
test('a completed booking cannot be cancelled', async () => {
  await seed(BOOKING, { ...base, status: 'completed' });
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { status: 'cancelled', tripStatus: 'cancelled' }),
  );
});
test('a customer cannot mark a booking completed without the return km', async () => {
  await seed(BOOKING, started);
  await assertFails(updateDoc(doc(customer(), BOOKING), { status: 'completed' }));
});
test('a customer cannot set an arbitrary status', async () => {
  await seed(BOOKING, base);
  await assertFails(updateDoc(doc(customer(), BOOKING), { status: 'confirmed2' }));
});

// --------------------------------------------- booking: odometer and bill
test('app: a customer records the pickup km', async () => {
  await seed(BOOKING, base);
  await assertSucceeds(
    updateDoc(doc(customer(), BOOKING), {
      odometer: { startKm: 1000, startPhotoUrl: 'u', startCapturedBy: 'u1' },
      tripStatus: 'in_progress',
      updatedAt: serverTimestamp(),
    }),
  );
});
test('the pickup km cannot be recorded twice', async () => {
  await seed(BOOKING, started);
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { odometer: { startKm: 0 }, tripStatus: 'in_progress' }),
  );
});
test('app: a customer records the return km with the extra-km bill', async () => {
  await seed(BOOKING, started);
  await assertSucceeds(updateDoc(doc(customer(), BOOKING), finalizeWrite()));
});
test('app: return within the allowance has no extra charge', async () => {
  await seed(BOOKING, started);
  await assertSucceeds(
    updateDoc(doc(customer(), BOOKING), {
      ...finalize,
      odometer: { startKm: 1000, endKm: 1100 },
      kmAllowance: {
        kmPerDay: 120,
        allowedKm: 120,
        drivenKm: 100,
        extraKm: 0,
        extraKmRateEgp: 5,
        extraKmChargeEgp: 0,
      },
      final_amount: 1000,
      extraKmPaymentStatus: 'not_applicable',
    }),
  );
});
test('a customer cannot forge a zero extra-km bill for a long drive', async () => {
  await seed(BOOKING, started);
  await assertFails(
    updateDoc(doc(customer(), BOOKING), {
      ...finalize,
      odometer: { startKm: 1000, endKm: 6000 },
      kmAllowance: { ...finalize.kmAllowance, extraKm: 0, extraKmChargeEgp: 0 },
      final_amount: 1000,
      extraKmPaymentStatus: 'not_applicable',
    }),
  );
});
test('a customer cannot under-report the final amount', async () => {
  await seed(BOOKING, started);
  await assertFails(updateDoc(doc(customer(), BOOKING), { ...finalizeWrite(), final_amount: 1000 }));
});
test('a customer cannot mark their extra-km charge paid', async () => {
  await seed(BOOKING, started);
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { ...finalizeWrite(), extraKmPaymentStatus: 'paid' }),
  );
  await seed(BOOKING, { ...started, ...finalize });
  await assertFails(updateDoc(doc(customer(), BOOKING), { extraKmPaymentStatus: 'paid' }));
});
test('a customer cannot change the final amount or odometer later', async () => {
  await seed(BOOKING, { ...started, ...finalize });
  await assertFails(updateDoc(doc(customer(), BOOKING), { final_amount: 1000 }));
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { odometer: { startKm: 1000, endKm: 1001 } }),
  );
});

// ---------------------------------------------------- booking: evidence
test('app: a customer uploads a condition video once', async () => {
  await seed(BOOKING, base);
  await assertSucceeds(
    updateDoc(doc(customer(), BOOKING), {
      pickupVideo: { url: 'https://res.cloudinary.com/x/v.mp4', publicId: 'v' },
      updatedAt: serverTimestamp(),
    }),
  );
});
test('a condition video cannot be replaced', async () => {
  await seed(BOOKING, { ...base, pickupVideo: { publicId: 'v1' } });
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { pickupVideo: { publicId: 'v2' } }),
  );
});
test('app: a customer signs the agreement; it cannot be re-signed', async () => {
  await seed(BOOKING, base);
  await assertSucceeds(
    updateDoc(doc(customer(), BOOKING), {
      agreement: { isSigned: true, signedBy: 'u1' },
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(customer(), BOOKING), { agreement: { isSigned: false } }),
  );
});
test('an agreement cannot be signed in someone else\'s name', async () => {
  await seed(BOOKING, base);
  await assertFails(
    updateDoc(doc(customer(), BOOKING), {
      agreement: { isSigned: true, signedBy: 'u2' },
      updatedAt: serverTimestamp(),
    }),
  );
});

// ------------------------------------------------------------- reviews
test('app: a customer reviews a completed booking once', async () => {
  await seed(BOOKING, { ...base, status: 'completed' });
  const review = {
    bookingId: 'b1',
    carId: 'c1',
    carName: 'Car',
    rating: 5,
    comment: 'Great',
    userId: 'u1',
    userName: 'Ali',
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(customer(), 'reviews/b1'), review));
  await assertSucceeds(updateDoc(doc(customer(), BOOKING), { reviewed: true, rating: 5 }));
  await assertFails(updateDoc(doc(customer(), BOOKING), { reviewed: true, rating: 1 }));
});
test('reviews: no fake ratings, no reviewing others\' or unfinished bookings', async () => {
  await seed(BOOKING, { ...base, status: 'completed' });
  const ok = {
    bookingId: 'b1',
    rating: 5,
    comment: '',
    userId: 'u1',
    createdAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(customer(), 'reviews/b1'), { ...ok, rating: 1e9 }));
  await assertFails(setDoc(doc(stranger(), 'reviews/b1'), { ...ok, userId: 'u2' }));
  await assertFails(setDoc(doc(customer(), 'reviews/other'), { ...ok, bookingId: 'other' }));
  await seed(BOOKING, base); // not completed
  await assertFails(setDoc(doc(customer(), 'reviews/b1'), ok));
});
test('car rating summary stays in range', async () => {
  await seed('cars/c1', { name: 'Car', price_per_day: 100 });
  await assertSucceeds(
    updateDoc(doc(customer(), 'cars/c1'), { avgRating: 4.5, reviewCount: 2 }),
  );
  await assertFails(
    updateDoc(doc(customer(), 'cars/c1'), { avgRating: 0.1, reviewCount: 9999 }),
  );
});

// ------------------------------------------------------- admin alerts
test('app: a customer action posts an alert about their own booking', async () => {
  await seed(BOOKING, base);
  await assertSucceeds(
    addDoc(collection(customer(), 'admin_alerts'), {
      title: 'New booking',
      body: 'Ali booked Car',
      type: 'new_booking',
      bookingId: 'b1',
      read: false,
      createdAt: serverTimestamp(),
    }),
  );
});
test('fake or oversized admin alerts are rejected', async () => {
  await seed(BOOKING, base);
  const alert = {
    title: 'x',
    body: 'y',
    type: 'new_booking',
    bookingId: 'b1',
    read: false,
    createdAt: serverTimestamp(),
  };
  await assertFails(
    addDoc(collection(customer(), 'admin_alerts'), { ...alert, type: 'geofence_breach' }),
  );
  await assertFails(
    addDoc(collection(customer(), 'admin_alerts'), { ...alert, body: 'x'.repeat(301) }),
  );
  await assertFails(addDoc(collection(stranger(), 'admin_alerts'), alert));
});

// ------------------------------------------------- payments, chauffeurs
test('a user cannot create a payment for someone else', async () => {
  await assertFails(
    addDoc(collection(stranger(), 'payments'), { userId: 'u1', status: 'paid' }),
  );
});
test('chauffeur contact details are admin-only', async () => {
  await seed('chauffeurs/d1', { name: 'Driver', phone: '010' });
  await assertFails(getDoc(doc(customer(), 'chauffeurs/d1')));
  await assertSucceeds(getDoc(doc(admin(), 'chauffeurs/d1')));
});

// ------------------------------------------------ review round 1 fixes
// Bookings an admin entered carry only the customer's email, no userId.
const adminEntered = { user_email: EMAIL, status: 'completed', total_amount: 500, days: 1 };

test('app: a customer reviews an admin-entered booking (matched by email)', async () => {
  await seed(BOOKING, adminEntered);
  await assertSucceeds(
    setDoc(doc(customer(), 'reviews/b1'), {
      bookingId: 'b1',
      rating: 4,
      comment: '',
      userId: 'u1',
      createdAt: serverTimestamp(),
    }),
  );
});
test('app: alerts about an admin-entered booking are accepted', async () => {
  await seed(BOOKING, { ...adminEntered, status: 'confirmed' });
  await assertSucceeds(
    addDoc(collection(customer(), 'admin_alerts'), {
      title: 'Pickup video uploaded',
      body: 'A condition video was uploaded.',
      type: 'video_pickup',
      bookingId: 'b1',
      read: false,
      createdAt: serverTimestamp(),
    }),
  );
});
test('a trip cannot be cancelled once the car is out', async () => {
  await seed(BOOKING, started);
  await assertFails(
    updateDoc(doc(customer(), BOOKING), {
      status: 'cancelled',
      tripStatus: 'cancelled',
      cancelledAt: serverTimestamp(),
    }),
  );
});
test('the return km cannot skip the bill', async () => {
  await seed(BOOKING, started);
  const { final_amount, extraKmPaymentStatus, ...noBill } = finalizeWrite();
  await assertFails(updateDoc(doc(customer(), BOOKING), noBill));
});
test('pickup evidence cannot be rewritten at return', async () => {
  await seed(BOOKING, { ...started, odometer: { startKm: 1000, startPhotoUrl: 'real' } });
  await assertFails(
    updateDoc(doc(customer(), BOOKING), {
      ...finalizeWrite(),
      odometer: { startKm: 1000, startPhotoUrl: 'fake', endKm: 1150 },
    }),
  );
});
test('timestamps must be the server time', async () => {
  await seed(BOOKING, base);
  await assertFails(
    updateDoc(doc(customer(), BOOKING), {
      status: 'cancelled',
      tripStatus: 'cancelled',
      cancelledAt: new Date(2000, 0, 1),
    }),
  );
});
test('app: FCM token save works even if the stored email drifted', async () => {
  await seed('users/u1', { role: 'user', email: 'typo@example.com' });
  await assertSucceeds(
    setDoc(doc(customer(), 'users/u1'), { fcmToken: 't', fcmUpdatedAt: serverTimestamp() }, { merge: true }),
  );
});
test('profile completion needs real https ID photo URLs', async () => {
  await assertFails(
    updateDoc(doc(customer(), 'users/u1'), {
      national_id_url: '',
      license_id_url: '',
      profile_completed: true,
    }),
  );
});
