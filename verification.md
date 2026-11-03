# Verification

Everything still unverified. Static checks (`scripts/ci.sh`, `openspec validate --strict`) pass for all of it; what is left needs a live session, a tracker or a throwaway repo. The repo is public, so use a throwaway repo, never dotskills itself.

When an item is checked, tick it, note the date and the result, and fix the skill or tracker doc if it failed. Delete this file when everything is ticked.

## Needs a GitHub PAT and a live session

- [x] **`${GITHUB_PAT}` in `-H` headers** (2026-11-03). `~/.claude.json` stores the literal `Bearer ${GITHUB_PAT}` plus `X-MCP-Toolsets: issues,labels`. A fresh headless `claude -p` called `mcp__github__list_issues` on `Kaygijzen/dotskills-verify-sandbox` and got a valid empty result, so the variable is expanded at connect time (no 401). `claude mcp list` shows `Connected`. One earlier `claude mcp list` showed "tools fetch failed: authentication service temporarily unavailable"; it was transient (the same PAT worked directly against the endpoint and on the next run). The "connectors are disabled" warning (`ANTHROPIC_API_KEY` set) does not hide the user-scope `github` server in headless mode, which also answers part of the `ralph-tickets` GitHub item.

## Needs a throwaway repo and a tracker

Plan task 2. Run in the order given.

- [x] **Local tracker** (2026-11-03). Real `claude -p` with `--plugin-dir`, no setup, throwaway repo in `/tmp`. Wrote `spec.md`, three `issues/NN-*.md` (marker, `Parent:`, `Status: ready-for-agent`, `Blocked by:` correct) and `.tracker.json`. Needs `--add-dir <repo>/skills` headless, or the skill can't read its templates and the local-tracker doc (it then improvises headings). Note: `claude -p` with variadic `--allowedTools` before the prompt swallows the prompt; pipe it on stdin.
- [x] **Re-run in a fresh session** (2026-11-03, local tracker). Passed `spec.md`: one retitle (same key and file, one update), one close (`Status: closed`, comment appended, key retired in `.tracker.json`), one create (`04`, `Blocked by: 02`). Review step was skipped by instruction, so the *displayed* change set is untested.
- [ ] **GitHub.** `/setup-dotskills`, then repeat the two checks above. Check the parent and sub-issues, the `Blocked by:` lines, the label created when missing, and a closed ticket with its comment.
- [ ] **Foreign issue.** Run on a hand-written issue. Its body is unchanged, it gets exactly one comment, and a new parent exists with `Source: #<n>`.
- [ ] **Recovery.** Delete `.tracker.json` and re-run. It is rebuilt from the markers, with no duplicates.
- [ ] **GitLab (19.5+).** The first three checks if a test project exists; otherwise check the tracker doc against GitLab's docs only.
- [ ] **OpenSpec mirror.** In a repo with OpenSpec and GitHub, `/to-tracker <change>`. Tick one group's tasks and re-run: that child closes. Archive the change and re-run: the parent closes.

## Tracker as intake for OpenSpec

Added in the uncommitted `grill-spec` and `openspec-mirror.md` edits. Only the static checks are done; no run yet.

- [ ] **`/grill-spec #<n>` reads the issue.** It reads the body and all comments, seeds the design tree from them, asks only what is left open, and does not edit, label, close or comment on the issue.
- [ ] **`Source:` line.** The generated `proposal.md` starts with `Source: <reference>`, written as the user gave it.
- [ ] **Mirror with a source issue.** `/to-tracker <change>` uses that issue as the parent and creates no second one. The body, title and labels stay unchanged. Children are created and linked.
- [ ] **Comments only.** One comment on the first push; one per later run in which a child closed or the change was archived; none when nothing changed.
- [ ] **Archive.** After archiving, the source issue is commented on, not closed.
- [ ] **Unreadable reference.** The mirror stops with a message and creates nothing.
- [ ] **Recovery with a source issue.** Delete `.tracker.json` and re-run. The parent is found from the `Source:` line in `proposal.md` and the children from their markers, with no duplicates. (Rule added; untested.)
- [ ] **Split wording (decide).** `to-tracker/SKILL.md` step 6 says a foreign source gets one comment linking to the new parent. `openspec-mirror.md` now says comments only, starting with one on the first push. They don't conflict, but the rule lives in two files.

## Azure DevOps

Plan task 3. Drafted 2026-11-03 from Microsoft's published docs only; **nothing has run against a real organization**. `issue-tracker-ado.md` carries a draft banner until these pass. Then remove the banner.

Checked against the docs (static):

- Tool and action names agree between the remote-server page and the local `TOOLSET.md`: `wit_work_item` (`get`, `get_batch`, `list_comments`, `get_type`, ...), `wit_work_item_write` (`create`, `update`, `update_batch`, `add_child`), `wit_work_item_comment_write` (`add`, `update`), `wit_work_item_link_write` (`link`, `unlink`, ...), `wit_query`. The plan's worry about `wit_query_by_wiql` vs `wiql` is only half settled: the remote page lists a separate `wit_query_by_wiql` tool, while `TOOLSET.md` lists `wit_query` with `action: wiql`. The doc uses the second form.
- Remote setup command, `--client-id`, `--callback-port 3118`, the Entra app registration steps, and the Entra-backed-organization prerequisite, as written in Microsoft's Claude Code section.
- Local setup: `npx -y @azure-devops/mcp <org> --authentication azcli`, domains `core`, `work-items`.

Still to verify (needs a real project):

- [ ] **Tool list and parameters.** Run `tools/list` against the live server. Pin the parameter names (project, work item type, fields/patch shape for `create`, `update`, `add_child`, `link`, the WIQL parameter) and the `X-MCP-Toolsets: wit` header; fix `issue-tracker-ado.md`. Settle `wit_query_by_wiql` vs `wit_query` `wiql` (which one exists on the remote server).
- [ ] **Marker survival.** `<!-- to-tracker:<key> -->` survives a write and a read in `System.Description`. If not, switch the doc to the tag marker and update `to-tracker`'s dedupe step (it looks for the marker in children's bodies).
- [ ] **Soft blocking.** A `Blocked by: #<id>` line survives in the HTML description and parses back.
- [ ] **Format of the description.** Whether the server accepts Markdown (some versions have a format option) or needs HTML; adjust the "Description is HTML" section.
- [ ] **Edit with a revision.** `update` with `test /rev` refuses an edit made since the read.
- [ ] **Tags.** Setting `System.Tags` replaces the value, so `ready-for-agent` and other tags must be merged; `to-tracker:<key>` tags are created on first use.
- [ ] **Child types.** The process template allows the ticket type as a child of the spec type (Agile `User Story` under `Feature`, etc.).
- [ ] **Close.** Setting the done state works from every open state for each template; some templates need an intermediate state.
- [ ] **Remote connection.** The Entra app registration steps work, `--callback-port 3118` is enough, and `/mcp` signs in. `-H 'X-MCP-Toolsets: wit'` is accepted alongside OAuth.
- [ ] **Local fallback.** `-d core work-items` is the right domain flag; `az login` auth works headless.
- [ ] **Default connection (user decision).** Remote or local as the default, decided after the tests. The doc currently recommends remote when the user can register an app.
- [ ] **setup-dotskills flow.** The Azure DevOps branch (remote detection, the process-template question, Scope block filled in, Done step) run in a session.
- [ ] **`ralph-tickets`, `wayfinder`, `code-review`** against Azure DevOps. Dispatcher tools are allowed whole (`mcp__ado__wit_work_item_write`); check that the headless session accepts that.
- [ ] **Other agents.** Microsoft says Codex and Claude Desktop can't use the remote server (no dynamic client registration); belongs to the "Other agents" backlog item.

## Against the vendors' docs

- [ ] **MCP tool names.** Re-check every tool name in the GitHub and GitLab tracker docs against the vendor's tools reference before changing any of them. GitHub half checked 2026-11-03 against the tool schemas the live `github` MCP server exposes: every tool name and parameter in `issue-tracker-github.md` exists (`issue_read` methods `get`/`get_comments`/`get_sub_issues`/`get_labels`, `issue_write` with `parent_issue_number`/`state_reason`, `sub_issue_write` with `replace_parent`, `get_label`, `label_write` with required `color`, `add_issue_comment`, `list_issues` with `fields`). Quirk to document: `list_issues` `state` is uppercase (`OPEN`/`CLOSED`), `issue_write` `state` is lowercase. GitLab half still open.
- [ ] **Wayfinding blocking.** The `wayfinder` blocking paragraph and the GitLab Wayfinding section now use the `Blocked by:` line (static check only). Run `/wayfinder` once on a throwaway repo: chart a map, check the second pass writes the lines, and that the frontier query skips a blocked ticket.

## `ralph-tickets`

**Verified 2026-11-03** with the real `claude -p` (2.1.317) on the local tracker, in a throwaway repo with three tickets (`03` blocked by `01` and `02`), `AGENTS.md` naming `bash test.sh`, and `RALPH_ALLOWED_TOOLS="Bash(bash:*)"`:

- Three iterations, one ticket each, then a fourth that found the frontier empty, wrote `.ralph-done` and exited 0.
- Each commit held exactly its own ticket: the script, the ticket file (`Status: closed`, criteria ticked, a comment), `.tracker.json` and `notes.md`. The spec was untouched and the tree was clean.
- Blocking works. With `.tracker.json` listing `both` first, it was still done last.
- Without the verify command allowed, the iteration wrote `.ralph-stop` with a clear reason instead of guessing, and left the ticket open (and, after the revert fix, a clean tree).
- The script alone, against a fake `claude`: stalled run, stop file, refusal on `main`, bad slug, missing state.

Still to verify:

- [x] **Half-done work on a stop** (2026-11-03). The prompt now saves uncommitted work to `.ralph/<feature>/wip-<ticket>.patch`, restores a clean tree, then writes `.ralph-stop`. Rerun of the permission-denied case: clean tree, ticket still open, nothing committed, patch applies and passes `test.sh`.
- [x] **All tickets blocked, none ready** (2026-11-03). A circular `Blocked by:` pair: `.ralph-done` with the reason, exit 0, tree clean, no commits.
- [x] **Missing `ready-for-agent` label** (2026-11-03). A `needs-triage` ticket is skipped; `.ralph-done` says why.
- [x] **Stale `.tracker.json`** (2026-11-03), local tracker only. The file said open, the ticket file said closed: the iteration trusted the ticket and wrote `.ralph-done`. Still to check on GitHub, where the tracker is a remote service.
- [ ] **GitHub.** Needs a throwaway repo and the connected MCP server. Check that the `mcp__github__<tool>` names in `SKILL.md` step 2 are right, that the headless `claude -p` sees a user-scope MCP server (here `claude mcp list` warns that connectors are off because `ANTHROPIC_API_KEY` is set; check that this doesn't hide servers), and that reading, commenting on and closing an issue and reading its sub-issues all work headless.
- [ ] **GitLab.** The same, with `mcp__GitLab__*` names, if a 19.5+ project exists.
- [ ] **Preflight in a session.** `/ralph-tickets` itself (the model-driven part: ticket counts, the frontier report, the allowed-tools list, the hand-over command) has not been run. It stops cleanly on `main`, a dirty tree, a missing connection and no ready tickets.
- [ ] **`Blocked by:` after a `to-tracker` re-run.** Blocking edges are read correctly after a re-run rewrote them.
- [ ] **Two loops at once.** Not guarded, since tickets aren't claimed; the docs say to run one. Decide whether a lock file is worth it.
- [ ] **Hook-rewritten commands** (`rtk`). Not installed here, so the `rtk git ...` allow-list entries are untested.
- [x] **Revert in other stop cases** (2026-11-03). A product-decision stop and an unfixable-test stop both left a clean tree, an open ticket and no commit. With nothing written there is no patch (no empty file); with work written (`hello.sh`) the patch holds only that file. Caveat: whether the model writes code before stopping varies, so this is a few runs, not a guarantee.
