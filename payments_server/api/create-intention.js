// POST /api/create-intention  { bookingId }  (Authorization: Bearer <Firebase ID token>)
// -> { checkoutUrl, testMode }
//
// Starts Paymob's hosted checkout for one of the caller's own unpaid
// bookings. The amount comes from Firestore, never from the request.
import { auth, db } from '../lib/firebase.js';
import { applyCors, requireEnv, selfOrigin } from '../lib/http.js';
import { checkoutUrl, createIntention } from '../lib/paymob.js';
import { payableProblem, specialReferenceFor, splitName, toCents } from '../lib/booking.js';

export default async function handler(req, res) {
  applyCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });

  let env;
  try {
    env = requireEnv('PAYMOB_SECRET_KEY', 'PAYMOB_PUBLIC_KEY', 'PAYMOB_INTEGRATION_IDS');
  } catch (e) {
    console.error(e.message);
    return res.status(500).json({ error: 'Payment service is not configured yet.' });
  }

  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  let uid;
  try {
    uid = (await auth().verifyIdToken(token)).uid;
  } catch {
    return res.status(401).json({ error: 'Please sign in again.' });
  }

  const bookingId = String(req.body?.bookingId || '');
  if (!/^[A-Za-z0-9]{10,40}$/.test(bookingId)) {
    return res.status(400).json({ error: 'Invalid booking.' });
  }

  try {
    const bookingRef = db().collection('bookings').doc(bookingId);
    const booking = (await bookingRef.get()).data();
    const carId = booking?.car_id ? String(booking.car_id) : '';
    const car = carId ? (await db().collection('cars').doc(carId).get()).data() : null;
    const problem = payableProblem(booking, uid, car);
    if (problem) return res.status(409).json({ error: problem });

    const user = (await db().collection('users').doc(uid).get()).data() || {};
    const phone = String(booking.phone || user.phone || user.phone_number || '').trim();
    if (!phone) {
      return res.status(400).json({ error: 'Add your phone number in Profile first.' });
    }

    const integrationIds = env.PAYMOB_INTEGRATION_IDS.split(',')
      .map((id) => Number(id.trim()))
      .filter(Number.isInteger);
    const specialReference = specialReferenceFor(bookingId);
    const origin = selfOrigin(req);
    const amountCents = toCents(booking.total_amount);

    const { id, clientSecret } = await createIntention({
      secretKey: env.PAYMOB_SECRET_KEY,
      amountCents,
      integrationIds,
      specialReference,
      customer: {
        ...splitName(booking.customerName || booking.userName || user.name),
        email: String(booking.user_email || user.email || 'na@example.com'),
        phone,
      },
      itemName: `Car rental: ${booking.carName || booking.car_name || 'car'}`,
      notificationUrl: `${origin}/api/paymob-webhook`,
      redirectionUrl: `${origin}/api/return`,
    });

    await bookingRef.update({
      paymob: { intentionId: id, specialReference, amountCents, startedAt: new Date() },
    });

    return res.status(200).json({
      checkoutUrl: checkoutUrl(env.PAYMOB_PUBLIC_KEY, clientSecret),
      testMode: env.PAYMOB_SECRET_KEY.includes('_test_'),
    });
  } catch (e) {
    console.error('create-intention failed', e.message, e.details ?? '');
    return res.status(502).json({ error: 'Paymob could not start the payment. Try again.' });
  }
}
