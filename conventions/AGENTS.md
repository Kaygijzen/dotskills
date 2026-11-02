# Working conventions

Short rules. Follow them in every project unless the project's own AGENTS.md says otherwise.

<!-- Coding principles condensed from https://github.com/multica-ai/andrej-karpathy-skills (commit 2c60614). MIT, (c) the original authors. -->
## Coding principles
- **Think before coding.** State assumptions. If a request has several readings, or something is unclear, say so and ask. Don't pick silently.
- **Simplicity first.** Write the minimum code that solves the problem. No extra features, no abstractions for single-use code, no unrequested configurability.
- **Surgical changes.** Touch only what the task needs. Match the existing style. Don't improve adjacent code. Clean up only your own mess.
- **Goal-driven execution.** Turn the task into a verifiable success criterion, such as a failing test that should pass. Loop until it is met.

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
- Run the project's tests and linters before saying work is done. Report failures as they are.
- Decisions belong to the human; look facts up yourself instead of asking.
