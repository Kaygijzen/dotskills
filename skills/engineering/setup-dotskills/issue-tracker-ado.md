# Issue tracker: Azure DevOps

> **Partly tested.** The operations below were run on 2026-11-03 against the local server (`@azure-devops/mcp` 2.11.0, `--authentication azcli`) in a project on the Agentic SDLC process. The remote server, other process templates and the dependent skills are not yet tested.

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
- **Create an issue**: `wit_work_item_write` with `action: create`, `workItemType`, and `fields`: a list of `{name, value, format}` (`System.Title`, `System.Description` with `format: Html`, `System.Tags`). If the project's process requires more fields on create, list them in Scope; `wit_work_item` `get_type` shows the required ones.
- **Read an issue**: `wit_work_item` with `action: get` (`id`, `project`; `expand: Relations` for links), then `action: list_comments` (`workItemId`, not `id`) for the comments.
- **List issues**: `wit_query` with `action: wiql` and a `WHERE` on type, state and tags. `wit_work_item` `get_batch` (with `project`, or it returns "Project selection cancelled") fetches the bodies of the ids it returns.
- **Edit body and title**: `wit_work_item_write` with `action: update`, patching `System.Title` and `System.Description`. `updates` is a JSON Patch list. Start it with `{op: test, path: /rev, value: <rev from the read>}`; an edit made since then is refused (HTTP 412), not overwritten.
- **Link a child to a parent**: at creation, `wit_work_item_write` with `action: add_child` (`parentId`, `workItemType`, `items`: `{title, description, format}`; the result is a batch response with the new id). For an existing item, `wit_work_item_link_write` with `action: link` and `updates: [{id: <child>, linkToId: <parent>, type: parent}]`.
- **List a parent's children**: `wit_query` with `action: wiql` on `WorkItemLinks` (`[System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward'` from the parent), or `wit_work_item` `get` with relations and read the child links.
- **Blocking**: a `Blocked by: #<id>, #<id>` line at the top of the description, or `Blocked by: none`. Add, remove and list blockers by reading and editing that line with **Edit body and title**. A ticket is unblocked when every listed item is in its done state. Predecessor/successor links are not used.
- **Ensure a label exists**: nothing to do. Labels are **tags** (`System.Tags`, semicolon-separated), created the first time they are used.
- **Comment on an issue**: `wit_work_item_comment_write` with `action: add`.
- **Apply / remove labels**: `wit_work_item_write` with `action: update` on `System.Tags`. The field replaces the whole value, so start from the item's current tags.
- **Close with a comment**: `wit_work_item_comment_write` `add` (`workItemId`, `text`), then `wit_work_item_write` `update` setting `System.State` to the done state from Scope. On Agentic SDLC, `New` to `Closed` works directly.

### Description is HTML

`System.Description` is HTML, not Markdown. Write bodies as simple HTML (`<p>`, `<ul>`, `<h2>`, `<code>`), and keep the first line plain so it stays readable on a re-read:

```
<p>Blocked by: #12, #14</p>
```

**The server strips HTML comments** (tested: from `Html` creates and from plain updates; a `Markdown` create stores the comment escaped as visible text). So `<!-- to-tracker:<key> -->` does **not** work as the marker here. **Marker: tag.** Apply the tag `to-tracker:<key>` instead of a body comment, and look it up with `WHERE [System.Tags] CONTAINS 'to-tracker:<key>'`.

`CONTAINS` on `System.Tags` matches whole tags only, so `to-tracker:*` or a prefix finds nothing. Look up an exact tag (`to-tracker:<key>`). `to-tracker:spec` is shared by every feature's parent, so tell parents apart by title or by `.scratch/<slug>/spec.md`, and find a parent's tickets through its child links, not through tags.

`add_child` cannot set tags (its items take only title, description, format and paths). Create tickets with `create`, then link them with `wit_work_item_link_write` (`type: parent`); or use `add_child` and set the tags in a follow-up `update`. The link tool must be allowed in headless sessions (`mcp__ado__wit_work_item_link_write`).

The server reformats HTML slightly (adds a space before closing tags, blank lines). A `Blocked by: #12, #14` line survives and parses back. Send `format: Html` on create; a plain update value is stored as given. Tags are merged by you: setting `System.Tags` replaces the whole value, and the server returns them sorted.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external pull requests as feature requests; a `triage` skill, if installed, reads this flag.)_ Pull requests are reached through the Azure DevOps `repositories` toolset, which is not enabled by default; add it to the server's toolsets if you need it.

## When a skill says "publish to the issue tracker"

Create a work item of the spec type from Scope.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above. The user will normally pass the id or the work item URL.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single work item with **child** work items as tickets.

- **Map**: a work item of the spec type, tagged `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: a work item of the ticket type, a child of the map (see **Link a child to a parent**), tagged `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). `add_child` cannot set tags, so apply the tag in a follow-up `update`. Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: see **Blocking** under Conventions.
- **Frontier query**: list the map's open children, drop any with an open item in its `Blocked by` line or an assignee; first in map order wins.
- **Claim**: `wit_work_item_write` `update` setting `System.AssignedTo` to the current user, the session's first write.
- **Resolve**: `wit_work_item_comment_write` `add` with the answer, then set the done state, then append a context pointer (gist + link) to the map's Decisions-so-far.
