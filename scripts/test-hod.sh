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
# pinned (tag) install and update
# ---------------------------------------------------------------------------
# Give the source repo two tags so update has somewhere to move.
git -C "$src_repo" tag -a vt1 -m t1
printf 'marker vt2\n' >>"$src_repo/README.md"
git -C "$src_repo" add -A
git -C "$src_repo" commit -q -m "vt2 content"
git -C "$src_repo" tag -a vt2 -m t2

# Fully isolated home/adapters so earlier global installs cannot interfere.
pin_home=$tmp_root/pin-home
pin_env=(env HOD_HOME="$pin_home" HOD_BIN_DIR="$tmp_root/pin-bin" \
  HOD_CLAUDE_DIR="$tmp_root/pin-claude" HOD_AGENTS_DIR="$tmp_root/pin-agents")
mkdir -p -- "$pin_home" "$tmp_root/pin-bin" "$tmp_root/pin-claude" "$tmp_root/pin-agents"

expect_success 'install --ref pins to a tag' \
  "${pin_env[@]}" "$hod" install --ref vt1

pinned_tag_is() {
  local want=$1
  [[ "$(git -C "$pin_home/skill" describe --tags --exact-match 2>/dev/null)" == "$want" ]]
}
expect_success 'pinned checkout sits at the requested tag' pinned_tag_is vt1

expect_success 'update on a pinned checkout moves to the newest tag' \
  "${pin_env[@]}" "$hod" update
expect_success 'pinned checkout now at the newest tag' pinned_tag_is vt2

expect_success 'doctor reports pinned mode' \
  bash -c "$(printf '%q ' "${pin_env[@]:1}") '$hod' doctor 2>/dev/null | grep -q 'pinned to tag vt2'"

# ---------------------------------------------------------------------------
# settings profiles
# ---------------------------------------------------------------------------
sproj=$tmp_root/projects/settings-demo
mkdir -p -- "$sproj"
git -C "$sproj" init -q
git -C "$sproj" config user.email "hod-test@example.com"
git -C "$sproj" config user.name "hod-test"

expect_success 'settings list exits 0' \
  "$hod" settings list

expect_rejection 'settings rejects unknown subcommand' \
  "$hod" settings bogus

expect_rejection 'settings install rejects unknown role' \
  "$hod" settings install --project "$sproj" --role nope

expect_rejection 'settings install rejects non-git target' \
  "$hod" settings install --project "$plain"

expect_success 'settings install writes all roles' \
  "$hod" settings install --project "$sproj"

for role in controller impl reviewer; do
  expect_success "settings profile written: $role" \
    test -f "$sproj/.claude/settings.$role.json"
  expect_success "settings profile is valid json: $role" \
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" \
      "$sproj/.claude/settings.$role.json"
  expect_success "settings profile excluded from git: $role" \
    grep -qxF -- ".claude/settings.$role.json" "$sproj/.git/info/exclude"
done

# Profiles must never ship credentials.
expect_rejection 'settings profiles carry no credential keys' \
  grep -rqE 'ANTHROPIC_(API_KEY|AUTH_TOKEN)|apiKeyHelper' "$sproj/.claude/"

# A bare "Agent" deny removes the sub-agent tool from the model's context, which
# is what forces delegation through Herdr panes instead of in-process children.
for role in controller reviewer; do
  expect_success "profile denies the sub-agent tool: $role" \
    python3 -c 'import json,sys; sys.exit(0 if "Agent" in json.load(open(sys.argv[1]))["permissions"]["deny"] else 1)' \
      "$sproj/.claude/settings.$role.json"
done

# Shell-prefix denies match the first token only, so they promise more than they
# deliver. Keep the controller profile built on tool denies.
expect_rejection 'controller profile has no build-tool prefix denies' \
  grep -qE '"Bash\((npm|pnpm|yarn|npx|cargo|make|go |pytest|xcodebuild|swift)' \
    "$sproj/.claude/settings.controller.json"

# Existing user edits are preserved unless --force.
printf '{ "permissions": { "deny": ["Mine"] } }\n' >"$sproj/.claude/settings.impl.json"
expect_success 'settings install keeps an existing profile' \
  "$hod" settings install --project "$sproj" --role impl
expect_success 'existing profile content untouched' \
  grep -q 'Mine' "$sproj/.claude/settings.impl.json"

expect_success 'settings install --force overwrites' \
  "$hod" settings install --project "$sproj" --role impl --force
expect_rejection 'forced profile no longer has user content' \
  grep -q 'Mine' "$sproj/.claude/settings.impl.json"

# A symlinked destination must be refused rather than followed.
rm -f -- "$sproj/.claude/settings.reviewer.json"
ln -s /etc/hosts "$sproj/.claude/settings.reviewer.json"
expect_rejection 'settings install refuses a symlinked destination' \
  "$hod" settings install --project "$sproj" --role reviewer --force
expect_success 'symlink target untouched' \
  test -L "$sproj/.claude/settings.reviewer.json"

# ---------------------------------------------------------------------------
# memo blocks in CLAUDE.md / AGENTS.md
# ---------------------------------------------------------------------------
memo_begin='<!-- hod:begin — managed by hod; edits inside this block are overwritten -->'

new_memo_project() {
  local dir=$1
  mkdir -p -- "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "hod-test@example.com"
  git -C "$dir" config user.name "hod-test"
}

mproj=$tmp_root/projects/memo-demo
new_memo_project "$mproj"
printf '# CLAUDE.md\n\nuser prose above\n' >"$mproj/CLAUDE.md"
chmod 644 "$mproj/CLAUDE.md"

expect_success 'project install writes memo blocks' \
  "$hod" install --project "$mproj"

for name in CLAUDE.md AGENTS.md; do
  expect_success "memo block present in $name" \
    grep -qxF -- "$memo_begin" "$mproj/$name"
done

expect_success 'memo keeps existing prose' \
  grep -qxF -- 'user prose above' "$mproj/CLAUDE.md"

expect_success 'memo preserves file mode' \
  bash -c "test \"\$(stat -f '%Lp' '$mproj/CLAUDE.md' 2>/dev/null || stat -c '%a' '$mproj/CLAUDE.md')\" = 644"

# Content the user adds after the block must survive a re-install.
printf '\n## added later\n\nkeep me\n' >>"$mproj/CLAUDE.md"
cp -- "$mproj/CLAUDE.md" "$tmp_root/memo-snapshot.md"
expect_success 'memo re-install succeeds' \
  "$hod" install --project "$mproj"
expect_success 'memo re-install is idempotent' \
  cmp -s "$tmp_root/memo-snapshot.md" "$mproj/CLAUDE.md"
expect_success 'memo block is not duplicated' \
  bash -c "test \"\$(grep -cxF -- '$memo_begin' '$mproj/CLAUDE.md')\" = 1"

expect_success 'uninstall strips memo blocks' \
  "$hod" uninstall --project "$mproj"
expect_rejection 'memo block gone after uninstall' \
  grep -qxF -- "$memo_begin" "$mproj/CLAUDE.md"
expect_success 'user prose survives uninstall' \
  grep -qxF -- 'keep me' "$mproj/CLAUDE.md"
expect_rejection 'hod-only memo file is removed, not left empty' \
  test -e "$mproj/AGENTS.md"

# --no-memo keeps adapters but never touches the repository's own files.
mskip=$tmp_root/projects/memo-skip
new_memo_project "$mskip"
expect_success 'install --no-memo succeeds' \
  "$hod" install --project "$mskip" --no-memo
expect_rejection 'install --no-memo writes no CLAUDE.md' \
  test -e "$mskip/CLAUDE.md"
expect_success 'install --no-memo still links adapters' \
  test -L "$mskip/.claude/skills/herdr-orchestrator"

# Damaged or hostile memo files must stop the install rather than be rewritten.
mbad=$tmp_root/projects/memo-unbalanced
new_memo_project "$mbad"
printf '# x\n%s\nno closing marker\n' "$memo_begin" >"$mbad/CLAUDE.md"
expect_rejection 'unbalanced memo markers are rejected' \
  "$hod" install --project "$mbad"

mlink=$tmp_root/projects/memo-symlink
new_memo_project "$mlink"
printf 'outside content\n' >"$tmp_root/memo-outside.md"
ln -s -- "$tmp_root/memo-outside.md" "$mlink/CLAUDE.md"
expect_rejection 'symlinked memo file is rejected' \
  "$hod" install --project "$mlink"
expect_success 'symlink target left untouched' \
  grep -qxF -- 'outside content' "$tmp_root/memo-outside.md"

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
