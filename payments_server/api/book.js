// POST /api/book  (Authorization: Bearer <Firebase ID token>)
// { carId, pickupDay, returnDay, quantity, colorPreferences, pickupLocation,
//   dropoffLocation, signatureUrl, paymentMethod, paymobMethod?, reference?,
//   payerPhone? }  ->  { bookingId, allocatedColors, totalAmount, status, paymentStatus }
//
// Creates a booking. In ONE Firestore transaction it reads the car and its
// overlapping bookings, assigns colours by the customer's priority, and
// writes the booking and its payment record, so two customers can never
// both get the last car. Price, days and payment state are decided here,
// not by the app.
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/firebase.js';
import { caller } from '../lib/caller.js';
import { applyCors } from '../lib/http.js';
import { allocate, availability, cairoMidnight } from '../lib/fleet.js';
import { enabledMethods, parseBookRequest } from '../lib/booking-request.js';

class Refusal extends Error {
  constructor(status, message, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

export default async function handler(req, res) {
  applyCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });

  const who = await caller(req);
  if (!who) return res.status(401).json({ error: 'Please sign in again.' });

  const request = parseBookRequest(req.body, { paymobConfigured: Boolean(process.env.PAYMOB_SECRET_KEY) });
  if (request.error) return res.status(400).json({ error: request.error });

  const store = db();
  const carRef = store.collection('cars').doc(request.carId);
  const bookingRef = store.collection('bookings').doc();
  const paymentRef = store.collection('payments').doc();

  try {
    const result = await store.runTransaction(async (tx) => {
      const [carSnap, bookings, config, profile] = await Promise.all([
        tx.get(carRef),
        tx.get(store.collection('bookings').where('car_id', '==', request.carId)),
        tx.get(store.collection('config').doc('payments')),
        tx.get(store.collection('users').doc(who.uid)),
      ]);
      if (!carSnap.exists) throw new Refusal(404, 'Car not found.');
      if (!enabledMethods(config.data())[request.switchKey]) {
        throw new Refusal(409, 'This payment method is not available right now. Choose another.');
      }

      const car = carSnap.data();
      const pricePerDay = Number(car.price_per_day);
      if (!(pricePerDay > 0)) throw new Refusal(409, 'This car has no price yet.');

      const avail = availability(
        car,
        bookings.docs.map((d) => ({ id: d.id, ...d.data() })),
        { start: request.pickupDay, end: request.returnDay },
      );
      const allocatedColors = allocate(avail, request.colorPreferences, request.quantity);
      if (!allocatedColors) {
        throw new Refusal(409, avail.totalAvailable === 0
          ? 'No cars of this model are free on those dates.'
          : `Only ${avail.totalAvailable} ${avail.totalAvailable === 1 ? 'car is' : 'cars are'} free on those dates.`,
        { available: avail });
      }

      const user = profile.data() ?? {};
      const name = String(user.name ?? user.displayName ?? 'Customer');
      const phone = String(user.phone ?? user.phone_number ?? '');
      const carName = String(car.name ?? 'Car');
      // Optional Arabic name, shown to Arabic readers (lib/l10n/content_labels.dart).
      const carNameAr = typeof car.name_ar === 'string' ? car.name_ar.trim().slice(0, 100) : '';
      const totalAmount = pricePerDay * request.days * request.quantity;
      const pickupDate = Timestamp.fromDate(cairoMidnight(request.pickupDay));

      tx.create(bookingRef, {
        userId: who.uid,
        user_email: who.email,
        userName: name,
        customerName: name,
        phone,
        car_id: request.carId,
        car_name: carName,
        carName,
        ...(carNameAr ? { car_name_ar: carNameAr } : {}),
        brand: String(car.brand ?? ''),
        pickupDate,
        startDate: pickupDate,
        returnDate: Timestamp.fromDate(cairoMidnight(request.returnDay)),
        pickupDay: request.pickupDay,
        returnDay: request.returnDay,
        days: request.days,
        quantity: request.quantity,
        colorPreferences: request.colorPreferences,
        allocatedColors: allocatedColors.filter((c) => c.name),
        price_per_day: pricePerDay,
        total_amount: totalAmount,
        status: request.status,
        payment_method: request.paymentMethod,
        ...(request.paymobMethod ? { paymob_method: request.paymobMethod } : {}),
        payment_reference: request.reference,
        payment_status: request.paymentStatus,
        ...(request.payerPhone ? { payer_phone: request.payerPhone } : {}),
        tripStatus: 'pending',
        pickupLocation: request.pickupLocation,
        dropoffLocation: request.dropoffLocation,
        createdAt: FieldValue.serverTimestamp(),
        agreement: {
          isSigned: true,
          signedAt: FieldValue.serverTimestamp(),
          signatureUrl: request.signatureUrl,
          signedBy: who.uid,
        },
      });
      tx.create(paymentRef, {
        userId: who.uid,
        user_email: who.email,
        booking_id: bookingRef.id,
        car_name: carName,
        amount: totalAmount,
        method: request.paymentMethod,
        reference: request.reference,
        ...(request.payerPhone ? { payer_phone: request.payerPhone } : {}),
        status: request.paymentStatus,
        payment_date: FieldValue.serverTimestamp(),
      });
      const units = `${request.quantity} × ${carName}`;
      tx.create(store.collection('users').doc(who.uid).collection('notifications').doc(), {
        title: request.status === 'confirmed' ? 'Booking confirmed' : 'Booking received',
        body: `Your ${units} rental is ${request.status}. Open My Bookings for details.`,
        // Keys the reader's app translates (see lib/l10n/notification_text.dart).
        i18n: {
          title: request.status === 'confirmed' ? 'nBookingConfirmed' : 'nBookingReceived',
          body: 'nBookingBody',
          args: { units, bookingStatus: request.status },
        },
        type: `booking_${request.status}`,
        bookingId: bookingRef.id,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.create(store.collection('admin_alerts').doc(), {
        title: 'New booking',
        body: `${name} booked ${units}`,
        type: 'new_booking',
        bookingId: bookingRef.id,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      return { allocatedColors, totalAmount };
    });

    return res.status(200).json({
      bookingId: bookingRef.id,
      allocatedColors: result.allocatedColors,
      totalAmount: result.totalAmount,
      status: request.status,
      paymentStatus: request.paymentStatus,
    });
  } catch (e) {
    if (e instanceof Refusal) return res.status(e.status).json({ error: e.message, ...e.extra });
    console.error('book failed', e.message);
    return res.status(500).json({ error: 'Could not save the booking. Try again.' });
  }
}
