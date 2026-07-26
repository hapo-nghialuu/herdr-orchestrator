# Parallel Worktrees and Ownership

Use the smallest team that materially improves speed or quality. Keep work
sequential when coordination would cost more than the parallel work saves.

## Design the team first

Before creating panes, maintain a small internal ledger with:

- unique agent name and role;
- worker kind;
- pane, workspace, and optional worktree and branch;
- exact files or globs owned for writing;
- task, acceptance criteria, and required proof;
- dependencies and current state;
- integration owner.

Choose short role names matching `[a-z][a-z0-9_-]{0,31}`, such as `api_impl`,
`tester`, and `reviewer`. Give each worker a distinct, useful role. Do not create
duplicate workers with the same task.

A ledger held only in the controller's context dies with the session, and the
loss scales with team size: which worker owns which file becomes unrecoverable
exactly when it matters most. From three concurrent workers on, write the
ledger to a file outside the project checkout — one task-scoped path, Markdown,
updated whenever ownership, status, or dependencies change. Below three
workers, an in-context ledger is enough. A controller resuming after a restart
reconciles from that file plus `herdr agent list`, and adopts or replaces each
agent explicitly rather than guessing.

Use one interactive coding agent per pane. Default to sibling panes in the
current tab and current working directory. Add workspaces, tabs, sessions, or
worktrees only when topology or isolation requires them.

## Separate independent and dependent work

- Parallelize only tasks that can complete without consuming each other's
  unfinished edits.
- Chain dependent work in the required order, commonly implementation, testing,
  then read-only review.
- Name each dependency input and its expected artifact or interface.
- Do not start a blocked dependent worker merely to keep all panes busy.
- Re-evaluate the ledger before a follow-up changes task boundaries.

Prefer one worker when the task is small, touches one shared file, or requires
tightly interleaved decisions.

## Enforce disjoint file ownership

- Assign exactly one live writer to each file.
- Express ownership as exact paths or narrow globs.
- Keep reviewers read-only.
- Give testers ownership only of test files unless a fix is explicitly
  reassigned to them.
- Give shared manifests, lockfiles, migrations, indexes, and integration files
  to one designated integration owner.
- Preserve unrelated user changes in every checkout.

If two workers need the same file, sequence their turns or reassign ownership
before either edits. Stop conflicting edits immediately. Resolve the intended
result centrally; never let workers race and hope the final write wins.

Central resolution means one accountable decision, not one pair of hands. Name
a single integrator worker and give it the conflicting files; the controller
decides the intended outcome and states it, but does not edit. This is
mandatory whenever parallel work produces overlapping edits — a controller
that repairs a conflict itself has silently become a writer, and the change
loses its worker transcript.

## Choose checkout isolation

Use one checkout with disjoint ownership when workers can safely share the
working tree. Use separate Git worktrees when agents need isolation and the
repository workflow permits the commits or integration required to bring work
back.

For each worktree:

- record the absolute path and branch in the ledger;
- start its worker with that worktree as the working context;
- keep file ownership disjoint across worktrees too;
- avoid broad formatting or generated-file rewrites outside ownership;
- commit only when the user request or repository workflow authorizes it;
- preserve a traceable diff for integration.

Do not use worktrees to bypass user approval, repository rules, or shared-file
coordination. Do not force-push or destructively reset another worker's branch.

## Integrate through one owner

Designate one owner to assemble the final state. That owner must:

1. Confirm prerequisite workers are settled and their evidence is readable.
2. Inspect each actual diff and artifact before accepting it.
3. Resolve interface mismatches and ownership conflicts.
4. Bring approved changes into the target checkout using the repository's
   permitted workflow.
5. Run validation against the integrated state, not isolated worker states.
6. Request independent read-only review for material code changes.

Worker completion does not transfer ownership automatically. Update the ledger
before asking another worker to modify an already owned file.
