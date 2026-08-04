Place a git-ignored `local.env` file in this folder for local-only build and run config:

```text
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
API_BASE_URL=https://api-dev.reelpin.in
MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

Use `tool/reelpin.sh` for normal development and store builds. It delegates to
`tool/reelpin_flutter.sh`, which passes these values as Dart defines. Run
`tool/reelpin.sh --help` for the available commands.

This folder is not packaged as a Flutter asset because `local.env` must not be
bundled into release builds.
