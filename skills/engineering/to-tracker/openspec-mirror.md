# OpenSpec mirror

The OpenSpec change is the source of truth: it is what `ralph-apply` implements and `code-review` checks against. The tracker gets a one-way **mirror** of it for visibility and status, never a second spec. There is no spec synthesis and no ticket slicing in this mode: only map and push.

## Preconditions

- An external tracker is configured (step 1 of `SKILL.md`). The local tracker is not offered, because the change already lives in the repo: if `docs/agents/issue-tracker.md` is missing or names the local tracker, stop and say so.
- The change folder: `openspec/changes/<change>/`, or `openspec/changes/archive/<date>-<change>/` once archived. Read `proposal.md` and `tasks.md` in full.

## Map

- **Parent, with a source issue**: if `proposal.md` starts with a `Source: <reference>` line (written by `grill-spec`), that issue is the parent. It is a foreign issue: never edit its body, title or labels, and never close it. It carries no marker, so on a lost `.tracker.json` the `Source:` line in `proposal.md` stands in for it: read the issue from there, then rebuild the children from their markers. If the reference can't be read, stop and say so; don't create a second parent.
- **Parent, without one**: a short summary of `proposal.md` (its Why and What Changes, in a few lines), then a link to the change folder. Leave the delta specs out, so the mirror can't drift from them. Marker: `<!-- to-tracker:spec -->`.
- **Children**: one per task group, the numbered `## N. <heading>` sections of `tasks.md`. Body: the group's checkboxes, copied with their tick state, which shows progress. Marker: `<!-- to-tracker:<key> -->`, where the key is a kebab slug of the heading without its number.
- **Blocking**: each group is blocked by the group before it, because `ralph-apply` works top to bottom. The first group is `Blocked by: none`.
- **Labels**: as in `SKILL.md` step 1.
- **State**: `.tracker.json` inside the change folder, in the format of `SKILL.md` step 7. `/opsx:archive` moves it with the change.

## Review and push

Follow `SKILL.md` step 5 (review) and step 6 (push, dedupe, writing state after every create), with these status rules on a re-run:

- A group whose checkboxes are all ticked: edit its body, then close it with the comment "All tasks done".
- A group removed from `tasks.md`: close it with "Removed from the change by to-tracker".
- An archived change: update every child as above, then close the parent with a comment linking to the archived folder. A source-issue parent is never closed: comment instead.
- A source-issue parent gets status as comments only: one comment on the first push linking to the change folder and listing the children, and one comment per later run in which a child closed or the change was archived. No comment when nothing changed.

Then report as in `SKILL.md` step 8.
