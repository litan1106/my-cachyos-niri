#!/bin/bash

# Launch Android apps via Waydroid, or show the full Android UI.
# Usage: launch-waydroid [--app <package>]

set -e

app_package=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      if [[ -z "$2" ]]; then
        echo "Error: --app requires a package name" >&2
        exit 1
      fi
      app_package="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: launch-waydroid [--app <package>]

Launch Android apps via Waydroid. If no app is specified, opens the full
Android UI.

Options:
  --app <package>   Launch a specific Android app by package name
  -h, --help        Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Try: launch-waydroid --help" >&2
      exit 1
      ;;
  esac
done

# Pre-flight: check if waydroid is installed
if ! command -v waydroid >/dev/null 2>&1; then
  echo "Waydroid is not installed. Run install-android-waydroid.sh first." >&2
  exit 1
fi

# Pre-flight: ensure waydroid session is running
if ! waydroid status 2>/dev/null | grep -q "running"; then
  # Start the session in the background and give it a moment
  waydroid session start >/dev/null 2>&1 &
  sleep 2
fi

# Launch
if [[ -n "$app_package" ]]; then
  waydroid app launch "$app_package"
else
  waydroid show-full-ui
fi
