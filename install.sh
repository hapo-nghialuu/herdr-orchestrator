#!/bin/sh
# Bootstrap installer for hod (Herdr Orchestrator Driver).
# Usage: curl -fsSL <raw-url>/install.sh | sh
# POSIX sh only — no bashisms.

set -eu

HOD_REPO_URL="${HOD_REPO_URL:-https://github.com/hapo-nghialuu/herdr-orchestrator.git}"
HOD_HOME="${HOD_HOME:-${HOME}/.hod}"
HOD_BIN_DIR="${HOD_BIN_DIR:-${HOME}/.local/bin}"
SKILL_DIR="${HOD_HOME}/skill"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if ! command -v git >/dev/null 2>&1; then
  fail "git is required; install git and re-run this installer"
fi

if [ -z "${HOME:-}" ]; then
  fail "HOME is not set"
fi

mkdir -p -- "$(dirname -- "$SKILL_DIR")"
mkdir -p -- "$HOD_BIN_DIR"

if [ -d "${SKILL_DIR}/.git" ]; then
  printf 'updating existing skill checkout: %s\n' "$SKILL_DIR"
  git -C "$SKILL_DIR" pull --ff-only || \
    printf 'warning: could not fast-forward %s; continuing with current tree\n' "$SKILL_DIR" >&2
else
  if [ -e "$SKILL_DIR" ]; then
    fail "skill path exists but is not a git checkout: $SKILL_DIR"
  fi
  printf 'cloning %s -> %s\n' "$HOD_REPO_URL" "$SKILL_DIR"
  git clone -- "$HOD_REPO_URL" "$SKILL_DIR" || fail "git clone failed"
fi

if [ ! -f "${SKILL_DIR}/bin/hod" ]; then
  fail "cloned checkout is missing bin/hod: ${SKILL_DIR}/bin/hod"
fi

chmod +x "${SKILL_DIR}/bin/hod"

# Prefer a symlink so updates to the skill checkout are picked up automatically.
if [ -L "${HOD_BIN_DIR}/hod" ] || [ ! -e "${HOD_BIN_DIR}/hod" ]; then
  ln -sfn -- "${SKILL_DIR}/bin/hod" "${HOD_BIN_DIR}/hod"
  printf 'installed: %s -> %s\n' "${HOD_BIN_DIR}/hod" "${SKILL_DIR}/bin/hod"
else
  cp -- "${SKILL_DIR}/bin/hod" "${HOD_BIN_DIR}/hod"
  chmod +x "${HOD_BIN_DIR}/hod"
  printf 'installed: %s (copied)\n' "${HOD_BIN_DIR}/hod"
fi

# Install global adapters when hod is available.
if [ -x "${HOD_BIN_DIR}/hod" ]; then
  HOD_HOME="$HOD_HOME" HOD_BIN_DIR="$HOD_BIN_DIR" \
    HOD_CLAUDE_DIR="${HOD_CLAUDE_DIR:-${HOME}/.claude}" \
    HOD_AGENTS_DIR="${HOD_AGENTS_DIR:-${HOME}/.agents}" \
    HOD_REPO_URL="$HOD_REPO_URL" \
    "${HOD_BIN_DIR}/hod" install || \
    printf 'warning: hod install reported a problem; run: hod doctor\n' >&2
fi

printf '\n'
printf 'hod is installed.\n'
printf '\n'
printf 'Next steps:\n'
case ":${PATH:-}:" in
  *":${HOD_BIN_DIR}:"*) ;;
  *)
    printf '  1. Add %s to PATH (add to your shell profile):\n' "$HOD_BIN_DIR"
    printf '       export PATH="%s:$PATH"\n' "$HOD_BIN_DIR"
    printf '  2. Run: hod status\n'
    printf '  3. Run: hod doctor\n'
    exit 0
    ;;
esac
printf '  1. Run: hod status\n'
printf '  2. Run: hod doctor\n'
