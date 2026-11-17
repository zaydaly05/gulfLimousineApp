// Configuration self-check. Reports only yes/no facts and key *modes*,
// never a secret value, so it is safe to expose.

const NAMES = [
  'PAYMOB_SECRET_KEY', 'PAYMOB_PUBLIC_KEY', 'PAYMOB_HMAC_SECRET',
  'PAYMOB_INTEGRATION_IDS', 'FIREBASE_SERVICE_ACCOUNT',
];

function keyMode(value, prefix) {
  if (!value) return 'missing';
  if (value.startsWith(`${prefix}_test_`)) return 'test';
  if (value.startsWith(`${prefix}_live_`)) return 'live';
  return 'unrecognised';
}

/** Checks everything that doesn't need the network. */
export function configReport(env, expectedProjectId) {
  const present = Object.fromEntries(NAMES.map((n) => [n, Boolean(env[n])]));

  let serviceAccount = { valid: false };
  if (env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
      serviceAccount = {
        valid: Boolean(sa.private_key && sa.client_email),
        projectMatches: sa.project_id === expectedProjectId,
      };
    } catch {
      serviceAccount = { valid: false, error: 'not valid JSON' };
    }
  }

  const ids = String(env.PAYMOB_INTEGRATION_IDS || '')
    .split(',').map((s) => s.trim()).filter(Boolean);
  const secretMode = keyMode(env.PAYMOB_SECRET_KEY, 'sk');
  const publicMode = keyMode(env.PAYMOB_PUBLIC_KEY, 'pk');

  const paymob = {
    secretKeyMode: secretMode,
    publicKeyMode: publicMode,
    modesMatch: secretMode === publicMode && ['test', 'live'].includes(secretMode),
    integrationIds: ids.length,
    integrationIdsValid: ids.length > 0 && ids.every((id) => /^\d+$/.test(id)),
    hmacSecretSet: Boolean(env.PAYMOB_HMAC_SECRET),
  };

  const ok = Object.values(present).every(Boolean) &&
    serviceAccount.valid && serviceAccount.projectMatches &&
    paymob.modesMatch && paymob.integrationIdsValid && paymob.hmacSecretSet;
  return { ok, present, serviceAccount, paymob };
}
