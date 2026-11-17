// Pure booking rules, kept free of Firebase so they can be unit tested.

/** Bookings get one Paymob reference per attempt: `<bookingId>_<time>`. */
export function specialReferenceFor(bookingId, now = Date.now()) {
  return `${bookingId}_${now}`;
}

/** Firestore auto-IDs contain no underscore, so the split is unambiguous. */
export function bookingIdFromReference(reference) {
  const id = String(reference ?? '').split('_')[0];
  return /^[A-Za-z0-9]{10,40}$/.test(id) ? id : null;
}

/**
 * Why [booking] can't be paid online by [uid] right now, or null if it can.
 * The amount is checked against the car's current price so a tampered
 * booking can't be paid at a discount.
 */
export function payableProblem(booking, uid, car) {
  if (!booking) return 'Booking not found';
  if (booking.userId !== uid) return 'This booking belongs to another account';
  if (booking.payment_method !== 'paymob') return 'This booking is not an online payment';
  if (booking.status !== 'pending') return 'This booking is no longer awaiting payment';
  if (!['unpaid', 'failed'].includes(booking.payment_status)) {
    return 'This booking is already paid or being checked';
  }
  const total = Number(booking.total_amount);
  if (!Number.isFinite(total) || total <= 0) return 'Booking has no amount';
  if (car) {
    const quantity = Math.max(1, Number(booking.quantity) || 1);
    const expected = Number(car.price_per_day) * Number(booking.days) * quantity;
    if (Number.isFinite(expected) && Math.abs(expected - total) > 0.005) {
      return 'The price has changed. Please make a new booking.';
    }
  }
  return null;
}

/** EGP to integer piastres without float drift (19.99 -> 1999). */
export function toCents(amount) {
  return Math.round(Number(amount) * 100);
}

/** Paymob wants a first and last name. */
export function splitName(name) {
  const parts = String(name ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { firstName: 'Customer', lastName: 'NA' };
  return { firstName: parts[0], lastName: parts.slice(1).join(' ') || 'NA' };
}

/**
 * Integration IDs for the checkout: only the requested method's ID when
 * PAYMOB_CARD_INTEGRATION_ID / PAYMOB_WALLET_INTEGRATION_ID say which is
 * which, otherwise every ID in PAYMOB_INTEGRATION_IDS (Paymob then shows a
 * tab per method).
 */
export function integrationIdsFor(method, env) {
  const one = (v) => (/^\d+$/.test(String(v ?? '').trim()) ? [Number(String(v).trim())] : null);
  if (method === 'card') {
    const id = one(env.PAYMOB_CARD_INTEGRATION_ID);
    if (id) return id;
  }
  if (method === 'wallet') {
    const id = one(env.PAYMOB_WALLET_INTEGRATION_ID);
    if (id) return id;
  }
  return String(env.PAYMOB_INTEGRATION_IDS || '')
    .split(',')
    .map((id) => id.trim())
    .filter((id) => /^\d+$/.test(id))
    .map(Number);
}

/**
 * Which Paymob method ('card', 'wallet' or null for both) a checkout may
 * offer, given the admin switches from enabledMethods(). [requested] is the
 * app's choice, [stored] the booking's paymob_method. Returns `{ method }`
 * or `{ error }` when the method has been switched off since booking.
 */
export function paymobMethodFor(requested, stored, enabled) {
  const on = { card: enabled.card !== false, wallet: enabled.walletOnline !== false };
  const pick = ['card', 'wallet'].includes(requested) ? requested
    : ['card', 'wallet'].includes(stored) ? stored : null;
  if (pick) {
    return on[pick] ? { method: pick } : { error: 'This payment method is not available right now. Make a new booking with another method.' };
  }
  if (on.card && on.wallet) return { method: null };
  if (on.card) return { method: 'card' };
  if (on.wallet) return { method: 'wallet' };
  return { error: 'Online payment is switched off right now. Make a new booking with another method.' };
}
