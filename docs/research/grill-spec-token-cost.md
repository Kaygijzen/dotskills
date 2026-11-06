# Token cost of one end-to-end `grill-spec` run

Measured 2026-11-06 on one run against a separate private project (name and contents left out of this public repo), using the `grill-spec` skill as changed on the `grill-spec-cheaper` branch. "Measured" means summed from the `usage` fields in the Claude Code session transcript (`~/.claude*/projects/<project>/<session>.jsonl` and its `subagents/*.jsonl`), de-duplicated by message id, from a timestamp taken at the start of the run. One run, one machine, a mock change, so treat the numbers as an order of magnitude, not a benchmark. Prices are the Claude 5.5 API list prices from third-party aggregators, not Anthropic's own pricing page, which I could not fetch; check them before relying on the dollar figures.

## Setup

- `SKILL.md` was followed by hand, because `grill-spec` has `disable-model-invocation: true` and a model cannot call it. The user's answers were mocked by the same session, so there were fewer and shorter rounds than a real interview.
- Mock change: make the verdict validator reject a critic finding whose `path:line` evidence points at a file or line that does not exist. Phase 0 recon used 3 Sonnet `Explore` fact-finders. Phase 1 had 7 questions in 3 rounds. Phase 3 ran reviewer A (Sonnet) and reviewer B (Opus), then a second pass of both, because the first pass's blockers changed the design.
- Main session model: Sonnet 5.5 (the new `model: sonnet` pin). The session already held about 103k tokens of earlier conversation when the run started and ended at about 183k.

## Result

| Part | Model | Calls | Cache reads | Output | Cost |
|---|---|---|---|---|---|
| Main session | Sonnet | 24 | 3.2M | 39k | $1.06 |
| 3 recon fact-finders | Sonnet | 16 | 0.39M | 5k | $0.37 |
| Reviewer A, 2 passes | Sonnet | 14 | 0.68M | 12k | $0.56 |
| Reviewer B, pass 1 | Opus | 39 | 3.1M | 18k | $1.56 |
| Reviewer B, pass 2 | Opus | 41 | 3.7M | 21k | $1.60 |
| **Total** | | | | | **$5.15** |

- Reviewer B (Opus) was 61% of the cost. With one review pass the total would have been about $3.3.
- Cache reads dominate token counts everywhere (about 11M of about 11.2M input tokens). They are cheap per token, but every tool call re-reads the whole context. Reviewer B made about 40 tool calls per run, so it processed about 3.4M tokens each time despite reading only about 80k fresh.
- A fresh session would save about $0.2 on the main session, because this one started with a large context.
- Cache writes were the 1-hour tier in the main session and the 5-minute tier in every subagent (checked in the logs: 0 tokens in the 1-hour tier for reviewers A and B). I priced 1-hour writes at 2x the base input rate (an assumption) and 5-minute writes at the 1.25x rates in the table below.

## Prices used (per million tokens)

| | Input | Cache read | Cache write 5m (1.25x) | Cache write 1h (assumed 2x) | Output |
|---|---|---|---|---|---|
| Opus 5.5 | $4 | $0.20 | $5 | $8 | $20 |
| Sonnet 5.5 | $2 | $0.10 | $2.50 | $4 | $10 |

Sources (third party): <https://anotherwrapper.com/tools/llm-pricing/claude-opus-5-5>, <https://metricnexus.ai/blog/claude-opus-5-5-benchmarks-pricing>, <https://www.developersdigest.tech/models/claude-opus-5-5>, <https://www.ssdnodes.com/learn/claude-sonnet-5-5-price-and-uses>. The Sonnet cache-read price had only one source.

## Lessons

- The earlier estimate for this skill (about $2 after the Sonnet changes) was too low. It counted reviewer B at 80-200k tokens and ignored per-call cache re-reads, which is where most of the tokens are.
- The second review pass costs about as much as the first. The skill already says to re-run reviewers only when a blocker changed the design; here it did.
- Levers not applied: cap reviewer B's tool calls (risks truncating its codebase search), run reviewer B on Sonnet (saves about $1.50 a run, loses the Opus catches).
- Reviewer B (Opus) caught defects the Sonnet reviewer A missed on both passes (the production-path `run_case` caller and cassette breakage on pass 1; deterministic critics and a gate ordering dependency on pass 2), which is the case for keeping it on Opus.

## Second opinion (Opus) and what was applied

An Opus review of this note ranked the levers. Reviewer B's second pass, not B being on Opus, is the main avoidable cost, because pass 2 only ran when pass-1 findings changed the design.

Applied on branch `grill-spec-cheaper`:
- **Find blast-radius facts while grilling.** Phase 0 recon and the Phase 1 branch checklist now ask for every caller of the touched code (including production paths), fixtures or snapshots that encode current behaviour, and ordering against active changes. The pass-1 findings that forced a second pass were of exactly this kind. Not yet measured: whether it makes pass 2 rarer.
- **Read-only reviewer B.** A new `spec-impact-reviewer` agent (`tools: Read, Grep, Glob`, `model: opus`). Measured fixed prefix on the first call: 48.6k tokens for the `general-purpose` reviewer B, 8.2k for a read-only Opus subagent (the `ask-opus` run in the same session, with a slightly different prompt; one pair of runs). That is about 40k fewer tokens on each of reviewer B's roughly 40 calls, about $0.5 per B pass. Reviewer B's logged tool use was `Bash` only (grep, cat, ls), so `Read, Grep, Glob` should cover it.

Not applied:
- **Pass 2 as a re-check of the changed sections.** Small quality risk: B's pass-2 catches (deterministic critics, gate ordering) came from exploring beyond what the edits touched. If tried, fall back to a full pass when a design decision changed, and replay it on the frozen mock change first (about $1).
- Pre-digesting recon into B's prompt (anchors B to recon's blind spots), reviewer A alone on pass 2 (A missed those catches), hard tool-call caps (silent truncation).
- A 5-minute subagent cache TTL: subagents already write the 5-minute tier.
- Still open: whether B runs acceptably on Sonnet (could save about $1.5; test it against the frozen change before deciding), and whether a finished subagent can be resumed.

## How to repeat the measurement

Note the time before the run, then sum `message.usage` (`input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`) per model over assistant entries after that time in the session file and each `subagents/agent-*.jsonl`, keeping the last entry per message id. Or read `/cost` after the run.
