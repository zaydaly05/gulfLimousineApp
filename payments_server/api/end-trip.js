// POST /api/end-trip  (Authorization: Bearer <Firebase ID token>)
// { bookingId, endKm, photoUrl?, photoPublicId? }
//   ->  { finalAmount, kmAllowance, extraKmPaymentStatus }
//
// Records the return odometer and closes the rental. In ONE Firestore
// transaction it computes the extra-km bill, completes the booking, writes
// the extra-km payment record (customers cannot write payments), moves the
// car's odometer, and notifies the customer and admins. So a finished trip
// always has its bill, and the bill is computed here, not by the app.
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/firebase.js';
import { caller } from '../lib/caller.js';
import { applyCors } from '../lib/http.js';
import { kmBill } from '../lib/km-billing.js';
import { checkEndTrip, parseEndTrip } from '../lib/customer-requests.js';

class Refusal extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export default async function handler(req, res) {
  applyCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });

  const who = await caller(req);
  if (!who) return res.status(401).json({ error: 'Please sign in again.' });

  const request = parseEndTrip(req.body);
  if (request.error) return res.status(400).json({ error: request.error });

  const store = db();
  const bookingRef = store.collection('bookings').doc(request.bookingId);

  try {
    const result = await store.runTransaction(async (tx) => {
      const snap = await tx.get(bookingRef);
      const booking = snap.exists ? snap.data() : null;
      const check = checkEndTrip(booking, who, request.endKm);
      if (check.error) throw new Refusal(check.status, check.error);

      const carId = String(booking.car_id ?? booking.carId ?? '');
      const carRef = carId ? store.collection('cars').doc(carId) : null;
      const carSnap = carRef ? await tx.get(carRef) : null;

      const kmAllowance = kmBill(check.startKm, request.endKm, booking.days);
      const charge = kmAllowance.extraKmChargeEgp;
      const finalAmount = Number(booking.total_amount ?? 0) + charge;
      const extraKmPaymentStatus = kmAllowance.extraKm > 0 ? 'pending' : 'not_applicable';
      const carName = String(booking.carName ?? booking.car_name ?? 'Car');

      tx.update(bookingRef, {
        'odometer.endKm': request.endKm,
        'odometer.endPhotoUrl': request.photoUrl,
        'odometer.endPhotoPublicId': request.photoPublicId,
        'odometer.endCapturedAt': FieldValue.serverTimestamp(),
        'odometer.endCapturedBy': who.uid,
        kmAllowance,
        final_amount: finalAmount,
        extraKmPaymentStatus,
        status: 'completed',
        tripStatus: 'completed',
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (carSnap?.exists) tx.update(carRef, { current_odometer: request.endKm });

      if (charge > 0) {
        // One extra-km record per booking: the id makes a retry harmless.
        tx.create(store.collection('payments').doc(`extra_km_${request.bookingId}`), {
          userId: booking.userId ?? who.uid,
          user_email: booking.user_email ?? who.email,
          booking_id: request.bookingId,
          car_name: carName,
          amount: charge,
          method: 'extra_km',
          status: 'pending',
          description: `Extra ${kmAllowance.extraKm} km (${kmAllowance.drivenKm} driven, ${kmAllowance.allowedKm} allowed)`,
          payment_date: FieldValue.serverTimestamp(),
        });
      }

      const egp = charge.toFixed(0);
      tx.create(store.collection('users').doc(who.uid).collection('notifications').doc(), {
        title: 'Rental completed',
        body: kmAllowance.extraKm > 0
          ? `${carName} returned. Extra ${kmAllowance.extraKm} km: EGP ${egp} due.`
          : `${carName} returned. No extra km charges.`,
        // Keys the reader's app translates (see lib/l10n/notification_text.dart).
        i18n: kmAllowance.extraKm > 0
          ? { title: 'nRentalCompleted', body: 'nRentalCompletedExtra', args: { car: carName, km: String(kmAllowance.extraKm), amount: egp } }
          : { title: 'nRentalCompleted', body: 'nRentalCompletedNoExtra', args: { car: carName } },
        type: 'rental_completed',
        bookingId: request.bookingId,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.create(store.collection('admin_alerts').doc(), {
        title: 'Return km recorded',
        body: `${carName} returned at ${request.endKm} km. Extra: ${kmAllowance.extraKm} km (EGP ${egp})`,
        type: 'odometer_end',
        bookingId: request.bookingId,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      return { finalAmount, kmAllowance, extraKmPaymentStatus };
    });
    return res.status(200).json(result);
  } catch (e) {
    if (e instanceof Refusal) return res.status(e.status).json({ error: e.message });
    console.error('end-trip failed', e.message);
    return res.status(500).json({ error: 'Could not save the return km. Try again.' });
  }
}
