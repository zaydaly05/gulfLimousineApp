import { auth } from './firebase.js';

/** The signed-in caller from `Authorization: Bearer <Firebase ID token>`, or null. */
export async function caller(req) {
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  try {
    const decoded = await auth().verifyIdToken(token);
    return { uid: decoded.uid, email: decoded.email ?? '' };
  } catch {
    return null;
  }
}
