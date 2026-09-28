# dotskills

My personal [Claude Code skills](https://code.claude.com/docs/en/skills), kept in one repo and installable two ways:

- **On this machine:** `install.sh` symlinks each skill into `~/.claude/skills/`, so edits here are live in Claude Code right away. Claude Code watches that folder, so you don't need to restart or copy anything.
- **On any other machine:** the repo is also a Claude Code plugin marketplace, so two commands install everything.

Both methods read the same `skills/` folder.

## Layout

```
dotskills/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md          # required: frontmatter + instructions
│       └── ...               # optional supporting files and scripts
├── .claude-plugin/
│   ├── marketplace.json      # makes the repo a marketplace named "dotskills"
│   └── plugin.json           # the repo root is also the "dotskills" plugin; it loads skills/
├── scripts/validate.sh       # checks every SKILL.md's frontmatter
├── install.sh                # symlink installer for local development
└── .github/workflows/validate.yml
```

## Add a new skill

1. Create `skills/<skill-name>/SKILL.md`. The folder name must be lowercase letters, digits and hyphens.

   ```markdown
   ---
   name: <skill-name>
   description: What it does and when Claude should use it. Put the main trigger first.
   ---

   # Instructions for Claude go here.
   ```

   `name` must match the folder name, and `description` must be under 1536 characters.
2. Run `./install.sh --check` to validate it.
3. Run `./install.sh <skill-name>` (or plain `./install.sh`) to link it. The skill is then available in Claude Code as `/<skill-name>`.

## Install

### Local development (this machine)

```bash
./install.sh                  # link every skill; safe to rerun, picks up new skills
./install.sh grill-spec       # link just one (or several) skills by name
./install.sh --uninstall      # remove every symlink this script created
./install.sh --uninstall NAME # remove just one
./install.sh --check          # validate all SKILL.md files
```

The installer only touches symlinks that point into this repo:

- If `~/.claude/skills/<name>` already exists as a real folder, or as a symlink to somewhere else, it warns and skips that skill.
- If you delete or rename a skill here, the next full `./install.sh` removes its dangling link.
- To link into a different skills folder, set `CLAUDE_SKILLS_DIR`.

The script uses plain bash and works on macOS and Linux.

### Another machine (plugin marketplace)

In a Claude Code session:

```
/plugin marketplace add <github-user>/dotskills
/plugin install dotskills@dotskills
```

Or from a shell:

```bash
claude plugin marketplace add <github-user>/dotskills
claude plugin install dotskills@dotskills
```

Plugin skills are namespaced, so they appear as `/dotskills:<skill-name>`.

`plugin.json` deliberately has no `version`, so installs track the repo's commits. To pull new commits, run `/plugin marketplace update dotskills`, or turn on auto-update for the marketplace under **Marketplaces** in `/plugin`. Because of this, `claude plugin validate .` shows a "No version specified" warning, which is expected.

Don't use both methods on the same machine. If you do, every skill shows up twice: once as `/<name>` and once as `/dotskills:<name>`.
