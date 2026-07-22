# Agent Lifecycle and Waits

Use installed Herdr help as the command authority. Detect capabilities before
creating or controlling an agent.

## Confirm the modern command family

Run read-only discovery commands:

```bash
command -v herdr
command -v jq
herdr --version
status_json=$(herdr status --json)
printf '%s\n' "$status_json" | jq -e \
  '.server.running == true and .server.compatible == true' >/dev/null
herdr agent --help
herdr pane --help
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

Stop before any control action unless status JSON parses and both
`.server.running` and `.server.compatible` are exactly `true`. On failure,
surface the client and server versions without restarting or updating Herdr.
Do not treat a reachable but incompatible server as usable.

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
position. Use `--current` only for the calling pane.

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
herdr agent wait api_impl --until idle --timeout 120000
```

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
| `agent_prompt_stalled` | Confirm target, foreground agent, and visible input before retrying. |
| `agent_not_running` | Refresh `agent list`; never guess another pane or target. |

`done` is the unseen-attention form of the same ready state as `idle`. A CLI
read does not mark the work seen. Neither state proves that the task succeeded.
Blocked detection is strict and may miss an unfamiliar prompt, so always inspect
the final visible output. Use `agent explain` before acting on a suspicious
classification.

Keep the user informed during long waits.

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
