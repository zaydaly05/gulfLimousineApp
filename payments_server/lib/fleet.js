// Fleet availability and colour allocation. Pure functions: no Firebase.
//
// Dates are calendar days in Cairo ("YYYY-MM-DD"). Both the pickup and the
// return day count, as in the app's RentalDates.rentalDays, so two
// bookings overlap when they share at least one day.

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const ZONE = 'Africa/Cairo';

/** Unpaid online bookings hold their cars this long, then free them. */
export const UNPAID_HOLD_MINUTES = 30;

export function isDay(value) {
  if (typeof value !== 'string' || !DAY.test(value)) return false;
  const [y, m, d] = value.split('-').map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

/** Days since 1970-01-01 for a "YYYY-MM-DD" day. */
export function dayNumber(day) {
  const [y, m, d] = day.split('-').map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / 86400000);
}

export function addDays(day, n) {
  return new Date((dayNumber(day) + n) * 86400000).toISOString().slice(0, 10);
}

/** The Cairo calendar day of an instant. */
export function cairoDay(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONE, year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(date);
}

/** The instant Cairo's clocks read 00:00 on [day]. */
export function cairoMidnight(day) {
  const [y, m, d] = day.split('-').map(Number);
  const noon = new Date(Date.UTC(y, m - 1, d, 12));
  const name = new Intl.DateTimeFormat('en-US', { timeZone: ZONE, timeZoneName: 'shortOffset' })
    .formatToParts(noon).find((p) => p.type === 'timeZoneName')?.value ?? 'GMT+2';
  const match = name.match(/GMT([+-]\d+)(?::(\d+))?/);
  const offsetMinutes = match ? Number(match[1]) * 60 + Math.sign(Number(match[1])) * Number(match[2] ?? 0) : 120;
  return new Date(Date.UTC(y, m - 1, d) - offsetMinutes * 60000);
}

/** Billable days, both ends counted; never less than 1. */
export function rentalDays(pickupDay, returnDay) {
  return Math.max(1, dayNumber(returnDay) - dayNumber(pickupDay) + 1);
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

/** First and last day a booking holds its cars, or null if unknown. */
export function bookingSpan(booking) {
  let start = isDay(booking.pickupDay) ? booking.pickupDay : null;
  let end = isDay(booking.returnDay) ? booking.returnDay : null;
  if (!start) {
    const d = toDate(booking.pickupDate) ?? toDate(booking.startDate);
    if (d) start = cairoDay(d);
  }
  if (!end) {
    const d = toDate(booking.returnDate) ?? toDate(booking.endDate);
    if (d) end = cairoDay(d);
    else if (start) end = addDays(start, Math.max(1, Number(booking.days) || 1) - 1);
  }
  return start && end ? { start, end } : null;
}

/** Whether a booking still holds its cars at [now]. */
export function holdsCars(booking, now = new Date()) {
  if (!['pending', 'confirmed'].includes(booking.status)) return false;
  if (['completed', 'cancelled'].includes(booking.tripStatus)) return false;
  if (booking.payment_status === 'rejected') return false;
  if (['unpaid', 'failed'].includes(booking.payment_status)) {
    // heldAt is renewed each time the customer starts paying.
    const created = toDate(booking.heldAt) ?? toDate(booking.createdAt);
    if (created && now - created > UNPAID_HOLD_MINUTES * 60000) return false;
  }
  return true;
}

export function overlaps(a, b) {
  return dayNumber(a.start) <= dayNumber(b.end) && dayNumber(b.start) <= dayNumber(a.end);
}

/**
 * The model's colours. A car saved before colours existed counts as one
 * car of an unnamed colour; a car switched off ("available: false") has
 * none to rent.
 */
export function fleetColors(car) {
  if (car?.available === false) return [];
  const list = Array.isArray(car?.colors) ? car.colors : [];
  const colors = list
    .filter((c) => c && typeof c.name === 'string' && c.name.trim() && Number.isInteger(c.count) && c.count >= 0)
    .map((c) => ({ name: c.name.trim(), count: c.count }));
  return colors.length ? colors : (Array.isArray(car?.colors) && list.length ? [] : [{ name: '', count: 1 }]);
}

/**
 * Cars of each colour still free between [start] and [end], given the
 * model's other bookings. Bookings made before colours existed (no
 * allocation) take cars from the total without a colour.
 */
export function availability(car, bookings, span, { excludeId, now = new Date() } = {}) {
  const colors = fleetColors(car);
  const usedBy = new Map();
  let unassigned = 0;
  for (const b of bookings) {
    if (b.id === excludeId || !holdsCars(b, now)) continue;
    const s = bookingSpan(b);
    if (!s || !overlaps(s, span)) continue;
    const alloc = Array.isArray(b.allocatedColors) ? b.allocatedColors : null;
    if (alloc && alloc.length) {
      for (const a of alloc) usedBy.set(a.name, (usedBy.get(a.name) ?? 0) + (Number(a.count) || 0));
    } else {
      unassigned += Math.max(1, Number(b.quantity) || 1);
    }
  }
  const perColor = colors.map((c) => ({
    name: c.name,
    total: c.count,
    available: Math.max(0, c.count - (usedBy.get(c.name) ?? 0)),
  }));
  const total = colors.reduce((s, c) => s + c.count, 0);
  const used = [...usedBy.values()].reduce((s, n) => s + n, 0) + unassigned;
  const byColour = perColor.reduce((s, c) => s + c.available, 0);
  return { colors: perColor, totalAvailable: Math.max(0, Math.min(total - used, byColour)) };
}

/**
 * Assigns [quantity] cars: first from the customer's preferred colours in
 * order, then from any other colour still free. Returns null when there
 * aren't enough cars.
 */
export function allocate(avail, preferences, quantity) {
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > avail.totalAvailable) return null;
  const left = new Map(avail.colors.map((c) => [c.name, c.available]));
  const order = [
    ...preferences.filter((p) => left.has(p)),
    ...avail.colors.map((c) => c.name).filter((n) => !preferences.includes(n)),
  ];
  const result = [];
  let need = quantity;
  for (const name of [...new Set(order)]) {
    if (need === 0) break;
    const take = Math.min(need, left.get(name) ?? 0);
    if (take > 0) {
      result.push({ name, count: take });
      need -= take;
    }
  }
  return need === 0 ? result : null;
}

/**
 * Whether [booking]'s own cars (its allocated colours, or just its quantity
 * for older bookings) are still free, ignoring the booking itself.
 */
export function stillAvailable(car, bookings, booking, now = new Date()) {
  const span = bookingSpan(booking);
  if (!span) return false;
  const avail = availability(car, bookings, span, { excludeId: booking.id, now });
  const quantity = Math.max(1, Number(booking.quantity) || 1);
  if (avail.totalAvailable < quantity) return false;
  const alloc = Array.isArray(booking.allocatedColors) ? booking.allocatedColors : [];
  return alloc.every((a) => (avail.colors.find((c) => c.name === a.name)?.available ?? 0) >= a.count);
}
