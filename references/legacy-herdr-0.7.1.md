# Legacy Herdr 0.7.1

Use this file only when `herdr agent` confirms the legacy command family. Do not switch to it merely because a parsed version string looks old.

## Confirm the legacy capabilities

All of these forms must appear in group help:

```text
agent start <name> ... -- <argv...>
agent send <target> <text>
agent wait <target> --status idle|working|blocked|unknown
wait agent-status <pane_id> --status idle|working|blocked|done|unknown
```

Modern `agent prompt` must be absent. If the help is mixed or different, stop and ask the user to update Herdr or provide matching documentation.

## Start and address a legacy agent

Legacy `agent start` creates or splits topology while launching the provided executable:

```bash
start_json=$(herdr agent start api_impl \
  --cwd "$PWD" \
  --split right \
  --no-focus \
  -- codex)

worker_pane=$(printf '%s\n' "$start_json" | jq -er '.result.agent.pane_id')
herdr agent wait api_impl --status idle --timeout 30000
```

Use `--workspace` or `--tab` only with an explicit ID parsed from JSON or caller context. Put every native executable flag after `--`.

## Submit work safely

Legacy `agent send` writes literal bytes and does **not** press Enter. Never treat it as a prompt-submission command.

Resolve the agent's pane, then use the pane's atomic text-plus-Enter path:

```bash
agent_json=$(herdr agent get api_impl)
worker_pane=$(printf '%s\n' "$agent_json" | jq -er '.result.agent.pane_id')
herdr pane run "$worker_pane" "$task_prompt"
```

Wait for an observed working transition when possible, then for a settled state:

```bash
herdr agent wait api_impl --status working --timeout 10000
herdr agent wait api_impl --status idle --timeout 120000
herdr agent read api_impl --source recent-unwrapped --lines 160
```

Legacy `agent wait --status idle` also accepts the pane's `done` attention state. If the working transition times out, inspect `agent get` and `agent read`; the turn may have completed or detection may have missed the transition. Do not resend blindly.

Use `herdr wait agent-status "$worker_pane" --status done` only when the unseen `done` distinction materially matters. Use `herdr wait output` for ordinary non-agent processes, with the same unique per-run sentinel and captured-exit-status guard required by the main skill; legacy output waits can also match stale pane text.

## Legacy limits

- Prompt submission has no modern `agent_prompt_stalled` guard and no turn correlation.
- `agent wait` accepts one exact requested status and has different `done` behavior from modern Herdr.
- Agent targets are more permissive than modern Herdr. Still use only the unique name created for the task or its explicit pane ID.
- Read and verify output after every wait. State alone is not success.
- Prefer updating to a current stable Herdr release for new orchestration workflows; do not update it automatically.
