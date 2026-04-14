# ReelPin

ReelPin is a Flutter app for saving short-form video links, processing them in the background, and organizing the results into something you can actually use later.

The app is built around a simple idea:

1. You find a reel worth keeping.
2. You share it to ReelPin.
3. The backend processes it asynchronously.
4. ReelPin sends a push notification when it is ready.
5. You open the app later and browse the saved reel, extracted details, map pins, and search results.

## What The App Includes

- Email and Google sign in with Supabase auth.
- A first-run onboarding flow.
- Background reel enqueue from the share sheet.
- Push notification support for completed reel processing.
- Home feed for saved reels.
- Discover screen with search, quick prompts, category browsing, recent saves, and date filtering.
- Reel detail screen with summary, facts, transcript, locations, people mentioned, and action items.
- Map screen with custom pins for extracted places.
- Nearby recall notifications for saved places when background geofencing is enabled.
- Theme persistence.
- Profile screen with collection stats and settings.

## Current Share Flow

On Android, sharing a reel to ReelPin uses a native share receiver that queues the backend job without opening the full Flutter UI flow.

On the app side, ReelPin does not wait for the reel to finish processing in the foreground. The backend worker completes the job, stores the reel, and sends a `reel_ready` push notification. When the app receives that notification, it refreshes saved reels so the finished content is visible when the user opens ReelPin.

## Nearby Recall

ReelPin can monitor saved places in the background and notify the user when they are near a place connected to a saved reel.

This relies on:

- notification permission
- location permission
- background geofencing support
- reels that include map-pinnable locations

On Android, the background location service uses a persistent system notification because the OS requires it for this kind of monitoring.

## Tech Stack

- Flutter
- Provider
- Supabase auth and profile storage
- Firebase Cloud Messaging
- flutter_local_notifications
- google_maps_flutter
- flutter_background_geofencing
- receive_sharing_intent

## Backend Expectations

This app expects a ReelPin backend that supports:

- processing jobs at `/api/v1/processing-jobs/reels`
- polling job status at `/api/v1/processing-jobs/<job_id>`
- saved reel APIs at `/api/v1/reels`
- search at `/api/v1/search`
- device push token registration at `/api/v1/device-push-tokens`

The current app is wired for the backend flow where the worker sends a push notification after a reel finishes processing successfully.

## Local Setup

### Prerequisites

- Flutter SDK
- Android Studio and/or Xcode
- A running ReelPin backend
- A Supabase project
- A Google Maps API key
- Firebase project files for push notifications

### Supabase Config

Create or update:

```text
assets/config/local.env
```

With values like:

```env
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
SUPABASE_REDIRECT_SCHEME=com.chetan.reelpin
SUPABASE_REDIRECT_HOST=login-callback
API_BASE_URL=https://YOUR_BACKEND/api/v1
```

### Android Maps Config

Create:

```text
android/local.properties
```

And include:

```properties
MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

### Firebase Config

Add the Firebase platform files that match the app package:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Without these files, push notifications will not work correctly on real devices.

### Android Release Signing

Release APK and bundle builds require:

```text
android/key.properties
```

With:

```properties
keyAlias=...
keyPassword=...
storeFile=...
storePassword=...
```

If `android/key.properties` is missing, release builds fail by design.

## Run The App

```bash
flutter pub get
flutter run
```

## Useful Commands

Analyze:

```bash
flutter analyze
```

Build a debug APK:

```bash
flutter build apk --debug
```

Build a release APK:

```bash
flutter build apk
```

## Main User Flows

### Save A Reel

1. Share a reel to ReelPin.
2. ReelPin queues the backend processing job.
3. The backend finishes processing asynchronously.
4. The user receives a `Reel pinned in ReelPin` notification.
5. The reel appears in Home, Discover, and Map when relevant.

### Browse Saved Reels

- Home shows the saved reel grid.
- Discover helps users search by phrase, category, or saved date.
- Map shows saved places that were extracted and geocoded.
- Reel detail shows the processed information for one saved reel.

### Nearby Recall

1. User grants notification and location permission.
2. ReelPin syncs geofence regions from saved map locations.
3. When the user is near a saved place, ReelPin sends a contextual reminder.

## Notes

- The app uses responsive sizing helpers for dense screens so layouts adapt better across device sizes.
- Push handling is set up for foreground, background, and app-open-from-notification cases.
- Android share handoff is optimized to avoid blocking the user while scrolling through reels.
