// POST /api/pay-ticket  (Authorization: Bearer <Firebase ID token>)
// { violationId, paymentMethod: 'card' | 'wallet' | 'instapay' | 'cash' }
//   ->  { status, amount }
//
// Settles the caller's own traffic ticket. In ONE Firestore transaction it
// checks the ticket is theirs and still pending, records the method on the
// ticket, and writes its payment record (customers cannot write payments).
// Cash leaves the ticket pending until an admin confirms it at the office.
// The amount comes from the ticket, not from the app.
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/firebase.js';
import { caller } from '../lib/caller.js';
import { applyCors } from '../lib/http.js';
import { checkPayTicket, parsePayTicket } from '../lib/customer-requests.js';

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

  const request = parsePayTicket(req.body);
  if (request.error) return res.status(400).json({ error: request.error });

  const store = db();
  const ticketRef = store.collection('traffic_violations').doc(request.violationId);
  // One payment record per ticket: choosing cash and later paying by card
  // updates it instead of adding a second one.
  const paymentRef = store.collection('payments').doc(`ticket_${request.violationId}`);
  const status = request.paid ? 'paid' : 'pending';

  try {
    const result = await store.runTransaction(async (tx) => {
      const snap = await tx.get(ticketRef);
      const ticket = snap.exists ? snap.data() : null;
      const check = checkPayTicket(ticket, who);
      if (check.error) throw new Refusal(check.status, check.error);

      tx.update(ticketRef, {
        status,
        payment_method: request.paymentMethod,
        paidBy: who.uid,
        ...(request.paid ? { paidAt: FieldValue.serverTimestamp() } : {}),
      });
      tx.set(paymentRef, {
        userId: ticket.userId ?? who.uid,
        user_email: ticket.user_email ?? who.email,
        booking_id: ticket.rentalId ?? null,
        violation_id: request.violationId,
        car_name: ticket.car_name ?? null,
        amount: check.amount,
        method: request.paymentMethod,
        status,
        type: 'traffic_violation',
        payment_date: FieldValue.serverTimestamp(),
      });
      return { status, amount: check.amount };
    });
    return res.status(200).json(result);
  } catch (e) {
    if (e instanceof Refusal) return res.status(e.status).json({ error: e.message });
    console.error('pay-ticket failed', e.message);
    return res.status(500).json({ error: 'Could not record the payment. Try again.' });
  }
}
