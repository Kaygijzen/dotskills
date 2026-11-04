# Which model for which task

Last checked: 2026-11-02 against code.claude.com/docs/en/model-config and Anthropic's models overview.

**Sonnet is the default. Switch up or down on purpose, then switch back.**

Use the aliases (`sonnet`, `opus`, `haiku`), not dated model IDs. The alias always points at the current model of that family.

| Task | Model | Why |
| --- | --- | --- |
| Everyday coding: features, bug fixes, tests, refactors, small reviews | **Sonnet** (default) | Strong enough for nearly all implementation work; faster and cheaper than Opus |
| Long agentic runs and Ralph loops that implement an approved spec | Sonnet | The spec holds the hard thinking; execution needs reliability |
| Planning and architecture, writing or grilling a spec, hard debugging after Sonnet got stuck twice, reviewing a large or risky change | **Opus** | Better at ambiguous multi-step reasoning, where a wrong plan costs more than extra tokens |
| Plan with Opus, build with Sonnet | `opusplan` | Opus in plan mode, Sonnet when executing, without switching by hand |
| Quick questions, renames, small edits, summarising files, read-only search subagents, repetitive steps | **Haiku** | Fast and cheap; fine when the task is narrow and easy to check |

Set the model with `/model <alias>`, `claude --model <alias>`, or the `model` key in `settings.json`.

## Signals to switch up
- It repeats the same mistake.
- It loses track of a change that spans many files.
- The design is still unclear.

## Signals to switch down
- The task is mechanical.
- Tests check the result immediately.

## Subagents

A subagent can set its own `model:` in its frontmatter. Use Haiku for search and exploration agents, Sonnet for implementation agents, and Opus only for review, planning or consulting agents. The `code-reviewer` agent in this repo uses `opus`.

`ask-opus` lets a Sonnet session ask Opus one hard question without switching models. It is cheaper than `/model opus` because Opus gets only a short briefing, not the whole session: the question, the answer type, file:line pointers and what was tried. It reads at most about 6 targeted lookups, checks the claim its answer rests on, and replies with an answer, confidence and evidence. `maxTurns` is a hard stop in case the soft budget is ignored. `effort: high` is parsed by recent Claude Code versions but not yet listed in the official sub-agents docs.

## The skills in this repo

- `grill-spec`: your session model runs the interview, so switch to **Opus** for it. Its fact-finder sub-agents use `sonnet` and its spec reviewers use `opus`.
- `ralph-apply`: **Sonnet**. `ralph.sh` already passes `--model` (default `sonnet`, override with `RALPH_MODEL`), so the loop model is enforced.
- `ralph-tickets`: **Sonnet**, enforced the same way by `ralph-tickets.sh`.

### Imported skills (from mattpocock/skills)

Chosen from what each skill does. The session model runs the skill, so switch before you start.

| Skill | Model | Why |
| --- | --- | --- |
| `grill-me`, `wayfinder`, `improve-codebase-architecture` | **Opus** | Open-ended interviews and design judgement: a wrong plan costs more than the tokens |
| `code-review` | **Opus** (pinned in frontmatter) | It fans out to sub-agents and aggregates their reports; judgement matters more than speed |
| `prototype` | **Sonnet** | Execution against an agreed spec, with tests checking the result |
| `to-tracker` | **Opus** (pinned in frontmatter) | Synthesis of a conversation into a spec and tickets; a weak spec misleads every later step |
| `research` (pinned), `domain-modeling`, `codebase-design`, `teach` | Sonnet | Reading, writing and explaining |
| `pr` and `wizard` (pinned), `handoff`, `retro`, `setup-dotskills` | Sonnet, or Haiku for a small change | Short, structured writing |
| `hello-skill` | Haiku (pinned) | A one-line greeting and install check |

## Effort and thinking

`/effort` sets how hard the model thinks (`low`, `medium`, `high`, `xhigh`, `max`). The `effortLevel` setting and `claude --effort` do the same. Raise effort first when the model is on the right track but sloppy. Switch to a bigger model when it keeps misunderstanding the problem. Thinking is always on for current Sonnet, Opus and Haiku models.

## Cost

Opus costs noticeably more and responds more slowly than Sonnet. Haiku is the cheapest and fastest. Prices change, so see the official pricing page: <https://www.anthropic.com/pricing>.

## Higher tier

The `fable` alias is a tier above Opus. Only use it for exceptional problems, and check that your plan includes it.
