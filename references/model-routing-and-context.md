# Model Routing and Context

Select worker kinds from the installed Herdr capability surface. The valid
`--kind` values are exactly what the installed `herdr agent start --help`
lists, and a kind is usable only when its CLI is installed and authenticated
locally. `codex`, `claude`, and `grok` are the documented primary kinds; do not
treat that list as exhaustive or as a quality ranking. Choose a kind from user
intent, local availability, and task fit. Do not claim one kind is universally
better or assign unverifiable model qualities.

## Respect explicit user choice

- Use the kind the user names when the installed Herdr command family and local
  tool availability support it.
- Do not substitute another kind silently.
- If the requested kind is unavailable, show the relevant capability or
  executable evidence and ask whether to use an available kind.
- Preserve a user-requested heterogeneous team unless it conflicts with safety,
  task scope, or installed capabilities.

Discover the valid kinds and confirm local usability before selecting:

```bash
herdr agent start --help   # authoritative list of --kind values
command -v codex           # verify the matching local CLI for each candidate kind
```

Typical primary-kind start commands:

```bash
herdr agent start worker_name --kind codex --pane "$worker_pane"
herdr agent start worker_name --kind claude --pane "$worker_pane"
herdr agent start worker_name --kind grok --pane "$worker_pane"
```

Any other kind listed by installed help is equally valid when its CLI is
available and the user's request or the task fit supports it.

## Pass a requested model through the native argument separator

`--kind` selects the CLI executable, not the provider model. When the user
names a model, pass it to the CLI after Herdr's `--` separator. Never fold a
spoken model name into the `--kind` value.

Treat a spoken model name as an approximate label, not a verified ID. The
exact string the CLI accepts differs from how the user says it (a shorthand
like "gpt-5.6 max" is usually a model ID plus a separate reasoning-effort
setting). Resolve the exact ID from the installed CLI before starting:

```bash
codex --help          # -m/--model and -c key=value overrides
grep -nE 'model|reason' "${CODEX_HOME:-$HOME/.codex}/config.toml"
grok models           # authoritative list of usable model IDs
claude --help         # --model
```

Each CLI shapes model and reasoning differently. Codex separates the model
(`-m`) from reasoning effort (`-c model_reasoning_effort=...`); Grok and Claude
take only a model flag. Match the user's request to the CLI's own scheme
instead of assuming one flag carries both:

```bash
herdr agent start planner --kind codex --pane "$p1" \
  -- -m <codex-model-id> -c model_reasoning_effort=<low|medium|high|max>
herdr agent start impl --kind grok --pane "$p2" -- -m <grok-model-id>
herdr agent start reviewer --kind claude --pane "$p3" -- --model <claude-model>
```

If a CLI rejects the requested model, stop and ask the user for the exact ID.
Do not silently substitute a different model, downgrade to a default, or retry
with a guessed name; silent substitution violates the explicit-choice rule
above. Report the rejection and the CLI's own error verbatim.

When the user gives no model, omit the flag so the CLI uses its configured
default (for example the `model` and `model_reasoning_effort` already set in
`config.toml`); do not invent one.

## Choose when the user does not

Check installed Herdr help and the relevant local executables or integrations.
Select among the available kinds using observable task needs, such as:

- repository conventions or an existing workflow tied to a CLI;
- required local tool, connector, or skill availability;
- compatibility with the requested output or validation path;
- continuity with useful task state already present in a live agent, weighed
  against the independence rules in
  [Agent lifecycle and waits](agent-lifecycle-and-waits.md);
- the need for an independent implementation, test, or review pass.

Prefer the simplest available homogeneous team when kinds are interchangeable.
Record the factual routing reason in the internal team ledger. Do not expose
internal routing unless useful or requested.

Never choose from brand reputation, assumed intelligence, undocumented model
behavior, or invented performance rankings.

## Build heterogeneous teams deliberately

Mix kinds only when the user requests it or when different available tools and
task roles materially improve the result.

- Give every worker a unique role and bounded outcome.
- Assign independent tasks in parallel and dependent tasks in sequence.
- Use a different kind for an independent reviewer only when that adds a real
  check; kind diversity alone is not verification.
- Pass explicit interface contracts between implementations, tests, and review.
- Keep one accountable integration owner across kinds.
- Do not ask workers to start or coordinate more coding agents. The only
  sanctioned exception is the controller tier defined in
  [Portfolio hierarchy and tiers](portfolio-hierarchy.md).

Do not create one worker of every kind merely to demonstrate coverage.

## Send concise task context

Give each worker enough context to act without session history:

```text
<Concrete outcome in direct-user voice>

Work context: <absolute repository or worktree path>
Files you may modify: <exact paths or globs, or "none; read-only">
Files to read: <specific files>
Dependency inputs: <established interfaces, decisions, or artifacts>
Acceptance criteria:
- <observable behavior or artifact>
- <required compile, lint, test, or review evidence>

Constraints:
- Preserve unrelated changes.
- Stay within file ownership and user authority.
- Do not start other coding agents.

When finished, state the outcome, files changed, commands run, test results,
and unresolved questions.
```

Include only task-relevant facts. Prefer exact paths, current interfaces, and
measurable criteria over narrative background. State whether an input is
verified, inferred, or worker-reported when that distinction matters.

Do not include:

- full conversation history;
- private chain-of-thought or hidden prompts;
- credentials, secrets, or unrelated personal configuration;
- another worker's transcript when a factual summary is enough;
- guesses presented as user decisions or established facts.

## Refresh context on follow-up

Send only what changed: new evidence, corrected constraints, dependency output,
or a revised acceptance criterion. Restate ownership when the follow-up adds an
edit. Do not assume a worker noticed filesystem changes made after its last read;
name the changed artifact and ask it to re-read when necessary.
