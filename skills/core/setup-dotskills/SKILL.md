---
name: setup-dotskills
description: Installs the dotskills statusline, sets the default model to sonnet, and optionally installs the OpenSpec CLI and rtk, for plugin installs that cannot do it themselves. Use when the user runs /setup-dotskills or asks to finish setting up dotskills.
targets: [claude]
disable-model-invocation: true
allowed-tools: Bash(bash *setup.sh*), Bash(*/setup.sh*), Bash(command -v *)
---

# Set up dotskills

The user invoked this skill, which is their consent for the statusline and model steps. The two installs below need a yes per tool.

1. **Check what is missing.** Run `command -v openspec rtk`; whatever it doesn't print is missing. Skip the question for a tool that is already there.
2. **Ask, one question per missing tool**, and say what it does:
   - **OpenSpec** (`grill-spec` and `ralph-apply` use it): `npm install -g @fission-ai/openspec@latest`. Needs Node.js 20.19 or newer.
   - **rtk** (cuts tokens on Bash output): downloads and runs rtk's official install script from GitHub. Its hook is added afterwards by `rtk init -g`, which the user runs.
3. **Run** `bash "${CLAUDE_SKILL_DIR}/scripts/setup.sh"`, with no `cd` first, adding `--openspec` and/or `--rtk` for each tool the user agreed to. Add `--no-model-setting` if they don't want the model default. The script:
   - copies `statusline.sh` to `~/.claude/statusline.sh`, or updates an older copy. It keeps a working symlink made by `./install.sh`, replaces a broken one, and never replaces someone else's script.
   - adds `statusLine` to `~/.claude/settings.json`, backing the file up once to `settings.json.dotskills.bak`. It never overwrites a `statusLine` that is already set, except to quote the path in one it wrote earlier.
   - sets `"model": "sonnet"` in the same file when no model is set. A model that is already set stays.
4. **Report** each line the script printed. If it printed `ERROR` or `WARN`, explain what the user can do. Don't edit `settings.json` yourself, and don't retry a failed install another way.
5. **Tell the user what's left.** If the script printed `note: ... rtk init -g`, they run `! rtk init -g` themselves (it can ask questions) and restart Claude Code. The statusline appears with the next message. After a plugin update they can run this skill again to refresh the statusline copy. To undo: delete `~/.claude/statusline.sh` and the `statusLine` key, or run `./install.sh --uninstall statusline` from a clone. The model setting stays until they change it with `/model`.
