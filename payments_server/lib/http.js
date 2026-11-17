// Small helpers shared by the endpoints.

// The web demo calls the server from the browser, so it needs CORS. Native
// apps send no Origin header and are unaffected.
const DEFAULT_ORIGINS = [
  'https://gulf-limousine-travel-1d4c7.web.app',
  'https://gulf-limousine-travel-1d4c7.firebaseapp.com',
];

export function applyCors(req, res) {
  const allowed = (process.env.ALLOWED_ORIGINS || DEFAULT_ORIGINS.join(','))
    .split(',')
    .map((o) => o.trim());
  const origin = req.headers.origin;
  if (origin && allowed.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  }
}

export function requireEnv(...names) {
  const missing = names.filter((n) => !process.env[n]);
  if (missing.length) throw new Error(`Missing environment variables: ${missing.join(', ')}`);
  return Object.fromEntries(names.map((n) => [n, process.env[n]]));
}

/** Public HTTPS origin of this deployment, for Paymob's callback URLs. */
export function selfOrigin(req) {
  if (process.env.PUBLIC_URL) return process.env.PUBLIC_URL.replace(/\/$/, '');
  return `https://${req.headers['x-forwarded-host'] || req.headers.host}`;
}
