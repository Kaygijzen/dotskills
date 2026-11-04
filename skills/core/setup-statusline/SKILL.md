---
name: setup-statusline
description: Installs the dotskills statusline (model, context bar, cost, time, git branch, rate limits) into ~/.claude and turns it on in settings.json. For plugin installs, which cannot set a statusline themselves.
targets: [claude]
disable-model-invocation: true
allowed-tools: Bash(bash *install-statusline.sh), Bash(*/install-statusline.sh)
---

# Set up the statusline

The user invoked this skill, which is their consent to the changes below.

1. Run exactly `bash ${CLAUDE_SKILL_DIR}/scripts/install-statusline.sh`, with no `cd` first. It:
   - copies `statusline.sh` to `~/.claude/statusline.sh`, or updates an older copy. It keeps a working symlink made by `./install.sh`, replaces a broken one, and never replaces someone else's script.
   - adds `statusLine` to `~/.claude/settings.json`, backing the file up once to `settings.json.dotskills.bak`. It never overwrites a `statusLine` that is already set.
2. Report each line the script printed. If it printed `ERROR` or `WARN`, explain what the user can do and stop. Don't edit `settings.json` yourself.
3. On success, tell the user the statusline appears with the next message, and that they can run this skill again after a plugin update to refresh the copy. To remove it, they delete `~/.claude/statusline.sh` and the `statusLine` key, or run `./install.sh --uninstall statusline` from a clone.
