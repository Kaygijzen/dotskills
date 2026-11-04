# Working on dotskills

A public repo of Claude Code skills, subagents, hooks and conventions, shared like dotfiles. Plain bash and awk; `jq` is the only required dependency. Node/npm (OpenSpec), the `claude` CLI (`ralph-apply`) and network access (`upstream-status.sh`) are optional.

## Layout
- `skills/<domain>/<name>/SKILL.md`: skills. Names are unique across all domains (the installer flattens them).
- `agents/<domain>/<name>.md`: subagents.
- `hooks/<domain>/hooks.json` plus `hooks/<domain>/scripts/`: hooks. Ship through the plugin only.
- `mcp/<domain>/.mcp.json`: optional MCP configs. Secrets only as `${ENV_VAR}`. None yet.
- `statusline/`: vendored statusline script (MIT, upstream LICENSE kept). `install.sh` symlinks it to `~/.claude/statusline.sh`; for plugin installs the `setup-statusline` skill copies it there.
- `conventions/`: personal conventions and the project template.
- `docs/`: user and contributor docs. `templates/SKILL.md`: skeleton for new skills.
- `install.sh` (Linux/macOS) and `install.ps1` (Windows): symlink installers.
- `upstream.json`: provenance and local edits of skills imported from mattpocock/skills.
- `scripts/`: `validate.sh`, `update-readme.sh`, `sync-plugin.sh`, `new-skill.sh`, `ci.sh`, plus helpers `frontmatter.sh` and `upstream-status.sh`.
- `.claude-plugin/`: one marketplace and one plugin, both named `dotskills`.

## Rules
- The repo is public. No personal, client or secret data. Ever.
- `install.sh` only creates, updates or removes symlinks into this repo and its managed block in `~/.claude/CLAUDE.md`. It edits `settings.json` only with `--statusline-settings`, and then only the `statusLine` key. It also replaces or removes a copy of the statusline that the `setup-statusline` skill made.
- The `setup-statusline` skill follows the same rules: it runs only when the user invokes it, edits only the `statusLine` key, backs up `settings.json` once and never overwrites a different `statusLine` or someone else's `statusline.sh`.
- Versioning is `head`: manifests have no `version`.

## Workflow
- New skill: `scripts/new-skill.sh <domain> <name>`.
- New domain: `scripts/new-skill.sh <domain> <name>` creates `skills/<domain>/` with a first skill; add `agents/`, `hooks/`, `mcp/` folders as needed.
- After adding, removing or moving anything: `scripts/update-readme.sh` then `scripts/sync-plugin.sh`.
- Before committing: `scripts/ci.sh` must pass.
- Do not hand-edit the generated README tables or the path lists in `plugin.json`.
