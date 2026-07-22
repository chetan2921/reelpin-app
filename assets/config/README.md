Place a git-ignored `local.env` file in this folder for local-only build and run config:

```text
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
API_BASE_URL=https://dev-api-64-227-168-119.nip.io
MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

Use `tool/reelpin_flutter.sh` so the values are passed as Dart defines. This folder is not packaged as a Flutter asset because `local.env` must not be bundled into release builds.
