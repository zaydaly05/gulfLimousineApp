// Parsing and ownership checks for /api/end-trip and /api/pay-ticket. Pure
// functions, so they are unit-tested without Firestore.

const ID = /^[A-Za-z0-9_-]{1,128}$/;
const HTTPS = /^https:\/\/\S{1,2000}$/;

// The furthest a car can plausibly be driven in one rental.
const MAX_DRIVEN_KM = 1_000_000;

// Ticket payment methods the app offers (my_traffic_violations_screen.dart).
export const TICKET_METHODS = ['card', 'wallet', 'instapay', 'cash'];

/** True if the document belongs to the caller by uid or by email. */
export function ownedBy(doc, who) {
  if (doc.userId && doc.userId === who.uid) return true;
  const stored = String(doc.user_email ?? '').trim().toLowerCase();
  const email = String(who.email ?? '').trim().toLowerCase();
  return email !== '' && stored === email;
}

export function parseEndTrip(body) {
  const b = body && typeof body === 'object' ? body : {};
  const bookingId = String(b.bookingId ?? '');
  if (!ID.test(bookingId)) return { error: 'Missing booking.' };
  const endKm = b.endKm;
  if (!Number.isSafeInteger(endKm) || endKm < 0) return { error: 'Enter the return km as a whole number.' };
  const photoUrl = String(b.photoUrl ?? '');
  if (photoUrl && !HTTPS.test(photoUrl)) return { error: 'The odometer photo did not upload. Try again.' };
  const photoPublicId = String(b.photoPublicId ?? '').slice(0, 300);
  return { bookingId, endKm, photoUrl, photoPublicId };
}

/**
 * Checks the booking can be finished with [endKm]. Returns { error, status }
 * or { startKm }.
 */
export function checkEndTrip(booking, who, endKm) {
  if (!booking) return { status: 404, error: 'Booking not found.' };
  if (!ownedBy(booking, who)) return { status: 403, error: 'Not allowed.' };
  const status = String(booking.status ?? '').toLowerCase();
  if (status === 'cancelled') return { status: 409, error: 'This booking was cancelled.' };
  const odometer = booking.odometer;
  const startKm = odometer && typeof odometer === 'object' ? odometer.startKm : undefined;
  if (!Number.isSafeInteger(startKm)) return { status: 409, error: 'Record pickup km first.' };
  if (odometer.endKm != null || status === 'completed') {
    return { status: 409, error: 'Return km already recorded.' };
  }
  if (endKm < startKm) return { status: 400, error: `Return km must be at least ${startKm}.` };
  if (endKm - startKm > MAX_DRIVEN_KM) return { status: 400, error: 'That return km looks wrong. Check it and try again.' };
  return { startKm };
}

export function parsePayTicket(body) {
  const b = body && typeof body === 'object' ? body : {};
  const violationId = String(b.violationId ?? '');
  if (!ID.test(violationId)) return { error: 'Missing ticket.' };
  const paymentMethod = String(b.paymentMethod ?? '');
  if (!TICKET_METHODS.includes(paymentMethod)) return { error: 'Choose a payment method.' };
  // Cash is paid at the office and confirmed by an admin; the other methods
  // are recorded as paid, as the app did before this endpoint existed.
  return { violationId, paymentMethod, paid: paymentMethod !== 'cash' };
}

export function checkPayTicket(ticket, who) {
  if (!ticket) return { status: 404, error: 'Ticket not found.' };
  if (!ownedBy(ticket, who)) return { status: 403, error: 'Not allowed.' };
  if (ticket.status !== 'pending') return { status: 409, error: 'This ticket is already settled.' };
  const amount = Number(ticket.amount);
  return { amount: Number.isFinite(amount) && amount > 0 ? amount : 0 };
}
