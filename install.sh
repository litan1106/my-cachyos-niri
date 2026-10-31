#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" == "--profile" && "${2:-}" == "hypr-v5" ]]; then
    shift 2
fi

exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/install-hypr-v5.sh" "$@"
