import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

// FIREBASE_SERVICE_ACCOUNT holds the JSON key from Firebase console >
// Project settings > Service accounts > Generate new private key.
function app() {
  if (getApps().length) return getApps()[0];
  // Local tests run against the emulators, which need no credentials.
  if (process.env.FIRESTORE_EMULATOR_HOST && !process.env.FIREBASE_SERVICE_ACCOUNT) {
    return initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-gulf-limousine' });
  }
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT is not set');
  return initializeApp({ credential: cert(JSON.parse(raw)) });
}

export const db = () => getFirestore(app());
export const auth = () => getAuth(app());
