# Working well with Claude Code

Last checked: 2026-11-02 against the Claude Code docs.

A draft for you to edit. It takes about five minutes to read.

## 1. Spec-driven development

For anything bigger than an afternoon: write the spec first, review it, implement it in fresh contexts, then verify against the spec.

| Size of change | Tool |
| --- | --- |
| Small | Plan mode (`/plan`) |
| A feature | [OpenSpec](https://github.com/Fission-AI/OpenSpec) with the `grill-spec` skill |
| A long approved change | `ralph-apply`, which runs one fresh session per task |

Two spec flows. Pick one per project:

| Project type | Flow |
| --- | --- |
| OpenSpec | `grill-spec` (user) → `ralph-apply` (user) |
| Issue tracker | `grill-me` (user) → `to-spec` (user) → `to-tickets` (user) → `implement` (user), with `wayfinder` (user) for work bigger than one session |

Run `/dotskills:setup-dotskills` once per project before the issue-tracker flow.

These skills work alongside either flow. (model) means Claude may invoke it on its own, (user) means it runs only when you type it:

- `grilling` (model), `codebase-design` (model), `improve-codebase-architecture` (user)
- `code-review` (model), `pr` (model), `prototype` (model), `research` (model)
- `tdd` (model), `domain-modeling` (model)
- `handoff` (user), `retro` (user), `teach` (user)
- `writing-for-agents` (model), `wizard` (model)

Do:
- Keep specs in the repo.
- Review the spec before any code is written.
- Let the agent look up facts. Make decisions yourself.

Don't:
- Implement a spec nobody approved.

## 2. Context management

The context window is a budget. Quality drops as it fills up.

Do:
- `/clear` between unrelated tasks.
- Use `/compact <what to keep>` when a task drags on, or start a fresh session.
- Check `/context` now and then.
- Delegate broad searches to subagents, so only conclusions come back.
- Keep `AGENTS.md` short. Move procedures into skills, which load only when needed.
- Enable only the MCP servers and plugin domains you use.
- Write state to files (specs, `tasks.md`, notes). `ralph-apply` is built on this idea.
- Use `handoff` to pass work to a fresh session: it writes a short document the next session reads, instead of you carrying a long conversation forward.

Don't:
- Keep one conversation running for days.

## 3. Model selection

Sonnet by default, Opus for planning and hard problems, Haiku for narrow, easy work. See [model-selection.md](model-selection.md).

## Habits that pay off

- [ ] Give the agent a way to verify its work: tests, a linter, a command to run.
- [ ] Keep diffs small and reviewable.
- [ ] Work on a branch or worktree.
- [ ] Review before committing.
- [ ] Never paste client data or secrets.
- [ ] If it goes off track twice, stop. Re-prompt or `/clear` instead of arguing.
