# Working conventions

Short rules. Follow them in every project unless the project's own AGENTS.md says otherwise.

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
