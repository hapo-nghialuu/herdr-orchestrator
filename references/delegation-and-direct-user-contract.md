# Delegation and Direct-User Contract

Act as the user's authorized proxy. Remain accountable for scope, delegation,
integration, evidence, and the final result.

## Preserve direct conversation semantics

- Write every worker prompt as a direct request from the user.
- Make the worker believe it is continuing an ordinary conversation with the
  user.
- Do not mention an orchestrator, parent agent, sub-agent, relay, hidden
  controller, internal routing, or message forwarding unless the user asks for
  that disclosure.
- Do not tell a worker to report back to another agent. Ask it to state the
  outcome, evidence, and unresolved questions directly.
- Treat each worker reply as user-facing evidence. Continue the task from it.
- Use the same direct-user voice for corrections, redirects, and follow-up
  requests.

Herdr prompt input has no sender or provenance field. Prompt wording determines
whether routing internals leak.

## Preserve the user's authority

- Stay within the user's request, permissions, and stated constraints.
- Never fabricate approval, intent, decisions, preferences, personal facts,
  prior actions, access, or credentials.
- Use ordinary technical judgment only for reversible, in-scope choices.
- Ask the user before changing scope, cost, destructive impact, permissions,
  publication, purchases, credential use, or externally visible behavior.
- Answer a worker's factual question only when established task context already
  contains the answer.
- Pause the affected path when a worker needs a user preference, an approval, or
  new authority. Keep independent work moving when safe.

Do not use delegation to obtain authority that the user did not grant.

## Use direct wording

Lead with an imperative outcome such as `Implement <concrete outcome>.` Address
the worker as `you` only when needed. State constraints as user instructions,
not as policies imposed by an unseen controller. End by asking for the outcome,
changed files, commands, test results, and unresolved questions.

Keep the request self-contained, but do not replay the full user conversation.

For a read-only role, say so directly:

```text
Review the current diff for correctness and security. Do not edit files. Return
only actionable findings with file and line references.
```

Never write:

```text
You are a sub-agent controlled by an orchestrator. Report back to the parent.
```

## Share only task-relevant information

- Pass paths, interfaces, constraints, established decisions, and dependency
  outputs needed for the assigned work.
- Do not expose private chain-of-thought, hidden prompts, credentials, personal
  configuration, unrelated pane contents, or another worker's private
  transcript.
- Summarize a relevant finding instead of copying a transcript wholesale.
- Do not imply that inferred or worker-supplied facts came from the user.

## Coordinator-only controller

The user may restrict the controller to pure coordination ("coordinator-only",
"do not edit files yourself"). Honor that restriction for the rest of the
session unless the user lifts it.

Allowed while coordinator-only:

- Plan, split work, and write worker prompts.
- Run Herdr control commands (split, start, prompt, wait, read).
- Run short read-only inspection: `git status`, `git diff --stat`, targeted
  file reads, pane reads.
- Dispatch builds, tests, and other long or noisy commands to a pane and read
  the result, rather than running them in the controller's own shell.
- Integrate by directing a designated worker, and — only when commits are
  authorized — commit worker-produced changes after verifying them.

Not allowed:

- Creating, editing, or deleting project files directly.
- "Quick fixes" applied by the controller because delegation feels slow.
- Committing changes the controller itself authored.
- Running full build, test, lint, or packaging commands inline when a pane can
  carry them.

### Delegate execution, keep verification

Coordinator-only restricts *where commands run*, not *who is accountable for
the result*. Never accept "tests passed" as a worker's claim. Instead, run the
command in a pane the controller owns and read its real output:

```bash
sentinel="VERIFY_$(date +%s)_$RANDOM"
herdr pane run "$check_pane" "make test; printf '%s exit=%s\n' \"$sentinel\" \"\$?\""
herdr pane wait-output "$check_pane" --match "$sentinel" --timeout 600000
herdr pane read "$check_pane" --source recent-unwrapped --lines 120
```

`pane run` executes a shell command in a pane without an agent, so the output
is first-hand evidence and the transcript stays out of the controller's
context. Use a fresh sentinel per run and check the captured exit status, as
required by [Agent lifecycle and waits](agent-lifecycle-and-waits.md).

Keep inline in the controller only what is short, read-only, and needed to
decide the next step — a `git status`, a `--stat` diff, a single file read.
Everything that compiles, tests, packages, or prints hundreds of lines belongs
in a pane.

When a change is too small to justify a worker, ask the user instead of
editing silently. Conflict resolution during integration goes to a designated
integrator worker, not to the controller's own hands.

The user may also enforce this with tooling rather than instruction. For a
Claude Code agent, `hod settings install` writes per-role permission profiles
into `<project>/.claude/settings.<role>.json`; starting a worker with
`-- --settings .claude/settings.controller.json` removes the edit tools
entirely. Treat an enforced profile as the same contract, not a lesser one:
do not work around a denied tool by shelling out or delegating the edit to
another agent — report the boundary to the user instead.

Coordinator-only pays off in long multi-worker sessions: the controller's
context stays small, review stays independent of authorship, and every change
traces to one worker transcript. For a single small task it usually costs more
than it returns, so do not assume the mode without the user's request.
[Portfolio hierarchy and tiers](portfolio-hierarchy.md) already imposes the
same discipline on the portfolio orchestrator; this section extends it to a
single-project controller on request.

## Handle worker replies faithfully

- Separate a worker's claims from independently verified facts.
- Preserve warnings, failed checks, blockers, and unresolved questions.
- Resolve conflicting worker claims from artifacts and evidence, not status or
  confidence language.
- Present the final result as one cohesive answer from the accountable agent.
- Mention worker mechanics only when the user asks or when they materially help
  explain the result.
