#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${REELPIN_CONFIG_FILE:-"$ROOT_DIR/assets/config/local.env"}"
IOS_SECRETS_FILE="$ROOT_DIR/ios/Flutter/Secrets.xcconfig"
VSCODE_LAUNCH_FILE="$ROOT_DIR/.vscode/launch.json"
PRODUCTION_API_BASE_URL="https://api-64-227-168-119.nip.io"
DEV_API_BASE_URL="https://dev-api-64-227-168-119.nip.io"

CONFIG_SUPABASE_URL=""
CONFIG_SUPABASE_ANON_KEY=""
CONFIG_SUPABASE_REDIRECT_SCHEME=""
CONFIG_SUPABASE_REDIRECT_HOST=""
CONFIG_API_BASE_URL=""

usage() {
  cat <<'USAGE'
Usage:
  tool/reelpin_flutter.sh [--reelpin-env=dev|production] run [flutter run args]
  tool/reelpin_flutter.sh [--reelpin-env=dev|production] build apk [flutter build apk args]
  tool/reelpin_flutter.sh [--reelpin-env=dev|production] build appbundle [flutter build appbundle args]
  tool/reelpin_flutter.sh [--reelpin-env=dev|production] build ipa [flutter build ipa args]
  tool/reelpin_flutter.sh sync-local
  tool/reelpin_flutter.sh sync-vscode
  tool/reelpin_flutter.sh sync-xcode

The wrapper reads assets/config/local.env, validates the required Supabase
values, and passes them to Flutter as Dart defines without committing them.

Examples:
  tool/reelpin_flutter.sh --reelpin-env=dev run
  tool/reelpin_flutter.sh --reelpin-env=production run
  tool/reelpin_flutter.sh --reelpin-env=production build apk --release
  tool/reelpin_flutter.sh --reelpin-env=production build appbundle --release
USAGE
}

die() {
  printf 'reelpin_flutter: %s\n' "$*" >&2
  exit 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_config_file() {
  [[ -f "$CONFIG_FILE" ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$(trim "$line")" ]] && continue
    [[ "$(trim "$line")" == \#* ]] && continue
    [[ "$line" == *"="* ]] || continue

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"

    if [[ "$value" == \"*\" && "$value" == *\" && ${#value} -ge 2 ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' && ${#value} -ge 2 ]]; then
      value="${value:1:${#value}-2}"
    fi

    case "$key" in
      SUPABASE_URL) CONFIG_SUPABASE_URL="$value" ;;
      SUPABASE_ANON_KEY) CONFIG_SUPABASE_ANON_KEY="$value" ;;
      SUPABASE_REDIRECT_SCHEME) CONFIG_SUPABASE_REDIRECT_SCHEME="$value" ;;
      SUPABASE_REDIRECT_HOST) CONFIG_SUPABASE_REDIRECT_HOST="$value" ;;
      API_BASE_URL) CONFIG_API_BASE_URL="$value" ;;
    esac
  done < "$CONFIG_FILE"
}

value_for() {
  local key="$1"
  case "$key" in
    SUPABASE_URL) printf '%s' "${SUPABASE_URL:-$CONFIG_SUPABASE_URL}" ;;
    SUPABASE_ANON_KEY) printf '%s' "${SUPABASE_ANON_KEY:-$CONFIG_SUPABASE_ANON_KEY}" ;;
    SUPABASE_REDIRECT_SCHEME) printf '%s' "${SUPABASE_REDIRECT_SCHEME:-${CONFIG_SUPABASE_REDIRECT_SCHEME:-com.chetan.reelpin}}" ;;
    SUPABASE_REDIRECT_HOST) printf '%s' "${SUPABASE_REDIRECT_HOST:-${CONFIG_SUPABASE_REDIRECT_HOST:-login-callback}}" ;;
    API_BASE_URL) printf '%s' "${REELPIN_API_BASE_URL:-${API_BASE_URL:-$CONFIG_API_BASE_URL}}" ;;
    *) return 1 ;;
  esac
}

reject_placeholder() {
  local key="$1"
  local value="$2"
  [[ -n "$value" ]] || die "Missing $key. Add it to $CONFIG_FILE or export it before running this command."
  [[ "$value" != *"YOUR_"* ]] || die "$key still contains a placeholder value in $CONFIG_FILE."
}

dart_define_value() {
  local key="$1"
  shift

  local expecting_value="false"
  local prefix="--dart-define=$key="
  local arg
  for arg in "$@"; do
    if [[ "$expecting_value" == "true" ]]; then
      if [[ "$arg" == "$key="* ]]; then
        printf '%s' "${arg#"$key="}"
        return 0
      fi
      expecting_value="false"
      continue
    fi

    if [[ "$arg" == "$prefix"* ]]; then
      printf '%s' "${arg#"$prefix"}"
      return 0
    fi

    if [[ "$arg" == "--dart-define" ]]; then
      expecting_value="true"
    fi
  done

  return 1
}

has_dart_define() {
  dart_define_value "$@" >/dev/null
}

encode_define() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  printf '%s' "$value"
}

json_define_list() {
  local api_base_url="$1"
  local defines=(
    "SUPABASE_URL=$SUPABASE_URL_VALUE"
    "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY_VALUE"
    "SUPABASE_REDIRECT_SCHEME=$SUPABASE_REDIRECT_SCHEME_VALUE"
    "SUPABASE_REDIRECT_HOST=$SUPABASE_REDIRECT_HOST_VALUE"
    "API_BASE_URL=$api_base_url"
  )

  local index
  for index in "${!defines[@]}"; do
    if [[ "$index" -gt 0 ]]; then
      printf ',\n'
    fi
    printf '                "--dart-define=%s"' "$(json_escape "${defines[$index]}")"
  done
}

write_ios_secrets() {
  local encoded=""
  local part define
  for define in "$@"; do
    part="$(encode_define "$define")"
    if [[ -n "$encoded" ]]; then
      encoded="$encoded,$part"
    else
      encoded="$part"
    fi
  done

  mkdir -p "$(dirname "$IOS_SECRETS_FILE")"
  {
    printf '// Generated by tool/reelpin_flutter.sh. Do not commit.\n'
    printf 'DART_DEFINES=%s\n' "$encoded"
  } > "$IOS_SECRETS_FILE"
}

write_vscode_launch() {
  mkdir -p "$(dirname "$VSCODE_LAUNCH_FILE")"
  {
    cat <<'JSON'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "reelpin (Flutter)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "toolArgs": [
JSON
    json_define_list "$DEV_API_BASE_URL"
    cat <<'JSON'

            ]
        },
        {
            "name": "ReelPin Production (configured)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "toolArgs": [
JSON
    json_define_list "$PRODUCTION_API_BASE_URL"
    cat <<'JSON'

            ]
        }
    ]
}
JSON
  } > "$VSCODE_LAUNCH_FILE"
}

append_define_if_missing() {
  local key="$1"
  local value="$2"
  shift 2

  if ! has_dart_define "$key" "$@"; then
    FLUTTER_ARGS+=(--dart-define="$key=$value")
  fi
}

REELPIN_ENV="${REELPIN_ENV:-}"
API_BASE_URL_OVERRIDE=""
REQUESTED_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --reelpin-env=*)
      REELPIN_ENV="${arg#--reelpin-env=}"
      ;;
    --reelpin-api-base-url=*)
      API_BASE_URL_OVERRIDE="${arg#--reelpin-api-base-url=}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      REQUESTED_ARGS+=("$arg")
      ;;
  esac
done

case "$REELPIN_ENV" in
  ""|dev|development|prod|production) ;;
  *) die "Invalid --reelpin-env value '$REELPIN_ENV'. Use dev or production." ;;
esac

set -- "${REQUESTED_ARGS[@]}"

[[ $# -gt 0 ]] || {
  usage
  exit 64
}

read_config_file

SUPABASE_URL_VALUE="$(dart_define_value SUPABASE_URL "$@" || value_for SUPABASE_URL)"
SUPABASE_ANON_KEY_VALUE="$(dart_define_value SUPABASE_ANON_KEY "$@" || value_for SUPABASE_ANON_KEY)"
SUPABASE_REDIRECT_SCHEME_VALUE="$(dart_define_value SUPABASE_REDIRECT_SCHEME "$@" || value_for SUPABASE_REDIRECT_SCHEME)"
SUPABASE_REDIRECT_HOST_VALUE="$(dart_define_value SUPABASE_REDIRECT_HOST "$@" || value_for SUPABASE_REDIRECT_HOST)"

reject_placeholder SUPABASE_URL "$SUPABASE_URL_VALUE"
reject_placeholder SUPABASE_ANON_KEY "$SUPABASE_ANON_KEY_VALUE"

if API_BASE_URL_VALUE="$(dart_define_value API_BASE_URL "$@")"; then
  :
elif [[ -n "$API_BASE_URL_OVERRIDE" ]]; then
  API_BASE_URL_VALUE="$API_BASE_URL_OVERRIDE"
elif [[ "$REELPIN_ENV" == "prod" || "$REELPIN_ENV" == "production" ]]; then
  API_BASE_URL_VALUE="$PRODUCTION_API_BASE_URL"
elif [[ "$REELPIN_ENV" == "dev" || "$REELPIN_ENV" == "development" ]]; then
  API_BASE_URL_VALUE="$DEV_API_BASE_URL"
elif [[ "${1:-}" == "build" ]]; then
  API_BASE_URL_VALUE="$PRODUCTION_API_BASE_URL"
else
  API_BASE_URL_VALUE="$(value_for API_BASE_URL)"
  [[ -n "$API_BASE_URL_VALUE" ]] || API_BASE_URL_VALUE="$DEV_API_BASE_URL"
fi

XCODE_DART_DEFINES=(
  "SUPABASE_URL=$SUPABASE_URL_VALUE"
  "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY_VALUE"
  "SUPABASE_REDIRECT_SCHEME=$SUPABASE_REDIRECT_SCHEME_VALUE"
  "SUPABASE_REDIRECT_HOST=$SUPABASE_REDIRECT_HOST_VALUE"
  "API_BASE_URL=$API_BASE_URL_VALUE"
)

if [[ "${1:-}" == "sync-xcode" ]]; then
  write_ios_secrets "${XCODE_DART_DEFINES[@]}"
  printf 'Wrote iOS Dart defines to ios/Flutter/Secrets.xcconfig.\n'
  exit 0
fi

if [[ "${1:-}" == "sync-vscode" ]]; then
  write_vscode_launch
  printf 'Wrote VS Code debug configs to .vscode/launch.json.\n'
  exit 0
fi

if [[ "${1:-}" == "sync-local" ]]; then
  write_ios_secrets "${XCODE_DART_DEFINES[@]}"
  write_vscode_launch
  printf 'Wrote local debug config to .vscode/launch.json and iOS Dart defines to ios/Flutter/Secrets.xcconfig.\n'
  exit 0
fi

FLUTTER_ARGS=("$@")
append_define_if_missing SUPABASE_URL "$SUPABASE_URL_VALUE" "$@"
append_define_if_missing SUPABASE_ANON_KEY "$SUPABASE_ANON_KEY_VALUE" "$@"
append_define_if_missing SUPABASE_REDIRECT_SCHEME "$SUPABASE_REDIRECT_SCHEME_VALUE" "$@"
append_define_if_missing SUPABASE_REDIRECT_HOST "$SUPABASE_REDIRECT_HOST_VALUE" "$@"
append_define_if_missing API_BASE_URL "$API_BASE_URL_VALUE" "$@"

if [[ "${1:-}" == "build" ]]; then
  write_ios_secrets "${XCODE_DART_DEFINES[@]}"
fi

cd "$ROOT_DIR"
flutter "${FLUTTER_ARGS[@]}"
