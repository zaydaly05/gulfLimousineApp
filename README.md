# Gulf Limousine Travel

Flutter app for Gulf Limousine Travel luxury car rentals in Cairo, backed by
Firebase (Auth, Firestore, Messaging) and Cloudinary for images and videos.

- Android application ID: `com.gulflimousine.travel`
- Cloud Functions (optional, Blaze plan): see [`functions/README.md`](functions/README.md)

## Development

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

### AI features (free Gemini key)

The odometer reader (photo of the dashboard → km reading for the bill) and the
AI assistant use Google Gemini. A free key from Google AI Studio is enough: no
card, no Firebase upgrade.

1. Open <https://aistudio.google.com/apikey> and click **Create API key**.
2. In Google Cloud console → **APIs & Services → Credentials**, open the key
   and under **API restrictions** allow only the *Generative Language API*.
3. In the Firebase console → Firestore, create the document **`config/ai`**
   with a string field `geminiApiKey` holding the key. Optionally add
   `geminiModel` (default `gemini-flash-latest`, which always points at
   Google's current Flash model).

Any signed-in user can read `config/ai`, just as they could extract a key
built into the app, so use a key restricted to Gemini only. Firestore rules
let only admins change it. Without a key, the app falls back to manual km
entry and the built-in FAQ assistant.

### Payments

- **InstaPay and wallet transfers**: customers send money to the InstaPay
  address / wallet number in `config/payments` and enter the transaction ID.
  Admins confirm or reject each one on the **Payments** screen.
- **Card and instant wallet (Paymob)**: see
  [payments_server/README.md](payments_server/README.md). Until it's set up,
  the card option is the simulated demo checkout.

### Running against local emulators

To try changes without touching the live project, start the Auth and
Firestore emulators (they use `firestore.rules` from this repo) and point
the app at them:

```bash
cd firestore_tests && npm ci && cd ..
firestore_tests/node_modules/.bin/firebase emulators:start --only auth,firestore --project gulf-limousine-travel-1d4c7
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

The emulators start empty: sign up in the app, then set `role: "admin"` on
your `users/{uid}` document in the emulator to see the admin screens.
Release builds ignore this switch.

## Releasing to Google Play

### 1. Create the upload keystore (once)

Run this on your own computer, **outside** the repository. `keytool` ships with
Java and with Android Studio (`<Android Studio>/jbr/bin/keytool`).

```bash
keytool -genkey -v -keystore gulf-limousine-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Choose a strong password and store it in a password manager.
- **Back up the `.jks` file** (password manager, encrypted cloud drive). With
  Play App Signing a lost upload key can be reset through Play support, but it
  takes days.
- Never commit the keystore or its passwords. `*.jks`, `*.keystore` and
  `key.properties` are git-ignored.

### 2. Point the build at it

Copy `android/key.properties.example` to `android/key.properties` and fill in
the path and passwords. Without this file, release builds fall back to the
debug key, which Google Play rejects.

### 3. Build the app bundle

Google Play takes an Android App Bundle (`.aab`), not an APK:

```bash
flutter build appbundle --release
```

The bundle is written to `build/app/outputs/bundle/release/app-release.aab`.

Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`) before every upload: the
number after `+` must increase each time.

### 4. Upload

In the Play Console, create the app, keep **Play App Signing** enabled (the
default), and upload the `.aab` to a testing track first.

### 5. Register signing certificates with Firebase

Google Sign-In only works for signing certificates registered in Firebase.
Add both SHA-1 fingerprints to the Android app in Firebase (Project settings
→ Your apps → `com.gulflimousine.travel` → Add fingerprint):

- **Upload key:** `keytool -list -v -keystore gulf-limousine-upload.jks -alias upload`
- **App signing key** (the one Google signs installs with): Play Console →
  Test and release → App integrity → App signing.

Then download the updated `google-services.json` into `android/app/`.
