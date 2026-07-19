Place a git-ignored `local.env` file in this folder for local-only build and run config.

Use `tool/reelpin_flutter.sh` so the values are passed as Dart defines. This folder is not packaged as a Flutter asset because `local.env` must not be bundled into release builds.
