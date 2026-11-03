# Setting up Claude Code

Last checked: 2026-11-02 against the Claude Code docs at code.claude.com/docs.

## 1. Install Claude Code and sign in

Follow the official install steps at <https://code.claude.com/docs/en/quickstart>, then run `claude` and sign in. If you use an API key, keep it in an environment variable or your shell profile. It never goes in a repo, and never in a prompt.

## 2. Make Sonnet your default model

On most plans the account default is Opus. Set Sonnet yourself in `~/.claude/settings.json`:

```json
{
  "model": "sonnet"
}
```

Check it with `/model`. Sonnet is the default because it is the best balance of quality, speed and cost for day-to-day work. See [model-selection.md](model-selection.md) for when to switch.

## 3. Install dotskills

Prerequisites: `git` and `jq` (used by the installer, the secret hook and the statusline). Node 20.19+ with npm is needed only for the optional OpenSpec install.

Pick **one** of these. Using both duplicates every skill.

**Plugin marketplace** (no clone needed, installs every domain):

```
/plugin marketplace add Kaygijzen/dotskills
/plugin install dotskills@dotskills
```

**Symlink installer** (for machines where you edit the skills):

```bash
git clone https://github.com/Kaygijzen/dotskills.git
cd dotskills
./install.sh                 # every domain; or: ./install.sh --domain engineering
```

Then add the personal conventions, which plugins cannot ship. This applies to plugin installs too, so run it from a clone either way:

```bash
./install.sh --conventions
```

This adds a clearly marked block to `~/.claude/CLAUDE.md` that imports `conventions/AGENTS.md`. `./install.sh --uninstall` removes only that block.

## 4. Recommended personal settings

The installer edits `settings.json` only when you pass `--statusline-settings` (see the statusline below). Paste everything else in yourself.

**Statusline** with model, a context-use bar, cost, session time, git branch and rate limits. `./install.sh` links `statusline/statusline.sh` (vendored from [kcchien/claude-code-statusline](https://github.com/kcchien/claude-code-statusline), MIT) to `~/.claude/statusline.sh`. Run `./install.sh --statusline-settings` to set `statusLine` for you (backs up `settings.json` first, and never overwrites a `statusLine` you already have), or add it yourself:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "timeout": 10
  }
}
```

Optional env vars: `CLAUDE_STATUSLINE_NERDFONT=1`, `CLAUDE_STATUSLINE_POWERLINE=1`, `CLAUDE_STATUSLINE_ASCII=1`. Needs `jq`. Prefer your own? Run `/statusline` instead and skip the link with `./install.sh --uninstall statusline`.

**Permission allowlists** instead of `--dangerously-skip-permissions`. Allow the safe commands you run all the time:

```json
{
  "permissions": {
    "allow": ["Bash(git status)", "Bash(git diff:*)", "Bash(npm test:*)"]
  }
}
```

**IDE integration:** if you use VS Code or JetBrains, install the Claude Code extension from your IDE's marketplace.

## 5. Smoke test

1. Run `/dotskills:hello-skill` (plugin) or `/hello-skill` (symlinks). It prints where it loaded from.
2. Run `/memory` and check that `~/.claude/CLAUDE.md` is listed. Then ask Claude "what are my commit message conventions?" to confirm the import resolves.
3. Ask Claude to read a `.env` file. The secret hook (plugin installs only; the symlink installer does not ship hooks) should block it and explain why.

Per project: run `/dotskills:setup-dotskills` once (or `/setup-dotskills` with symlinks) to set the issue tracker and domain docs for the engineering skills. The tracker can be local markdown files in the repo, which needs nothing else. For GitHub or GitLab, setup also connects the tracker's MCP server: GitHub needs a personal access token, and GitLab needs version 19.5 or newer. The `gh`/`glab` CLIs are optional; the skills fall back to them only for a few steps, and `wayfinder` still uses them.

## 6. Before using it on a client project

- Check that the client allows AI coding tools, and which data may be shared.
- Run `./install.sh --init-project <path>` to add a starter `AGENTS.md`, `CLAUDE.md` and project settings. It never overwrites existing files.
- Put client-specific rules in that project's `AGENTS.md`. Never put them in this public repo.

## 7. Updating

- Plugin: `/plugin marketplace update dotskills`
- Symlinks: `git pull && ./install.sh`

## Codex (later)

`AGENTS.md` already works in OpenAI Codex. Installing skills for Codex is planned but not implemented: `./install.sh --target codex` is a placeholder.
