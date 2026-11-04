# Setting up Claude Code

Last checked: 2026-11-02 against the Claude Code docs at code.claude.com/docs.

## 1. Install Claude Code and sign in

Follow the official install steps at <https://code.claude.com/docs/en/quickstart>, then run `claude` and sign in. If you use an API key, keep it in an environment variable or your shell profile. It never goes in a repo, and never in a prompt.

On a corporate network that inspects TLS, the installer can fail with a certificate error. See [Behind a TLS-inspecting proxy](troubleshooting.md#behind-a-tls-inspecting-proxy).

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

Every flag is listed in the [install reference](install-reference.md).

Then add the personal conventions:

- **Plugin:** nothing to do. A hook loads `conventions/AGENTS.md` at the start of every session.
- **Symlinks:** run `./install.sh --conventions`. It adds a clearly marked block to `~/.claude/CLAUDE.md` that imports `conventions/AGENTS.md`. `./install.sh --uninstall` removes this block, along with the links; the rest of `CLAUDE.md` stays as it is.

If both are present, the block wins and the hook stays silent, so the conventions never load twice. If the block points at a clone that no longer exists, the hook loads them instead.

## 4. Recommended personal settings

The installer edits `settings.json` only when you pass `--statusline-settings`, and the `setup-statusline` skill only when you run it (see the statusline below). Paste everything else in yourself.

**Statusline** with model, a context-use bar, cost, session time, git branch and rate limits. The script is `statusline/statusline.sh` (vendored from [kcchien/claude-code-statusline](https://github.com/kcchien/claude-code-statusline), MIT). Plugins cannot set a statusline, so install it one of these ways:

- **Plugin:** run `/dotskills:setup-statusline`. It copies the script to `~/.claude/statusline.sh` and sets `statusLine`. Run it again after a plugin update to refresh the copy.
- **Symlinks:** `./install.sh` links the script to `~/.claude/statusline.sh`. Run `./install.sh --statusline-settings` to set `statusLine`.

Both back up `settings.json` first and never overwrite a `statusLine` you already have. Or add it yourself:

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
2. Ask Claude "what are my commit message conventions?". With symlinks, also run `/memory` and check that `~/.claude/CLAUDE.md` is listed.
3. Ask Claude to read a `.env` file. The secret hook (plugin installs only; the symlink installer does not ship hooks) should block it and explain why.

Per project: run `/dotskills:setup-dotskills` once (or `/setup-dotskills` with symlinks). It sets the issue tracker and domain docs for the engineering skills, and connects the tracker's MCP server where there is one.

| Tracker | What you need | Notes |
| --- | --- | --- |
| Local markdown | Nothing else | Issues are files in the repo. |
| GitHub | A personal access token | Connects the GitHub MCP server. |
| GitLab | GitLab 19.5 or newer | Connects the GitLab MCP server. |
| Azure DevOps | Either a custom Microsoft Entra app registration with admin consent, or Node 20+ and `az login` | The app registration is for the remote server; the organization must be backed by an Entra tenant. Node and `az login` are for the local server. |

The `gh` and `glab` CLIs are optional. The skills fall back to them only for a few steps, and `wayfinder` still uses them.

## 6. Before using it on a client project

- Check that the client allows AI coding tools, and which data may be shared.
- Run `./install.sh --init-project <path>` to add a starter `AGENTS.md`, `CLAUDE.md` and project settings. It never overwrites existing files.
- Put client-specific rules in that project's `AGENTS.md`. Never put them in this public repo.

## 7. Updating

- Plugin: `/plugin marketplace update dotskills`
- Symlinks: `git pull && ./install.sh`

## Codex (later)

`AGENTS.md` already works in OpenAI Codex. Installing skills for Codex is planned but not implemented: `./install.sh --target codex` is a placeholder.
