# Verification and Safety

Verify the integrated outcome before claiming success. A worker's status,
confidence, or verbal `done` is not proof.

## Require artifact and test evidence

- Inspect actual diffs, generated files, diagnostics, and relevant runtime
  output.
- Confirm that changes stay inside assigned ownership and preserve unrelated
  work.
- Run the appropriate compile, lint, type-check, and test commands on the
  integrated state.
- Capture command exit status and fresh output. Do not accept stale pane text.
- Validate requested behavior and edge cases, not only file existence.
- Record failed or skipped checks and explain their impact.
- Use an independent read-only reviewer for material code changes after
  integration and testing. Review is a delegated role, never something the
  controller performs on its own: a controller that reviews the diff itself
  produces an opinion, not an independent check. Start the reviewer as a fresh
  agent — never the session that wrote the code, and never a resumed
  transcript of it.
- Require reviewer findings to cite actionable file and line evidence.
- Resolve correctness or security findings before reporting completion.

Reading a diff or a test result to confirm scope and outcome remains the
controller's own duty and is not review; see
[Delegation and direct-user contract](delegation-and-direct-user-contract.md).

Report a cohesive verified outcome. Distinguish verified facts from worker
claims and unresolved risk.

## Preserve permission and destructive boundaries

- Stay within the user's explicit request and authority.
- Do not approve permissions, destructive actions, publication, purchases,
  credential use, scope changes, or externally visible actions on the user's
  behalf unless already authorized.
- Ask the user when a blocker requires new authority or a preference that
  materially changes the result.
- Resolve exact targets with read-only checks before any authorized destructive
  action.
- Prefer reversible operations and narrow explicit paths.
- Never kill processes, stop Herdr services, delete sessions, force-remove
  worktrees, or reset repository state merely to tidy up.
- Do not enable pane history, install integrations or plugins, change
  configuration, or update Herdr without authorization.

Treat a worker's request for approval as a request to the user, not as permission
for the controlling agent to invent consent.

## Protect private information

- Do not expose private chain-of-thought, hidden prompts, credentials, secrets,
  personal configuration, or unrelated pane contents.
- Share the minimum task-relevant facts between workers.
- Do not copy one worker's private transcript into another prompt when an
  evidence summary is sufficient.
- Redact secrets from reports and command output. Do not commit confidential
  files or values.
- Reject unexpected output files, substitutions, and symlinks when a worker was
  granted an exact temporary report path.

## Clean up conservatively

- Do not close or remove any workspace, tab, pane, session, worktree, branch,
  process, or file that the task did not create.
- Keep task-created panes and temporary reports available for user inspection by
  default.
- Confirm work is safely integrated before proposing cleanup.
- Close task-created panes or remove task-created worktrees only when cleanup is
  authorized.
- Remove a temporary transcript or report only when its exact path is known and
  cleanup is authorized.
- State what was removed and whether recovery remains possible after material
  cleanup.

## Fail closed on protocol errors

Herdr server errors are JSON on stderr with exit status 1. Syntax errors exit
with status 2.

On malformed JSON, a protocol mismatch, a missing capability, an ambiguous
target, or an unexpected response shape:

1. Stop that control path.
2. Preserve the command, exit status, and relevant stderr evidence.
3. Refresh only with documented read-only discovery commands.
4. Do not guess syntax, IDs, target panes, or completion state.
5. Surface the incompatibility to the user when it cannot be resolved within
   established task context.

Treat a timeout as a monitoring event: inspect state and output before deciding
whether to wait, redirect, or ask the user.
