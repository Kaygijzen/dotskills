---
name: grill-spec
description: Grill the user until intent is shared, then generate a complete OpenSpec change (proposal, delta specs, design, tasks) and review it with fresh-context sub-agents before handing it to a coding agent. Use when the user invokes /grill-spec or asks to grill-and-spec a change.
argument-hint: "[rough description of the change]"
disable-model-invocation: true
---

# Grill → Spec → Review

Turn a rough idea into an OpenSpec change that a coding agent can implement without coming back with questions.

```
Phase 0  Recon          parallel sub-agents map the relevant code and specs
Phase 1  Grill          design-tree interview; facts from sub-agents, decisions from the user
Gate     Intent summary user confirms explicitly; nothing is generated before this
Phase 2  Propose        openspec-propose, synthesis only, no new questions
Phase 3  Review         two fresh-context reviewers + openspec validate
Phase 4  Handoff        apply-ready change, summary for the coding agent
```

Starting input: $ARGUMENTS

Ground rules for the whole run:
- **Never write application code.** OpenSpec artifacts are the only files you write.
- **Facts are your job, decisions are the user's.** Never ask the user something a sub-agent could look up. Never decide for the user something that is theirs to decide.
- **Keep your own context clean.** Delegate codebase reading to sub-agents and keep their conclusions, not their file dumps. A bloated context makes later questions worse.
- **Stay in one session.** The context built while grilling is what makes the spec good; do not suggest a fresh session before Phase 4.
- If the user is in plan mode, ask them to leave it. Plan mode pushes toward producing a plan, which works against the grilling.

## Phase 0: Recon

1. Invoke the `openspec-explore` skill with the Skill tool. Adopt its stance: read code and specs, never implement, use ASCII diagrams where a diagram makes a design clearer, question assumptions (including the user's). **Where explore and this skill disagree, this skill wins.** In particular:
   - The questioning cadence is the numbered rounds from Phase 1, not explore's free-flowing open threads.
   - Do not let explore capture artifacts or create a change; that happens in Phase 2.
   - Do not end with explore's "What we figured out" block; the Gate's intent summary replaces it.
2. Confirm OpenSpec is initialised (`openspec/` exists). If it is not, stop and tell the user to run `openspec init`.
3. In **one message**, dispatch 2–4 parallel `Explore` sub-agents (Agent tool, `subagent_type: "Explore"`) using the fact-finder prompt (Appendix A). Typical recon questions:
   - Which modules, files and entry points does this change touch? What calls them?
   - Which existing specs in `openspec/specs/` cover this area, and which requirements are relevant?
   - Are there active changes in `openspec/changes/` (not `archive/`) that overlap?
   - What conventions apply here (patterns, test setup, error handling, config)?
4. Summarise the recon in five lines or fewer and seed the design tree with what it found.

**Scope check.** If recon or the first round shows the tree spans several independent capabilities, or more than one reviewable change's worth of work, propose splitting it into multiple OpenSpec changes before grilling further. Then grill and spec them one at a time. A session heading past ~40 questions is a sign the scope is too big.

## Phase 1: Grill

Interview the user relentlessly until you reach a shared understanding. Map the work as a **design tree**: every decision branches into the decisions that depend on it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are settled, so you can ask it now without guessing at answers you haven't heard yet.

Each round:
1. **Separate facts from decisions.** A fact is anything the codebase, specs, config or tooling can answer. A decision is the user's call: intent, priorities, trade-offs, scope.
2. **Resolve facts in parallel.** Dispatch one `Explore` sub-agent per fact question, all in a single message, using the fact-finder prompt (Appendix A).
   - When a finding settles a question, state it as a finding with its file reference instead of asking.
   - When a finding is ambiguous, or contradicts what the user said, turn it into a decision question and show the evidence.
   - Don't block the whole round on a slow lookup: a pending lookup is an unsettled prerequisite, so only the questions downstream of it wait. If a lookup is broad, dispatch it with `run_in_background: true` and ask the independent questions now.
3. **Ask the decision frontier.** Number each question and give your recommended answer. Ask at most about 6 per round; if the frontier is bigger, ask the most upstream ones first. A question that depends on another question still open in this round belongs in a later round.
4. **Wait for answers,** then recompute the frontier. Settled decisions push it outward and unblock the questions that hung off them.

Format a round like this:

```
🔎 **Found**: <fact settled by recon or sub-agents> (path/to/file.ts:42)

❓ **Q1 - <question title>**: <question body, including options where relevant>

➡️ <your recommended answer and why>

---

❓ **Q2 - <question title>**: ...

➡️ ...
```

The user may answer briefly ("Q1 yes, Q2 option B") or just accept recommendations; accept that, but don't let acceptance substitute for a decision on anything with real trade-offs. If they are accepting everything, say so and point to the one or two questions that most deserve their own judgement.

Treat "I don't know" as a real answer. Record it as an open risk, or suggest a spike task, rather than guessing. Push back when an answer conflicts with a finding or an earlier decision.

Branches worth checking before you call the tree done: success criteria, error and edge cases, data/migration impact, backwards compatibility, security and permissions, observability, testing approach, and what is explicitly out of scope.

The interview is done when the frontier is empty: every branch has been visited and nothing is silently assumed.

## Gate: Intent summary

Present the summary below and ask the user to confirm it explicitly. Do not continue until they do. If they correct anything, update the summary and ask again.

```
## Intent: <change-name-in-kebab-case>

**Problem**: why this change is needed
**Outcome**: observable result; how we know it works (success criteria)
**In scope**: ...
**Out of scope / non-goals**: ...
**Decisions**: decision + one-line rationale, one per line
**Constraints**: technical, compatibility, performance, security
**Codebase facts**: findings the implementation must respect, with file refs
**Affected specs / capabilities**: existing specs modified, new capabilities added
**Open risks**: unknowns, "I don't know" answers, suggested spikes
```

This summary is the contract for Phases 2 and 3. Keep it verbatim in the conversation.

## Phase 2: Propose (synthesis only)

Invoke the `openspec-propose` skill with the Skill tool. Pass the change name and the confirmed intent summary as its input. Follow its steps (`openspec new change`, `openspec status --json`, `openspec instructions <artifact> --json`, artifacts in dependency order until every artifact in `applyRequires` is done), with these overrides:

- **No new questions.** Skip propose's opening "what do you want to build?" question; the intent summary answers it. Where propose would ask the user for missing context, stop generating instead. Grill that single branch in one short round, update the intent summary, get it confirmed again, and resume. A gap found here means the grilling missed something; do not fill it with a guess.
- **Trace everything to intent.** Every decision, requirement and non-goal in the summary must land in an artifact: proposal (why/what, non-goals), delta specs (requirements with scenarios), design (decisions, rationale, alternatives considered, open risks), tasks. Do not add scope the summary does not contain.
- **Follow the schema.** The `instruction`, `template`, `context` and `rules` from `openspec instructions` are authoritative for each artifact's structure; the overrides here only govern content and cadence.
- **Write tasks for a coding agent.** Each task should be small enough for one focused session, name the files or modules it touches (from the codebase facts), and state how to verify it (a test, a command, or an observable behaviour). Put spike tasks for open risks first.
- **Do not end the way propose normally ends.** Where it would tell the user to run `/opsx:apply`, continue to Phase 3 instead.

## Phase 3: Review

The context that wrote the artifacts is the worst one to review them, so the review runs in fresh sub-agents.

1. Run `openspec validate <change-name> --strict` and fix any errors yourself first.
2. In **one message**, dispatch two parallel `general-purpose` sub-agents using the reviewer prompts (Appendix B). (Not `Explore`: it locates code but doesn't review it.)
   - **Reviewer A, intent and consistency.** Give it the intent summary and the change path.
   - **Reviewer B, codebase impact.** Give it the change path only, so it judges the artifacts against reality rather than against the conversation.
3. Merge the findings, drop duplicates, and sort by severity. Then route each one:
   - **Artifact defect** (inconsistency, a missing scenario, a vague task, a missed file): fix it in the artifacts yourself.
   - **Needs a decision** (a new trade-off, a conflict with an existing spec, a breaking change nobody discussed): ask a short grilling round, update the intent summary, then fix the artifacts.
   - **Not an issue / out of scope**: note it and move on.
4. Re-run `openspec validate --strict`. Re-run the reviewers only if a blocker changed the design; otherwise one review pass is enough.

## Phase 4: Handoff

Report briefly:
- Change name and path (`openspec/changes/<name>/`) and which artifacts were produced.
- What the review found and how each item was resolved, plus any accepted risks.
- Remaining open risks or spike tasks the coding agent should do first.
- The next step: `/opsx:apply <name>` in a fresh session, or point a coding agent at the change folder.

Do not start implementing. The handoff ends this skill.


---

## Appendix A: Fact-finder sub-agent prompt

Use this for every codebase lookup in Phase 0 (recon) and Phase 1 (grilling).

- Tool: the Agent tool, with `subagent_type: "Explore"`. Explore takes its search breadth from the prompt: keep "medium" below, and change it to "very thorough" only for cross-cutting questions.
- Send one question per agent. Dispatch all of a round's lookups in a single message so they run in parallel.

Fill in `<QUESTION>` and `<CONTEXT>` and send the rest as written.

---

You are answering one factual question about this codebase for a planning session. Read-only: do not modify anything. Search breadth: medium.

**Question:** <QUESTION>

**Why it matters:** <CONTEXT: the change being planned, in one or two sentences>

Also check `openspec/specs/` and active changes in `openspec/changes/` (ignore `archive/`) when they are relevant to the question.

Reply in this format, under 200 words:

**Answer:** one or two sentences.
**Confidence:** confirmed (seen in code) | inferred (strong indirect evidence) | not found.
**Evidence:** `path/to/file.ext:line` with a short note for each relevant location (at most 5).
**Also relevant:** anything you noticed that the planners would likely want to know, such as conflicting patterns, an overlapping active change, an existing spec requirement, or a surprising caller. Write "none" if there is nothing.

Do not speculate beyond the evidence. If the answer depends on a choice nobody has made yet, say so. Do not pick an answer.

---

## Appendix B: Reviewer sub-agent prompts

Phase 3 dispatches both reviewers in a single message.

- Tool: the Agent tool, with `subagent_type: "general-purpose"`.
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

Use sub-searches as needed. Cite file:line for every claim about the code.

<SHARED FINDING FORMAT>
```

---

Adapted from Matt Pocock's `grilling` and `code-review` skills (github.com/mattpocock/skills, MIT) and OpenSpec's `openspec-explore` / `openspec-propose` (github.com/Fission-AI/OpenSpec, MIT).
