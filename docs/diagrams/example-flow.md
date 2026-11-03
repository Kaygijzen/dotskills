# Example flow: from idea to pull request

One way to chain the skills for a feature that is too big for a single prompt.

```mermaid
flowchart LR
    idea(["Idea"]) --> grill["/grill-spec<br/>interview + OpenSpec change"]
    grill --> review{"Spec reviewed<br/>and approved?"}
    review -- "no" --> grill
    review -- "yes" --> ralph["/ralph-apply<br/>checks change, prints command"]
    ralph --> loop["scripts/ralph.sh<br/>fresh claude -p per task"]
    loop --> cr["/code-review<br/>standards + spec"]
    cr --> arch["/opsx:archive<br/>merge deltas into openspec/specs"]
    arch --> pr["/pr<br/>write PR body"]
    pr --> done(["Pull request"])
```

| Step | Skill | Model | Where it runs |
| --- | --- | --- | --- |
| 1 | `grill-spec` | session model, `sonnet` fact-finders, `opus` reviewers | Claude Code session |
| 2 | `ralph-apply` | `sonnet` (override with `RALPH_MODEL`) | Terminal, on a non-`main` branch or worktree |
| 3 | `code-review` | session model | Claude Code session |
| 4 | `/opsx:archive` | session model | Claude Code session |
| 5 | `pr` | session model | Claude Code session |

Archiving runs after review and before the PR, so the updated `openspec/specs/` and the archived change land in the same pull request as the code. `/opsx:archive` moves the change to `openspec/changes/archive/` and updates the codebase specs in `openspec/specs/`, which is what the next `/grill-spec` reads as current behaviour.

For smaller work, swap steps 1-2 for `/to-spec` and `/to-tickets`.
