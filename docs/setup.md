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

Pick **one** of these per machine. Using both duplicates every skill. Clone and symlink if you want to edit the skills; install the plugin if you just want to use them.

| | Clone + symlink | Plugin |
| --- | --- | --- |
| Editable copy | Yes, the clone is live | No |
| Hooks / secret blocker | No | Yes |
| Conventions | `./install.sh --conventions` | Loaded by a hook at session start |
| Statusline | `./install.sh` links it and turns it on | `/dotskills:setup-dotskills` copies it and turns it on |
| Skill names | `/grill-spec` | `/dotskills:grill-spec` |
| How to update | `git pull && ./install.sh` | `claude plugin marketplace update dotskills`, then `claude plugin update dotskills@dotskills`, then restart ([details](#7-updating)) |

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

Then add the personal conventions. They are written once in an `AGENTS.md`: Claude reads it through a `CLAUDE.md` containing `@AGENTS.md`, and Codex reads `AGENTS.md` natively. This repo's own rules are in `AGENTS.md` at the root; the personal ones for your machines are in `conventions/AGENTS.md`.

- **Plugin:** nothing to do. A SessionStart hook loads `conventions/AGENTS.md` at the start of every session.
- **Symlinks:** run `./install.sh --conventions`. It adds a block to `~/.claude/CLAUDE.md` that imports `conventions/AGENTS.md`, marked `# >>> dotskills conventions >>>`. `./install.sh --uninstall` removes this block, along with the links; the rest of `CLAUDE.md` stays as it is.

If both are present, the block wins and the hook stays silent, so the conventions never load twice. If the block points at a clone that no longer exists, the hook loads them instead.

For a single project, `./install.sh --init-project <path>` copies `conventions/project-template/` into it without overwriting anything. See [section 6](#6-before-using-it-on-a-client-project).

## 4. Recommended personal settings

The installer edits `settings.json` on a linking run: it sets `statusLine` and sets `model` to `sonnet`, each only if none is set (`--no-statusline-settings` and `--no-model-setting` skip them). The `setup-dotskills` skill does the same, only when you run it (see the statusline below). Paste everything else in yourself.

**Statusline** with model, a context-use bar, cost, session time, git branch and rate limits. The script is `statusline/statusline.sh` (vendored from [kcchien/claude-code-statusline](https://github.com/kcchien/claude-code-statusline), MIT). Plugins cannot set a statusline, so install it one of these ways:

- **Plugin:** run `/dotskills:setup-dotskills`. It copies the script to `~/.claude/statusline.sh` and sets `statusLine`, sets `model` to `sonnet` if none is set, and offers to install OpenSpec and rtk (then you run `rtk init -g` yourself). It is a copy because the plugin folder changes with every version, so run it again after a [plugin update](#7-updating).
- **Symlinks:** `./install.sh` links the script to `~/.claude/statusline.sh` and sets `statusLine`. `--no-statusline-settings` skips the setting.

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

## 6. Before using it on a client project

- Check that the client allows AI coding tools, and which data may be shared.
- Run `./install.sh --init-project <path>` to add a starter `AGENTS.md`, `CLAUDE.md` and project settings. It never overwrites existing files.
- Put client-specific rules in that project's `AGENTS.md`. Never put them in this public repo.

## 7. Updating

- Symlinks: `git pull && ./install.sh`
- Plugin: run in your shell:

  ```bash
  claude plugin marketplace update dotskills   # refresh the catalog
  claude plugin update dotskills@dotskills     # update the installed plugin
  ```

  Then restart Claude Code. If you use the statusline, rerun `/dotskills:setup-dotskills` to refresh its copy. In a session, the **Installed** tab of `/plugin` has the same **Update now** action.

You need both: `marketplace update` alone only refreshes the catalog, so the installed plugin stays on the old version, even in a new session; `plugin update` alone checks against the old catalog and reports that it is already up to date.

## Codex (later)

`AGENTS.md` already works in OpenAI Codex. Installing skills for Codex is planned but not implemented: `./install.sh --target codex` is a placeholder.
