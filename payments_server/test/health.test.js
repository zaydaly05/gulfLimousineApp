import { test } from 'node:test';
import assert from 'node:assert/strict';
import { configReport } from '../lib/health.js';

const sa = JSON.stringify({ project_id: 'p1', private_key: 'PRIVATE-9f3a', client_email: 'x@p1' });
const good = {
  PAYMOB_SECRET_KEY: 'sk_test_abc', PAYMOB_PUBLIC_KEY: 'pk_test_def',
  PAYMOB_HMAC_SECRET: 'h', PAYMOB_INTEGRATION_IDS: '111, 222', FIREBASE_SERVICE_ACCOUNT: sa,
};

test('a complete test-mode config is ok', () => {
  const r = configReport(good, 'p1');
  assert.equal(r.ok, true);
  assert.equal(r.paymob.secretKeyMode, 'test');
  assert.equal(r.paymob.integrationIds, 2);
});

test('problems are reported without echoing values', () => {
  const r = configReport({ ...good, PAYMOB_PUBLIC_KEY: 'pk_live_x', FIREBASE_SERVICE_ACCOUNT: '{bad' }, 'p1');
  assert.equal(r.ok, false);
  assert.equal(r.paymob.modesMatch, false);
  assert.equal(r.serviceAccount.error, 'not valid JSON');
  assert.equal(JSON.stringify(r).includes('sk_test_abc'), false);
  assert.equal(JSON.stringify(r).includes('PRIVATE-9f3a'), false);
});

test('wrong Firebase project and bad IDs are caught', () => {
  const r = configReport({ ...good, PAYMOB_INTEGRATION_IDS: 'abc' }, 'other');
  assert.equal(r.serviceAccount.projectMatches, false);
  assert.equal(r.paymob.integrationIdsValid, false);
  assert.equal(r.ok, false);
});

test('region-prefixed Paymob keys and wrong-key hints', () => {
  const egy = configReport({ ...good, PAYMOB_SECRET_KEY: 'egy_sk_test_x', PAYMOB_PUBLIC_KEY: 'egy_pk_test_y' }, 'p1');
  assert.equal(egy.ok, true);
  assert.equal(egy.paymob.secretKeyMode, 'test');
  const legacy = configReport({ ...good, PAYMOB_SECRET_KEY: 'ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5' }, 'p1');
  assert.equal(legacy.paymob.secretKeyMode, 'legacy-api-key');
  assert.equal(legacy.ok, false);
});
