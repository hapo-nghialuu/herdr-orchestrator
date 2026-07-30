# Troubleshooting

Start with read-only evidence. Do not restart Herdr, update binaries, replace
adapters, or kill pane processes merely to test a theory.

## The skill does not activate

Confirm the adapter exists:

```bash
hod install --project ./project-a
hod status
```

Confirm you started the controller from the linked project and invoked the
skill explicitly. Codex reads `.agents/skills`; Claude Code and Grok Build use
the `.claude/skills` adapter.

## `Herdr orchestration requires a Herdr-managed pane`

The controller was started outside Herdr, or the environment was stripped.

Check:

```bash
printf 'HERDR_ENV=%s\n' "${HERDR_ENV:-<unset>}"
printf 'HERDR_PANE_ID=%s\n' "${HERDR_PANE_ID:-<unset>}"
```

Start Herdr from the project, then launch the controller inside a Herdr shell
pane. Do not export fake values to bypass this guard.

## Server is running but incompatible

Inspect structured status:

```bash
herdr status --json | jq '{client, server}'
```

The workflow requires both:

```text
.server.running == true
.server.compatible == true
```

Do not stop or update a running Herdr session automatically. Stopping a server
can terminate processes in its panes. Choose a maintenance window and follow
the official Herdr update documentation.

## Adapter already exists and is not a symlink

The installer refuses to replace existing content. Inspect it:

```bash
ls -ld project-a/.agents/skills/herdr-orchestrator
ls -ld project-a/.claude/skills/herdr-orchestrator
```

Decide whether the existing directory is a project-owned skill that must be
preserved. Do not delete or overwrite it without confirming ownership and
backup requirements.

## Requested worker kind is unavailable

Inspect Herdr and the executable:

```bash
herdr agent start --help
command -v codex
command -v claude
command -v grok
```

Do not silently substitute another worker kind when the user named one. Install
the requested CLI or ask the user whether an available kind is acceptable.

## Agent remains `working`

Continue waiting with a bounded timeout. Do not resend the original prompt.
After a timeout, inspect:

```bash
herdr agent get <agent-name>
herdr agent read <agent-name> --source recent-unwrapped --lines 160
```

Timeout is a monitoring event, not task failure.

## Agent state is `unknown`

Read its terminal evidence and ask Herdr to explain detection:

```bash
herdr agent read <agent-name> --source recent-unwrapped --lines 160
herdr agent explain <agent-name> --verbose
```

Do not assume completion or send input to a guessed target.

## A test appears to pass from old pane output

Herdr output waits may match text already present in a reused pane. Run each
command with a unique sentinel and captured exit code, then wait for that exact
sentinel. See
[Operations](../references/operations.md#sentinel-guarded-checks).

## A Claude project model is ignored

Check for higher-priority session or local configuration:

- A native `--model` argument affects the launched session.
- Environment variables may override settings.
- `.claude/settings.local.json` may override shared project settings.
- Resumed sessions may retain their previous model.

Start a new session without a native model override when you want the project
default to apply.

## Collecting a useful issue report

Include:

- operating system and architecture;
- `herdr --version`;
- redacted `herdr status --json` client/server fields;
- relevant leaf `--help` output;
- controller and requested worker kind;
- exact adapter check output;
- expected behavior and actual behavior;
- commands and exit statuses;
- whether the task used a main checkout or Git worktree.

Remove tokens, credentials, personal paths, private repository names, and
unrelated pane output before posting publicly.
