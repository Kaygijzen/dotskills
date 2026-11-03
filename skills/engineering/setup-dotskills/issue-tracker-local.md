# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file. Numbers are never reused or renumbered; a new ticket takes the next free number.
- Each ticket file opens with a title line, then plain metadata lines:

  ```
  # 03: <Ticket title>

  Parent: ../spec.md
  Status: ready-for-agent
  Blocked by: 01, 02
  ```

  `Status:` holds a role string from `triage-labels.md`, or `closed`. `Blocked by:` lists ticket numbers, or `none`.
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## Operations

- **Create an issue**: write a new file (create the directory if needed).
- **Edit body and title**: rewrite the file, keeping its `Status:` line and its `## Comments` section as they are.
- **Link a child to a parent**: the `Parent: ../spec.md` line.
- **List a parent's children**: the files in `.scratch/<feature-slug>/issues/`.
- **Add / remove a blocker, list blockers**: read or edit the `Blocked by:` line. A ticket is unblocked when every ticket it lists is `closed`.
- **Ensure a label exists**: nothing to do; the label is the `Status:` value.
- **Close with a comment**: append the comment under `## Comments`, then set `Status: closed`.

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
