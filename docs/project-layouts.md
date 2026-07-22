# Project Layouts and GitHub Sharing

Choose a layout based on what collaborators will clone. The included linker
implements the sibling workspace model only.

## Sibling workspace model

Use one canonical skill checkout for several adjacent Git projects:

```text
engineering-workspace/
├── herdr-orchestrator/
├── service-api/
├── web-app/
└── desktop-app/
```

The parent directory name is arbitrary. Each linked project and the canonical
checkout must be immediate children of that parent.

Install adapters:

```bash
cd engineering-workspace
./herdr-orchestrator/scripts/link-project.sh install ./service-api
./herdr-orchestrator/scripts/link-project.sh install ./web-app
./herdr-orchestrator/scripts/link-project.sh check ./service-api
./herdr-orchestrator/scripts/link-project.sh check ./web-app
```

### Advantages

- One canonical skill version for every local project.
- Updates become visible through existing symlinks.
- Project-specific `.claude/settings.json`, `.codex`, hooks, and local skills
  remain independent.

### Constraints

- Cloning a linked project by itself produces adapters whose sibling target is
  missing.
- Moving a project below another directory breaks the supported topology.
- Renaming the canonical checkout breaks the current fixed relative target.

Use this model for a personal or team workstation layout that a bootstrap
process recreates consistently.

## Sharing an umbrella workspace

A normal Git repository cannot transparently embed several unrelated Git
repositories as full children. Use a meta-repository with Git submodules or a
bootstrap script that clones each project.

Example meta-repository:

```text
team-workspace/
├── herdr-orchestrator/   # submodule
├── service-api/          # submodule
├── web-app/              # submodule
└── scripts/setup.sh
```

Clone submodules explicitly:

```bash
git clone --recurse-submodules https://github.com/your-org/team-workspace.git
```

Run the adapter installer after the layout exists. Prefer generated local
adapters over committing cross-repository symlinks into each application repo,
unless the team guarantees that every clone uses the same sibling topology.

## Standalone project model

If collaborators normally clone only one application repository, keep the skill
inside that repository instead of pointing to a missing sibling:

```text
project-a/
├── tooling/
│   └── herdr-orchestrator/
├── .agents/skills/herdr-orchestrator
└── .claude/skills/herdr-orchestrator
```

The canonical content can be vendored, added as a Git subtree, or added as a
submodule under `tooling/`. Both project adapters can then point to the internal
canonical directory.

The included `link-project.sh` does not install this topology. Create a
project-specific bootstrap script and test its relative links on every
supported operating system.

### Vendor

Best when `git clone` must work without extra commands. Updating the skill
requires synchronizing the vendored copy.

### Git subtree

Keeps files present in an ordinary clone while retaining an upstream sync
workflow. Subtree update commands require maintainers to follow a documented
process.

### Git submodule

Keeps an explicit version pointer to the canonical repository. Contributors
must clone with `--recurse-submodules` or initialize submodules afterward.

## Settings that belong in the application repository

Commit shared, non-sensitive project policy:

```text
.claude/settings.json
.claude/skills/
.agents/skills/
CLAUDE.md
AGENTS.md
```

Do not commit personal or secret-bearing state:

```text
.claude/settings.local.json
.env
credentials
session transcripts
absolute machine-specific paths
```

Use repository-relative paths and documented variables such as
`$CLAUDE_PROJECT_DIR` inside shared hooks.

## Choosing a model

| Collaboration need | Recommended layout |
| --- | --- |
| One user, many adjacent projects | Sibling workspace |
| Team clones the complete tool-and-project bundle | Meta-repository plus bootstrap |
| Team clones application repositories separately | Standalone vendored/subtree skill |
| Central version pin with explicit setup | Submodule |

The repository layout controls discovery, not authority. Every controller must
still run inside Herdr and receive an explicit user request to orchestrate
agents.
