# Role Boundaries

A role is defined by the promise the controller may trust, not by the mechanism. Each CLI enforces that promise with its strongest available layer. Where a mechanism cannot reach, the boundary becomes prompt wording and the controller checks evidence.

## Three promises

| Role | Promise | Claude | Codex |
| --- | --- | --- | --- |
| `reviewer` | Cannot change anything or spawn agents. Always use a fresh session; never resume. | [`settings.reviewer.json`](../templates/settings-reviewer.json) | `-s read-only -c features.multi_agent=false` |
| `controller` | Does not do task work or spawn agents. | [`settings.controller.json`](../templates/settings-controller.json) | `-s workspace-write --ask-for-approval never -c sandbox_workspace_write.network_access=true -c features.multi_agent=false` |
| `impl` | May edit code and commit; must not publish (`push`/`merge`) or spawn agents. | [`settings.impl.json`](../templates/settings-impl.json) | `-s workspace-write --ask-for-approval never -c sandbox_workspace_write.network_access=true -c 'sandbox_workspace_write.writable_roots=["<abs-repo>/.git"]'` |

Codex worker examples, passed after Herdr's `--` separator:

```bash
# reviewer: fresh session; never resume
herdr agent start reviewer --kind codex --pane "$pane" \
  -- -s read-only -c features.multi_agent=false

# controller: needs the Herdr socket, which read-only blocks (see Honest gaps)
herdr agent start controller --kind codex --pane "$pane" \
  -- -s workspace-write --ask-for-approval never \
  -c sandbox_workspace_write.network_access=true \
  -c features.multi_agent=false

# impl: replace <abs-repo> with the repository's absolute path
herdr agent start impl --kind codex --pane "$pane" \
  -- -s workspace-write --ask-for-approval never \
  -c sandbox_workspace_write.network_access=true \
  -c 'sandbox_workspace_write.writable_roots=["<abs-repo>/.git"]'
```

The `<abs-repo>` replacement matters because Codex protects `.git` by default in `workspace-write`; opening only that repository's `.git` lets `git commit` create its lock. `workspace-write` also cuts network by default; `sandbox_workspace_write.network_access=true` re-opens it for this impl profile. Do not replace `-c features.multi_agent=false` with `--disable multi_agent`: the former removes `spawn_agent` from context; the latter does not provide this boundary.

## Honest gaps

- Claude reviewer and controller profiles still leave `Bash` available. Codex `read-only` blocks OS writes, so these Claude roles are weaker at the harness layer. Prompt wording and controller evidence must enforce their promises.
- Claude shell-prefix denies are not complete command sandboxes. The existing profiles therefore need prompt discipline and evidence checks; never treat a matching `Bash(...)` deny as proof that every equivalent shell path is blocked.
- The existing Claude impl profile blocks the named publish commands but does not remove every route to them, and does not remove `Agent`; controller must check commit, no publication, and no child-agent evidence.
- Codex impl deliberately opens network and `.git` so it can work and commit. It does not hard-block `push`, `merge`, `reset`, or `tag`; that boundary is wording-level and evidence-checked, unlike Claude's deny rules for the named commands.
- A Codex controller cannot be sandbox-locked and still drive Herdr. Verified on `0.146.0`: `herdr status` fails with `Operation not permitted` under `read-only` and under default `workspace-write`; it works only with `sandbox_workspace_write.network_access=true`, because the seatbelt network rule also covers Herdr's Unix socket. So the controller's no-edit promise on Codex is wording-level plus evidence — exactly the same weakness as Claude's controller profile, which leaves `Bash` open. The two CLIs are symmetric at precisely this point.

## Verified Codex behavior

Verified experimentally with codex-cli `0.145.0` on macOS; re-verified with `0.146.0`:

- The `0.146.0` impl proof committed successfully: `ce220e4 proof`; `rev-list count = 2`.
- `-s read-only` rejects writes at the OS layer: `patch rejected: writing is blocked by read-only sandbox`.
- `-s workspace-write` cuts network (`Could not resolve host`). `-c sandbox_workspace_write.network_access=true` re-opens network access on this version. Older seatbelt issue [#10390](https://github.com/openai/codex/issues/10390) was fixed in the tested version.
- `.git` is read-only under `workspace-write`; commit fails with `Unable to create .git/index.lock: Operation not permitted` until `sandbox_workspace_write.writable_roots` includes the absolute repository `.git` path. The same protection applies to `.codex/` and `.agents/`.
- `features.multi_agent` is `stable`; `-c features.multi_agent=false` removes `spawn_agent` from context.
- Interactive `codex` accepts `--ask-for-approval` with `untrusted`, `on-request`, or `never`. `codex exec` has no approval flag: it is non-interactive, and sandbox is its only boundary. Do not pass `-a` to `codex exec`.

CLI arguments override `config.toml`. Official references: [config reference](https://developers.openai.com/codex/config-reference), [config sample](https://developers.openai.com/codex/config-sample), and [advanced configuration](https://developers.openai.com/codex/config-advanced).
