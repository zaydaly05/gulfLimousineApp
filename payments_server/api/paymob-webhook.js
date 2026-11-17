// POST /api/paymob-webhook?hmac=...   (called by Paymob, not by the app)
//
// Paymob's "transaction processed" callback. Only a callback whose HMAC
// verifies may change a booking. Each Paymob transaction is recorded once
// (paymob_events/{id}), so retried callbacks are harmless.
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/firebase.js';
import { bookingIdFromReference, toCents } from '../lib/booking.js';
import { verifyTransactionHmac } from '../lib/paymob.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });

  const obj = req.body?.obj;
  const secret = process.env.PAYMOB_HMAC_SECRET;
  if (req.body?.type !== 'TRANSACTION' || !verifyTransactionHmac(obj, req.query.hmac, secret)) {
    return res.status(401).json({ error: 'Invalid signature' });
  }
  // Still in progress (e.g. waiting for OTP): a final callback follows.
  if (obj.pending === true) return res.status(200).json({ received: true });

  const bookingId = bookingIdFromReference(obj.order?.merchant_order_id);
  if (!bookingId) return res.status(200).json({ received: true, ignored: 'unknown order' });

  const store = db();
  const bookingRef = store.collection('bookings').doc(bookingId);
  const eventRef = store.collection('paymob_events').doc(String(obj.id));

  try {
    await store.runTransaction(async (tx) => {
      const [event, bookingSnap, payments] = await Promise.all([
        tx.get(eventRef),
        tx.get(bookingRef),
        tx.get(store.collection('payments').where('booking_id', '==', bookingId).limit(1)),
      ]);
      if (event.exists || !bookingSnap.exists) return; // duplicate or unknown
      const booking = bookingSnap.data();

      // Paid in full for this booking, not some other amount.
      const paid = obj.success === true &&
        Number(obj.amount_cents) === toCents(booking.total_amount);

      tx.create(eventRef, {
        bookingId,
        success: obj.success === true,
        amountCents: Number(obj.amount_cents),
        sourceType: obj.source_data?.type ?? null,
        receivedAt: FieldValue.serverTimestamp(),
      });

      if (booking.payment_status === 'paid') return; // never downgrade
      tx.update(bookingRef, {
        payment_status: paid ? 'paid' : 'failed',
        ...(paid && booking.status === 'pending' ? { status: 'confirmed' } : {}),
        ...(paid ? { payment_reference: String(obj.id), paidAt: FieldValue.serverTimestamp() } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (!payments.empty) {
        tx.update(payments.docs[0].ref, {
          status: paid ? 'paid' : 'failed',
          reference: String(obj.id),
          source: obj.source_data?.type ?? null,
        });
      }
      if (booking.userId) {
        tx.create(store.collection('users').doc(booking.userId).collection('notifications').doc(), {
          title: paid ? 'Payment received' : 'Payment failed',
          body: paid
            ? `Your ${booking.carName || 'car'} booking is confirmed.`
            : 'Your online payment did not go through. Open My Bookings to try again.',
          // Keys the reader's app translates (see lib/l10n/notification_text.dart).
          i18n: paid
            ? { title: 'nPaymentReceived', body: 'nPaymentConfirmedBody', args: { car: booking.carName || '' } }
            : { title: 'nPaymentFailed', body: 'nPaymentFailedBody', args: {} },
          type: paid ? 'payment_confirmed' : 'payment_failed',
          bookingId,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
  } catch (e) {
    console.error('paymob-webhook failed', e.message);
    // Non-2xx makes Paymob retry later.
    return res.status(500).json({ error: 'Could not record payment' });
  }
  return res.status(200).json({ received: true });
}
