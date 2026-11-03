# Follow-ups: out of scope for `to-tracker`

Work deliberately left out of [plan.md](plan.md). Each item stands on its own and can be picked up after `to-tracker` lands.

## 3. Standardize all tracker docs

**Problem.** `to-tracker` adds only the operations it needs. The three tracker docs in `setup-dotskills/` still differ:

- Local has very few Conventions.
- GitLab keeps parent links and blocking only in its Wayfinding section.
- Each doc's "Wayfinding operations" section repeats commands instead of pointing to Conventions.

**Fix.** Give every doc the same ordered operation list:

- create, read, edit body/title, list
- link to parent, list children
- add/remove blocker, list blockers, count open blockers
- labels, comment, close

Then make the Wayfinding sections refer to those entries. Weigh this against drift from upstream mattpocock/skills: every rewritten section makes `upstream-status.sh` report bigger local changes.

## 4. Two-way sync

**Problem.** `to-tracker` pushes one way. Edits made by hand in the tracker (issue bodies, new tickets created there) are overwritten on the next push or ignored. The review step only warns about this.

**Option.** A pull step that compares tracker bodies against the last pushed version (hash in `.tracker.json`) and asks before overwriting. Only worth building if people really do edit tickets in the tracker.

## 5. Implementing tickets

**Problem.** The issue-tracker flow ends at the tickets (`docs/best-practices.md`: "skills for implementing them are still in progress"). The OpenSpec flow has `ralph-apply`; the tracker flow has nothing.

**Option.** A skill that works the frontier: claim an unblocked `ready-for-agent` ticket, implement it in a fresh session, and close it. Use the operations from item 3 and the `.tracker.json` written by `to-tracker`. `wayfinder` already defines claim/resolve/frontier, so reuse its terms.

## 6. MCP setup for agents other than Claude Code

**Problem.** The rewritten `setup-dotskills` uses `claude mcp add`, `claude mcp login` and `/mcp`, which exist only in Claude Code. `install.sh --target codex` isn't implemented yet. Microsoft also says Codex and Claude Desktop can't use the remote Azure DevOps server.

**Option.** When another target lands in `install.sh`, add that agent's MCP config format to `setup-dotskills`, or document a CLI-only mode for it.

## 7. Tracker as intake for OpenSpec

> The OpenSpec mirror itself is built (`to-tracker/openspec-mirror.md`, branch `openspec-mirror`). Checked 2026-11-03 with OpenSpec 1.8.0: `openspec validate --strict` accepts `.tracker.json` in a change folder and `openspec archive` moves it along; `tasks.md` groups are numbered `##` headings by OpenSpec's own instructions. Per-group progress shows as the copied checkboxes in each child body.

**Related option: tracker as intake.** Work often starts as a backlog issue (especially in ADO). `/grill-spec <issue>` would read the issue as input and put a link to it in `proposal.md`, and the mirror then uses that issue as the parent instead of creating one. That's a small change to `grill-spec`, and it uses plan.md's "foreign issue" rule: the skill never rewrites the issue's body, so the mirror adds its status as comments or child issues only.

**When.** After PR 1, once `to-tracker`'s own flow is solid. It can be done in parallel with PR 2 or PR 3.
