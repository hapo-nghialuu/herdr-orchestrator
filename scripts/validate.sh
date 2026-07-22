#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"

bash -n scripts/link-project.sh scripts/validate.sh

python3 - <<'PY'
from pathlib import Path
import re

root = Path.cwd()
skill = (root / "SKILL.md").read_text(encoding="utf-8")
frontmatter = re.match(r"\A---\n(.*?)\n---\n", skill, re.DOTALL)
if not frontmatter:
    raise SystemExit("SKILL.md: missing YAML frontmatter")

header = frontmatter.group(1)
for field in ("name", "description"):
    if not re.search(rf"(?m)^{field}:\s*\S", header):
        raise SystemExit(f"SKILL.md: missing non-empty {field}")

missing = []
for markdown in sorted(root.rglob("*.md")):
    if ".git" in markdown.parts or "plans" in markdown.parts:
        continue
    text = markdown.read_text(encoding="utf-8")
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        relative = target.split("#", 1)[0]
        if relative and not (markdown.parent / relative).resolve().exists():
            missing.append(f"{markdown.relative_to(root)}: {target}")

if missing:
    raise SystemExit("Missing local Markdown targets:\n" + "\n".join(missing))

print("Validated Bash syntax, skill frontmatter, and local Markdown targets.")
PY
