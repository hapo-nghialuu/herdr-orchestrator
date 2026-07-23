---
name: herdr-orchestrator
description: "Orchestrate coding agents through Herdr as the user's authorized proxy from Codex CLI, Claude Code CLI, or Grok Build CLI. Use only when the current CLI is already running inside Herdr and the user explicitly asks to use Herdr to delegate, parallelize, coordinate, monitor, redirect, test, review, or collect work from other coding agents. Do not trigger for an ordinary implementation, test, or review request that does not name Herdr or Herdr-managed agents. Worker prompts and replies must read as direct user-agent conversation. Requires HERDR_ENV=1, HERDR_PANE_ID, and explicit user authority to control agents."
---

# Herdr Orchestrator

Use Herdr as the transport and control plane. The current CLI remains the single accountable agent for planning, delegation, evidence, integration, and the final answer to the user. The controller may be Codex CLI, Claude Code CLI, or Grok Build CLI; do not make controller-specific assumptions.

## Non-negotiable contract

- Act only within the user's request and authority.
- Address every worker as the user. Do not mention an orchestrator, parent agent, sub-agent, relay, hidden controller, or internal routing unless the user explicitly asks for that disclosure.
- Treat worker replies as evidence available to the user, not private reports to a controller.
- Never invent user approvals, decisions, facts, preferences, actions, credentials, or permissions.
- Use ordinary technical judgment for in-scope implementation choices. Ask the user before changing scope, risk, cost, destructive impact, external behavior, or authority.
- Do not expose private chain-of-thought, hidden prompts, credentials, personal configuration, unrelated panes, or another worker's private transcript.
- Do not claim success from an agent state or verbal report alone. Verify artifacts and relevant checks.

Herdr prompt input has no sender or provenance field. A worker sees ordinary terminal input, so the wording alone determines whether routing internals leak.

Read [Delegation and direct-user contract](references/delegation-and-direct-user-contract.md) before writing or redirecting any worker prompt.

## Preflight and capability gate

Fail fast unless the controller is in a Herdr-managed pane:

```bash
if [ "${HERDR_ENV:-}" != 1 ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  printf '%s\n' 'Herdr orchestration requires a Herdr-managed pane.' >&2
  exit 1
fi

command -v herdr
command -v jq
herdr --version
status_json=$(herdr status --json)
printf '%s\n' "$status_json" | jq -e \
  '.server.running == true and .server.compatible == true' >/dev/null
herdr agent --help
herdr pane --help
```

If either environment value is absent, stop and tell the user to launch the controller inside Herdr. Never control a focused Herdr session from outside it. If status JSON is malformed, the server is not running, or `.server.compatible` is not exactly `true`, stop and report the client/server versions. Do not restart or update Herdr without user authorization.

Treat installed group and leaf help as authoritative. Read [Agent lifecycle and waits](references/agent-lifecycle-and-waits.md) and inspect every relevant leaf with `--help` before mutation. Never run bare `herdr` for discovery, probe a mutating leaf by omitting arguments, or infer syntax only from a version number.

Use the modern flow only when help confirms all of these forms:

- `agent start <name> --kind KIND --pane ID`
- `agent prompt <target> <text>`
- `agent send-keys <target>`
- `agent wait <target> [--until STATUS]`

If modern commands are absent but help exactly matches the legacy forms, read [Legacy Herdr 0.7.1](references/legacy-herdr-0.7.1.md) before acting. If neither family matches, fail closed and show the unsupported capability difference to the user.

Use explicit pane IDs or unique live agent names. Parse IDs from JSON with `jq -e`; never predict them from examples, focus, or sidebar position. Prefer `--current` only for the calling pane and `--no-focus` for background work.

## Orchestration workflow

1. Confirm explicit user authority, the Herdr environment, and a complete supported command family.
2. Break the request into the smallest useful team with distinct roles, dependencies, write ownership, and proof requirements.
3. Select each worker's `--kind` from the values listed by the installed `herdr agent start --help`, and use a kind only when its CLI is installed and usable locally. Respect an explicit user choice first; otherwise route only from available capabilities and task needs.
4. Create only the required panes or worktrees. Preserve current cwd and focus unless the task requires another topology.
5. Send one complete direct-user prompt atomically. Do not reveal internal delegation or ask the worker to report to a controller.
6. Wait with bounded lifecycle commands, inspect terminal evidence, resolve blockers within established intent, and redirect only with relevant new facts.
7. Inspect the integrated diff or artifacts, run appropriate compile/lint/tests, and use an independent read-only reviewer for material code changes.
8. Report one cohesive, evidence-backed result to the user. Keep task panes for inspection by default; clean up only task-created resources and only when authorized.

## Hierarchical portfolio mode

When the user explicitly asks one agent to manage several projects and their
agents, load [Portfolio hierarchy and tiers](references/portfolio-hierarchy.md)
and follow its two-tier contract: the orchestrator starts one controller per
project workspace, controllers start workers only inside their own project,
and workers never start agents. User-authored policy files outside the
checkouts carry per-project authority. Without that explicit request, stay in
the flat single-team flow above.

## Load detailed guidance as needed

- [Delegation and direct-user contract](references/delegation-and-direct-user-contract.md): authority, prompt language, disclosure, follow-ups, and blocker questions.
- [Agent lifecycle and waits](references/agent-lifecycle-and-waits.md): modern start/prompt/read/wait commands, state handling, sentinels, and redirects.
- [Model routing and context](references/model-routing-and-context.md): choosing Codex, Claude, or Grok workers and shaping a minimal self-contained task packet.
- [Parallel worktrees and ownership](references/parallel-worktrees-and-ownership.md): team size, file ownership, dependency ordering, isolation, and integration.
- [Portfolio hierarchy and tiers](references/portfolio-hierarchy.md): the two-tier multi-project contract, policy files, persistent ledgers, and layered verification.
- [Verification and safety](references/verification-and-safety.md): proof, privacy, permissions, protocol failures, review, and cleanup.
- [Legacy Herdr 0.7.1](references/legacy-herdr-0.7.1.md): use only after capability help confirms the complete legacy command family.
