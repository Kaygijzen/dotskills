# Plan: what is left of the tracker work

A handoff for a fresh session. It replaces `setup-plan.md` and `follow-ups.md`; everything still open from those files is here. Read `AGENTS.md` first: `scripts/ci.sh` must pass before each commit, and after adding, removing or moving anything, run `scripts/update-readme.sh` then `scripts/sync-plugin.sh`. The repo is public: no personal, client or secret data.

## Where things stand (2026-11-03)

- **Merged to `main`** (PR #18): MCP tool maps in the tracker docs, and the `to-tracker` skill, which replaces `to-spec` and `to-tickets`.
- **Pushed, no PR yet**: branch `tracker-mcp`, four commits on top of `main`. CI passes. Open the PR at <https://github.com/Kaygijzen/dotskills/pull/new/tracker-mcp> (`gh` was not installed in the last session). The commits:
  1. soft blocking on every tracker, and `to-tracker` falls back to local files;
  2. `setup-dotskills` rewrite: connects the tracker's MCP server, always writes the `ready-for-agent` label, copies `to-tracker`'s templates to `docs/agents/templates/`. It is now our own skill: its `upstream.json` entry became a provenance line;
  3. OpenSpec mirror: `/to-tracker <change>`, rules in `skills/engineering/to-tracker/openspec-mirror.md`;
  4. `to-tracker`, `wayfinder` and `code-review` use the local tracker when none is configured.

Build new work on `tracker-mcp`, or on `main` once it is merged.

## Decisions already made

Don't reopen these without asking the user.

- **One-way push.** Tracker content never flows back into the spec. Tracker state (ids, children, open/closed, assignee) is read only to update safely.
- **Soft blocking only.** On every tracker, blocking is a `Blocked by: #3, #5` line in the ticket body (`Blocked by: 01, 02` locally), never a native link. There is no tier check, no feature header and no blocker CLI fallback.
- **An external tracker is optional.** Without `docs/agents/issue-tracker.md`, skills use local markdown in `.scratch/` and say so once.
- **MCP first.** GitHub and GitLab are reached through MCP servers. The CLI is used only where MCP has a gap; the PR/MR and Wayfinding sections of the tracker docs stay CLI-only.
- **Setup never handles a token.** It prints commands for the user to run with `! <command>`. User scope is recommended; project scope gets a `.mcp.json` snippet with `${VAR}` only. The repo's `mcp/` folder stays empty.
- **Claude Code only** for now: `setup-dotskills` and `to-tracker` have `targets: [claude]`.

## Tasks

In order. Each one stands on its own.

### 1. Verify the GitHub credential route

**Needs:** the user, a GitHub PAT and a live session. This can't be done alone.

The setup step prints:

```
claude mcp add -s user --transport http github https://api.githubcopilot.com/mcp/ \
  -H 'Authorization: Bearer ${GITHUB_PAT}' -H 'X-MCP-Toolsets: issues,labels'
```

The Claude Code docs say `${VAR}` expands in user-scope entries in `~/.claude.json`, but don't say so explicitly for headers added with `-H`. Have the user export `GITHUB_PAT`, run the command, start a new session and check `/mcp`.

- **Connected:** done.
- **Literal `${GITHUB_PAT}` sent (401):** switch the GitHub route in `skills/engineering/setup-dotskills/SKILL.md` Section A2 to project scope with a `.mcp.json` snippet, or to `headersHelper`.

GitHub OAuth is out of scope: it needs a pre-registered OAuth app (GitHub has no dynamic client registration), which is too much setup. GitHub uses the PAT route only.

### 2. Manual test matrix

**Needs:** the user, and a throwaway repo, not dotskills: the GitHub tracker doc forbids filing into dotskills.

1. **Local tracker.** Run `/to-tracker` on a short conversation without running setup. Check `spec.md`, the `issues/NN-*.md` files with their `Parent:`/`Status:`/`Blocked by:` lines, and `.tracker.json`.
2. **Re-run in a fresh session.** Pass `spec.md`, retitle one ticket, drop one and add one. The review should show one update (same key), one close and one create.
3. **GitHub.** Run `/setup-dotskills`, then repeat steps 1–2. Check the parent and sub-issues, the `Blocked by:` lines, the label created if it was missing, and a closed ticket with its comment.
4. **Foreign issue.** Run on an existing hand-written issue. Its body stays unchanged, it gets one comment, and a new parent exists with `Source: #<n>`.
5. **Recovery.** Delete `.tracker.json` and re-run. It is rebuilt from the markers, with no duplicates.
6. **GitLab** (19.5+): steps 1–3 if a test project exists. Otherwise check against the docs only.
7. **OpenSpec mirror.** In a repo with OpenSpec and GitHub, run `/to-tracker <change>`. Tick one group's tasks and re-run: that child closes. Archive the change and re-run: the parent closes.

Fix what fails in the skill or tracker doc. Re-check any MCP tool name against the vendor's tools reference before changing it.

### 3. Azure DevOps (DRAFTED, uncommitted, untested; the live tests are in `verification.md`)

Separate PR. **Needs:** a real ADO project. Test three things first; each one changes the design:

1. **Tool names.** The tools were recently merged into action dispatchers, and the remote docs and `TOOLSET.md` disagree (`wit_query_by_wiql` vs `wiql`). Pin the names from a live `tools/list`.
2. **Marker survival.** `System.Description` is HTML. Check that `<!-- to-tracker:<key> -->` survives a write and a read. If it doesn't, use the tag `to-tracker:<key>` as the marker.
3. **Soft blocking.** Check that a `Blocked by: #<id>` line survives in the HTML description and stays readable on a re-read. Native Predecessor/Successor links are out (soft-only decision).

Then:

- **Connect.**
  - Remote: `claude mcp add --transport http ado https://mcp.dev.azure.com/<org> --client-id <id> --callback-port 3118`. It needs an Entra-backed org and a custom Entra app registration with admin consent; the `wizard` skill can walk the user through it.
  - Local fallback: `npx -y @azure-devops/mcp <org> --authentication azcli`, which needs Node 20+ and `az login`.
  - Toolset header `X-MCP-Toolsets: wit`.
  - **Open decision for the user:** which of the two is the default. Decide after the tests.
- **Seed `skills/engineering/setup-dotskills/issue-tracker-ado.md`**, with the same operations as the GitHub doc: create, read, list, edit body and title, link a child to a parent, list a parent's children, ensure a label exists, comment, apply labels, close with a comment. Mapping:

  | Concept | ADO |
  | --- | --- |
  | Issue | Work item; its type depends on the process template |
  | Spec / ticket types | Asked once in setup. Defaults: Agile Feature / User Story, Scrum Feature / Product Backlog Item, Basic Epic / Issue. This is the one question setup must ask |
  | Parent | `wit_work_item_write` `add_child` (pin the name in test 1) |
  | Edit | `wit_work_item_write` `update` |
  | Labels | Tags (`System.Tags`); nothing to create |
  | Close | The process template's done state |
  | Scope | Organization + project; optional area path and iteration, written to the doc |

- **`setup-dotskills`:** add the ADO option to Section A, detect `dev.azure.com` and `*.visualstudio.com` remotes in Explore, and add the ADO branch to Section A2 and to the Done step.
- **`docs/setup.md`:** prerequisites (an Entra app registration, or Node 20+ and `az`).
- Microsoft says Codex and Claude Desktop can't use the remote ADO server; that belongs to backlog item "Other agents" below.

### 4. Tracker as intake for OpenSpec (DONE, uncommitted on `tracker-mcp`)

Small. Work often starts as a backlog issue. Teach `skills/engineering/grill-spec/SKILL.md` to take an issue as input:

- read its body and comments, and put a link to it in `proposal.md`;
- never edit or close it (the "foreign issue" rule in `to-tracker`).

Then make `to-tracker/openspec-mirror.md` use that linked issue as the parent instead of creating one. Status goes onto it as comments and child issues only, never as body edits.

`grill-spec` is our own skill (it has no `upstream.json` entry).

### 5. Implementing tickets (DONE, uncommitted: `ralph-tickets`; see `verification.md`)

A new skill, so ask the user before building it. The spec-plus-tickets flow ends at the tickets (`docs/best-practices.md` says so); the OpenSpec flow has `ralph-apply`.

- **Shape:** work the **frontier**: claim an unblocked `ready-for-agent` ticket, implement it in a fresh session, close it, repeat.
- **Reuse:** `.tracker.json` from `to-tracker`, the `Blocked by:` lines, and `wayfinder`'s claim/resolve/frontier terms. Consider reusing `ralph-apply`'s loop script (`skills/engineering/ralph-apply/scripts/ralph.sh`).
- **Then:** remove "still in progress" from `docs/best-practices.md`.

## Backlog

Not scheduled. Pick up only when the trigger happens.

- **Other agents.** `setup-dotskills` uses `claude mcp add`, `claude mcp login` and `/mcp`, which exist only in Claude Code. Trigger: another target lands in `install.sh` (`--target codex` isn't implemented). Then add that agent's MCP config format, or a CLI-only mode.
- **Two-way sync.** Hand edits in the tracker are overwritten on the next push; the review step only warns. A pull step could compare each body against a hash of the last pushed version (in `.tracker.json`) and ask before overwriting. Trigger: people really do edit tickets in the tracker.
- **Standardize the Wayfinding sections.** Blocking is now consistent (soft, via Conventions). The sections still repeat some commands; leave that unless someone edits them.

## Housekeeping

- After the `tracker-mcp` PR merges, delete `setup-plan.md` and `follow-ups.md`; this file supersedes them. Delete this file when the tasks are done. None of the three is committed.
