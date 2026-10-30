#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_root="$(pwd -P)"
graphify_bin="${GRAPHIFY_BIN:-}"
if [ -z "$graphify_bin" ]; then
  if [ -x "$project_root/.graphify-venv/bin/graphify" ]; then
    graphify_bin="$project_root/.graphify-venv/bin/graphify"
  else
    graphify_bin=graphify
  fi
fi
if ! command -v "$graphify_bin" >/dev/null 2>&1; then
  echo "Graphify CLI not found. See TOOLING.md; install graphifyy or set GRAPHIFY_BIN." >&2
  exit 1
fi
output_dir="$project_root/.graphify-familytracker"
if [ -L "$output_dir" ]; then
  echo "Refusing to use a symlink for the Graphify output directory." >&2
  exit 1
fi
mkdir -p "$output_dir"
# Code-only avoids semantic/LLM extraction and never overwrites the supplied sample graph.
GRAPHIFY_BACKEND=none GRAPHIFY_QUERY_LOG_DISABLE=1 "$graphify_bin" extract "$project_root" \
  --code-only --max-workers 4 --out "$output_dir"
GRAPHIFY_BACKEND=none GRAPHIFY_QUERY_LOG_DISABLE=1 "$graphify_bin" cluster-only "$output_dir" --no-label
echo "FamilyTracker graph: $output_dir/graphify-out/graph.json"
