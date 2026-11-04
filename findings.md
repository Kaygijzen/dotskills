# Findings: ralph-tickets, wayfinder and code-review on Azure DevOps

Run 2026-11-03 against the local server (`@azure-devops/mcp` 2.11.0, `--authentication azcli`), organization `<org>`, project `<project>` (Agentic SDLC process). All sessions were headless `claude -p` 2.1.317 with the dotskills plugin, in throwaway repos under `/tmp`. Answers that a human would give were scripted, so the interactive parts are untested.

## Summary

| Skill | Result | Needs a doc or skill change |
|---|---|---|
| `ralph-tickets` | Works | No |
| `wayfinder` | Works | Two small doc notes (applied) |
| `code-review` | Works | No |

Dispatcher tools allowed whole (`mcp__ado__wit_work_item`, `mcp__ado__wit_work_item_write`, `mcp__ado__wit_work_item_comment_write`, `mcp__ado__wit_query`) were accepted by every headless session. The `RALPH_ALLOWED_TOOLS` list that worked was `Bash(bash:*),Bash(chmod:*),mcp__ado__wit_work_item,mcp__ado__wit_work_item_write,mcp__ado__wit_work_item_comment_write,mcp__ado__wit_query`.

## ralph-tickets

Setup: feature `greeter` with work items #297, #298 (already closed by the earlier `to-tracker` re-run) and #299, a branch `feature/greeter`, `AGENTS.md` naming `bash test.sh`, and `ralph-tickets.sh greeter 4`.

- Iteration 1 did #297: `greet.sh` and `test.sh`, one commit with the message `greeter: <title> (297)`, three criteria ticked, one comment, state `Closed`.
- Iteration 2 did #299 (blocked by #297, so it came second): one commit, four criteria ticked, comment, `Closed`.
- Iteration 3 found the frontier empty, wrote `.ralph-done`, and the script printed "Frontier empty after 2 ticket(s)".
- Each commit held exactly its own files plus `.tracker.json` and `notes.md`. The tree was clean at the end. The parent #296 stayed `New`.
- The tracker and `.tracker.json` agreed at the end.
- The `Blocked by:` lines were not edited.

Notes:

- **Server discovery.** The loop starts its own `claude -p` with no `--mcp-config`. It found the server only because the throwaway repo had a project `.mcp.json` plus `{"enableAllProjectMcpServers": true}` in `.claude/settings.local.json`. No `ado` server was registered at user scope on this machine. With the server registered through `claude mcp add -s user`, as `setup-dotskills` prints, it should be found the same way; not tested.
- **Closed ticket with unticked criteria.** #298 was closed by `to-tracker` ("removed from the spec"), so its five criteria stay unticked. Iteration 3 noticed this and said so in its final message. It did not reopen or touch the ticket. That is the intended behavior.
- **Close reason.** Closing sets the reason to "Acceptance tests pass" on Agentic SDLC, whatever the comment says.
- **Exit code.** My `PIPESTATUS` capture came back empty, so the exit code of the script was not read. The output shows the "done" branch, which exits 0.
- **Stdin warning.** Each iteration prints "no stdin data received in 3s, proceeding without it". It is harmless. Adding `< /dev/null` to the `claude` call in `ralph-tickets.sh` would silence it; not changed.

Not tested here: the stop and revert cases, a stale `.tracker.json`, and the `/ralph-tickets` preflight. These were verified on the local and GitHub trackers and do not depend on the tracker.

## wayfinder

Setup: throwaway repo with the ADO tracker doc, `AGENTS.md`, project `.mcp.json`. Two runs.

**Charting (map #300).** One map (Feature) and three tickets (User Story, children of #300), each tagged `wayfinder:<type>` plus the test tag. `Blocked by:` lines were written by the second pass: #301 none, #302 `#301`, #303 none. The frontier was #301 and #303, with #302 waiting.

**Working through.** The run reported the frontier first. It claimed the AFK research ticket #301 (assignee set, with a `/rev` test), left the task ticket #303 alone because a human has to choose, and did not answer the HITL grilling ticket #302. It posted the answer as a comment, set `Closed`, and added a Decisions-so-far line with the ticket name and a one-line gist to the map. The frontier afterwards listed #302 as unblocked and #303, with no AFK ticket left. I checked this against the tracker: #301 `Closed` with an assignee and a comment, #302 and #303 `New` and unassigned, and the map's Decisions section holds the line.

Notes:

- **`add_child` cannot set tags.** The map's tickets were created without their `wayfinder:` tags, and the skill added them in a follow-up `update` on each. This already sits in `issue-tracker-ado.md` under the marker section, but the "Wayfinding operations" section still reads as if `add_child` tags the ticket. Applied: the **Child ticket** bullet now says to apply the tag in a follow-up `update`.
- **`get_batch` needs `project`.** Without it the call returns "Project selection cancelled" and no data. The doc's **List issues** bullet says `get_batch` fetches the bodies, but not that `project` is required. Applied: the **List issues** bullet now says so.
- The research subagent was skipped on purpose, because I told the session not to run subagents. That path (the `research` skill) is untested on ADO.
- A `HITL` ticket (grilling, prototype) was deliberately not exercised.

## code-review

Setup: the `feature/greeter` branch from the ralph run, baseline commit `4c47a24`, spec = parent #296 plus children #297 to #299 read through the tracker. The session was allowed only `wit_work_item`, `wit_query`, `git` and `Agent`.

- It read the spec from the tracker and reported on both axes.
- **Standards:** no hard violations of `AGENTS.md`, three smells in `test.sh`, all minor.
- **Spec:** it found a real gap: `greet.sh NAME` is not built, so `greet.sh Bob` prints "Hello, world". User story 2 of #296 requires it. The cause is the earlier `to-tracker` re-run that closed #298 (which covered both the name greeting and `--shout`) when only `--shout` left the spec. The review also noted that no open ticket covers the gap, that the trailing-newline requirement is not really tested, and that `greet.sh --version extra` falls through to the default greeting.
- It could not run `bash test.sh` (only `git` was allowed), and said so instead of claiming a pass.

The gap is the same one `to-tracker` reported at the end of its recovery run, so two independent skills agree on it. It follows from the instruction I gave (close `greet-name-shout`), not from a skill bug.

Not tested: how the review picks the fixed point when none is given, and the Spec axis against a source that is a pull request.

## Test items still in `<project>`

#296 to #299 (the `to-tracker` and `ralph-tickets` feature) and #300 to #303 (the wayfinder map). All carry the tag `dotskills-verify`. Nothing was deleted.
