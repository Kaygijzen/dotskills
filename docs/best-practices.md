# Working well with Claude Code

Last checked: 2026-11-02 against the Claude Code docs.

## 1. Spec-driven development

For anything bigger than an afternoon: write the spec first, review it, implement it in fresh contexts, then verify against the spec.

When requirements live only in chat history, AI-written code is unpredictable. [OpenSpec](https://github.com/Fission-AI/OpenSpec) adds a lightweight spec layer: you and the agent agree on *what* to build in plain Markdown, in the repo, before any code is written. Then the spec, not the chat, is what the agent implements and what a reviewer checks against.

### The loop

`openspec init` installs these slash commands. On their own they cover the whole loop:

1. **Explore** (optional). `/opsx:explore` is a thinking mode: investigate the code and clarify requirements before anything is written down.
2. **Propose.** `/opsx:propose <idea>` drafts a *change*: a folder with a proposal (why), *delta specs* (what changes), a design and a task list.
3. **Review.** You read and correct the spec. This is the cheap place to catch a wrong assumption. `/opsx:update` revises the artifacts and keeps them consistent with each other.
4. **Implement.** `/opsx:apply` works through the tasks in the current session.
5. **Archive.** `/opsx:archive` moves the finished change into `archive/` and merges its delta specs into the *codebase specs*, which describe what the system does today. The next change starts from an accurate picture. (`/opsx:sync` does the merge without archiving.)

### Where dotskills fits in

Two skills replace steps of that loop when the change is large or the intent is fuzzy:

- **`/grill-spec` instead of explore + propose.** It interviews you until intent is shared, then runs `openspec-explore` and `openspec-propose` itself and has fresh-context sub-agents review the result before you see it.
- **`/ralph-apply` instead of `/opsx:apply`.** It runs one fresh headless session per task, so context never piles up over a long task list.

Review and archive stay the same. `/code-review` slots in between implement and archive to check the code against the change's spec.

### What it looks like

```
openspec/
├── specs/                 codebase specs: what the system does today
└── changes/
    ├── add-dark-mode/     one folder per change in flight
    │   ├── proposal.md    why we're doing this
    │   ├── specs/         delta specs: what this change adds or alters
    │   ├── design.md      technical approach
    │   └── tasks.md       implementation checklist
    └── archive/           finished changes
```

A delta spec lists requirements with concrete scenarios. It uses `ADDED`, `MODIFIED` or `REMOVED` to say how it differs from the codebase spec:

```md
## ADDED Requirements

### Requirement: Theme selection
The app SHALL let users switch between light and dark themes,
defaulting to the system preference.

#### Scenario: User toggles dark mode
- **WHEN** the user clicks the theme toggle
- **THEN** the app switches to dark mode and persists the choice
```

`/grill-spec` reads `openspec/specs/` first, so a new change is checked against current behaviour. Setup is in [Requirements](#requirements).

### Requirements

Most skills work out of the box. `grill-spec` and `ralph-apply` need [OpenSpec](https://github.com/Fission-AI/OpenSpec):

- The `openspec` CLI on your `PATH`. If it's missing, the installer offers to run `npm install -g @fission-ai/openspec@latest`. Pass `--with-openspec` (`-WithOpenSpec` on Windows) to skip the prompt and install, or `--no-openspec` (`-NoOpenSpec`) to skip the question. See the [install reference](install-reference.md).
- `openspec init` run in the project you're specifying. It creates `openspec/` and installs the `/opsx:*` commands and the `openspec-explore` and `openspec-propose` skills that `grill-spec` invokes.

`ralph-apply` also needs:

- The `claude` CLI on your `PATH`, since the loop runs `claude -p` once per task.
- An approved change on its own branch or worktree. The script refuses to run on `main` or `master`.
- A terminal for the loop itself. `/ralph-apply <change>` checks the change and prints the exact `scripts/ralph.sh` command to run.

### Choosing a flow

| Size of change | Tool |
| --- | --- |
| Small | Plan mode (`/plan`) |
| A feature | [OpenSpec](https://github.com/Fission-AI/OpenSpec) with the `grill-spec` skill |
| A long approved change | `ralph-apply`, which runs one fresh session per task |
| A spec with tickets | `ralph-tickets`, which runs one fresh session per ready ticket |

Each project makes two separate choices. (user) means the skill runs only when you type it, (model) means Claude may also invoke it on its own.

**How the spec is written:**

| Spec flow | Skills |
| --- | --- |
| OpenSpec | `grill-spec` (user) → `ralph-apply` (user) |
| Spec plus tickets | `grill-me` (user) → `to-tracker` (user) → `ralph-tickets` (user), with `wayfinder` (user) for work bigger than one session |

**Where the work is visible:**

| Tracker | With OpenSpec | With spec plus tickets |
| --- | --- | --- |
| None | the change folder in the repo | — |
| Local markdown | — (the change is already local) | files in `.scratch/`, the default without setup |
| GitHub, GitLab, Azure DevOps | optional mirror: `/to-tracker <change>` pushes the change as a parent issue with one child per task group, and later runs update their status | issues, pushed by `to-tracker` |

With the local-markdown tracker, or a `docs/agents/issue-tracker.md` you wrote for an external one, `/ralph-tickets` then implements the pushed tickets one by one, each in a fresh session.

These skills work alongside either flow:

- `grilling` (model), `codebase-design` (model), `improve-codebase-architecture` (user)
- `code-review` (model), `pr` (model), `prototype` (model), `research` (model), `domain-modeling` (model)
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

The always-on coding principles (think before coding, simplicity first, surgical changes, goal-driven execution) live in `conventions/AGENTS.md`. The full original text is in [karpathy-guidelines.md](karpathy-guidelines.md).

## 3. Model selection

Sonnet by default, Opus for planning and hard problems, Haiku for narrow, easy work. See [model-selection.md](model-selection.md).

## Habits that pay off

- [ ] Give the agent a way to verify its work: tests, a linter, a command to run.
- [ ] Keep diffs small and reviewable.
- [ ] Work on a branch or worktree.
- [ ] Review before committing.
- [ ] Never paste client data or secrets.
- [ ] If it goes off track twice, stop. Re-prompt or `/clear` instead of arguing.
