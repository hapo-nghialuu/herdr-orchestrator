#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  link-project.sh install <project-path>
  link-project.sh check <project-path>

Link one immediate child Git project to the shared Herdr orchestrator skill.

Created adapters:
  <project>/.agents/skills/herdr-orchestrator
  <project>/.claude/skills/herdr-orchestrator

The project must remain an immediate child of the workspace that contains
herdr-orchestrator/. Codex project skills belong in .agents/skills; .codex is
reserved for project configuration. Grok reads the Claude skill adapter, so
this script does not create .grok/skills.
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 2
fi

mode=$1
project_input=$2

if [[ "$mode" != install && "$mode" != check ]]; then
  usage >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
canonical_dir=$(cd -- "$script_dir/.." && pwd -P)
workspace_dir=$(cd -- "$canonical_dir/.." && pwd -P)

[[ -f "$canonical_dir/SKILL.md" ]] || fail "canonical SKILL.md is missing"
[[ "$(basename -- "$canonical_dir")" == herdr-orchestrator ]] || \
  fail "canonical directory must be named herdr-orchestrator: $canonical_dir"
[[ -d "$project_input" ]] || fail "project path is not an existing directory: $project_input"

project_dir=$(cd -- "$project_input" && pwd -P)
[[ "$project_dir" != "$workspace_dir" ]] || fail "workspace root is not a child project"
[[ "$project_dir" != "$canonical_dir" ]] || fail "canonical package is not a child project"
[[ "$(dirname -- "$project_dir")" == "$workspace_dir" ]] || \
  fail "project must be an immediate child of $workspace_dir"
[[ -e "$project_dir/.git" ]] || fail "project must contain a .git marker: $project_dir"
[[ ! -L "$project_dir/.git" ]] || fail ".git marker must not be a symlink: $project_dir/.git"
command -v git >/dev/null 2>&1 || fail "git executable is required"

git_top=$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null) || \
  fail "project path is not a valid Git worktree: $project_dir"
git_top=$(cd -- "$git_top" && pwd -P)
[[ "$git_top" == "$project_dir" ]] || \
  fail "project path must be its Git worktree root: $project_dir"

relative_target=../../../herdr-orchestrator
codex_link=$project_dir/.agents/skills/herdr-orchestrator
claude_link=$project_dir/.claude/skills/herdr-orchestrator
links=("$codex_link" "$claude_link")
created_codex_link=false
created_claude_link=false
install_complete=false

rollback_partial_install() {
  local status=$?

  if [[ "$mode" == install && "$install_complete" != true && $status -ne 0 ]]; then
    if [[ "$created_codex_link" == true && -L "$codex_link" && \
      "$(readlink "$codex_link")" == "$relative_target" ]]; then
      rm -- "$codex_link"
      printf 'rolled back: %s\n' "$codex_link" >&2
    fi
    if [[ "$created_claude_link" == true && -L "$claude_link" && \
      "$(readlink "$claude_link")" == "$relative_target" ]]; then
      rm -- "$claude_link"
      printf 'rolled back: %s\n' "$claude_link" >&2
    fi
  fi
}

trap rollback_partial_install EXIT

check_safe_parent() {
  local path=$1

  if [[ -L "$path" ]]; then
    fail "adapter parent must not be a symlink: $path"
  fi
  if [[ -e "$path" && ! -d "$path" ]]; then
    fail "adapter parent is not a directory: $path"
  fi
}

for parent_path in \
  "$project_dir/.agents" \
  "$project_dir/.agents/skills" \
  "$project_dir/.claude" \
  "$project_dir/.claude/skills"; do
  check_safe_parent "$parent_path"
done

validate_adapter() {
  local link_path=$1
  local actual_target
  local resolved_target

  if [[ ! -e "$link_path" && ! -L "$link_path" ]]; then
    return 1
  fi
  [[ -L "$link_path" ]] || fail "adapter path already exists and is not a symlink: $link_path"

  actual_target=$(readlink "$link_path")
  [[ "$actual_target" == "$relative_target" ]] || \
    fail "adapter has unexpected target '$actual_target': $link_path"
  [[ -d "$link_path" ]] || fail "adapter is broken: $link_path"

  resolved_target=$(cd -- "$link_path" && pwd -P)
  [[ "$resolved_target" == "$canonical_dir" ]] || \
    fail "adapter resolves outside the canonical package: $link_path"
}

if [[ "$mode" == check ]]; then
  for link_path in "${links[@]}"; do
    validate_adapter "$link_path" || fail "adapter is missing: $link_path"
    printf 'ok: %s -> %s\n' "$link_path" "$relative_target"
  done
  exit 0
fi

for link_path in "${links[@]}"; do
  if validate_adapter "$link_path"; then
    printf 'already linked: %s\n' "$link_path"
  fi
done

mkdir -p -- "$project_dir/.agents/skills" "$project_dir/.claude/skills"
for parent_path in \
  "$project_dir/.agents" \
  "$project_dir/.agents/skills" \
  "$project_dir/.claude" \
  "$project_dir/.claude/skills"; do
  check_safe_parent "$parent_path"
done

for link_path in "${links[@]}"; do
  if [[ ! -e "$link_path" && ! -L "$link_path" ]]; then
    check_safe_parent "$(dirname -- "$(dirname -- "$link_path")")"
    check_safe_parent "$(dirname -- "$link_path")"
    ln -s "$relative_target" "$link_path"
    if [[ "$link_path" == "$codex_link" ]]; then
      created_codex_link=true
    else
      created_claude_link=true
    fi
    printf 'linked: %s -> %s\n' "$link_path" "$relative_target"
  fi
done

for link_path in "${links[@]}"; do
  validate_adapter "$link_path" || fail "adapter installation did not complete: $link_path"
done

install_complete=true
