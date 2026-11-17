// POST /api/availability  { carId, pickupDay, returnDay }  (signed-in users)
// -> { colors: [{ name, total, available }], totalAvailable, days, pricePerDay }
//
// How many cars of each colour are free for those dates. Reveals counts
// only, never who booked them.
import { db } from '../lib/firebase.js';
import { caller } from '../lib/caller.js';
import { applyCors } from '../lib/http.js';
import { availability, isDay, rentalDays } from '../lib/fleet.js';

export default async function handler(req, res) {
  applyCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST' });
  if (!(await caller(req))) return res.status(401).json({ error: 'Please sign in again.' });

  const { carId, pickupDay, returnDay } = req.body ?? {};
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(String(carId ?? '')) || !isDay(pickupDay) || !isDay(returnDay) || returnDay < pickupDay) {
    return res.status(400).json({ error: 'Choose valid dates.' });
  }
  try {
    const store = db();
    const [carSnap, bookings] = await Promise.all([
      store.collection('cars').doc(carId).get(),
      store.collection('bookings').where('car_id', '==', carId).get(),
    ]);
    if (!carSnap.exists) return res.status(404).json({ error: 'Car not found.' });
    const car = carSnap.data();
    const result = availability(car, bookings.docs.map((d) => ({ id: d.id, ...d.data() })), { start: pickupDay, end: returnDay });
    return res.status(200).json({
      ...result,
      days: rentalDays(pickupDay, returnDay),
      pricePerDay: Number(car.price_per_day) || 0,
    });
  } catch (e) {
    console.error('availability failed', e.message);
    return res.status(500).json({ error: 'Could not check availability. Try again.' });
  }
}
