# Issue tracker: GitLab

Issues and specs for this repo live as GitLab issues (work items), reached through GitLab's built-in MCP server (GitLab 19.5+). Tools are named by short name: `save_work_item` means `mcp__GitLab__save_work_item`. Pass `project_id` (the project path from `git remote -v`) on every call. The [`glab`](https://gitlab.com/gitlab-org/cli) CLI is used only for the steps marked **CLI**, and for the MR and Wayfinding sections.

## Conventions

- **Check the connection**: `list_work_items` with `types: ["ISSUE"]`, `first: 1`. Read-only; run it before the first write of a session.
- **Create an issue**: `save_work_item` without `work_item_iid`, with `type_name: Issue`, `title`, `description`, `labels`. Add `parent_id` to create it as a child.
- **Read an issue**: `get_work_item` with `work_item_iid`, then again with `include: ["notes"]` for the comments.
- **List issues**: `list_work_items` with `state` (`opened`/`closed`/`all`) and `label_name`.
- **Edit body and title**: `save_work_item` with `work_item_iid`, `title`, `description`.
- **Link a child to a parent**: `save_work_item` with `parent_id`, at creation or on update. `parent_id` is the parent's numeric `id` (or global ID) from `get_work_item`, not its iid. An Issue's child type depends on the tier's hierarchy rules; if the server rejects an Issue as a child, use `type_name: Task`.
- **List a parent's children**: `list_work_items` with `parent_iid` (GitLab 19.6+). On 19.5, use `list_work_items` with `search: <text>`, which searches titles and descriptions, with the marker text the children carry.
- **Blocking**: a `Blocked by: #<n>, #<n>` line at the top of the description, or `Blocked by: none`. Add, remove and list blockers by reading and editing that line with **Edit body and title**. A ticket is unblocked when every listed issue is closed. Native blocking links are not used, so this works on every tier.
- **Ensure a label exists**: `search_labels` with `full_path: <project path>`, `is_project: true`, `search: <name>`. MCP has no create-label tool: if it is missing, **CLI** `glab label create --name <name>`.
- **Comment on an issue**: `save_note` with `work_item_iid`, `body`. GitLab calls comments "notes". A line starting with `/` runs as a quick action, so keep the body clear of those.
- **Apply / remove labels**: `save_work_item` with `work_item_iid` and `add_labels` / `remove_labels`. `labels` works only at creation. Unknown label names are an error, not created.
- **Close with a comment**: `save_note`, then `save_work_item` with `work_item_iid`, `state: closed`.

## Merge requests as a triage surface

This section uses the `glab` CLI, not the MCP server.

**MRs as a request surface: no.** _(Set to `yes` if this repo treats external merge requests as feature requests; a `triage` skill, if installed, reads this flag.)_

When set to `yes`, MRs run through the same labels and states as issues, using the `glab mr` equivalents:

- **Read an MR**: `glab mr view <number> --comments` and `glab mr diff <number>` for the diff.
- **List external MRs for triage**: `glab mr list -O json`, then keep only MRs whose author is not a project member/owner (a contributor's MR, not a maintainer's in-flight work).
- **Comment / label / close**: `glab mr note`, `glab mr update --label`/`--unlabel`, `glab mr close`.

Unlike GitHub, GitLab numbers issues and MRs separately, so `#42` is unambiguous once you know which surface the maintainer means.

## When a skill says "publish to the issue tracker"

Create a GitLab issue.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above.

## Wayfinding operations

Used by `/wayfinder`. This section uses the `glab` CLI, not the MCP server. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `glab issue create --label wayfinder:map`. (On GitLab tiers with native epics, an epic may hold the map instead; a labelled issue works everywhere.)
- **Child ticket**: an issue carrying `Part of #<map>` at the top of its description, linked to the map (`glab issue create --linked-issues <map> --link-type relates_to`), and labels `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitLab's **native blocking link**, the canonical, UI-visible representation. Add it with the `/blocked_by #<n>` quick action, posted as a note (`glab issue note <child> --message "/blocked_by #<blocker>"`). Native blocking links are a Premium/Ultimate feature; on the free tier (or where unavailable) fall back to a `Blocked by: #<n>, #<n>` line at the top of the description. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's children with `glab api projects/:id/issues/<map>/links`, keeping open issues that carry a `wayfinder:<type>` label; drop any with an open blocker: a native `blocked_by` link to an open issue (`glab api projects/:id/issues/<child-iid>/links`), or an open issue in the `Blocked by` line, or an assignee; first in map order wins.
- **Claim**: `glab issue update <n> --assignee @me`, the session's first write.
- **Resolve**: `glab issue note <n> --message "<answer>"`, then `glab issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
