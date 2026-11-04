# Install script reference

`install.sh` also asks whether to install two command-line tools if they're missing: the [OpenSpec](https://github.com/Fission-AI/OpenSpec) CLI, which `grill-spec` needs, and [rtk](https://github.com/rtk-ai/rtk), an optional hook that cuts the tokens Bash output uses. `install.ps1` does the same. Both are optional and nothing is installed without a yes.

**Windows:** the recommended route is WSL, then follow the bash instructions in the README. For native PowerShell, clone onto a local drive (not a `\\wsl$` path) and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

| Command | What it does |
| --- | --- |
| `./install.sh` | Links every domain's skills and agents. Safe to rerun; removes links to items deleted from the repo. |
| `./install.sh --domain engineering` | Links `core` plus the named domain(s). Repeatable. |
| `./install.sh --all` | Every domain (the default, spelled out). |
| `./install.sh grill-spec code-reviewer` | Links only the named skills or agents. |
| `./install.sh --conventions` | Adds the managed import block to `~/.claude/CLAUDE.md`. |
| `./install.sh --init-project <path>` | Copies the project template into `<path>`, skipping existing files and reporting them. |
| `./install.sh --uninstall [NAME...]` | Removes only what this script created, including the conventions block. |
| `./install.sh --check` | Runs `scripts/validate.sh`. |
| `./install.sh --statusline-settings` | Sets `statusLine` in `settings.json`, the only key the script edits. Backs up the file first and never overwrites an existing `statusLine`. Writes through a symlinked `settings.json` and quotes the command path, so spaces work (an unquoted path from an older version is updated). Needs `jq`. |
| `./install.sh --target codex` | Placeholder: prints "not implemented yet" and exits 0. |
| `./install.sh --with-openspec` | Installs the OpenSpec CLI with npm if it's missing, without asking. Needs Node.js 20.19.0 or newer. |
| `./install.sh --no-openspec` | Skips the OpenSpec question. |
| `./install.sh --with-rtk` | Installs rtk if it's missing and runs `rtk init -g`, without asking. |
| `./install.sh --no-rtk` | Skips the rtk questions. |
| `./install.sh --help` | Prints usage. |

A full install (no `--uninstall`, `--check`, `--help` or `--target codex`) warns if `jq` is missing and ends with next steps. A missing `jq` does not fail the install. The next steps suggest `--conventions` only when the block is not installed yet.

A regular file at `~/.claude/statusline.sh` that is a copy of the dotskills statusline (made by the `setup-statusline` skill) counts as the installer's own: a full install replaces it with a link, and `--uninstall` removes it.

Without a terminal to answer on (CI, piped input), neither script installs OpenSpec or rtk unless you pass the matching `--with-…` / `-With…` option, and neither runs `rtk init -g`, since it can ask its own questions. In those cases the script prints how to do it yourself.

On Windows, `install.ps1` takes these options as PowerShell switches: `-Uninstall`, `-Check`, `-WithOpenSpec`, `-NoOpenSpec`, `-WithRtk`, `-NoRtk` and `-Help`. It differs from `install.sh` in these ways:

- It links skills only. Agents, the statusline, `--domain`, `--all`, `--conventions`, `--init-project`, `--statusline-settings` and `--target` have no PowerShell equivalent; run them with `install.sh` from WSL or Git Bash. With the plugin, `/dotskills:setup-statusline` installs the statusline instead (it needs bash and `jq`, for example from Git Bash).
- Its next steps point to `install.sh --conventions` instead of running it.
- It links with directory junctions, which need no admin rights or Developer Mode. Junctions can't point at network paths, so the repo has to be on a local drive. If junctions fail, it falls back to a symlink, which needs Developer Mode.
- It installs rtk with `winget install rtk-ai.rtk` instead of rtk's shell script.
- `-Check` runs `scripts/validate.sh`, so it needs bash from Git Bash or WSL.

To link into different folders (handy for testing), set `CLAUDE_SKILLS_DIR`, `CLAUDE_AGENTS_DIR` or `CLAUDE_CONFIG_DIR`:

```bash
CLAUDE_CONFIG_DIR=/tmp/test-claude ./install.sh --conventions
```

**Name conflicts:** the script only creates, updates or removes symlinks that point into this repo's `skills/` and `agents/` folders. It prints a `WARN` line and skips the skill in two cases:

- `~/.claude/skills/<name>` (or `~/.claude/agents/<name>.md`) is a real file or folder.
- It is a symlink to somewhere else.

When a skill is skipped this way, the script exits with status 1. Uninstall leaves both kinds of entry alone.

## Saving tokens with rtk

[rtk](https://github.com/rtk-ai/rtk) is a single Rust binary plus a Claude Code `PreToolUse` hook. The hook rewrites Bash commands such as `git status`, `git diff` and test runs to `rtk` equivalents that filter, group and truncate the output before Claude reads it; the project reports 60-90% less output on common dev commands. It only touches Bash tool calls, not the built-in `Read`, `Grep` and `Glob` tools, and it trims Bash output only, so the saving on your total bill is smaller than that.

`./install.sh` offers to install it and run `rtk init -g`; `--with-rtk` or `--no-rtk` skips the prompt (see the table above). `rtk gain` shows what it has saved. It is optional; nothing in this repo depends on it.
