# payments_server: Paymob checkout

Three small serverless functions that let the app take card and mobile-wallet
payments through [Paymob](https://paymob.com). They run on Vercel's free
Hobby plan. No card is needed, and Firebase stays on the free Spark plan.

| Endpoint | Called by | Does |
|---|---|---|
| `POST /api/create-intention` | the app | Checks the caller's Firebase ID token and that the booking is theirs and unpaid. Reads the price from Firestore (and checks it against the car's price), creates a Paymob intention, returns the hosted checkout link. |
| `POST /api/paymob-webhook` | Paymob | Verifies Paymob's HMAC signature, then marks the booking paid and confirmed (or failed). Each Paymob transaction is recorded once in `paymob_events`, so retries are harmless. |
| `GET /api/return` | the customer's browser | "Return to the app" page after checkout. Changes nothing. |
| `GET /api/health` | you | Configuration check: which variables are set, whether the Firebase key matches the project and reaches Firestore, Paymob key modes. Never shows a value. |

The app never sees the Paymob secret key and never decides the amount or the
result. InstaPay transfers don't go through here: InstaPay has no merchant
API, so the app records the transaction ID and an admin confirms it on the
Payments screen.

## One-time setup (about 15 minutes)

### 1. Paymob test account (free)

1. Sign up at <https://accept.paymob.com> (test mode is free and needs no
   company documents).
2. **Settings → API Keys**: note the **Secret key** (`sk_test_…`), the
   **Public key** (`pk_test_…`) and the **HMAC secret**.
3. **Settings → Payment Integrations**: note the **test** Integration IDs for
   *Online Card* and *Mobile Wallet*.

### 2. Firebase service account

Firebase console → Project settings → **Service accounts** → *Generate new
private key*. This downloads a JSON file. Keep it private: it grants admin
access to the database.

### 3. Deploy on Vercel (free, no card)

1. Sign in at <https://vercel.com> with GitHub → **Add New… → Project** →
   import this repository.
2. Set **Root Directory** to `payments_server`. Leave the framework preset as
   *Other*.
3. Add these **Environment Variables**:

   | Name | Value |
   |---|---|
   | `PAYMOB_SECRET_KEY` | `sk_test_…` |
   | `PAYMOB_PUBLIC_KEY` | `pk_test_…` |
   | `PAYMOB_HMAC_SECRET` | the HMAC secret |
   | `PAYMOB_INTEGRATION_IDS` | card and wallet IDs, comma-separated, e.g. `4567890,4567891` |
   | `FIREBASE_SERVICE_ACCOUNT` | the whole JSON file's contents |

4. **Deploy**. Note the URL, e.g. `https://gulf-payments.vercel.app`.

### 4. Tell the app

In the Firebase console → Firestore, create the document **`config/payments`**
(collection `config`, document ID `payments`) with these fields:

| Field | Example |
|---|---|
| `paymentsServerUrl` | `https://gulf-payments.vercel.app` |
| `instapayAddress` | `yourname@instapay` |
| `walletNumber` | `01XXXXXXXXX` (receives manual wallet transfers) |
| `walletName` | `Gulf Limousine` (optional) |

Restart the app. Checkout now shows **Credit / Debit Card (Paymob)** and
**Mobile Wallet (instant)**.

## Testing a payment (no real money)

- Wallet: number `01010101010`, MPIN `123456`, OTP `123456`
- Cards: use the test cards in the Paymob dashboard or Paymob's docs

The app shows these hints automatically while test keys are in use.

## Going live later

Live mode needs a registered business (Paymob asks for company documents)
and Paymob charges a fee per transaction. Swap the four `PAYMOB_*` values for
live ones; nothing else changes.

## Development

```bash
npm install
npm test                 # unit tests (HMAC, booking rules)
npm run test:emulators   # both endpoints against the Firebase emulators
```

`test:emulators` uses the Firebase CLI installed in `../firestore_tests`
(`cd ../firestore_tests && npm ci` first) and Java 21.
