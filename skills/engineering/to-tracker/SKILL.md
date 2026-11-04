---
name: to-tracker
description: Turn the current conversation, or a spec or issue you pass, into a spec plus tracer-bullet tickets and push both to the configured issue tracker; or mirror an OpenSpec change there. Re-running updates what it pushed before.
model: opus
disable-model-invocation: true
targets: [claude]
---

# To Tracker

Synthesize a **spec** and its **tickets** (tracer-bullet vertical slices with blocking edges), then push them to the issue tracker: the spec as the parent, each ticket as a child. The push is one-way: tracker *content* never flows back into the spec. Tracker *state* (ids, children, open/closed, assignee) is read only to update safely. Blocking edges are soft on every tracker: a `Blocked by:` line in the ticket body, never a native tracker link.

## 1. Preconditions

- Read `docs/agents/issue-tracker.md`. Every tracker action below is an operation named in that doc; carry it out exactly as the doc says.
- If `docs/agents/issue-tracker.md` is missing, use the local-markdown tracker (files in `.scratch/`) and tell the user so once; `/setup-dotskills` connects GitHub, GitLab or Azure DevOps. The local tracker's doc is `issue-tracker-local.md` in the `setup-dotskills` skill folder (the sibling of this skill folder's real path).
- External tracker: make the doc's read-only connection check the session's first tracker call. If the MCP server isn't connected, stop and point to `/setup-dotskills`. Use the CLI only where the doc marks a step **CLI**.
- A tracker the doc describes freely ("other"): check that it defines create, edit body and title, link a child to a parent, list a parent's children, ensure a label exists, and close with a comment. If any is missing, stop and name them.
- Labels: the `ready-for-agent` mapping in `docs/agents/triage-labels.md`, plus the file's extra labels, or the literal `ready-for-agent` when that file is absent.
- Templates: `docs/agents/templates/spec.md` and `ticket.md` when present, else [templates/spec.md](templates/spec.md) and [templates/ticket.md](templates/ticket.md). Fill every heading of the template, including headings the user added; write "n/a" where nothing applies.

## 2. Mode

Done when exactly one mode is chosen:

- **OpenSpec change**: the argument names a change under `openspec/changes/` (archived or not). Follow [openspec-mirror.md](openspec-mirror.md) from here on, in place of the steps below.
- **Re-run**: the argument is a spec or ticket this skill pushed. It carries a `to-tracker:…` marker (see step 6), or matches an entry in some `.scratch/*/.tracker.json`. Load that feature's `spec.md` and `.tracker.json`.
- **Foreign issue**: the argument is an issue this skill did not push. It is the *source*: read its body and all its comments. It stays untouched, apart from one comment in step 6.
- **New**: a spec path (read it in full) or the conversation.

## 3. Spec

**New** (and foreign issue): no interview; synthesize what you already know.

1. Explore the repo if you haven't. Use the project's glossary vocabulary and respect ADRs in the area you're touching.
2. Sketch the seams at which the feature will be tested. Prefer existing seams; use the highest seam possible; the ideal number is one. Check with the user that these seams match their expectations.
3. Write the spec from the spec template.

**Re-run**: start from the existing `spec.md` and apply only what this conversation changes. Unchanged sections stay byte-identical.

## 4. Tickets

Break the spec into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring comes first: "make the change easy, then make the easy change"

</vertical-slice-rules>

Give each ticket its **blocking edges**: the other tickets that must complete before it can start.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so no vertical slice can land green. Sequence it as **expand–contract**: expand (add the new form beside the old), then migrate call sites in batches sized by blast radius, each its own ticket blocked by the expand, then contract (delete the old form) in a ticket blocked by every batch. When even the batches can't stay green alone, let them share an integration branch that all block a final integrate-and-verify ticket.

Each ticket has a **key**: a kebab slug of its title, set at first push and kept for life. On a re-run, match the new ticket list to the existing keys by meaning, not by title. A key once closed is retired; a new ticket gets a new key.

Write each ticket body from the ticket template.

## 5. Review

Push nothing until the user approves. Iterate until they do.

- **New**: show the spec, then the tickets as a numbered list: key, title, blocked by, what it delivers. Ask whether the granularity is right, whether each edge genuinely gates its ticket, and whether any ticket should be merged or split.
- **Re-run**: show the change set:
  - the spec diff;
  - per ticket: keep / update / create / close, with the proposed key mapping, so a retitled ticket stays one update rather than a close plus a create;
  - closed or assigned tickets, which stay as they are unless the user says otherwise;
  - a warning that pushing overwrites manual edits made to these bodies in the tracker.

## 6. Push

The skill owns these parts of every body, outside the template:

- the marker: `to-tracker:spec` on the parent, `to-tracker:<key>` on each ticket. By default it is the body comment `<!-- to-tracker:<key> -->`. If the tracker doc says it strips body comments and names a **tag** marker, apply the tag `to-tracker:<key>` instead (merged with the item's other tags) and write no comment;
- on a foreign source, a first line `Source: #<n>` in the parent;
- the parent link, as the tracker doc represents it;
- the `Blocked by:` line, listing the ids of the blocking tickets (`#<n>` externally, `NN` locally), or `none`.

Run "ensure a label exists" for each label once before the first write.

**New**:

1. Create the parent from the spec. On the local tracker, the parent is `.scratch/<feature-slug>/spec.md`.
2. With a foreign source, comment once on the source, linking to the new parent.
3. Create the tickets in dependency order (blockers first), so each `Blocked by:` line can name real ids. Link each to the parent and apply the label.

**Re-run**:

1. Edit the parent body.
2. Changed tickets, including changed edges: edit body and title. The `Blocked by:` line is part of the body, so the edit updates the edges.
3. Create new tickets as above.
4. Close removed tickets with the comment "Removed from the spec by to-tracker".

Touch only the parent and issues listed in `.tracker.json` or carrying this feature's markers. The parent stays open.

**Before every create**, list the parent's children and look for the marker (comment or tag, as above). A child that carries it is adopted, not duplicated. After every create, write `.tracker.json`.

## 7. State

Everything for one feature lives in `.scratch/<feature-slug>/`, for every tracker type:

- `spec.md`: the source of truth for the spec. On an external tracker the parent body is a copy of it.
- `.tracker.json`:

  ```json
  {
    "tracker": "github",
    "parent": "123",
    "tickets": {
      "add-login-form": { "id": "124", "state": "open" },
      "old-idea": { "id": "126", "state": "closed" }
    }
  }
  ```

  On the local tracker, ids are paths relative to the feature directory (`spec.md`, `issues/01-add-login-form.md`).
- A lost `.tracker.json` is rebuilt from the markers on the parent's children.
- Whether `.scratch/` is committed is the project's choice; leave `.gitignore` as it is.

## 8. Report

Print the parent link, then one line per ticket: key → id, and the action taken.
