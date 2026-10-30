#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_root="$(pwd)"
for pair in 'feature-spec spec-template' 'plan plan-template' 'tasks tasks-template' 'requirements checklist-template'; do
  read -r source_template specify_template <<< "$pair"
  cmp ".spec/templates/$source_template.md" ".specify/templates/$specify_template.md"
done
workspace="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-specify.XXXXXX")"
trap 'rm -rf "$workspace"' EXIT
project="$workspace/Test Workspace"
mkdir -p "$project/.specify" "$project/.spec/001-example" "$project/.spec/012-existing"
cp -R .specify/scripts .specify/templates "$project/.specify/"
export SPECIFY_INIT_DIR="$project"

# Dry run must neither create a feature nor write the active-feature pointer.
output="$(bash "$project/.specify/scripts/bash/create-new-feature.sh" --json --dry-run --short-name sample 'Sample feature')"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["FEATURE_NUM"] == "013" and d["DRY_RUN"] is True and "/.spec/013-sample/spec.md" in d["SPEC_FILE"]' "$output"
test ! -e "$project/.spec/013-sample"
test ! -e "$project/.specify/feature.json"
if bash "$project/.specify/scripts/bash/create-new-feature.sh" --dry-run --short-name '!!!' 'Sample feature' >/dev/null 2>&1; then
  echo 'FAIL: empty feature name accepted' >&2
  exit 1
fi

# Real creation stays in .spec and never checks out a branch.
output="$(bash "$project/.specify/scripts/bash/create-new-feature.sh" --json --short-name sample 'Sample feature')"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["FEATURE_NUM"] == "013" and "/.spec/013-sample/spec.md" in d["SPEC_FILE"]' "$output"
test -f "$project/.spec/013-sample/spec.md"
test ! -d "$project/specs"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["feature_directory"] == ".spec/013-sample"' "$project/.specify/feature.json"

SPECIFY_FEATURE_DIRECTORY=.spec/013-sample SPECIFY_FEATURE_NO_PERSIST=1 \
  bash "$project/.specify/scripts/bash/setup-plan.sh" --json >/dev/null
printf '%s\n' 'existing plan must survive' > "$project/.spec/013-sample/plan.md"
SPECIFY_FEATURE_DIRECTORY=.spec/013-sample SPECIFY_FEATURE_NO_PERSIST=1 \
  bash "$project/.specify/scripts/bash/setup-plan.sh" --json >/dev/null
test "$(cat "$project/.spec/013-sample/plan.md")" = 'existing plan must survive'

# Explicit selection is read-only when no-persist is requested.
SPECIFY_FEATURE_DIRECTORY=.spec/012-existing SPECIFY_FEATURE_NO_PERSIST=1 \
  bash "$project/.specify/scripts/bash/check-prerequisites.sh" --paths-only --json >/dev/null
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["feature_directory"] == ".spec/013-sample"' "$project/.specify/feature.json"
test -f "$source_root/.specify/memory/constitution.md"
echo 'PASS: .spec feature numbering, isolated creation, safe plan setup and no-persist selection'
