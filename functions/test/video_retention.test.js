const test = require('node:test');
const assert = require('node:assert/strict');
const { retentionCutoff, conditionVideos, RETENTION_DAYS } = require('../video_retention');

test('cutoff is the retention window before now', () => {
  const now = new Date('2026-05-10T12:00:00Z');
  const cutoff = retentionCutoff(now);
  assert.equal(now - cutoff, RETENTION_DAYS * 24 * 60 * 60 * 1000);
});

test('no videos on a booking', () => {
  assert.deepEqual(conditionVideos({ status: 'completed' }), []);
});

test('lists pickup and return videos with their public ids', () => {
  assert.deepEqual(
    conditionVideos({
      pickupVideo: { url: 'u1', publicId: 'p1' },
      returnVideo: { url: 'u2', publicId: 'p2' },
    }),
    [
      { field: 'pickupVideo', publicId: 'p1' },
      { field: 'returnVideo', publicId: 'p2' },
    ],
  );
});

test('a video without a public id is still unlinked but not deleted', () => {
  assert.deepEqual(conditionVideos({ returnVideo: { url: 'u', publicId: '' } }), [
    { field: 'returnVideo', publicId: null },
  ]);
});
