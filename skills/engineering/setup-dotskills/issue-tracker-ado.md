# Issue tracker: Azure DevOps

> **Draft, not yet tested against a live organization.** The tool and action names below come from Microsoft's published tool lists. Parameter names are not pinned: read them from the server's `tools/list` before the first write and correct this file. See `verification.md` in the dotskills repo for what is still open.

Issues and specs for this repo live as Azure DevOps **work items**, reached through the Azure DevOps MCP server. Tools are named by short name: `wit_work_item_write` means `mcp__ado__wit_work_item_write`. Most tools are dispatchers: one tool plus an `action` parameter. Pass the organization's **project** on every call that takes one.

## Scope

Written by `/setup-dotskills`; edit freely.

- **Organization / project**: `<organization>` / `<project>`
- **Spec type** (the parent): `<e.g. Feature>`
- **Ticket type** (the children): `<e.g. User Story>`
- **Done state** (what "closed" means for the ticket type): `<e.g. Closed>`
- **Area path / iteration** (optional): `<leave empty for the project default>`

Defaults by process template: Agile `Feature` / `User Story` / `Closed`; Scrum `Feature` / `Product Backlog Item` / `Done`; Basic `Epic` / `Issue` / `Done`; CMMI `Feature` / `Requirement` / `Closed`. Check with `wit_work_item` `get_type` if the project uses a custom process.

## Conventions

Ids are the work item's numeric id, written `#<id>` in text.

- **Check the connection**: `wit_query` with `action: wiql` for `SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project`, one result. Read-only; run it before the first write of a session.
- **Create an issue**: `wit_work_item_write` with `action: create`, the work item type, title, description and tags.
- **Read an issue**: `wit_work_item` with `action: get`, then `action: list_comments` for the comments.
- **List issues**: `wit_query` with `action: wiql` and a `WHERE` on type, state and tags. `wit_work_item` `get_batch` fetches the bodies of the ids it returns.
- **Edit body and title**: `wit_work_item_write` with `action: update`, patching `System.Title` and `System.Description`. Pass the revision (`test /rev`) so an edit made since you read it is refused, not overwritten.
- **Link a child to a parent**: at creation, `wit_work_item_write` with `action: add_child` on the parent. For an existing item, `wit_work_item_link_write` with `action: link` and the parent/child link type.
- **List a parent's children**: `wit_query` with `action: wiql` on `WorkItemLinks` (`[System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward'` from the parent), or `wit_work_item` `get` with relations and read the child links.
- **Blocking**: a `Blocked by: #<id>, #<id>` line at the top of the description, or `Blocked by: none`. Add, remove and list blockers by reading and editing that line with **Edit body and title**. A ticket is unblocked when every listed item is in its done state. Predecessor/successor links are not used.
- **Ensure a label exists**: nothing to do. Labels are **tags** (`System.Tags`, semicolon-separated), created the first time they are used.
- **Comment on an issue**: `wit_work_item_comment_write` with `action: add`.
- **Apply / remove labels**: `wit_work_item_write` with `action: update` on `System.Tags`. The field replaces the whole value, so start from the item's current tags.
- **Close with a comment**: `wit_work_item_comment_write` `add`, then `wit_work_item_write` `update` setting `System.State` to the done state from Scope.

### Description is HTML

`System.Description` is HTML, not Markdown. Write bodies as simple HTML (`<p>`, `<ul>`, `<h2>`, `<code>`), and keep the first lines plain so they stay readable on a re-read:

```
<p>Blocked by: #12, #14</p>
<!-- to-tracker:add-login-form -->
```

If the server strips the HTML comment marker (see `verification.md`), use the tag `to-tracker:<key>` as the marker instead, and look it up with a `WHERE [System.Tags] CONTAINS 'to-tracker:<key>'` query. Record which one applies here once tested.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external pull requests as feature requests; a `triage` skill, if installed, reads this flag.)_ Pull requests are reached through the Azure DevOps `repositories` toolset, which is not enabled by default; add it to the server's toolsets if you need it.

## When a skill says "publish to the issue tracker"

Create a work item of the spec type from Scope.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above. The user will normally pass the id or the work item URL.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single work item with **child** work items as tickets.

- **Map**: a work item of the spec type, tagged `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: a work item of the ticket type, a child of the map (see **Link a child to a parent**), tagged `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: see **Blocking** under Conventions.
- **Frontier query**: list the map's open children, drop any with an open item in its `Blocked by` line or an assignee; first in map order wins.
- **Claim**: `wit_work_item_write` `update` setting `System.AssignedTo` to the current user, the session's first write.
- **Resolve**: `wit_work_item_comment_write` `add` with the answer, then set the done state, then append a context pointer (gist + link) to the map's Decisions-so-far.
