#!/usr/bin/env bash

set -euo pipefail

# Behavioral tests for scripts/link-project.sh. Everything runs inside a
# disposable temporary workspace; no real project is touched. The canonical
# checkout is copied (working tree, without .git) so the linker under test is
# the current local code and resolves the temporary workspace as its sibling
# root.

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/herdr-orchestrator-test.XXXXXX")
# Resolve symlinked temp parents (e.g. macOS /var -> /private/var) so physical
# path comparisons match.
tmp_root=$(cd -- "$tmp_root" && pwd -P)
trap 'rm -rf -- "$tmp_root"' EXIT

workspace=$tmp_root/workspace
mkdir -p -- "$workspace"
cp -R -- "$repo_dir" "$workspace/herdr-orchestrator"
rm -rf -- "$workspace/herdr-orchestrator/.git"

linker=$workspace/herdr-orchestrator/scripts/link-project.sh
canonical=$workspace/herdr-orchestrator
relative_target=../../../herdr-orchestrator

pass=0
fail_count=0
failures=()

record() {
  local name=$1
  local ok=$2

  if [[ "$ok" == true ]]; then
    pass=$((pass + 1))
    printf 'ok: %s\n' "$name"
  else
    fail_count=$((fail_count + 1))
    failures+=("$name")
    printf 'FAIL: %s\n' "$name"
  fi
}

expect_success() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    record "$name" true
  else
    record "$name" false
  fi
}

expect_rejection() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    record "$name" false
  else
    record "$name" true
  fi
}

new_project() {
  local name=$1

  rm -rf -- "$workspace/$name"
  mkdir -p -- "$workspace/$name"
  git -C "$workspace/$name" init -q
}

adapter_ok() {
  local link=$1

  [[ -L "$link" ]] &&
    [[ "$(readlink "$link")" == "$relative_target" ]] &&
    [[ "$(cd -- "$link" && pwd -P)" == "$canonical" ]]
}

excludes_ok() {
  local exclude=$workspace/$1/.git/info/exclude

  grep -qxF -- .agents/skills/herdr-orchestrator "$exclude" &&
    grep -qxF -- .claude/skills/herdr-orchestrator "$exclude"
}

excludes_unique() {
  local exclude=$workspace/$1/.git/info/exclude

  [[ -z "$(sort -- "$exclude" | uniq -d)" ]]
}

# Successful install and check.
new_project project-a
expect_success 'install links a fresh project' \
  "$linker" install "$workspace/project-a"
expect_success 'codex adapter target and resolution' \
  adapter_ok "$workspace/project-a/.agents/skills/herdr-orchestrator"
expect_success 'claude adapter target and resolution' \
  adapter_ok "$workspace/project-a/.claude/skills/herdr-orchestrator"
expect_success 'adapters are excluded from git' excludes_ok project-a
expect_success 'check passes after install' \
  "$linker" check "$workspace/project-a"

# Idempotent repeated installation.
expect_success 'repeated install is idempotent' \
  "$linker" install "$workspace/project-a"
expect_success 'repeated install adds no duplicate excludes' \
  excludes_unique project-a
expect_success 'check still passes after repeated install' \
  "$linker" check "$workspace/project-a"

# Missing adapter detection.
new_project project-b
expect_rejection 'check rejects an unlinked project' \
  "$linker" check "$workspace/project-b"

# Non-Git and nested project rejection.
rm -rf -- "$workspace/plain-dir"
mkdir -p -- "$workspace/plain-dir"
expect_rejection 'install rejects a non-Git directory' \
  "$linker" install "$workspace/plain-dir"

new_project project-c
mkdir -p -- "$workspace/project-c/nested"
git -C "$workspace/project-c/nested" init -q
expect_rejection 'install rejects a nested project' \
  "$linker" install "$workspace/project-c/nested"

expect_rejection 'install rejects the workspace root' \
  "$linker" install "$workspace"
expect_rejection 'install rejects the canonical checkout' \
  "$linker" install "$canonical"

# Conflicting file rejection.
new_project project-d
mkdir -p -- "$workspace/project-d/.claude/skills"
touch -- "$workspace/project-d/.claude/skills/herdr-orchestrator"
expect_rejection 'install rejects a conflicting adapter file' \
  "$linker" install "$workspace/project-d"
expect_success 'conflicting install leaves no partial codex adapter' \
  test ! -e "$workspace/project-d/.agents/skills/herdr-orchestrator"

# Unexpected symlink parent rejection.
new_project project-e
mkdir -p -- "$workspace/project-e/real-claude"
ln -s real-claude "$workspace/project-e/.claude"
expect_rejection 'install rejects a symlinked adapter parent' \
  "$linker" install "$workspace/project-e"

# Rollback when installation fails after links were created: replace the
# exclude file with a directory so the exclude append fails after both
# adapters exist.
new_project project-f
rm -f -- "$workspace/project-f/.git/info/exclude"
mkdir -p -- "$workspace/project-f/.git/info/exclude"
expect_rejection 'install fails when the exclude file is unwritable' \
  "$linker" install "$workspace/project-f"
expect_success 'failed install rolls back the codex adapter' \
  test ! -e "$workspace/project-f/.agents/skills/herdr-orchestrator"
expect_success 'failed install rolls back the claude adapter' \
  test ! -e "$workspace/project-f/.claude/skills/herdr-orchestrator"

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
if (( fail_count > 0 )); then
  printf 'failed: %s\n' "${failures[@]}" >&2
  exit 1
fi
