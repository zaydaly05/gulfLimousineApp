// Validates a customer's booking request and decides its payment state.
// Pure functions: no Firebase.

import { addDays, cairoDay, isDay, rentalDays } from './fleet.js';

/** What the app sends once the customer ticks "I have read and agree". */
export const ACCEPTED_BY_CHECKBOX = 'digital_signature_accepted';

/** Admin switches in config/payments.methods; missing means on. */
export const METHOD_SWITCHES = ['card', 'walletOnline', 'walletTransfer', 'instapay', 'cash'];

export const MAX_QUANTITY = 20;
export const MAX_DAYS_AHEAD = 365;

/** The admin switch a request's payment method depends on. */
export function switchFor(paymentMethod, paymobMethod) {
  if (paymentMethod === 'paymob') return paymobMethod === 'wallet' ? 'walletOnline' : 'card';
  return { cash: 'cash', instapay: 'instapay', wallet: 'walletTransfer', card: 'card' }[paymentMethod] ?? null;
}

export function enabledMethods(paymentsConfig) {
  const m = paymentsConfig?.methods ?? {};
  return Object.fromEntries(METHOD_SWITCHES.map((k) => [k, m[k] !== false]));
}

/** 01XXXXXXXXX, or null if [input] isn't an Egyptian mobile number. */
export function normalizeEgyptianMobile(input) {
  let digits = String(input ?? '').replace(/[\s\-()]/g, '');
  if (digits.startsWith('+')) digits = digits.slice(1);
  if (digits.startsWith('0020')) digits = `0${digits.slice(4)}`;
  else if (digits.startsWith('20') && digits.length === 12) digits = `0${digits.slice(2)}`;
  return /^01[0125]\d{8}$/.test(digits) ? digits : null;
}

function location(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const lat = Number(raw.lat);
  const lng = Number(raw.lng);
  const address = String(raw.address ?? '').slice(0, 300);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  return { lat, lng, address };
}

/**
 * Checks the request body. Returns `{ error }` or the normalised request.
 * [paymobConfigured] decides whether 'card' means Paymob or the demo card.
 */
export function parseBookRequest(body, { now = new Date(), paymobConfigured }) {
  const b = body ?? {};
  const carId = String(b.carId ?? '');
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(carId)) return { error: 'Invalid car.' };

  const today = cairoDay(now);
  if (!isDay(b.pickupDay) || !isDay(b.returnDay)) return { error: 'Choose the pickup and return dates.' };
  if (b.pickupDay < today) return { error: 'The pickup date has passed.' };
  if (b.returnDay < b.pickupDay) return { error: 'Return must be on or after pickup.' };
  if (b.returnDay > addDays(today, MAX_DAYS_AHEAD)) return { error: 'Bookings open up to a year ahead.' };

  const quantity = Number(b.quantity ?? 1);
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > MAX_QUANTITY) {
    return { error: `You can book 1 to ${MAX_QUANTITY} cars at a time.` };
  }
  const colorPreferences = Array.isArray(b.colorPreferences)
    ? [...new Set(b.colorPreferences.map((c) => String(c).trim()).filter(Boolean))].slice(0, 20)
    : [];

  const pickupLocation = location(b.pickupLocation);
  const dropoffLocation = location(b.dropoffLocation);
  if (!pickupLocation || !dropoffLocation) return { error: 'Choose the pickup and drop-off locations.' };

  // The app records agreement as a ticked checkbox ('digital_signature_accepted');
  // a drawn signature uploaded to Cloudinary is accepted too.
  const signatureUrl = String(b.signatureUrl ?? '');
  let sigOk = signatureUrl === ACCEPTED_BY_CHECKBOX;
  try {
    const u = new URL(signatureUrl);
    sigOk ||= u.protocol === 'https:' && u.hostname === 'res.cloudinary.com';
  } catch { /* not a URL */ }
  if (!sigOk) return { error: 'Please sign the rental agreement first.' };

  let paymentMethod = String(b.paymentMethod ?? '');
  const paymobMethod = b.paymobMethod === 'wallet' ? 'wallet' : 'card';
  // With Paymob set up, a card is paid online, never by the demo card form.
  if (paymentMethod === 'card' && paymobConfigured) paymentMethod = 'paymob';
  if (!['cash', 'instapay', 'wallet', 'card', 'paymob'].includes(paymentMethod)) {
    return { error: 'Choose a payment method.' };
  }
  if (paymentMethod === 'paymob' && !paymobConfigured) return { error: 'Online payment is not set up.' };

  let reference = null;
  let payerPhone = null;
  if (paymentMethod === 'instapay' || paymentMethod === 'wallet') {
    reference = String(b.reference ?? '').trim();
    if (!/^[A-Za-z0-9-]{6,30}$/.test(reference)) return { error: 'Enter the transaction ID.' };
    payerPhone = normalizeEgyptianMobile(b.payerPhone);
    if (!payerPhone) return { error: 'Enter the mobile number you paid from.' };
  }

  const state = {
    cash: { status: 'pending', paymentStatus: 'pending' },
    instapay: { status: 'pending', paymentStatus: 'awaiting_verification' },
    wallet: { status: 'pending', paymentStatus: 'awaiting_verification' },
    card: { status: 'confirmed', paymentStatus: 'paid' }, // demo card (no Paymob)
    paymob: { status: 'pending', paymentStatus: 'unpaid' },
  }[paymentMethod];

  return {
    carId,
    pickupDay: b.pickupDay,
    returnDay: b.returnDay,
    days: rentalDays(b.pickupDay, b.returnDay),
    quantity,
    colorPreferences,
    pickupLocation,
    dropoffLocation,
    signatureUrl,
    paymentMethod,
    paymobMethod: paymentMethod === 'paymob' ? paymobMethod : null,
    switchKey: switchFor(paymentMethod, paymobMethod),
    reference,
    payerPhone,
    ...state,
  };
}
