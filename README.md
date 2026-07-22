# Herdr Orchestrator

Herdr Orchestrator is a reusable skill and project linker for coordinating
Codex CLI, Claude Code CLI, and Grok Build CLI through
[Herdr](https://herdr.dev/). It keeps one accountable controller responsible
for planning, delegation, evidence, verification, and the final result shown to
the user.

This repository includes:

- a concise Codex / Claude / Grok skill entry point;
- a deterministic project linker for sibling-workspace layouts;
- human documentation for setup, usage, layouts, and troubleshooting;
- operational references for safe multi-agent work.

This is an independent community project. It is not affiliated with Herdr,
OpenAI, Anthropic, or xAI.

## What It Does

- Lets Codex, Claude Code, or Grok Build act as the controller.
- Starts and addresses supported coding-agent CLIs in Herdr panes.
- Routes work by role, dependency, file ownership, and available capability.
- Supports sequential pipelines and isolated parallel worktrees.
- Preserves direct user-to-agent conversation semantics.
- Requires artifact, test, and review evidence before reporting success.
- Fails closed on incompatible Herdr client/server protocols or unknown command
  families.

## What It Does Not Do

- It does not install, authenticate, or pay for coding-agent CLIs.
- It does not grant permissions the user did not already provide.
- It does not force every task into multi-agent mode.
- It does not treat an agent's `done` state as proof of correctness.
- It does not automatically commit, merge, push, publish, delete, or clean up
  resources without user authority.

## Supported Surfaces

| Surface | Project adapter | Typical invocation |
| --- | --- | --- |
| Codex CLI | `.agents/skills/herdr-orchestrator` | `$herdr-orchestrator` |
| Claude Code CLI | `.claude/skills/herdr-orchestrator` | `/herdr-orchestrator` |
| Grok Build CLI | `.claude/skills/herdr-orchestrator` | Ask explicitly to use the `herdr-orchestrator` skill |

Herdr must support the agent kind you select. Treat the installed `herdr ... --help`
output as the command authority.

## Prerequisites

- macOS or Linux.
- Herdr, Git, and `jq`.
- At least one supported coding-agent CLI installed and authenticated:
  Codex, Claude Code, or Grok Build.
- A real Git project to link.

Install Herdr with the official installer:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

Or with Homebrew:

```bash
brew install herdr
```

Verify the tools you plan to use:

```bash
herdr --version
git --version
jq --version
command -v codex
command -v claude
command -v grok
```

Only one controller CLI is required. Install the others only when you want to
mix worker kinds.

## Quick Start

### 1. Create a sibling workspace

The linker intentionally uses a strict sibling layout. The canonical
`herdr-orchestrator` checkout and each linked project must be immediate
children of the same workspace directory.

```text
my-workspace/
├── herdr-orchestrator/
├── project-a/
└── project-b/
```

The workspace directory may have any name. The canonical checkout must retain
the directory name `herdr-orchestrator` because the adapters resolve that
relative target.

```bash
mkdir -p ~/work/my-workspace
cd ~/work/my-workspace
git clone https://github.com/hapo-nghialuu/herdr-orchestrator.git
PROJECT_REPO_URL='https://github.com/OWNER/REPOSITORY.git'
git clone "$PROJECT_REPO_URL" project-a
```

### 2. Link a project

```bash
cd ~/work/my-workspace
./herdr-orchestrator/scripts/link-project.sh install ./project-a
./herdr-orchestrator/scripts/link-project.sh check ./project-a
```

The installer creates two relative symlinks without replacing existing project
policy, hooks, or local skills:

```text
project-a/.agents/skills/herdr-orchestrator
  -> ../../../herdr-orchestrator

project-a/.claude/skills/herdr-orchestrator
  -> ../../../herdr-orchestrator
```

The operation is idempotent. It rejects non-Git directories, nested projects,
unexpected adapter targets, unsafe adapter-parent symlinks, and conflicting
files. If installation fails, links created by that invocation are rolled back.
Concurrent hostile mutation of the target checkout is outside the threat model;
run the linker only against projects you control.

### 3. Launch the controller inside Herdr

```bash
cd ~/work/my-workspace/project-a
herdr
```

Start one controller in a Herdr-managed shell pane:

```bash
codex
```

or:

```bash
claude
```

or:

```bash
grok
```

The skill requires the controller to run inside Herdr. A normal terminal
outside Herdr will not have `HERDR_ENV=1` and `HERDR_PANE_ID`, so the
orchestration preflight stops rather than controlling an unrelated session.

### 4. Delegate a task

Minimal request example:

```text
Use Herdr and the herdr-orchestrator skill to implement the health endpoint.

Requirements:
- Read README.md and the repository instructions first.
- Keep implementation, tests, and review sequential.
- Use one writer at a time.
- Run the repository's relevant checks.
- Do not commit or push.
- Return changed files, test results, and unresolved questions.
```

You may select worker kinds and models explicitly, or leave routing to the
controller. Native CLI arguments belong after Herdr's `--` separator when an
agent is started.

## How Orchestration Works

```text
User request
    │
    ▼
Controller in a Herdr-managed pane
    │  validates environment, server compatibility, and command capabilities
    ▼
Smallest useful worker team
    │  direct-user prompts, explicit ownership, bounded waits
    ▼
Integrated artifacts and fresh validation
    │  diff inspection, tests, independent read-only review
    ▼
One evidence-backed result for the user
```

The controller remains responsible throughout the workflow. Workers receive
task-local context and speak directly to the user; they are not told to report
to a hidden parent. Worker claims remain unverified until the controller checks
the artifacts and relevant commands.

## Common Workflows

### Sequential feature pipeline

Use this default for dependent work:

```text
Plan or inspect → Implement → Test → Read-only review → Integrate and verify
```

### Parallel independent work

Use parallel workers only when their inputs are ready and write ownership is
disjoint. Use separate Git worktrees when checkout isolation is necessary.
Keep shared manifests, generated files, migrations, and integration changes
under one designated owner.

### Cross-platform development and bug fixing

Create separate worktrees for independent platform work. If both paths need a
shared core file, stop concurrent writing, assign that file to one owner, and
sequence the dependent updates.

See [Usage guide](docs/usage-guide.md) for copy-ready prompts and routing
patterns.

## Safety Model

The skill enforces several non-negotiable boundaries:

- Explicit user authority is required before agent control begins.
- Worker prompts must not invent user decisions, approvals, access, or facts.
- Credentials, hidden prompts, private chain-of-thought, and unrelated pane
  contents must not be forwarded.
- Destructive actions, publication, purchases, credential use, and permission
  changes require existing user authority or a new user decision.
- Timeouts trigger inspection, not blind prompt resubmission.
- Agent state never replaces diff, test, build, or runtime evidence.
- Task-created panes and worktrees remain available for inspection unless the
  user authorizes cleanup.

Read [Delegation and direct-user contract](references/delegation-and-direct-user-contract.md)
and [Verification and safety](references/verification-and-safety.md) for the
full operational contract.

## Repository Structure

```text
herdr-orchestrator/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── scripts/
│   ├── link-project.sh
│   └── validate.sh
├── references/
│   ├── agent-lifecycle-and-waits.md
│   ├── delegation-and-direct-user-contract.md
│   ├── legacy-herdr-0.7.1.md
│   ├── model-routing-and-context.md
│   ├── parallel-worktrees-and-ownership.md
│   └── verification-and-safety.md
└── docs/
    ├── getting-started.md
    ├── project-layouts.md
    ├── troubleshooting.md
    └── usage-guide.md
```

`SKILL.md` stays concise and loads detailed references only when the current
workflow needs them. The `docs/` directory is written for human operators and
repository maintainers.

## Documentation

- [Getting started](docs/getting-started.md)
- [Usage guide and prompt recipes](docs/usage-guide.md)
- [Project layouts and GitHub sharing](docs/project-layouts.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Official Herdr documentation](https://herdr.dev/docs/)
- [Official Herdr CLI reference](https://herdr.dev/docs/cli-reference/)

## Known Limitations

- The linker supports only immediate-child Git projects in a sibling workspace.
- The canonical directory name is currently fixed to `herdr-orchestrator`.
- Native Windows is not currently supported or tested by this repository.
- Worker model availability depends on each user's provider account and CLI.
- The legacy Herdr 0.7.1 reference is a best-effort compatibility path and is
  not maintained at parity with current stable Herdr. Current stable Herdr is
  recommended for new workflows.
- This repository does not install Herdr integrations or change global agent
  configuration.

## Contributing

Focused issues and pull requests are welcome. Keep runtime changes small,
preserve the direct-user contract, and include validation evidence. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under the [MIT License](LICENSE). Copyright (c) 2026 Luu Trung Nghia.
