# Push notifications

The FCM payloads reelpin-api sends and reelpin-app opens, plus device token
registration. This file is an identical copy in both repos at
`.claude/contracts/push-notifications.md`; change both together.

| Side | Where the truth lives |
|------|-----------------------|
| server payloads | reelpin-api `app/services/notification_service.py` (`reel_ready`, `collection_update`, campaign `feature_update`), `app/tasks.py` (reminder and price-drop pushes) |
| server send | reelpin-api `app/services/notifications.py`: Android channel id, APNs category, collapse key |
| server tokens | reelpin-api `app/main.py`: `POST` and `DELETE /api/v1/device-push-tokens`, `POST /api/v1/notifications/{id}/opened` |
| client parse | reelpin-app `lib/data_models/notifications/app_notification.dart` (which shapes are accepted), `lib/services/notifications/notification_tap_handler.dart` |
| client display and routing | reelpin-app `lib/services/notifications/notification_service.dart`, `lib/screens/app_shell/authenticated_shell.dart` |
| client tokens | reelpin-app `lib/services/sharing/push_registration_service.dart` |
| client native | reelpin-app `android/app/src/main/AndroidManifest.xml` (default channel id), `ios/Runner/AppDelegate.swift` (APNs token handled by hand) |

## Rule

Every data value is a string. The client accepts a payload only when `type`,
`target`, `schema_version`, and the ids that shape needs are all present;
anything else counts as malformed and opens Home. So a new push type, target, or
required key is a change on both sides, and changing `schema_version` on the
server breaks taps on every installed app version. The Android channel id must
match in `notifications.py` and the manifest.

## Known drift when this was written (2026-10-15)

- Reminder and price-drop pushes (`app/tasks.py`) carry only their own ids, no `type` or `target`, so the app treats them as malformed and opens Home.
