---
name: ralph-tickets
description: Implement the tickets that to-tracker pushed, one at a time, with a Ralph loop - a bash loop that runs a fresh headless Claude session per ticket, always taking the next unblocked ready-for-agent ticket. Checks the feature is ready, sets the allowed tools, and hands over the command to run. Use when the user invokes /ralph-tickets or asks to implement the tickets of a spec with a Ralph loop.
argument-hint: "<feature-slug> [max-iterations]"
disable-model-invocation: true
targets: [claude]
---

# Ralph tickets

Implement the tickets of a spec one at a time, each in a fresh context. This is `ralph-apply` for the spec-plus-tickets flow: the work list is the tracker's tickets instead of `tasks.md`.

```
scripts/ralph-tickets.sh  ──loop──>  claude -p (prompt.md)  ──>  next frontier ticket
        ^                                                        │ build, verify, comment, close, commit
        └──── stops when: frontier empty · .ralph-stop written · no progress · max iterations
```

The **frontier** is the open, unblocked tickets labelled `ready-for-agent` that are listed in `.tracker.json`. A ticket is unblocked when every ticket in its `Blocked by:` line is closed. Each iteration works out the frontier itself, because only the agent can reach the tracker's MCP server; the script only loops and watches for progress.

State lives outside the context window:
- the tracker holds each ticket and whether it is closed;
- `.scratch/<feature>/.tracker.json` lists the tickets and the parent (written by `to-tracker`);
- `.scratch/<feature>/notes.md` is the memory between iterations (gotchas, decisions);
- `.ralph-stop` at the repo root is how an iteration hands a question back to the user; `.ralph-done` is how it reports an empty frontier.

Input: $ARGUMENTS

## 1. Preflight

Report these as a short list. Stop at the first hard failure.

1. **Feature.** `.scratch/<feature-slug>/.tracker.json` exists. If no slug was given, list the `.scratch/*/.tracker.json` files and ask which one.
2. **Tracker.** `docs/agents/issue-tracker.md` names the tracker, or the feature uses the local tracker. For an external tracker, run the doc's **Check the connection** operation. If the MCP server isn't connected, stop and point to `/setup-dotskills`.
3. **Work left.** Compute the frontier as above and report how many tickets are open, how many are ready now, and how many are blocked. If none are ready, say why (all closed, all blocked, or none labelled `ready-for-agent`) and stop.
4. **Branch.** The current branch is not `main` or `master`. If it is, suggest `git switch -c feature/<feature-slug>` or a worktree, and don't continue until the user picks one.
5. **Clean tree.** `git status --porcelain` is empty, so each ticket's commit holds only its own work.
6. **Leftover stop file.** If `.ralph-stop` exists, show it. Work through the question with the user, record the answer in `notes.md`, then delete `.ralph-stop`. Delete a stale `.ralph-done` too.
7. **Review.** Ask the user to confirm they read the tickets. A Ralph loop must never run on tickets nobody reviewed.

## 2. Allowed tools

The loop runs headless, so every command an iteration needs must be pre-approved.

1. **Verification commands.** Read `AGENTS.md` / `CLAUDE.md` for lint, test and codegen commands and build `Bash(<cmd>:*)` entries, as in `ralph-apply` step 2. Check hook-rewritten forms the same way. Never add broad entries such as `Bash(*)`, `Bash(rm:*)`, `Bash(git push:*)` or `Bash(curl:*)`.
2. **Tracker tools.** An external tracker needs its MCP tools pre-approved, or the headless session can't read or close tickets. List the ones the tracker doc's **Read an issue**, **List issues**, **Edit body and title**, **Comment on an issue** and **Close with a comment** operations use, written as `mcp__<server>__<tool>` (for GitHub, `mcp__github__issue_read`, `mcp__github__list_issues`, `mcp__github__issue_write`, `mcp__github__add_issue_comment`). Take the server name from `/mcp`. The local tracker needs nothing: its files are covered by `Read,Edit,Write`.
3. A server that is only in the project's `.mcp.json` needs approval in an interactive session first; tell the user to open `/mcp` once.
4. Show the combined list to the user.

## 3. Hand over

Give the user the exact command to run in a terminal at the repo root:

```bash
RALPH_ALLOWED_TOOLS="<list from step 2>" <skill-dir>/scripts/ralph-tickets.sh <feature-slug> [max-iterations]
```

Resolve `<skill-dir>` to this skill's real folder (run `cd "$(dirname <this SKILL.md>)" && pwd`) so the path works when copied.

Then tell them:
- **Max iterations** defaults to the number of open tickets + 3.
- **Optional env vars:** `RALPH_MODEL` (default `sonnet`) and `RALPH_MAX_TURNS` (default 60).
- **One runner at a time.** Tickets are not claimed, so two loops on the same feature would pick the same ticket.
- **Logs** go to `.ralph/<feature>/iter-N.log`.
- **When it stops** on a `.ralph-stop`, the tree is clean again and any unfinished work is saved as `.ralph/<feature>/wip-<ticket>.patch` (apply it with `git apply` if you want to keep it). Run `/ralph-tickets <feature>` again to handle the question, then rerun the command.
- **When the frontier is empty,** the loop reports it. If tickets are still open they are blocked or not labelled `ready-for-agent`; look at them yourself. Otherwise do the manual checks the loop skips, run `/code-review` against the spec, and close the parent.

Don't start the loop yourself in this session unless the user explicitly asks. If they do, run it with the Bash tool in the background and report when it exits.
