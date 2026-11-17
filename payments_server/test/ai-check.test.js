import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkGeminiKey, describeAiConfig } from '../lib/ai-check.js';

const KEY = 'AIza' + 'x'.repeat(35);

test('describes config/ai without echoing the key', () => {
  const { report } = describeAiConfig({ geminiApiKey: KEY });
  assert.deepEqual(report, {
    documentExists: true, keyPresent: true, keyLooksValid: true,
    keyHasSpaces: false, model: 'gemini-flash-latest',
  });
  assert.equal(JSON.stringify(report).includes(KEY), false);
});

test('flags missing, malformed and padded keys', () => {
  assert.equal(describeAiConfig(null).report.documentExists, false);
  assert.equal(describeAiConfig({ geminiApiKey: 'abc' }).report.keyLooksValid, false);
  const padded = describeAiConfig({ geminiApiKey: ` ${KEY} `, geminiModel: 'gemini-x' });
  assert.equal(padded.report.keyHasSpaces, true);
  assert.equal(padded.report.keyLooksValid, true);
  assert.equal(padded.report.model, 'gemini-x');
});

test('Gemini check sends the key in a header and reports the outcome', async () => {
  let seen;
  const ok = await checkGeminiKey(KEY, 'gemini-flash-latest', async (url, init) => {
    seen = { url, key: init.headers['x-goog-api-key'] };
    return { ok: true, status: 200 };
  });
  assert.equal(ok, 'accepted');
  assert.equal(seen.url.includes(KEY), false);
  assert.equal(seen.key, KEY);
  assert.equal(await checkGeminiKey(KEY, 'm', async () => ({ ok: false, status: 403 })), 'rejected (HTTP 403)');
  assert.equal(await checkGeminiKey(KEY, 'm', async () => { throw new Error('x'); }), 'unreachable');
});
