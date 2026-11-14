# Cloud Functions

Cloudinary only accepts **signed** deletes, and the API secret must never ship
inside the app, so deletes run here.

| Function | Trigger | What it does |
| --- | --- | --- |
| `deleteCloudinaryAsset` | Callable from the app | Deletes one image or video. Admins only. Used when a car is deleted or its image replaced. |
| `cleanupExpiredConditionVideos` | Daily, 03:00 Cairo time | Deletes pickup/return condition videos 3 days after a booking's return date, then removes the links from the booking. |

## One-time setup

Cloud Functions need the Firebase **Blaze** (pay-as-you-go) plan.

Find the API key and secret in the Cloudinary console (Settings → API Keys),
then store them as secrets. They are never committed or shipped in the app:

```bash
firebase functions:secrets:set CLOUDINARY_API_KEY
firebase functions:secrets:set CLOUDINARY_API_SECRET
```

The cloud name defaults to `delnnzcph`. Override it with a
`functions/.env` file containing `CLOUDINARY_CLOUD_NAME=...` if it changes.

## Deploy

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

## Test

```bash
cd functions && npm test
```
