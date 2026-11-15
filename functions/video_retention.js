// Pure helpers for the condition-video retention policy, kept free of
// Firebase so they can be unit tested.

/** Condition videos are kept this long after the booking's return date. */
const RETENTION_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;
const VIDEO_FIELDS = ['pickupVideo', 'returnVideo'];

/**
 * How far back past the cutoff each run looks. Older bookings were handled by
 * earlier daily runs, so re-reading them every day would only add cost; the
 * margin still covers runs missed for up to this many days.
 */
const LOOKBACK_DAYS = 30;

/** Return dates before this moment are past the retention window. */
function retentionCutoff(now) {
  return new Date(now.getTime() - RETENTION_DAYS * DAY_MS);
}

/** Return-date range [from, to) the daily cleanup scans. */
function cleanupWindow(now) {
  const to = retentionCutoff(now);
  return { from: new Date(to.getTime() - LOOKBACK_DAYS * DAY_MS), to };
}

/**
 * Lists the condition videos stored on a booking.
 * @param {object} booking Firestore booking data.
 * @returns {{field: string, publicId: string|null}[]}
 */
function conditionVideos(booking) {
  return VIDEO_FIELDS.filter((field) => booking[field] != null).map((field) => {
    const publicId = booking[field].publicId;
    return {
      field,
      publicId: typeof publicId === 'string' && publicId !== '' ? publicId : null,
    };
  });
}

module.exports = {
  RETENTION_DAYS,
  LOOKBACK_DAYS,
  VIDEO_FIELDS,
  retentionCutoff,
  cleanupWindow,
  conditionVideos,
};
