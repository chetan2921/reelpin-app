#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_WRAPPER="$ROOT_DIR/tool/reelpin_flutter.sh"
ARTIFACTS_ROOT="$ROOT_DIR/artifacts/releases"
ANDROID_APP_ID="com.chetanjain.reelpin"
IOS_APP_ID="com.chetan.reelpin"
IOS_SHARE_APP_ID="com.chetan.reelpin.ShareExtension"
IOS_APP_GROUP="group.com.chetan.reelpin"
IOS_TEAM_ID="QUPZH9T9R3"
ANDROID_TARGET_SDK="36"

VERSION=""
VERSION_NAME=""
BUILD_NUMBER=""

usage() {
  cat <<'USAGE'
Usage:
  tool/reelpin.sh doctor [android|ios|all]
  tool/reelpin.sh clean
  tool/reelpin.sh version
  tool/reelpin.sh verify
  tool/reelpin.sh run-dev [flutter run args]
  tool/reelpin.sh run-production [flutter run args]
  tool/reelpin.sh apk-dev
  tool/reelpin.sh apk-production
  tool/reelpin.sh playstore
  tool/reelpin.sh appstore
  tool/reelpin.sh stores

Commands:
  doctor          Check local config, signing files, SDKs, and store settings.
  clean           Run flutter clean. Saved release artifacts are not removed.
  version         Print the version and build number without changing them.
  verify          Run formatting, architecture, asset, analysis, and test checks.
  run-dev         Run with the development API base URL.
  run-production  Run with the production API base URL.
  apk-dev         Build a signed release APK that uses the development API.
  apk-production  Build a signed release APK that uses the production API.
  playstore       Verify and build a signed production Android App Bundle.
  appstore        Verify and build a signed production iOS IPA.
  stores          Verify once, then build both production store artifacts.

The script never changes the version in pubspec.yaml and never uploads files.
Release artifacts are copied to artifacts/releases/<version>/.

Examples:
  tool/reelpin.sh run-dev -d "iPhone 16 Pro"
  tool/reelpin.sh run-production -d emulator-5554
  tool/reelpin.sh apk-dev
  tool/reelpin.sh playstore
  tool/reelpin.sh appstore
USAGE
}

die() {
  printf 'reelpin: %s\n' "$*" >&2
  exit 1
}

step() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_file() {
  [[ -f "$1" ]] || die "Missing required file: ${1#"$ROOT_DIR/"}"
}

require_text() {
  local file="$1"
  local text="$2"
  local description="$3"
  grep -Fq "$text" "$file" || die "$description"
}

property_value() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '
    /^[[:space:]]*#/ { next }
    $1 ~ "^[[:space:]]*" wanted "[[:space:]]*$" {
      sub(/^[^=]*=/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print
      exit
    }
  ' "$file"
}

require_property() {
  local file="$1"
  local key="$2"
  local value
  value="$(property_value "$file" "$key")"
  [[ -n "$value" ]] || die "Missing $key in ${file#"$ROOT_DIR/"}."
  [[ "$value" != *"YOUR_"* ]] || die "$key still contains a placeholder in ${file#"$ROOT_DIR/"}."
}

read_version() {
  VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$ROOT_DIR/pubspec.yaml" | head -n 1)"
  [[ "$VERSION" == *+* ]] || die "pubspec.yaml version must use <version>+<build>, for example 1.0.9+15."

  VERSION_NAME="${VERSION%%+*}"
  BUILD_NUMBER="${VERSION#*+}"

  [[ -n "$VERSION_NAME" ]] || die "pubspec.yaml has an empty version name."
  [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "pubspec.yaml build number must be numeric."
}

find_android_tool() {
  local tool_name="$1"
  local sdk_root
  local candidate

  if command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
    return 0
  fi

  for sdk_root in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "${HOME:-}/Library/Android/sdk"; do
    [[ -n "$sdk_root" && -d "$sdk_root/build-tools" ]] || continue
    candidate="$(find "$sdk_root/build-tools" -type f -name "$tool_name" -perm -u+x 2>/dev/null | sort | tail -n 1)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

check_common_setup() {
  require_command flutter
  require_command dart
  require_file "$FLUTTER_WRAPPER"
  require_file "$ROOT_DIR/assets/config/local.env"
  require_file "$ROOT_DIR/lib/core/config/supabase_config.dart"

  require_text "$ROOT_DIR/lib/core/config/supabase_config.dart" "return 'com.chetanjain.reelpin';" \
    "SupabaseConfig must use the Android OAuth callback scheme com.chetanjain.reelpin."
  require_text "$ROOT_DIR/lib/core/config/supabase_config.dart" "return 'com.chetan.reelpin';" \
    "SupabaseConfig must use the iOS OAuth callback scheme com.chetan.reelpin."
  require_text "$ROOT_DIR/lib/core/config/supabase_config.dart" "redirectHost = 'login-callback'" \
    "SupabaseConfig must use the OAuth callback host login-callback."

  step "Checking development configuration"
  "$FLUTTER_WRAPPER" --reelpin-env=dev check-config

  step "Checking production configuration"
  "$FLUTTER_WRAPPER" --reelpin-env=production check-config
}

check_android_setup() {
  local key_properties="$ROOT_DIR/android/key.properties"
  local store_file
  local resolved_store_file

  require_command java
  require_command jarsigner
  require_file "$key_properties"
  require_file "$ROOT_DIR/android/app/google-services.json"

  require_property "$key_properties" keyAlias
  require_property "$key_properties" keyPassword
  require_property "$key_properties" storeFile
  require_property "$key_properties" storePassword

  store_file="$(property_value "$key_properties" storeFile)"
  if [[ "$store_file" == /* ]]; then
    resolved_store_file="$store_file"
  else
    resolved_store_file="$ROOT_DIR/android/app/$store_file"
  fi
  [[ -f "$resolved_store_file" ]] || die "Android keystore does not exist at the storeFile path from android/key.properties."

  require_text "$ROOT_DIR/android/app/google-services.json" "\"package_name\": \"$ANDROID_APP_ID\"" \
    "android/app/google-services.json does not contain package $ANDROID_APP_ID."
  require_text "$ROOT_DIR/android/app/build.gradle.kts" "applicationId = \"$ANDROID_APP_ID\"" \
    "Android applicationId must be $ANDROID_APP_ID."
  require_text "$ROOT_DIR/android/app/build.gradle.kts" "targetSdk = $ANDROID_TARGET_SDK" \
    "Android targetSdk must be $ANDROID_TARGET_SDK for the current Play requirement."
  require_text "$ROOT_DIR/android/app/src/main/AndroidManifest.xml" "android:scheme=\"com.chetanjain.reelpin\"" \
    "AndroidManifest.xml is missing the Supabase OAuth callback scheme."
  require_text "$ROOT_DIR/android/app/src/main/AndroidManifest.xml" "android:host=\"login-callback\"" \
    "AndroidManifest.xml is missing the Supabase OAuth callback host."

  find_android_tool apksigner >/dev/null || die "Android SDK build-tools are missing apksigner."
  printf 'Android signing and Firebase configuration are present.\n'
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

profile_is_installed() {
  local wanted_name="$1"
  local profile_dir
  local profile_file
  local decoded_profile

  for profile_dir in \
    "${HOME:-}/Library/MobileDevice/Provisioning Profiles" \
    "${HOME:-}/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
    [[ -d "$profile_dir" ]] || continue
    while IFS= read -r profile_file; do
      decoded_profile="$(openssl smime -verify -inform der -noverify -in "$profile_file" 2>/dev/null || true)"
      if [[ "$decoded_profile" == *"<string>$wanted_name</string>"* ]]; then
        return 0
      fi
    done < <(find "$profile_dir" -maxdepth 2 -type f -name '*.mobileprovision' -print)
  done

  return 1
}

check_ios_setup() {
  local identity_output
  local google_bundle_id
  local runner_profile
  local share_profile

  [[ "$(uname -s)" == "Darwin" ]] || die "App Store builds require macOS."
  require_command xcodebuild
  require_command xcrun
  require_command pod
  require_command security
  require_command codesign
  require_command plutil
  require_command openssl
  require_file "$ROOT_DIR/ios/ExportOptions.plist"
  require_file "$ROOT_DIR/ios/Runner/GoogleService-Info.plist"
  require_file "$ROOT_DIR/ios/Runner/Runner.entitlements"
  require_file "$ROOT_DIR/ios/Share Extension/Share Extension.entitlements"

  google_bundle_id="$(plist_value "$ROOT_DIR/ios/Runner/GoogleService-Info.plist" BUNDLE_ID || true)"
  [[ "$google_bundle_id" == "$IOS_APP_ID" ]] || die "GoogleService-Info.plist must use bundle ID $IOS_APP_ID."

  [[ "$(plist_value "$ROOT_DIR/ios/ExportOptions.plist" teamID || true)" == "$IOS_TEAM_ID" ]] || \
    die "ios/ExportOptions.plist must use Apple team $IOS_TEAM_ID."
  [[ "$(plist_value "$ROOT_DIR/ios/ExportOptions.plist" signingStyle || true)" == "manual" ]] || \
    die "ios/ExportOptions.plist must use manual signing."
  [[ "$(plist_value "$ROOT_DIR/ios/ExportOptions.plist" method || true)" == "app-store-connect" ]] || \
    die "ios/ExportOptions.plist must use the app-store-connect export method."

  require_text "$ROOT_DIR/ios/ExportOptions.plist" "<key>$IOS_APP_ID</key>" \
    "ExportOptions.plist is missing the Runner provisioning profile."
  require_text "$ROOT_DIR/ios/ExportOptions.plist" "<key>$IOS_SHARE_APP_ID</key>" \
    "ExportOptions.plist is missing the Share Extension provisioning profile."
  require_text "$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj" "PRODUCT_BUNDLE_IDENTIFIER = $IOS_APP_ID;" \
    "Runner bundle ID must be $IOS_APP_ID."
  require_text "$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj" "PRODUCT_BUNDLE_IDENTIFIER = $IOS_SHARE_APP_ID;" \
    "Share Extension bundle ID must be $IOS_SHARE_APP_ID."
  require_text "$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj" "CUSTOM_GROUP_ID = $IOS_APP_GROUP;" \
    "The iOS app group must be $IOS_APP_GROUP."
  require_text "$ROOT_DIR/ios/Runner/Info.plist" "<string>com.chetan.reelpin</string>" \
    "Runner Info.plist is missing the Supabase OAuth callback scheme."
  require_text "$ROOT_DIR/ios/Runner/Runner.entitlements" "<key>aps-environment</key>" \
    "Runner.entitlements is missing the push notification capability."
  require_text "$ROOT_DIR/ios/Runner/Runner.entitlements" "<key>com.apple.developer.applesignin</key>" \
    "Runner.entitlements is missing Sign in with Apple."
  require_text "$ROOT_DIR/ios/Runner/Runner.entitlements" "<key>com.apple.security.application-groups</key>" \
    "Runner.entitlements is missing the application group capability."
  require_text "$ROOT_DIR/ios/Share Extension/Share Extension.entitlements" "<key>com.apple.security.application-groups</key>" \
    "The Share Extension is missing the application group capability."

  runner_profile="$(plist_value "$ROOT_DIR/ios/ExportOptions.plist" "provisioningProfiles:$IOS_APP_ID" || true)"
  share_profile="$(plist_value "$ROOT_DIR/ios/ExportOptions.plist" "provisioningProfiles:$IOS_SHARE_APP_ID" || true)"
  [[ -n "$runner_profile" ]] || die "ExportOptions.plist does not name the Runner provisioning profile."
  [[ -n "$share_profile" ]] || die "ExportOptions.plist does not name the Share Extension provisioning profile."
  profile_is_installed "$runner_profile" || die "The iOS provisioning profile '$runner_profile' is not installed."
  profile_is_installed "$share_profile" || die "The iOS provisioning profile '$share_profile' is not installed."
  printf 'The App Store provisioning profiles are installed.\n'

  identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  [[ "$identity_output" == *"Apple Distribution"* && "$identity_output" == *"($IOS_TEAM_ID)"* ]] || \
    die "No usable Apple Distribution identity for team $IOS_TEAM_ID is installed. Import the distribution certificate and its private key into the login keychain."
  printf 'iOS signing, Firebase, bundle IDs, and capability settings are present.\n'
}

doctor() {
  local platform="${1:-all}"

  case "$platform" in
    android|ios|all) ;;
    *) die "Unknown doctor platform '$platform'. Use android, ios, or all." ;;
  esac

  check_common_setup
  if [[ "$platform" == "android" || "$platform" == "all" ]]; then
    step "Checking Android release setup"
    check_android_setup
  fi
  if [[ "$platform" == "ios" || "$platform" == "all" ]]; then
    step "Checking iOS release setup"
    check_ios_setup
  fi

  printf '\nReelPin %s setup is ready.\n' "$platform"
}

verify_project() {
  step "Checking Dart formatting"
  dart format --output=none --set-exit-if-changed lib test tool

  step "Checking required project files"
  dart run tool/verify_project.dart

  step "Checking architecture boundaries"
  dart run tool/check_architecture.dart

  step "Checking declared assets"
  dart run tool/check_assets.dart

  step "Running Flutter analysis"
  flutter analyze

  step "Running tests"
  flutter test
}

warn_if_dirty() {
  if command -v git >/dev/null 2>&1 && [[ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null || true)" ]]; then
    printf 'reelpin: warning: the build will include uncommitted repository changes.\n' >&2
  fi
}

prepare_store_build() {
  local platform="$1"

  doctor "$platform"
  warn_if_dirty

  step "Cleaning Flutter build output"
  flutter clean

  step "Installing Flutter dependencies"
  flutter pub get

  verify_project
}

artifact_directory() {
  read_version
  printf '%s/%s\n' "$ARTIFACTS_ROOT" "$VERSION"
}

verify_android_manifest() {
  local manifest="$ROOT_DIR/build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml"

  require_file "$manifest"
  require_text "$manifest" "package=\"$ANDROID_APP_ID\"" "Built Android package ID is not $ANDROID_APP_ID."
  require_text "$manifest" "android:versionCode=\"$BUILD_NUMBER\"" "Built Android version code does not match pubspec.yaml."
  require_text "$manifest" "android:versionName=\"$VERSION_NAME\"" "Built Android version name does not match pubspec.yaml."
  require_text "$manifest" "android:targetSdkVersion=\"$ANDROID_TARGET_SDK\"" "Built Android target SDK is not $ANDROID_TARGET_SDK."
  require_text "$manifest" "android:scheme=\"com.chetanjain.reelpin\"" "Built Android app is missing the Supabase OAuth callback scheme."
  require_text "$manifest" "android:host=\"login-callback\"" "Built Android app is missing the Supabase OAuth callback host."
}

copy_artifact() {
  local source_file="$1"
  local output_name="$2"
  local output_dir
  local destination

  output_dir="$(artifact_directory)"
  destination="$output_dir/$output_name"
  mkdir -p "$output_dir"
  cp "$source_file" "$destination"
  shasum -a 256 "$destination" > "$destination.sha256"
  printf '\nReady artifact: %s\n' "${destination#"$ROOT_DIR/"}"
  printf 'Checksum: %s\n' "${destination#"$ROOT_DIR/"}.sha256"
}

build_apk_artifact() {
  local environment="$1"
  local source_file="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
  local apksigner

  read_version
  step "Building signed $environment Android APK"
  "$FLUTTER_WRAPPER" --reelpin-env="$environment" build apk --release

  require_file "$source_file"
  verify_android_manifest
  apksigner="$(find_android_tool apksigner)"
  "$apksigner" verify --verbose "$source_file"
  copy_artifact "$source_file" "reelpin-$VERSION-$environment.apk"
}

build_playstore_artifact() {
  local source_file="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"

  read_version
  step "Building signed production Play Store bundle"
  "$FLUTTER_WRAPPER" --reelpin-env=production build appbundle --release

  require_file "$source_file"
  verify_android_manifest
  jarsigner -verify "$source_file" >/dev/null
  copy_artifact "$source_file" "reelpin-$VERSION-playstore.aab"
}

verify_ios_archive() {
  local app="$ROOT_DIR/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
  local share_extension="$app/PlugIns/Share Extension.appex"
  local entitlements_file
  local share_entitlements_file
  local app_version
  local app_build

  [[ -d "$app" ]] || die "The iOS archive does not contain Runner.app."
  [[ -d "$share_extension" ]] || die "The iOS archive does not contain the Share Extension."

  codesign --verify --deep --strict "$app"
  codesign --verify --strict "$share_extension"

  [[ "$(plist_value "$app/Info.plist" CFBundleIdentifier || true)" == "$IOS_APP_ID" ]] || \
    die "Built iOS bundle ID is not $IOS_APP_ID."
  [[ "$(plist_value "$share_extension/Info.plist" CFBundleIdentifier || true)" == "$IOS_SHARE_APP_ID" ]] || \
    die "Built Share Extension bundle ID is not $IOS_SHARE_APP_ID."

  app_version="$(plist_value "$app/Info.plist" CFBundleShortVersionString || true)"
  app_build="$(plist_value "$app/Info.plist" CFBundleVersion || true)"
  [[ "$app_version" == "$VERSION_NAME" ]] || die "Built iOS version does not match pubspec.yaml."
  [[ "$app_build" == "$BUILD_NUMBER" ]] || die "Built iOS build number does not match pubspec.yaml."

  entitlements_file="$(mktemp "${TMPDIR:-/tmp}/reelpin-entitlements.XXXXXX")"
  codesign -d --entitlements :- "$app" > "$entitlements_file" 2>/dev/null
  [[ "$(plist_value "$entitlements_file" aps-environment || true)" == "production" ]] || {
    rm -f "$entitlements_file"
    die "Built iOS app does not have the production push entitlement."
  }
  require_text "$entitlements_file" "$IOS_APP_GROUP" "Built iOS app is missing app group $IOS_APP_GROUP."
  require_text "$entitlements_file" "com.apple.developer.applesignin" "Built iOS app is missing Sign in with Apple."
  rm -f "$entitlements_file"

  share_entitlements_file="$(mktemp "${TMPDIR:-/tmp}/reelpin-share-entitlements.XXXXXX")"
  codesign -d --entitlements :- "$share_extension" > "$share_entitlements_file" 2>/dev/null
  require_text "$share_entitlements_file" "$IOS_APP_GROUP" "Built Share Extension is missing app group $IOS_APP_GROUP."
  rm -f "$share_entitlements_file"
}

build_appstore_artifact() {
  local source_file

  read_version
  step "Building signed production App Store IPA"
  "$FLUTTER_WRAPPER" --reelpin-env=production build ipa \
    --release \
    --export-options-plist="$ROOT_DIR/ios/ExportOptions.plist"

  source_file="$(find "$ROOT_DIR/build/ios/ipa" -maxdepth 1 -type f -name '*.ipa' -print | head -n 1)"
  [[ -n "$source_file" ]] || die "Flutter did not produce an IPA in build/ios/ipa."
  verify_ios_archive
  copy_artifact "$source_file" "reelpin-$VERSION-appstore.ipa"
}

command="${1:-}"
if [[ -z "$command" ]]; then
  usage
  exit 64
fi
shift

cd "$ROOT_DIR"

case "$command" in
  -h|--help|help)
    usage
    ;;
  doctor)
    doctor "${1:-all}"
    ;;
  clean)
    [[ $# -eq 0 ]] || die "clean does not accept additional arguments."
    step "Cleaning Flutter build output"
    flutter clean
    ;;
  version)
    [[ $# -eq 0 ]] || die "version does not accept additional arguments."
    read_version
    printf 'Version name: %s\nBuild number: %s\nCombined: %s\n' "$VERSION_NAME" "$BUILD_NUMBER" "$VERSION"
    ;;
  verify)
    [[ $# -eq 0 ]] || die "verify does not accept additional arguments."
    require_command flutter
    require_command dart
    step "Installing Flutter dependencies"
    flutter pub get
    verify_project
    ;;
  run-dev)
    "$FLUTTER_WRAPPER" --reelpin-env=dev run "$@"
    ;;
  run-production)
    "$FLUTTER_WRAPPER" --reelpin-env=production run "$@"
    ;;
  apk-dev)
    [[ $# -eq 0 ]] || die "apk-dev does not accept additional arguments."
    prepare_store_build android
    build_apk_artifact dev
    ;;
  apk-production)
    [[ $# -eq 0 ]] || die "apk-production does not accept additional arguments."
    prepare_store_build android
    build_apk_artifact production
    ;;
  playstore)
    [[ $# -eq 0 ]] || die "playstore does not accept additional arguments."
    prepare_store_build android
    build_playstore_artifact
    ;;
  appstore)
    [[ $# -eq 0 ]] || die "appstore does not accept additional arguments."
    prepare_store_build ios
    build_appstore_artifact
    ;;
  stores)
    [[ $# -eq 0 ]] || die "stores does not accept additional arguments."
    prepare_store_build all
    build_playstore_artifact
    build_appstore_artifact
    ;;
  *)
    die "Unknown command '$command'. Run tool/reelpin.sh --help."
    ;;
esac
