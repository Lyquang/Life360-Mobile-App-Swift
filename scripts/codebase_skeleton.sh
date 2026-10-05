#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-FamilyTracker}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "$SCRIPT_DIR/swift_skeleton.py" "$ROOT"
