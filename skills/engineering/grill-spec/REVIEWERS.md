# Reviewer sub-agent prompts

Phase 3 dispatches both reviewers in a single message.

- Tool: the Agent tool. Reviewer A uses `subagent_type: "general-purpose"` with `model: "sonnet"`: it checks the artifacts against the intent summary, which is mostly structural. Reviewer B uses `subagent_type: "spec-impact-reviewer"` (`dotskills:spec-impact-reviewer` in a plugin install), a read-only agent pinned to Opus: it judges the artifacts against the real codebase, which needs the strongest model. Its tool set is `Read, Grep, Glob`, which keeps each of its many calls cheap.
- Both reviewers are read-only and report findings; they never edit.
- Both use the same finding format, so the results merge cleanly.

### Shared finding format (paste into both prompts)

```
Report at most 12 findings, most severe first. For each:

- **[severity] title**: blocker (a coding agent would build the wrong thing or break something) | major (likely rework or a defect) | minor (clarity, polish)
- **Where**: artifact file + section, and/or `path/to/code.ext:line`
- **Problem**: what is wrong, in one or two sentences
- **Evidence**: quote or file reference
- **Suggested fix**: concrete wording or change
- **Route**: artifact-defect (fixable in the artifacts without asking anyone) | needs-decision (a trade-off or scope call the user must make)

Only report issues you can point to evidence for. If you find nothing at a severity level, don't invent something. End with one line: "Verdict: ready | ready after fixes | not ready".
```

---

### Reviewer A: intent and consistency

Fill in `<CHANGE_PATH>` and `<INTENT_SUMMARY>`.

```
You are reviewing an OpenSpec change before it is handed to a coding agent. Read-only: do not modify any file.

Change folder: <CHANGE_PATH> (read every file in it, including specs/**)
Confirmed intent (the contract the change must satisfy):

<INTENT_SUMMARY>

Check the artifacts on these axes:

1. Faithfulness: every decision, in-scope item, non-goal and constraint in the intent appears in the artifacts. Nothing was added that the intent does not contain (scope creep). Non-goals are stated, not silently dropped.
2. Spec quality: every requirement uses SHALL/MUST, is testable, and has at least one scenario (WHEN/THEN). Scenarios cover error and edge cases, not just the happy path. Delta operations (ADDED/MODIFIED/REMOVED/RENAMED) are used correctly; MODIFIED requirements contain the full updated text.
3. Traceability: every requirement maps to at least one task, and every task traces back to a requirement or design decision. Flag orphans in both directions.
4. Internal consistency: proposal, design, specs and tasks agree on names, behaviour, data shapes and scope. Terms are used consistently.
5. Executability for a coding agent: each task is small enough for one focused session, names the files/modules it touches, and has a verification step. Task order respects dependencies. Open risks have spike tasks placed first.
6. Ambiguity: anywhere a coding agent would have to guess (vague words like "handle", "support", "appropriate", undefined limits, unspecified error behaviour).

<SHARED FINDING FORMAT>
```

---

### Reviewer B: codebase impact

Fill in `<CHANGE_PATH>` only. Do **not** give this reviewer the intent summary or conversation. It should judge the artifacts against the codebase and existing specs, not against what was discussed.

```
You are reviewing an OpenSpec change against the actual codebase before a coding agent implements it. Read-only: do not modify any file.

Change folder: <CHANGE_PATH> (read every file in it, including specs/**)

Read the artifacts, then investigate the codebase and openspec/ to find defects and implications the authors may have missed:

1. Blast radius: all callers, consumers and dependents of the code the tasks touch. Are any affected places missing from the tasks?
2. Breaking changes: public APIs, data formats, DB schemas, config, CLI flags, events or file formats that change. Is migration, backwards compatibility or a rollout path covered?
3. Conflicts with existing specs: requirements in openspec/specs/ that the delta contradicts or silently changes without a MODIFIED/REMOVED entry.
4. Conflicts with active changes: other folders in openspec/changes/ (ignore archive/) touching the same capabilities or files.
5. Wrong assumptions: places where the design or tasks assume something about the code that isn't true (wrong file, missing function, different pattern, different library version).
6. Non-functionals: security and permissions, performance, concurrency, error handling, logging/observability, and test setup. Flag only where the change plausibly affects them.
7. Convention fit: does the design follow the patterns the codebase already uses for this kind of thing? If not, is the deviation justified in design.md?

Search as needed. Cite file:line for every claim about the code.

<SHARED FINDING FORMAT>
```

