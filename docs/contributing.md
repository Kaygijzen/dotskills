# Contributing to dotskills

## Repo layout

```
dotskills/
├── AGENTS.md  CLAUDE.md          how to work on this repo (CLAUDE.md is @AGENTS.md)
├── docs/                         setup, install reference, model selection, best practices,
│                                 contributing, troubleshooting, karpathy-guidelines
│   ├── diagrams/                 Mermaid diagrams (example flow)
│   └── images/                   README screenshot
├── conventions/                  my working conventions + project-template/
├── skills/<domain>/<name>/       SKILL.md, plus reference .md files, scripts/,
│                                 templates/ and agents/openai.yaml where needed
├── agents/<domain>/<name>.md     subagents
├── hooks/<domain>/               hooks.json + scripts/ (plugin installs only)
├── mcp/<domain>/.mcp.json        optional MCP configs, env vars only (planned, none yet)
├── statusline/                   vendored statusline script (MIT, licence kept)
├── templates/SKILL.md            skeleton for new skills
├── upstream.json                 provenance of imported skills
├── THIRD_PARTY_NOTICES.md        licences of imported and vendored code
├── install.sh  install.ps1       symlink installers
├── scripts/                      validate, update-readme, sync-plugin, new-skill, ci, frontmatter, upstream-status
├── .claude-plugin/               one marketplace and one plugin, both "dotskills"
└── .github/workflows/validate.yml  runs scripts/ci.sh
```

Domains organise the repo and decide what `install.sh` links. They are not separate plugins: there is one plugin, `dotskills`, containing every domain. If others ever want only some domains, per-domain plugins can be added next to it without moving files.

## How it works

`install.sh` symlinks each `skills/<domain>/<name>` folder into `~/.claude/skills/` and each agent into `~/.claude/agents/`. Claude Code reads the files straight from this repo, so an edit takes effect without a copy step.

`plugin.json` lists every domain folder under `skills`, every agent file under `agents` (the schema takes files, not folders), and the hook files, so both install methods use the same files. `scripts/sync-plugin.sh` regenerates those lists and `validate.sh` fails if they drift.

`plugin.json` has no `version`, so plugin installs track the latest commit. To pull changes on another machine, update the plugin itself, not just the marketplace (see [Updating](setup.md#7-updating)). `claude plugin validate .` warns about the missing version and about the root `CLAUDE.md` not being plugin context. Those warnings are expected.

## Adding a skill

Short version: `scripts/new-skill.sh <domain> <name>`, then `scripts/update-readme.sh && scripts/sync-plugin.sh && scripts/ci.sh`. In detail:

1. Scaffold it. The domain must exist and the name must be unused across all domains (the installer flattens names into `~/.claude/skills/<name>`).

   ```bash
   scripts/new-skill.sh engineering my-skill
   ```

2. Edit `skills/engineering/my-skill/SKILL.md`. `name` must match the folder. Put the trigger early in `description` (at most 1536 characters). Optional frontmatter:
   - `disable-model-invocation: true` runs the skill only when you type `/my-skill`.
   - `targets: [claude]` or `[claude, codex]` (default). Use `[claude]` for Claude-only features; the validator warns when a codex-targeted skill uses them.
   - `status: experimental` (default `stable`).

3. Sync and validate:

   ```bash
   scripts/update-readme.sh && scripts/sync-plugin.sh && scripts/ci.sh
   ./install.sh my-skill
   ```

## Adding a domain

Create `skills/<domain>/` and add a first skill with `scripts/new-skill.sh <domain> <name>`. Agents, hooks and MCP configs go in `agents/<domain>/`, `hooks/<domain>/` and `mcp/<domain>/`. Run `scripts/sync-plugin.sh`; `validate.sh` fails if `plugin.json` doesn't list the new folders. Then `./install.sh --domain <domain>` links it.

## Subagents, hooks and MCP

- **Subagents** (`agents/<domain>/<name>.md`) use Claude Code frontmatter (`name`, `description`, `tools`, optionally `model`). They are linked into `~/.claude/agents/`. Codex has no equivalent wired up yet.
- **Hooks** ship only through the plugin. The `core` hooks:
  - block reads and edits of `.env*`, `*.pem`, `id_rsa*`, `*.pfx` and `secrets.*` (fails open if `jq` is missing; `cat .env` through Bash is not checked). Test: `hooks/core/scripts/test-block-secrets.sh`.
  - load `conventions/AGENTS.md` at session start, unless `~/.claude/CLAUDE.md` already has the `--conventions` block. Test: `hooks/core/scripts/test-load-conventions.sh`.
- **MCP** configs are optional and none are included. Reference every secret as `${ENV_VAR}`; the validator rejects literal tokens. A starting point for `mcp/<domain>/.mcp.json`:

  ```json
  {
    "mcpServers": {
      "example": {
        "command": "npx",
        "args": ["-y", "some-mcp-server"],
        "env": { "EXAMPLE_API_KEY": "${EXAMPLE_API_KEY}" }
      }
    }
  }
  ```

## Updating imported skills

Skills copied from other repos are listed in `upstream.json` (source, path, pinned commit, and `local_changes`). To see what moved upstream:

```bash
scripts/upstream-status.sh
```

It is report-only and needs network access, so CI does not run it. It lists, per skill, whether upstream changed since the pinned commit and whether our copy differs from upstream. Skills that are both need a manual merge:

1. Read the upstream diff: `git diff <commit>..main -- <source_path>` in a clone of the source repo.
2. Re-apply it by hand, keeping the edits listed in `local_changes`.
3. Bump `commit` in `upstream.json`.
