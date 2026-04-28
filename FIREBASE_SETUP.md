# Firebase Setup

This app now stores user app data in Firebase Cloud Firestore instead of the
old Hive/local database. Runtime services keep small in-memory caches for the
current signed-in user so repeated reads do not hit the network every time.

## Current Project

This checkout is configured for Firebase project `halaph-d4eaa`.

Configured pieces:

- FlutterFire generated `lib/firebase_options.dart`.
- Android uses `android/app/google-services.json`.
- iOS uses `ios/Runner/GoogleService-Info.plist`.
- macOS uses `macos/Runner/GoogleService-Info.plist`.
- Email/Password Authentication is enabled.
- Firestore rules and indexes have been deployed.
- Hive/local database dependencies have been removed.

## Firebase Services

For a different Firebase project:

1. Create a Firebase project on the Spark plan.
2. Enable Authentication with the Email/Password provider.
3. Create a Cloud Firestore database.
4. Run FlutterFire configuration for this Flutter project.

Official setup guide: https://firebase.google.com/docs/flutter/setup

## Configure This App

Recommended:

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=your-project-id
```

This app prefers `lib/firebase_options.dart` when it exists. You can still add
Firebase keys to `.env` if you need local overrides:

```env
FIREBASE_API_KEY=your-api-key
FIREBASE_APP_ID=your-app-id
FIREBASE_MESSAGING_SENDER_ID=your-sender-id
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your-project-id.firebasestorage.app
FIREBASE_MEASUREMENT_ID=your-web-measurement-id
FIREBASE_IOS_BUNDLE_ID=com.example.halaph
FIREBASE_ANDROID_CLIENT_ID=
```

Do not commit real production secrets or local `.env` files if you make this
repo public.

## Firestore Data Shape

Data is stored per signed-in Firebase user:

```text
users/{firebaseUid}/sync/profile
users/{firebaseUid}/sync/favorites
users/{firebaseUid}/sync/friends
publicProfiles/{friendCode}
sharedPlans/{planId}
```

Plans, favorites, friends, and profile codes are read and written through
Firestore. Friend codes are published to `publicProfiles` so another signed-in
user can add a real account by code. Plans are stored in `sharedPlans` with
`participantUids`, so every selected friend can load the same plan document.

## Firestore Rules

The repo includes these rules in `firestore.rules` and references them from
`firebase.json`:

The deployed rules keep `users/{uid}/sync/...` private to the owner, allow
signed-in users to read friend-code documents in `publicProfiles`, and allow
`sharedPlans/{planId}` reads/writes only for Firebase UIDs listed in that plan's
`participantUids`.

Deploy changes with:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project halaph-d4eaa
```

Firestore has free quota, but reads/writes are still metered. Check the current
quota before production use: https://firebase.google.com/docs/firestore/pricing
