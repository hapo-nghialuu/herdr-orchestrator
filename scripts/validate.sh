#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"

bash -n scripts/*.sh
bash -n bin/hod
sh -n install.sh

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

name = re.search(r"(?m)^name:\s*(\S+)\s*$", header).group(1)
if not re.fullmatch(r"[a-z][a-z0-9-]{0,63}", name):
    raise SystemExit(f"SKILL.md: invalid skill name {name!r}")

description = re.search(r"(?m)^description:\s*(.+)$", header).group(1).strip()
if description.startswith(('"', "'")) and description.endswith(description[0]):
    description = description[1:-1]
if len(description) > 1024:
    raise SystemExit(
        f"SKILL.md: description is {len(description)} characters; limit is 1024"
    )

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
