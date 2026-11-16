# Security findings: Gulf Limousine app

Hardening pass over `lib/`, `firestore.rules`, `functions/`, the Android
manifest and Firebase Hosting config. A read-only adversarial audit produced
the findings, and every Critical/High finding was checked against the code
before any fix. Fixes were applied on the working branch and covered by tests
(`firestore_tests/`, `test/`); the full change set is in
`security_remediation.patch`.

No hardcoded credentials were found. The Firebase API keys in
`lib/firebase_options.dart` and `google-services.json` are public identifiers
by design. The Gemini key default is a placeholder, so `SECRETS.local.md` is
not needed.

## Scorecard

| Severity | Found | Fixed | Partly fixed | Needs a decision or console work |
|---|---|---|---|---|
| Critical | 1 | 0 | 1 | 1 |
| High | 3 | 1 | 1 | 1 |
| Medium | 9 | 3 | 2 | 4 |
| Low | 7 | 5 | 0 | 2 |

Top weakness categories:
- Client-side enforcement and business logic: CWE-602, CWE-840, CWE-345
- Access control: CWE-284, CWE-639
- Input validation: CWE-20
- Personal data exposure: CWE-359, CWE-532

## Findings (most severe first)

| ID | Sev | CWE | Where | Issue | Status |
|---|---|---|---|---|---|
| SEC-001 | Critical | 602, 345 | `booking_service.dart` completeRental; payment screens; `firestore.rules` booking create | Payment is simulated on the device, so the client decides "paid" and the price | **Partly fixed**: rules now reject underpriced, pre-completed or evidence-carrying bookings. Real payment verification needs a gateway and server; decision pending |
| SEC-002 | High | 639, 840 | `firestore.rules` traffic violations; `traffic_violation_service.dart` pay | A customer can mark their own ticket paid | **Not fixed**: same simulated-payment design as SEC-001; changes behaviour |
| SEC-003 | High | 20, 639 | `firestore.rules` booking update | Customers could rewrite odometer, km bill, status, evidence videos and live location | **Fixed**: bill recomputed in rules; evidence write-once; status transitions limited; live location admin-only |
| SEC-004 | High (if built with a key) | 798, 598 | `gemini_chat_service.dart`, `odometer_service.dart` | A Gemini key built into the app is extractable and was sent in the URL | **Partly fixed**: key moved to the `x-goog-api-key` header. Moving the calls server-side needs Cloud Functions (Blaze plan) |
| SEC-005 | Medium | 345 | `firestore.rules` payments | Customers can create "paid" payment records | **Not fixed**: tied to SEC-001's simulated payments |
| SEC-006 | Medium | 284 | `firestore.rules` reviews and cars; `review_service.dart` | Forged reviews and car ratings | **Fixed**: one review per completed booking (doc id = booking id), owner-only, rating 1–5; car rating summary range-checked |
| SEC-007 | Medium | 284, 1427 | `firestore.rules` admin alerts; `gemini_chat_service.dart` | Fake admin alerts; prompt injection into the admin assistant | **Fixed**: alert type, size and booking ownership validated; alert text fenced as untrusted data in the prompt |
| SEC-008 | Medium | 287, 639 | `firestore.rules` email-based ownership | Bookings matched by an unverified email claim | **Partly fixed**: bookings can't be planted under another email. `email_verified` was not required, because that would hide admin-created bookings from email/password users |
| SEC-009 | Medium | 359 | Cloudinary unsigned preset | National ID and licence images are public URLs | **Console work**: use an `authenticated` delivery-type preset and serve admins signed URLs |
| SEC-010 | Medium | 434, 770 | Cloudinary unsigned preset | Anyone can upload to the account | **Console work**: restrict the preset (formats, size, folder), or sign uploads server-side |
| SEC-011 | Medium | 441 | `functions/` daily cleanup | Cleanup could delete any public ID a customer planted | **Partly fixed**: new bookings can't carry video fields and videos are write-once. A per-booking folder check needs a preset folder setting |
| SEC-012 | Medium | 346 | `main.dart`; `functions/index.js` | App Check not activated | **Console work**: register Play Integrity / App Attest / reCAPTCHA, then activate and enforce |
| SEC-013 | Medium | 256, 287 | `biometric_service.dart` | Biometric login stores the account password | **Not fixed**: needs a keystore-bound credential redesign |
| SEC-014 | Low | 915 | `firestore.rules` users | Customers could change their profile email or mark the profile complete without IDs | **Fixed** |
| SEC-015 | Low | 319, 530 | `AndroidManifest.xml` | Cleartext HTTP allowed; app data backed up | **Fixed**: `usesCleartextTraffic=false`, `allowBackup=false` |
| SEC-016 | Low | 321 | `android/app/build.gradle.kts` | Release builds signed with the debug key | **Ready on request**: the Play Store signing setup was written earlier and set aside for the demo |
| SEC-017 | Low | 1021, 693 | `firebase.json` hosting | No security headers on the web app | **Fixed**: X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy (a full CSP needs on-site testing) |
| SEC-018 | Low | 359 | `firestore.rules` chauffeurs | Any user could list chauffeur phone numbers | **Fixed**: admins only (customers get their chauffeur's details on the booking) |
| SEC-019 | Low | 532 | `booking_service.dart`, `cloudinary_service.dart`, `login_screen.dart`, `whatsapp_service.dart` | Personal data in release logs | **Fixed** |
| SEC-020 | Low | 20 | `video_viewer_screen.dart` | Customer-supplied video URLs loaded on admin devices | **Fixed**: only the app's own Cloudinary URLs play |

Not in the repo: Realtime Database and Storage rules. Check in the Firebase
console that both are locked down (deny all if unused).

## Dependency vulnerabilities

| Package | Scope | Installed | Advisory | Fixed in | Impact |
|---|---|---|---|---|---|
| (none) | `functions/` (deployed) | cloudinary 2.11.0, firebase-admin 14.5.1, firebase-functions 7.4.0 | `npm audit`: 0 vulnerabilities | – | – |
| @grpc/grpc-js | `firestore_tests/` (dev only) | ≤1.13.5 | GHSA-m9gg-hp2v-232j, GHSA-f596-whhp-79r4 (high) | later firebase / firebase-tools | Test tooling only, never deployed |
| glob, minimatch, uuid, @opentelemetry/core, gaxios, rimraf, archiver | `firestore_tests/` (dev only) | various | moderate advisories | later firebase-tools | Test tooling only, never deployed |
| Dart packages | app | per `pubspec.lock` | no known advisories | – | – |

## Remediation log

| ID | Fix | Where |
|---|---|---|
| SEC-001 (partial) | `isValidNewCustomerBooking()`: only checkout's fields; status pending/confirmed; total = price × days; price > 0; caller's own uid and email; server timestamp | `firestore.rules` (security_remediation.patch) |
| SEC-003 | `hasValidUserBookingValues()` and helpers: km bill recomputed (120 km/day, 5 EGP/km); odometer, videos and agreement write-once; completed/cancelled transitions; rating 1–5; live location removed from customer keys | `firestore.rules` |
| SEC-004 (partial) | Gemini key in `x-goog-api-key` header | `gemini_chat_service.dart`, `odometer_service.dart` |
| SEC-006 | Review create validated; doc id = booking id; car rating range-checked | `firestore.rules`, `review_service.dart` |
| SEC-007 | Alert create validated; alerts fenced as untrusted in the prompt | `firestore.rules`, `gemini_chat_service.dart` |
| SEC-008 (partial) | Booking create requires the caller's token email | `firestore.rules` |
| SEC-014 | Profile email must be the caller's; completion requires ID photo URLs | `firestore.rules` |
| SEC-015 | Cleartext and backups off | `AndroidManifest.xml` |
| SEC-017 | Hosting security headers | `firebase.json` |
| SEC-018 | Chauffeurs read admin-only | `firestore.rules` |
| SEC-019 | PII removed from or guarded in logs | `booking_service.dart`, `cloudinary_service.dart`, `login_screen.dart`, `whatsapp_service.dart` |
| SEC-020 | `CloudinaryService.isOwnAssetUrl` gate in the video viewer (+ tests) | `cloudinary_service.dart`, `video_viewer_screen.dart` |

Tests: `firestore_tests/rules.test.js` has 47 emulator tests. Each blocked
attack has a test, and each real app write is replayed to prove it still
passes. CI runs them on every pull request.

## Patch review

An independent security review read the patch against the original code.
Round 1 verdicts, then what changed in response.

| Finding | Round 1 verdict | Reviewer's reason | Round 1 change | Now |
|---|---|---|---|---|
| SEC-001 | PARTIAL | Price, dates and payment are still the client's word | Agreement must be signed by the caller (`signedBy == uid`) | Partly fixed; the rest needs real payments (decision pending) |
| SEC-003 | PARTIAL | Return km could be written without the bill; pickup evidence could be rewritten at return; trips could be cancelled after pickup; timestamps were client-chosen | Bill fields required at trip end; only `end*` odometer keys may change; no cancel after pickup; `updatedAt`/`cancelledAt` must be server time; `billableDays` clamped to whole days 1–3650; `final_amount` uses `total_amount` default 0 | Resolved for the reviewed paths. Residual: the customer still supplies both odometer readings (photos are the evidence) |
| SEC-004 | RESOLVES | Key no longer in URLs or logs | – | Partly fixed overall (server-side needs Blaze) |
| SEC-006 | INTRODUCES-RISK | Customers whose booking an admin entered (email only, no `userId`) could no longer review | Review and alert ownership use `ownsBooking()` (uid **or** token email); reviewer uid comes from `currentUser` | Resolved; test added |
| SEC-007 | PARTIAL | Alert text could close the prompt fence | Alert fields have `<` and `>` stripped before fencing | Resolved |
| SEC-008 | PARTIAL | Unverified email still grants access to email-matched bookings | – (requiring `email_verified` hides admin-entered bookings from existing users) | Needs a decision |
| SEC-014 | PARTIAL | Profile email check broke FCM token saves when the stored email differed; any string counted as an ID URL | Email checked only when it changes; ID URLs must be `https://` | Resolved; tests added |
| SEC-015 | RESOLVES | – | – | Fixed |
| SEC-017 | RESOLVES | – | – | Fixed |
| SEC-018 | RESOLVES | – | – | Fixed |
| SEC-019 | PARTIAL | WhatsApp service still logged phone numbers | Guarded with `kDebugMode` | Resolved |
| SEC-020 | RESOLVES | – | – | Fixed |

Each round-1 change has an emulator test (`firestore_tests/rules.test.js`,
section "review round 1 fixes"), and the app's own writes are replayed to
show they still pass: 47/47 pass, `flutter analyze --fatal-infos` is clean
and `flutter test` passes.

Still open, because they change behaviour or need console/paid work:
- Price isn't checked against `cars/{id}` and days aren't checked against the
  dates (favourites store a copy of the price, so a strict check would break
  booking from favourites until that copy is refreshed).
- Simulated payments: SEC-001, SEC-002, SEC-005.
- `email_verified` not required: SEC-008.
- Cloudinary preset hardening and private ID images: SEC-009, SEC-010, SEC-011.
- App Check: SEC-012. Biometric password storage: SEC-013.
- Release signing: SEC-016 (ready on request).
- Realtime Database and Storage rules aren't in the repo; check them in the console.
