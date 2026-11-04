# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues, reached through the `github` MCP server. Tools are named by short name: `issue_write` means `mcp__github__issue_write`. Pass `owner` and `repo` from `git remote -v` on every call. The `gh` CLI is used only in the PR and Wayfinding sections.

File issues only into the user's own repo. Never file into `Kaygijzen/dotskills` (the repo these skills come from) unless the user owns it. In a fork, `origin` may point at the user's fork while the work belongs upstream, or the reverse: before the first create of a session, confirm the `owner`/`repo` with the user if it is not their repo.

## Conventions

- **Check the connection**: `list_issues` with `perPage: 1`. Read-only; run it before the first write of a session.
- **Create an issue**: `issue_write` with `method: create`, `title`, `body`, `labels`. Add `parent_issue_number` to create it as a child of that issue.
- **Read an issue**: `issue_read` with `method: get`, then `method: get_comments`.
- **List issues**: `list_issues` with `state` and `labels`. Pass `fields` without `body` when you only need numbers and titles.
- **Edit body and title**: `issue_write` with `method: update`, `issue_number`, `title`, `body`.
- **Link a child to a parent**: at creation, `parent_issue_number` (above). For an existing issue, `sub_issue_write` with `method: add`, `issue_number: <parent>`, `sub_issue_id: <child id>`; add `replace_parent: true` to move it, or use `method: remove` to unlink. `sub_issue_id` is the child's database `id` from `issue_read` `get`, not its number.
- **List a parent's children**: `issue_read` with `method: get_sub_issues` on the parent; page with `page`/`perPage`.
- **Blocking**: a `Blocked by: #<n>, #<n>` line at the top of the child body, or `Blocked by: none`. Add, remove and list blockers by reading and editing that line with **Edit body and title**. A ticket is unblocked when every listed issue is closed. Native issue dependencies are not used.
- **Ensure a label exists**: `get_label` with `name`. If it is not found, `label_write` with `method: create`, `name`, `color` (six hex digits, no `#`; required).
- **Comment on an issue**: `add_issue_comment` with `issue_number`, `body`.
- **Apply / remove labels**: `issue_write` with `method: update` and `labels`. The list replaces the issue's labels, so start from `issue_read` `method: get_labels`.
- **Close with a comment**: `add_issue_comment`, then `issue_write` with `method: update`, `state: closed`, `state_reason: completed` (or `not_planned`).

## Pull requests as a triage surface

This section uses the `gh` CLI, not the MCP server.

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; a `triage` skill, if installed, reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number>`, then `gh pr view <number> --comments` (off a TTY, `--comments` prints only the comments, not the body), and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above.

## Wayfinding operations

Used by `/wayfinder`. This section uses the `gh` CLI, not the MCP server. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue: `gh issue create --parent <map> ...`, or `gh issue edit <map> --add-sub-issue <child>` afterwards (`gh` 2.94+). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: see **Blocking** under Conventions.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open issue in its `Blocked by` line or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
