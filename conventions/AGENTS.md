# Working conventions

Short rules. Follow them in every project unless the project's own AGENTS.md says otherwise.

<!-- Coding principles condensed from https://github.com/multica-ai/andrej-karpathy-skills (commit 2c60614). MIT, (c) the original authors. -->
## Coding principles
Bias toward caution over speed. For trivial tasks, use judgment.
- **Think before coding.** State assumptions. If a request has several readings, list them; don't pick silently. If something is unclear, stop and ask. If a simpler approach exists, say so.
- **Simplicity first.** Minimum code that solves the problem. No unrequested features, no abstractions for single-use code, no configurability nobody asked for, no error handling for impossible cases. If 200 lines could be 50, rewrite.
- **Surgical changes.** Every changed line must trace to the request. Match existing style. Don't refactor or reformat adjacent code. Mention unrelated dead code instead of deleting it. Remove only the imports and functions your own change orphaned.
- **Goal-driven execution.** Turn the task into a check you can run: bug fix = a check that goes red on the old code and green after the fix, paired with a check that the behaviour which should still work still passes; refactor = tests green before and after. For multi-step work, state the plan as `step -> verify: check`.
- **Fix the cause.** Fix the root cause of a race or ordering bug; a timer, sleep or retry that hides the symptom is not a fix. When a workaround needs a comment to justify it, fix the code instead.

## Git
- Commit messages: imperative subject under 72 chars, then a blank line and a body saying why.
- Keep diffs small and reviewable. One logical change per commit.
- Ask before any destructive git operation: force-push, `reset --hard`, `clean`, branch deletion, rewriting published history.
- Work on a branch. Never commit straight to the default branch.

## Safety
- Never put client data, credentials or tokens into prompts, code, commits or docs.
- Never read or print secret files (`.env*`, keys, certificates). Ask for the specific value instead.
- Reference secrets as environment variables.

## Quality
- Write or update tests alongside every behaviour change.
- When the user corrects you, propose a check that would catch the mistake next time (lint rule, test, validator) before adding a prose rule.
- Run the check from the goal (tests, linters) before saying work is done. Report failures as they are.
- Decisions belong to the human; look facts up yourself instead of asking.
