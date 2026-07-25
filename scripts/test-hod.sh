#!/usr/bin/env bash

set -euo pipefail

# Behavioral tests for bin/hod. Everything runs inside a disposable temporary
# workspace; the real ~/.hod, ~/.claude, ~/.agents, ~/.local/bin, and real
# projects are never touched. Home-derived paths are overridden via HOD_HOME,
# HOD_BIN_DIR, HOD_CLAUDE_DIR, HOD_AGENTS_DIR, and HOD_REPO_URL.

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/hod-test.XXXXXX")
tmp_root=$(cd -- "$tmp_root" && pwd -P)
trap 'rm -rf -- "$tmp_root"' EXIT

# Local source repository so install never hits the network.
src_repo=$tmp_root/src-repo
mkdir -p -- "$src_repo"
# Copy working tree (including uncommitted bin/hod under test) into a local git repo.
tar -C "$repo_dir" \
  --exclude .git \
  --exclude .venv \
  -cf - . | tar -C "$src_repo" -xf -
git -C "$src_repo" init -q
git -C "$src_repo" config user.email "hod-test@example.com"
git -C "$src_repo" config user.name "hod-test"
git -C "$src_repo" add -A
git -C "$src_repo" commit -q -m "test fixture"

# Fake home layout.
fake_home=$tmp_root/home
hod_home=$fake_home/hod
bin_dir=$fake_home/local/bin
claude_dir=$fake_home/claude
agents_dir=$fake_home/agents
mkdir -p -- "$hod_home" "$bin_dir" "$claude_dir" "$agents_dir"

export HOD_HOME=$hod_home
export HOD_BIN_DIR=$bin_dir
export HOD_CLAUDE_DIR=$claude_dir
export HOD_AGENTS_DIR=$agents_dir
export HOD_REPO_URL=$src_repo
# Ensure PATH sees the fake bin dir for status checks, without requiring real tools
# to disappear — we only override HOD paths.
export PATH="$bin_dir:$PATH"

hod=$repo_dir/bin/hod
chmod +x "$hod" "$repo_dir/install.sh" 2>/dev/null || true

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

expect_output_success() {
  local name=$1
  shift
  local out
  if out=$("$@" 2>&1); then
    record "$name" true
  else
    printf '  output: %s\n' "$out" >&2
    record "$name" false
  fi
}

skill_dir=$hod_home/skill
global_agents=$agents_dir/skills/herdr-orchestrator
global_claude=$claude_dir/skills/herdr-orchestrator

adapter_points_to_skill() {
  local link=$1
  [[ -L "$link" ]] && [[ -d "$link" ]] && \
    [[ "$(cd -- "$link" && pwd -P)" == "$(cd -- "$skill_dir" && pwd -P)" ]]
}

# ---------------------------------------------------------------------------
# Fresh global install
# ---------------------------------------------------------------------------
expect_success 'fresh global install' \
  "$hod" install

expect_success 'skill checkout exists after install' \
  test -d "$skill_dir/.git"

expect_success 'global agents adapter resolves to skill' \
  adapter_points_to_skill "$global_agents"

expect_success 'global claude adapter resolves to skill' \
  adapter_points_to_skill "$global_claude"

expect_success 'executable link installed' \
  test -L "$bin_dir/hod" -o -x "$bin_dir/hod"

# ---------------------------------------------------------------------------
# Idempotent re-install
# ---------------------------------------------------------------------------
expect_success 'idempotent re-install' \
  "$hod" install

expect_success 'adapters still resolve after re-install' \
  adapter_points_to_skill "$global_claude"

# ---------------------------------------------------------------------------
# status exit codes both ways
# ---------------------------------------------------------------------------
# With a complete install and PATH set, status may still fail if herdr/jq/agents
# are missing on the host. Force a clean "all good" path by stubbing missing
# required tools into the fake bin dir, then a failing path by breaking an adapter.

stub_dir=$tmp_root/stubs
mkdir -p -- "$stub_dir"

# Preserve real tools when present; only stub missing ones needed for a green status.
for tool in herdr git jq claude; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    cat >"$stub_dir/$tool" <<'EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "$0 0.0.0-test"
  exit 0
fi
exit 0
EOF
    chmod +x "$stub_dir/$tool"
  fi
done
export PATH="$stub_dir:$bin_dir:$PATH"

expect_success 'status exits 0 when required pieces are present' \
  "$hod" status

# Break an adapter → status must fail.
rm -f -- "$global_claude"
expect_rejection 'status exits non-zero when adapter is missing' \
  "$hod" status

# Restore for later tests.
"$hod" install >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# --project install on a git repo
# ---------------------------------------------------------------------------
project=$tmp_root/projects/demo
mkdir -p -- "$project"
git -C "$project" init -q
git -C "$project" config user.email "hod-test@example.com"
git -C "$project" config user.name "hod-test"

expect_success 'project install on a git repo' \
  "$hod" install --project "$project"

expect_success 'project agents adapter present' \
  test -L "$project/.agents/skills/herdr-orchestrator"

expect_success 'project claude adapter present' \
  test -L "$project/.claude/skills/herdr-orchestrator"

expect_success 'project adapters resolve to skill' \
  adapter_points_to_skill "$project/.claude/skills/herdr-orchestrator"

expect_success 'project exclude has agents adapter entry' \
  grep -qxF -- .agents/skills/herdr-orchestrator "$project/.git/info/exclude"

expect_success 'project exclude has claude adapter entry' \
  grep -qxF -- .claude/skills/herdr-orchestrator "$project/.git/info/exclude"

# ---------------------------------------------------------------------------
# rejection of a non-git --project target
# ---------------------------------------------------------------------------
plain=$tmp_root/projects/not-git
mkdir -p -- "$plain"
expect_rejection 'project install rejects non-git directory' \
  "$hod" install --project "$plain"

# ---------------------------------------------------------------------------
# uninstall removes adapters and leaves foreign files untouched
# ---------------------------------------------------------------------------
foreign=$agents_dir/skills/other-skill
mkdir -p -- "$agents_dir/skills"
echo keep-me >"$foreign"

expect_success 'uninstall removes global adapters' \
  "$hod" uninstall

expect_success 'global agents adapter removed' \
  test ! -e "$global_agents" -a ! -L "$global_agents"

expect_success 'global claude adapter removed' \
  test ! -e "$global_claude" -a ! -L "$global_claude"

expect_success 'foreign skill file left untouched' \
  test -f "$foreign"

# Project uninstall
"$hod" install --project "$project" >/dev/null 2>&1 || true
foreign_project=$project/.agents/skills/keep-me
echo foreign >"$foreign_project"

expect_success 'uninstall --project removes project adapters' \
  "$hod" uninstall --project "$project"

expect_success 'project adapters removed' \
  test ! -e "$project/.agents/skills/herdr-orchestrator" -a \
       ! -e "$project/.claude/skills/herdr-orchestrator"

expect_success 'foreign project file left untouched' \
  test -f "$foreign_project"

expect_success 'exclude entries left alone after uninstall' \
  grep -qxF -- .agents/skills/herdr-orchestrator "$project/.git/info/exclude"

# ---------------------------------------------------------------------------
# update refuses a dirty checkout
# ---------------------------------------------------------------------------
"$hod" install >/dev/null 2>&1 || true
echo dirty >>"$skill_dir/SKILL.md"
expect_rejection 'update refuses dirty skill checkout' \
  "$hod" update

# Restore clean tree for remaining tests.
git -C "$skill_dir" checkout -- SKILL.md >/dev/null 2>&1 || \
  git -C "$skill_dir" restore SKILL.md >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# broken-symlink detection in doctor
# ---------------------------------------------------------------------------
"$hod" install >/dev/null 2>&1 || true
rm -f -- "$global_claude"
ln -s -- "$skill_dir/does-not-exist" "$global_claude"

doctor_out=$tmp_root/doctor.out
set +e
"$hod" doctor >"$doctor_out" 2>&1
doctor_rc=$?
set -e

if [[ $doctor_rc -ne 0 ]] && grep -Eqi 'dangling|broken|does not|missing|points' "$doctor_out"; then
  record 'doctor detects broken/dangling adapter symlink' true
else
  printf '  doctor rc=%s output:\n%s\n' "$doctor_rc" "$(cat "$doctor_out")" >&2
  record 'doctor detects broken/dangling adapter symlink' false
fi

# ---------------------------------------------------------------------------
# help / version
# ---------------------------------------------------------------------------
expect_success 'help exits 0' "$hod" help
expect_success 'version exits 0' "$hod" version
expect_success 'no-args prints usage' "$hod"

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
if (( fail_count > 0 )); then
  printf 'failed: %s\n' "${failures[@]}" >&2
  exit 1
fi
