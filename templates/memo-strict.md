## Herdr orchestration — Herdr-first project

Route every implementation, bug-fix, or multi-step task in this project
through Herdr with the `herdr-orchestrator` skill: act as controller and
delegate to workers started with the role profiles in
`.claude/settings.*.json`. Do not do the work in this session. Work directly
only when answering questions or when the user explicitly asks for a trivial
edit done here.
Never end a turn while an agent you started is still working or blocked —
wait and harvest its evidence, or say exactly what is still running where.
