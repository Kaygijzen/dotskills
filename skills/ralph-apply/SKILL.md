---
name: ralph-apply
description: Apply an approved OpenSpec change with a Ralph loop - a bash loop that runs a fresh headless Claude session per task, so context never piles up. Checks the change is ready, sets the allowed tools from the project's verification commands, and hands over the command to run. Use when the user invokes /ralph-apply or asks to apply an OpenSpec change with a Ralph loop.
argument-hint: "<change-name> [max-iterations]"
disable-model-invocation: true
---

# Ralph apply

Implement an approved OpenSpec change one task at a time, each in a fresh context.

```
scripts/ralph.sh  ──loop──>  claude -p (prompt.md)  ──>  first unchecked task in tasks.md
      ^                                                    │ build, verify, tick, notes.md, commit
      └──── stops when: all tasks ticked · .ralph-stop written · no progress · max iterations
```

State lives on disk, not in a context window:
- `openspec/changes/<change>/tasks.md` is the checklist.
- `openspec/changes/<change>/notes.md` is the memory between iterations (gotchas, decisions).
- `.ralph-stop` at the repo root is how an iteration hands a question back to the user.

Input: $ARGUMENTS

## 1. Preflight

Run these checks and report them as a short list. Stop at the first hard failure.

1. **OpenSpec root.** `openspec/changes/<change>/` exists. If no change name was given, run `openspec list` and ask which one.
2. **Approved and valid.** `openspec validate <change>` passes, and the change has `proposal.md`, `tasks.md` and specs. Ask the user to confirm they reviewed and approved the proposal; a Ralph loop must never run on an unreviewed change.
3. **Work left.** `tasks.md` has at least one unchecked `- [ ]` task. Report how many are open.
4. **Branch.** The current branch is not `main` or `master`. If it is, suggest `git switch -c change/<change>` or a worktree (`git worktree add ../<repo>-<change> -b change/<change>`), and don't continue until the user picks one.
5. **Clean tree.** `git status --porcelain` is empty, so each iteration's commit holds only its own task. Otherwise, ask the user to commit or stash first.
6. **Leftover stop file.** If `.ralph-stop` exists, show its contents. Work through that question with the user (it is usually a decision they owe), record the answer in `notes.md`, then delete `.ralph-stop`.
7. **Ignore files.** Nothing to do. The script adds `.ralph/` and `.ralph-stop` to the repo's local `.git/info/exclude`, so they never end up in commits.

## 2. Allowed tools

The loop runs headless, so every command an iteration needs must be pre-approved.

1. Read `AGENTS.md` / `CLAUDE.md` (and `openspec/config.yaml`) for the project's verification commands: lint, analyze, unit tests, database tests, codegen.
2. Build the list as `Bash(<cmd>:*)` entries, for example `Bash(flutter:*),Bash(dart:*),Bash(supabase:*)` or `Bash(npm run:*),Bash(npx tsc:*)`. The script always adds `git add`, `git commit`, `git status`, `git diff` and `openspec`.
3. Show the list to the user. Never add broad entries such as `Bash(*)`, `Bash(rm:*)`, `Bash(git push:*)` or `Bash(curl:*)`.

## 3. Hand over

Give the user the exact command to run in a terminal at the repo root:

```bash
RALPH_ALLOWED_TOOLS="<list from step 2>" <skill-dir>/scripts/ralph.sh <change> [max-iterations]
```

Resolve `<skill-dir>` to this skill's real folder (run `cd "$(dirname <this SKILL.md>)" && pwd`) so the path works when copied.

Then tell them:
- **Max iterations** defaults to the number of open tasks + 5.
- **Optional env vars:** `RALPH_MODEL` picks a model for the iterations, and `RALPH_MAX_TURNS` caps the turns per iteration (default 60).
- **Logs** for each iteration go to `.ralph/<change>/iter-N.log`.
- **When it stops** on a `.ralph-stop`, run `/ralph-apply <change>` again: preflight step 6 handles the question, then the loop resumes where it left off.
- **When all tasks are ticked,** do the manual checks the loop skips (for example a simulator or browser walkthrough), then run `/opsx:archive <change>`.

Don't start the loop yourself in this session unless the user explicitly asks. If they do, run it with the Bash tool in the background and report when it exits.
