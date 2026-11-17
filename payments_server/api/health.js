// GET /api/health  Is the server configured? Yes/no answers only.
import { configReport } from '../lib/health.js';

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'gulf-limousine-travel-1d4c7';

export default async function handler(req, res) {
  const report = configReport(process.env, PROJECT_ID);
  report.firestore = 'not checked';
  if (report.serviceAccount.valid) {
    try {
      const { db } = await import('../lib/firebase.js');
      await db().collection('config').doc('payments').get();
      report.firestore = 'reachable';
    } catch (e) {
      report.firestore = 'unreachable';
      report.ok = false;
      console.error('health: firestore', e.message);
    }
  }
  res.setHeader('Cache-Control', 'no-store');
  res.status(report.ok ? 200 : 503).json(report);
}
