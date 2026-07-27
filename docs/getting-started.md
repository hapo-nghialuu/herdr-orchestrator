# Getting Started

This guide installs Herdr Orchestrator into a sibling workspace, verifies the
adapters, and starts the first controller session.

## 1. Understand the parts

- **Herdr** provides persistent terminal panes, agent detection, lifecycle
  state, and a local control API.
- **The controller** is one Codex, Claude Code, or Grok Build session launched
  inside Herdr.
- **Workers** are additional coding-agent sessions started and addressed by the
  controller.
- **Herdr Orchestrator** is the skill that defines routing, authority,
  verification, privacy, and cleanup behavior.

The controller is the only integration owner. Herdr transports terminal input
and state; it does not decide whether worker output is correct.

## 2. Install prerequisites

Install current stable Herdr on macOS or Linux:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

Homebrew alternative:

```bash
brew install herdr
```

Install Git and `jq` through your operating system package manager. Install and
authenticate at least one controller CLI separately.

Verify availability:

```bash
herdr --version
git --version
jq --version
command -v codex || true
command -v claude || true
command -v grok || true
```

Missing optional CLIs are acceptable. Do not request a worker kind that is not
installed and supported by local Herdr help. Any other kind listed by
`herdr agent start --help` works the same way when its CLI is installed.

Install the Herdr integration for each agent CLI you plan to run
(recommended):

```bash
herdr integration install claude
herdr integration install codex
herdr integration status
```

Without an integration, Herdr detects agent state from screen output
(heuristic). With one, lifecycle state comes from an authoritative source, so
the sidebar and every `agent wait` become more reliable. Install integrations
yourself: agents must not install them on your behalf.

## 3. Prepare the workspace

Use a directory containing the canonical skill checkout and one or more Git
projects as immediate children:

```bash
mkdir -p ~/work/agent-workspace
cd ~/work/agent-workspace
git clone https://github.com/hapo-nghialuu/hod.git herdr-orchestrator
PROJECT_REPO_URL='https://github.com/OWNER/REPOSITORY.git'
git clone "$PROJECT_REPO_URL" project-a
```

Required topology:

```text
agent-workspace/
├── herdr-orchestrator/
└── project-a/
    └── .git
```

The project may be a main checkout or Git worktree. Its `.git` marker must be a
real file or directory, not a symlink, and the supplied path must be the Git
worktree root.

## 4. Install and verify adapters

Easier path with `hod` (no sibling workspace required — installs global adapters
and can target one project):

```bash
curl -fsSL https://raw.githubusercontent.com/hapo-nghialuu/hod/main/install.sh | sh
hod status
hod install --project ~/work/agent-workspace/project-a   # optional project link
```

Manual sibling-layout alternative:

```bash
cd ~/work/agent-workspace
./herdr-orchestrator/scripts/link-project.sh install ./project-a
./herdr-orchestrator/scripts/link-project.sh check ./project-a
```

Expected check output names both adapters and their local Git excludes:

```text
ok: .../project-a/.agents/skills/herdr-orchestrator -> ../../../herdr-orchestrator
ok: .../project-a/.claude/skills/herdr-orchestrator -> ../../../herdr-orchestrator
ok: excluded from git: .agents/skills/herdr-orchestrator
ok: excluded from git: .claude/skills/herdr-orchestrator
```

The installer also records both adapter paths in the project's local
`.git/info/exclude` so the machine-specific symlinks are not committed by
accident. That file is local-only and never committed.

The script is safe to run again when both adapters are already correct. It
stops instead of replacing an existing non-symlink skill or following an unsafe
parent symlink.

## 5. Start Herdr from the project

```bash
cd ~/work/agent-workspace/project-a
herdr
```

Herdr launches or attaches to its persistent session. Start your chosen
controller in a shell pane at the project root:

```bash
codex
```

Use `claude` or `grok` instead when that CLI should control the workflow.

Inside a correctly managed pane, these variables are available:

```bash
test "${HERDR_ENV:-}" = 1
test -n "${HERDR_PANE_ID:-}"
```

Do not export fake values outside Herdr. They are environment evidence, not a
feature toggle.

## 6. Confirm server compatibility

The controller performs this preflight automatically. To inspect it manually:

```bash
status_json=$(herdr status --json)
printf '%s\n' "$status_json" | jq -e \
  '.server.running == true and .server.compatible == true'
```

Also confirm the relevant command family:

```bash
herdr agent --help
herdr pane --help
herdr agent start --help
herdr agent prompt --help
herdr agent wait --help
```

Do not mix syntax from different Herdr versions. The installed leaf command
help is authoritative.

## 7. Submit the first task

Invoke the skill explicitly and describe an observable outcome:

```text
Use Herdr and herdr-orchestrator to add GET /health.

Read the repository instructions first. Keep one implementation writer, run the
relevant tests, request an independent read-only review, and do not commit or
push. Return the changed files, command results, and unresolved questions.
```

The controller will choose the smallest useful workflow. It may keep the task
single-agent when additional workers would add coordination cost without a real
quality or speed benefit.

## 8. Configure project-specific models

Use each CLI's native project configuration for defaults. For Claude Code, a
project can set a default in `.claude/settings.json`:

```json
{
  "model": "sonnet"
}
```

When the file already contains hooks or permissions, add the `model` field to
the existing JSON object rather than replacing it.

A task-specific native `--model` argument passed when the worker starts should
override the project default for that session. Model names, availability, and
effort controls remain provider-specific and may change over time.

## Next Steps

- Follow [Usage guide](usage-guide.md) for team patterns and prompt recipes.
- Read [Project layouts](project-layouts.md) before publishing an umbrella
  workspace or embedding the skill in another repository.
- Use [Troubleshooting](troubleshooting.md) when adapters or preflight checks
  fail.
