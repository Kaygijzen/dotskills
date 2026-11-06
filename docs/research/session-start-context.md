# What fills the context at session start, and what dotskills can trim

Researched 2026-11-06. Doc claims come from the official Claude Code docs at <https://code.claude.com/docs/en/> (page named per claim). Numbers for this repo are character counts of files, converted at about 4 characters per token, so treat them as rough. I did not run `/context`, so the 7% figure that prompted this note is not measured here.

## What loads before the first prompt

- CLAUDE.md files, with their `@imports`, load in full every session. "Splitting into @path imports ... doesn't reduce context, since imported files load with the CLAUDE.md importing them" (`memory`).
- Skill descriptions load every request. Each description plus `when_to_use` is cut at 1,536 characters, and the whole listing gets 1% of the context window; over that, descriptions of the least-used skills are dropped, names always stay (`skills`).
- `disable-model-invocation: true` keeps a skill's description out of context entirely. `user-invocable: false` does not (`skills`).
- Subagent descriptions load; the system prompts load only when the agent runs. A startup warning fires above 15,000 tokens of descriptions (`sub-agents`).
- Auto memory loads `MEMORY.md` (first 200 lines or 25KB), not topic files (`memory`).
- MCP tool schemas are deferred by default; only names and server instructions load (`costs`).
- Hooks cost nothing unless they print output (`features-overview`).
- Not documented: a baseline token count for the system prompt plus built-in tools. `/context` gives the live breakdown and `/doctor` estimates the skill listing cost (`context-window`, `skills`).

## What dotskills contributes

| Part | Size | Note |
|---|---|---|
| Conventions (`conventions/AGENTS.md`) | about 520 tokens | Loaded via the CLAUDE.md block or the SessionStart hook |
| Skill listing, invocable skills only | about 550 tokens | 10 of 20 skills already have `disable-model-invocation: true` |
| Agent descriptions | about 290 tokens | |
| Total, once | about 1.4k tokens | About 0.7% of a 200k window |

So the plugin is a small share of a 7% start. The rest is Claude Code's system prompt and tools, other plugins and connectors (their skills, agents and MCP instructions show in the same listings), and the user's own CLAUDE.md imports.

## Levers, biggest first

1. Set `disable-model-invocation: true` on skills the model rarely needs to start itself: `hello-skill` (a test skill), `wizard`, `prototype`, `domain-modeling`, `codebase-design`. Each saves its listing entry, about 50-110 tokens. Trade-off: the model stops suggesting them on its own; the user can still run them.
2. Shorten the longest descriptions, key use case first: `code-review` (434 characters), `wizard` (326), `codebase-design` (278), `ask-opus` (529). Saves about 300 tokens in total.
3. Outside this repo: disable plugins, connectors and skill packs you do not use, and keep `~/.claude/CLAUDE.md` and its imports short (the docs advise under 200 lines). Check `/context` first; this is likely where most of the 7% sits.
4. Keep `SKILL.md` bodies under 500 lines (docs advice). `grill-spec` (13 KB) and `writing-for-agents` (11 KB) cost only when invoked, so leave them.

## Not worth doing

- Trimming the conventions further: 520 tokens, and they carry the working rules.
- Removing the SessionStart hook: plugin-only users get no conventions without it. 
- Raising or lowering `skillListingBudgetFraction`: the listing is far below 1% of the window.

## Open

- Real baseline: run `/context` and `/doctor` in a fresh session and record the numbers here.
- Not found in primary docs: reserved auto-compact buffer, `@import` depth limit, exact SessionStart output handling.
