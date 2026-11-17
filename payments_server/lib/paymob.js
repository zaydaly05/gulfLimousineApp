// Paymob Intention API + Unified Checkout + callback HMAC.
// Reference: Paymob's integration docs (Intention API, "HMAC for transaction
// processed callback"). The secret key and HMAC secret only ever live here,
// in Vercel environment variables, never in the app.
import crypto from 'node:crypto';

export const PAYMOB_BASE_URL = 'https://accept.paymob.com'; // Egypt

/** Fields of the transaction-processed callback, in Paymob's HMAC order. */
const HMAC_FIELDS = [
  'amount_cents', 'created_at', 'currency', 'error_occured',
  'has_parent_transaction', 'id', 'integration_id', 'is_3d_secure',
  'is_auth', 'is_capture', 'is_refunded', 'is_standalone_payment',
  'is_voided', 'order.id', 'owner', 'pending',
  'source_data.pan', 'source_data.sub_type', 'source_data.type', 'success',
];

function pick(obj, path) {
  return path.split('.').reduce((v, key) => (v == null ? undefined : v[key]), obj);
}

/**
 * The string Paymob signs. Paymob doesn't document how a null field (seen in
 * some wallet callbacks) is written, so [nullAs] lets the caller try both
 * plausible forms; neither can be produced without the HMAC secret.
 */
export function hmacString(obj, nullAs = '') {
  return HMAC_FIELDS.map((path) => {
    const value = pick(obj, path);
    return value === null || value === undefined ? nullAs : String(value);
  }).join('');
}

function safeEqual(a, b) {
  const x = Buffer.from(String(a), 'utf8');
  const y = Buffer.from(String(b ?? ''), 'utf8');
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

/** True when [receivedHmac] is Paymob's signature of the callback [obj]. */
export function verifyTransactionHmac(obj, receivedHmac, secret) {
  if (!obj || !receivedHmac || !secret) return false;
  return ['', 'null'].some((nullAs) => {
    const expected = crypto
      .createHmac('sha512', secret)
      .update(hmacString(obj, nullAs))
      .digest('hex');
    return safeEqual(expected, String(receivedHmac).toLowerCase());
  });
}

export function checkoutUrl(publicKey, clientSecret) {
  const params = new URLSearchParams({ publicKey, clientSecret });
  return `${PAYMOB_BASE_URL}/unifiedcheckout/?${params}`;
}

/** Creates a payment intention and returns Paymob's client_secret. */
export async function createIntention({
  secretKey,
  amountCents,
  integrationIds,
  specialReference,
  customer,
  itemName,
  notificationUrl,
  redirectionUrl,
}) {
  const response = await fetch(`${PAYMOB_BASE_URL}/v1/intention/`, {
    method: 'POST',
    headers: {
      Authorization: `Token ${secretKey}`, // "Token", not "Bearer"
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: amountCents,
      currency: 'EGP',
      payment_methods: integrationIds,
      items: [{ name: itemName, amount: amountCents, quantity: 1 }],
      billing_data: {
        first_name: customer.firstName,
        last_name: customer.lastName,
        email: customer.email,
        phone_number: customer.phone, // required by Paymob
        apartment: 'NA', floor: 'NA', street: 'NA', building: 'NA',
        shipping_method: 'NA', postal_code: 'NA', city: 'Cairo',
        state: 'Cairo', country: 'EGY',
      },
      special_reference: specialReference,
      notification_url: notificationUrl,
      redirection_url: redirectionUrl,
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data.client_secret) {
    const error = new Error(`Paymob intention failed (${response.status})`);
    error.details = data;
    throw error;
  }
  return { id: data.id, clientSecret: data.client_secret };
}
