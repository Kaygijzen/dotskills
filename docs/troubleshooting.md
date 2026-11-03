# Troubleshooting

**A skill doesn't show up.** Check that the symlink exists and points into this repo:

```bash
ls -la ~/.claude/skills
```

Claude Code notices changes in `~/.claude/skills` while a session is running. If the folder didn't exist when the session started, restart Claude Code.

**Validation fails.** Run the validator on one skill to see the reason:

```bash
scripts/validate.sh my-skill
```

Common causes:

- `name` doesn't match the folder name.
- `description` is missing.
- `plugin.json` is out of sync: run `scripts/sync-plugin.sh`.
- The file doesn't start with a `---` line.

**The installer warns about a conflict.** Another skill with the same name already exists in `~/.claude/skills`. Either rename your skill, or move the other one out of the way and rerun `./install.sh <name>`.

**Validation says a name is duplicated.** Skill and agent names must be unique across domains. Rename one of them.

**A skill shows up twice.** A skill of the same name also comes from somewhere else, such as a plugin (`/dotskills:<name>` or another plugin's namespace) or a synced skill. Don't install this repo both ways on one machine.
