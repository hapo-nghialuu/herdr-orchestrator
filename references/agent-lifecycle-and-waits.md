# Agent Lifecycle and Waits

Use installed Herdr help as the command authority. Detect capabilities before
creating or controlling an agent.

## Confirm the modern command family

The environment and server gate in `SKILL.md` is the single canonical
preflight and must already have passed. Do not treat a reachable but
incompatible server as usable. Then inspect every relevant leaf with read-only
help commands:

```bash
herdr agent start --help
herdr agent prompt --help
herdr agent send-keys --help
herdr agent wait --help
herdr agent get --help
herdr agent read --help
herdr agent explain --help
herdr pane split --help
herdr pane run --help
herdr pane wait-output --help
```

Use the modern flow only when help confirms all of these forms:

```text
agent start <name> --kind KIND --pane ID
agent prompt <target> <text>
agent send-keys <target>
agent wait <target> [--until STATUS]
```

Treat group and leaf help as authoritative. A group listing proves only that a
subcommand exists; require the matching leaf help to prove its signature and
flags. Never run bare `herdr` for discovery. Never probe a mutating leaf command
by omitting arguments. Do not infer syntax from a version number. If the modern
forms are incomplete, stop this path and report the exact capability difference
so the caller can select a fully matching command family. Do not mix command
families.

Use explicit pane IDs or unique live agent names. Parse IDs from JSON with
`jq -e`; never predict an ID from an example, focus, pane order, or sidebar
position. Use `--current` only for the calling pane. The calling context is
identified by `HERDR_PANE_ID`, `HERDR_TAB_ID`, and `HERDR_WORKSPACE_ID`; read
these instead of guessing where the controller is. Workspace, tab, and pane
IDs are opaque and stable, and a closed ID is never reused. After
`pane move`, continue with the new pane ID from the move result; an in-flight
wait on the old pane ends with `agent_not_running`.

Agent state is authoritative only when the matching Herdr integration is
installed; otherwise it is screen-detected and heuristic. Check
`herdr integration status` read-only and surface a recommendation to the
user when an integration is missing. Never install one without user
authorization.

## Create, start, and prompt

Inspect the current layout. Split right for a wide pane or down for a tall,
narrow pane. Preserve the working directory and focus:

```bash
split_json=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
worker_pane=$(printf '%s\n' "$split_json" | jq -er '.result.pane.pane_id')
worker_kind=codex # Set to codex, claude, or grok before starting the agent.
herdr agent start api_impl --kind "$worker_kind" --pane "$worker_pane"
```

`agent start` requires an existing available shell pane; it does not create
topology. Put native agent arguments only after `--`.

Starting a worker bare when the project ships a role profile discards the
user's configuration without any error. Check for one first and pass it in the
same command; see
[Model routing and context](model-routing-and-context.md).

Submit one complete direct-user prompt atomically:

```bash
herdr agent prompt api_impl "$task_prompt" --wait --timeout 120000
```

`agent prompt` handles bracketed paste and Enter. Do not reproduce prompt
submission with raw text and key calls. Its wait is lifecycle-based, not
turn-correlated. A current turn can satisfy the wait when the target was already
working, so do not prompt a working agent unless sending an urgent correction.

For a separate bounded wait, use the confirmed modern wait form:

```bash
herdr agent wait api_impl --timeout 120000
```

Without `--until`, the wait settles on `idle`, `done`, or `blocked`; do not
restate those defaults. Pass `--until` only to demand one specific state, and
request `unknown` explicitly when needed.

After each settled wait, inspect structured state and terminal evidence:

```bash
herdr agent get api_impl
herdr agent read api_impl --source recent-unwrapped --lines 160
```

## Wait conservatively

Prefer bounded `agent wait` or `agent prompt --wait` calls. Never blind-poll or
abandon a task merely because one wait timed out.

| State or error | Required action |
| --- | --- |
| `working` | Continue waiting. Do not duplicate the prompt. |
| `blocked` | Read the pane. Answer only from established user intent; otherwise ask the user. |
| `idle` or `done` | Read output, then verify requested artifacts and checks. |
| `unknown` | Read output and run `herdr agent explain <target> --verbose`; never assume completion. |
| timeout | Inspect `agent get` and `agent read`; do not blindly resend. |
| `agent_prompt_stalled` | The prompt did not submit; see below. Nothing read after this error is worker output. |
| `agent_not_running` | Refresh `agent list`; never guess another pane or target. |

`done` is the unseen-attention form of the same ready state as `idle`. A CLI
read does not mark the work seen. Neither state proves that the task succeeded.
Blocked detection is strict and may miss an unfamiliar prompt, so always inspect
the final visible output. Use `agent explain` before acting on a suspicious
classification.

### A stalled prompt produced nothing

Per the installed help, `agent prompt --wait` requires an observed state change
shortly after submission; `agent_prompt_stalled` means none occurred — the
prompt never entered the agent. Whatever the pane shows afterwards is your own
text sitting unsent in the input box. Reading it back proves delivery failed,
not that work happened: matching your own prompt on screen and reporting it as
a result fabricates a completion that never ran. Recover in order:

1. Confirm the target and that the agent is the pane's foreground process.
2. Read the pane; your prompt visible in the input box confirms the stall.
3. Submit it (`agent send-keys <target> enter`) or re-prompt.
4. Confirm the agent actually left its pre-submission state — a settled
   `agent wait` or a changed `agent_status` in `agent get` — before treating
   anything on that screen as the worker's work.

Keep the user informed during long waits.

With several workers running, wait on them in turn rather than blocking on one
until it finishes: refresh `agent list`, then take the settled or blocked ones
first. A worker sitting `idle` with a finished result is not done — it is
waiting to be harvested, and an unharvested worker is the usual reason a team
appears stalled. Harvest each one's evidence and open questions before starting
the next round.

### Finish the roster before finishing the reply

A turn that ends while an owned agent is `working` or `blocked` orphans it. A
blocked worker's question reaches no one: the pane sits waiting for an answer
that will not come, and the user discovers the stalled team only by opening
panes. Before composing the final reply, run `agent list` one last time and
settle every agent this task started — wait on the `working`, resolve or
escalate the `blocked`. When stopping early is genuinely unavoidable, the
report must name each remaining agent, its pane, its state, and what it is
waiting for; a report that omits a live worker abandons it.

## Continue a live agent or start a fresh one

`agent start` always begins a new session with empty context; `agent prompt`
against a live agent continues its existing conversation. Decide from the work
itself, not from convenience.

Continue the live agent when all of these hold:

- the request directly extends what that agent just did (fix a failing check,
  finish the artifact it produced, answer its blocking question);
- its accumulated context is worth keeping — files already read, conventions
  already learned, decisions already established;
- the role and owned files are unchanged.

Start a fresh agent when any of these hold:

- the task needs an **independent perspective**: review, a second opinion, or a
  competing approach. A reviewer must never be the session that wrote the code;
  a session cannot audit reasoning it authored;
- the role, owned files, or work context changes, so stale assumptions would
  leak into the new task;
- the existing session is spent — context is bloated, it went down a wrong
  path, or it carries information the new task must not see;
- the two tasks require information isolation.

Prefer continuity for genuine follow-ups, but never trade away independent
verification to save context. When in doubt for a review or audit step, start
fresh. Record the reuse or restart decision and its reason in the team ledger.

### Reviving a context after the agent exited

A live agent is the cheapest continuation, but its context is not lost when it
exits. Most agent CLIs can reload a previous transcript at startup — Claude
Code takes `--continue` for the latest conversation in that directory and
`--resume` to pick one. Pass such a flag after `--`:

```bash
herdr agent start api_impl --kind claude --pane "$worker_pane" -- --continue
```

Use this when the same role resumes the same work and its earlier context is
worth more than the tokens to rebuild it — the agent had read many files,
learned conventions, or established decisions the new task depends on.

Resuming reopens exactly the reasoning the fresh-start rules above exist to
avoid, so the same bar applies, only harder to see: **never resume a
transcript for a review, audit, or second-opinion step.** A resumed reviewer
looks independent and is not. When the role, owned files, or work context
changed, start genuinely fresh instead. State in the ledger that a session was
resumed, and from which task, so a later reader can tell an independent pass
from a continued one.

Do not prompt an agent that is `working` unless the message is an urgent
correction: Herdr does not correlate turns, so the active turn may satisfy the
wait and the reply may be read against the wrong request.

## Redirect and interrupt

- Send a follow-up through `agent prompt` in direct-user voice. Include the new
  evidence, corrected constraint, or narrowed outcome.
- Do not restart an agent or duplicate its original task when a follow-up is
  sufficient.
- Use `herdr agent send-keys <name> esc` or `ctrl+c` only for a deliberate
  interactive interruption that is within scope and safer than continued work.
- Re-read state and visible output after an interruption.
- Refresh the agent list after an agent exits. Never silently retarget work to a
  different pane.

Use `agent send-keys` only for interactive controls. Use `pane run` and
`pane wait-output` for shell commands, tests, servers, and log watchers.

## Guard against stale pane output

`pane wait-output` searches text already present before it waits. Never accept a
generic match such as `passed` from a reused pane as fresh evidence.

For each finite command:

1. Generate a unique per-run sentinel.
2. Run the command with a wrapper that prints that sentinel and the captured
   exit status after the command finishes.
3. Wait for that exact sentinel.
4. Read the fresh output and verify both the result and exit status.
5. Use a new sentinel for every invocation.

For a long-running server, emit a run-specific startup token and separately
verify that the expected process remains alive.

## Recover missing full-screen output

Alternate-screen agents may not retain old rows. First enlarge the pane or read
the visible screen. If transcript recovery still fails and the user's existing
authority already permits a report write, allocate one task-scoped temporary
directory and one exact Markdown path. Grant only that one-file exception and
accept only the exact regular file: reject substitutions, symlinks, and paths
outside the allocated directory. If the worker was assigned read-only and the
user did not already authorize a written report, do not expand its role; ask the
user before granting the exception. Retain the file for user inspection unless
cleanup is authorized.
