// Extra-km billing. Same formula as the app's KmBillingService
// (lib/services/km_billing_service.dart) and firestore.rules
// (isKmBillCorrect): 120 km per day included, 5 EGP per extra km. Keep the
// three in step.
export const KM_PER_DAY = 120;
export const EXTRA_KM_RATE_EGP = 5;

/** Days as the app counts them: whole days, clamped to 1..3650. */
export function billableDays(raw) {
  const d = typeof raw === 'number' && Number.isFinite(raw) ? Math.trunc(raw) : 1;
  return Math.min(Math.max(d, 1), 3650);
}

/** The kmAllowance map stored on the booking. */
export function kmBill(startKm, endKm, rawDays) {
  const drivenKm = endKm - startKm;
  const allowedKm = KM_PER_DAY * billableDays(rawDays);
  const extraKm = drivenKm > allowedKm ? drivenKm - allowedKm : 0;
  return {
    kmPerDay: KM_PER_DAY,
    allowedKm,
    drivenKm,
    extraKm,
    extraKmRateEgp: EXTRA_KM_RATE_EGP,
    extraKmChargeEgp: extraKm * EXTRA_KM_RATE_EGP,
  };
}
