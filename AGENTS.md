# Working on dotskills

A public repo of Claude Code skills, subagents, hooks and conventions, shared like dotfiles. Plain bash and awk; the only dependency is `jq`.

## Layout
- `skills/<domain>/<name>/SKILL.md`: skills. Names are unique across all domains (the installer flattens them).
- `agents/<domain>/<name>.md`: subagents.
- `hooks/<domain>/hooks.json` plus `hooks/<domain>/scripts/`: hooks. Ship through the plugin only.
- `mcp/<domain>/.mcp.json`: optional MCP configs. Secrets only as `${ENV_VAR}`.
- `statusline/`: vendored statusline script (MIT, upstream LICENSE kept). `install.sh` symlinks it to `~/.claude/statusline.sh`.
- `conventions/`: personal conventions and the project template.
- `scripts/`: `validate.sh`, `update-readme.sh`, `sync-plugin.sh`, `new-skill.sh`, `ci.sh`.
- `.claude-plugin/`: one marketplace and one plugin, both named `dotskills`.

## Rules
- The repo is public. No personal, client or secret data. Ever.
- `install.sh` only creates, updates or removes symlinks into this repo and its managed block in `~/.claude/CLAUDE.md`. It edits `settings.json` only with `--statusline-settings`, and then only the `statusLine` key.
- Versioning is `head`: manifests have no `version`.

## Workflow
- New skill: `scripts/new-skill.sh <domain> <name>`.
- New domain: create `skills/<domain>/` (and `agents/`, `hooks/`, `mcp/` as needed) with a first component.
- After adding, removing or moving anything: `scripts/sync-plugin.sh` then `scripts/update-readme.sh`.
- Before committing: `scripts/ci.sh` must pass.
- Do not hand-edit the generated README tables or the path lists in `plugin.json`.
