#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  link-all-projects.sh install
  link-all-projects.sh check

Run link-project.sh for every immediate-child Git project of the workspace
that contains this herdr-orchestrator checkout. Non-Git directories and the
canonical checkout are skipped. The exit status is non-zero when any visited
project fails.
EOF
}

if [[ $# -ne 1 ]] || [[ "$1" != install && "$1" != check ]]; then
  usage >&2
  exit 2
fi

mode=$1
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
canonical_dir=$(cd -- "$script_dir/.." && pwd -P)
workspace_dir=$(cd -- "$canonical_dir/.." && pwd -P)
linker=$script_dir/link-project.sh

processed=0
failures=0

for entry in "$workspace_dir"/*/; do
  project_dir=${entry%/}
  [[ -d "$project_dir" ]] || continue
  [[ "$project_dir" != "$canonical_dir" ]] || continue
  [[ -e "$project_dir/.git" ]] || continue
  processed=$((processed + 1))
  name=$(basename -- "$project_dir")
  if output=$("$linker" "$mode" "$project_dir" 2>&1); then
    printf 'ok: %s\n' "$name"
  else
    failures=$((failures + 1))
    printf 'fail: %s\n%s\n' "$name" "$output" >&2
  fi
done

printf '%d project(s) visited, %d failure(s)\n' "$processed" "$failures"
[[ "$failures" -eq 0 ]]
