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

Chosen from what each skill does. Unless a skill is pinned, the session model runs it, so switch before you start.

| Skill | Model | Why |
| --- | --- | --- |
| `grill-spec` | **Opus** | The session model runs the interview. Its fact-finder sub-agents use `sonnet` and its spec reviewers use `opus` |
| `ralph-apply` | **Sonnet** (enforced) | `ralph.sh` passes `--model` to every loop session (default `sonnet`, override with `RALPH_MODEL`) |
| `grill-me`, `grilling`, `improve-codebase-architecture` | **Opus** | Open-ended interviews and design judgement: a wrong plan costs more than the tokens |
| `code-review` | **Opus** (pinned in frontmatter) | It fans out to sub-agents and aggregates their reports; judgement matters more than speed |
| `second-opinion` | Sonnet | It hands the hard question to Opus through the `ask-opus` agent, so the session can stay on Sonnet |
| `prototype` | **Sonnet** | Execution against an agreed spec, with tests checking the result |
| `research` (pinned), `domain-modeling`, `codebase-design`, `teach`, `writing-for-agents` | Sonnet | Reading, writing and explaining |
| `pr` and `wizard` (pinned), `handoff`, `retro`, `bro`, `setup-dotskills` | Sonnet, or Haiku for a small change | Short, structured writing or a scripted setup |
| `hello-skill` | Haiku (pinned) | A one-line greeting and install check |

## Effort and thinking

`/effort` sets how hard the model thinks (`low`, `medium`, `high`, `xhigh`, `max`). The `effortLevel` setting and `claude --effort` do the same. Raise effort first when the model is on the right track but sloppy. Switch to a bigger model when it keeps misunderstanding the problem. Thinking is always on for current Sonnet, Opus and Haiku models.

## Cost

Opus costs noticeably more and responds more slowly than Sonnet. Haiku is the cheapest and fastest. Prices change, so see the official pricing page: <https://www.anthropic.com/pricing>.

## Higher tier

The `fable` alias is a tier above Opus. Only use it for exceptional problems, and check that your plan includes it.
