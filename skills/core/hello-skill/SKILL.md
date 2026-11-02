---
name: hello-skill
description: Greets the user and confirms the dotskills setup is working. Use when the user says "hello skill", asks to test their dotskills install, or invokes /hello-skill.
---

# Hello skill

Confirm that this skill loaded, then greet the user.

1. Run `scripts/whereami.sh` from this skill's folder. It prints the path this skill was loaded from, its domain, and whether it came from the plugin.
2. Reply with a one-line greeting, followed by that path, domain and plugin line, so the user can see whether the skill came from the `~/.claude/skills` symlink or from the plugin cache.
