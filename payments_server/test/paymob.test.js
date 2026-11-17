import { test } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { checkoutUrl, hmacString, verifyTransactionHmac } from '../lib/paymob.js';

// Paymob's documented worked example for the transaction callback.
const sample = {
  amount_cents: 100,
  created_at: '2020-03-25T18:39:44.719228',
  currency: 'EGP',
  error_occured: false,
  has_parent_transaction: false,
  id: 2556706,
  integration_id: 6741,
  is_3d_secure: true,
  is_auth: false,
  is_capture: false,
  is_refunded: false,
  is_standalone_payment: true,
  is_voided: false,
  order: { id: 4778239, merchant_order_id: 'abc_1' },
  owner: 4705,
  pending: false,
  source_data: { pan: '2346', sub_type: 'MasterCard', type: 'card' },
  success: true,
};
const sign = (s, secret = 'test-secret') =>
  crypto.createHmac('sha512', secret).update(s).digest('hex');

test('concatenates fields in Paymob\'s documented order', () => {
  assert.equal(
    hmacString(sample),
    '1002020-03-25T18:39:44.719228EGPfalsefalse25567066741truefalsefalsefalsetruefalse47782394705false2346MasterCardcardtrue',
  );
});

test('accepts a genuine signature and rejects tampering', () => {
  const hmac = sign(hmacString(sample));
  assert.equal(verifyTransactionHmac(sample, hmac, 'test-secret'), true);
  assert.equal(verifyTransactionHmac(sample, hmac.toUpperCase(), 'test-secret'), true);
  assert.equal(verifyTransactionHmac({ ...sample, amount_cents: 1 }, hmac, 'test-secret'), false);
  assert.equal(verifyTransactionHmac({ ...sample, success: false }, hmac, 'test-secret'), false);
  assert.equal(verifyTransactionHmac(sample, hmac, 'other-secret'), false);
  assert.equal(verifyTransactionHmac(sample, '', 'test-secret'), false);
  assert.equal(verifyTransactionHmac(sample, 'short', 'test-secret'), false);
  assert.equal(verifyTransactionHmac(sample, hmac, ''), false);
});

test('null fields verify whether Paymob writes them as "" or "null"', () => {
  const wallet = { ...sample, source_data: { pan: null, sub_type: 'wallet', type: 'wallet' } };
  for (const nullAs of ['', 'null']) {
    const hmac = sign(hmacString(wallet, nullAs));
    assert.equal(verifyTransactionHmac(wallet, hmac, 'test-secret'), true);
  }
});

test('checkout URL uses the public key and client secret', () => {
  assert.equal(
    checkoutUrl('pk_test_1', 'csk_test_2'),
    'https://accept.paymob.com/unifiedcheckout/?publicKey=pk_test_1&clientSecret=csk_test_2',
  );
});
