// Cloudinary deletes need a signed request (API key + secret). The secret must
// never be in the mobile app, so deletes run here instead.
//
// One-time setup (Blaze plan required for Cloud Functions):
//   firebase functions:secrets:set CLOUDINARY_API_KEY
//   firebase functions:secrets:set CLOUDINARY_API_SECRET
//   firebase deploy --only functions

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret, defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const cloudinary = require('cloudinary').v2;

const { retentionCutoff, conditionVideos } = require('./video_retention');

initializeApp();
const db = getFirestore();

const cloudName = defineString('CLOUDINARY_CLOUD_NAME', { default: 'delnnzcph' });
const apiKey = defineSecret('CLOUDINARY_API_KEY');
const apiSecret = defineSecret('CLOUDINARY_API_SECRET');
const secrets = [apiKey, apiSecret];

const RESOURCE_TYPES = new Set(['image', 'video']);

function configureCloudinary() {
  cloudinary.config({
    cloud_name: cloudName.value(),
    api_key: apiKey.value(),
    api_secret: apiSecret.value(),
    secure: true,
  });
}

/** Deletes one asset. "not found" counts as success (already gone). */
async function destroyAsset(publicId, resourceType) {
  const res = await cloudinary.uploader.destroy(publicId, {
    resource_type: resourceType,
    invalidate: true,
  });
  if (res.result !== 'ok' && res.result !== 'not found') {
    throw new Error(`Cloudinary destroy ${publicId}: ${res.result}`);
  }
  return res.result;
}

/**
 * Callable from the app: delete a Cloudinary asset. Admin only, matching who
 * deletes in the app (car images, condition videos).
 * data: { publicId: string, resourceType?: 'image' | 'video' }
 */
exports.deleteCloudinaryAsset = onCall({ secrets }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');

  const user = await db.collection('users').doc(uid).get();
  if (user.get('role') !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }

  const publicId = request.data?.publicId;
  const resourceType = request.data?.resourceType ?? 'image';
  if (typeof publicId !== 'string' || publicId.trim() === '') {
    throw new HttpsError('invalid-argument', 'publicId is required.');
  }
  if (!RESOURCE_TYPES.has(resourceType)) {
    throw new HttpsError('invalid-argument', 'resourceType must be image or video.');
  }

  configureCloudinary();
  try {
    return { result: await destroyAsset(publicId, resourceType) };
  } catch (e) {
    logger.error('Cloudinary delete failed', { publicId, resourceType, error: e.message });
    throw new HttpsError('internal', 'Could not delete the file.');
  }
});

/**
 * Daily: delete condition videos 3 days after a booking's return date, then
 * remove the links from the booking. Runs whether or not anyone opens the app.
 */
exports.cleanupExpiredConditionVideos = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'Africa/Cairo', secrets },
  async () => {
    configureCloudinary();
    const snapshot = await db
      .collection('bookings')
      .where('returnDate', '<', Timestamp.fromDate(retentionCutoff(new Date())))
      .get();

    let cleaned = 0;
    for (const doc of snapshot.docs) {
      const videos = conditionVideos(doc.data());
      if (videos.length === 0) continue;
      try {
        for (const { publicId } of videos) {
          if (publicId) await destroyAsset(publicId, 'video');
        }
        // Only unlink after every delete succeeded, so a failure is retried
        // on the next run instead of leaving an orphaned file.
        const update = { updatedAt: FieldValue.serverTimestamp() };
        for (const { field } of videos) update[field] = FieldValue.delete();
        await doc.ref.update(update);
        cleaned++;
      } catch (e) {
        logger.error('Video cleanup failed', { bookingId: doc.id, error: e.message });
      }
    }
    logger.info(`Cleaned condition videos on ${cleaned} booking(s).`);
  },
);
