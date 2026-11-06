# Reducing token usage and cost of the `ralph-apply` loop

Researched 2026-11-06 against Claude Code 2.1.319 and the official docs at code.claude.com and platform.claude.com. No convention for research notes existed in this repo (no `docs/research/`), so this file starts one. Claims carry their source URL. "Measured" means I ran `claude -p --output-format json` locally; those numbers come from one machine (plugins, skills and a user-level CLAUDE.md loaded), n is small, and they are not doc claims.

## Summary: ranked recommendations

1. **Restrict the tool set with `--tools "Bash,Read,Edit,Write,Glob,Grep"` in `ralph.sh`.** Biggest saving. Every turn re-reads the system prompt and all tool definitions from cache. Measured: a one-turn `claude -p` dropped from about 36.9k to about 8.3k total input tokens (about -28k per turn). On a 25-40 turn iteration that is 0.7-1.1M fewer cache-read tokens plus a smaller cache write. Flag exists: <https://code.claude.com/docs/en/cli-reference>. The loop only needs the tools already listed in `--allowedTools`; `openspec` and verify commands run through Bash. Make it overridable (for example `RALPH_TOOLS`) for projects that need more.
2. **Stop telling the iteration to re-read `AGENTS.md`/`CLAUDE.md` in `prompt.md` step 1.** Without `--bare`, Claude Code loads CLAUDE.md (or AGENTS.md when no CLAUDE.md exists) at session start; reading it again pays for the content twice, once in the prefix and once as a tool result that is then re-read every later turn. Keep a conditional ("read AGENTS.md only if it is not already in your context") because a project with both files and a CLAUDE.md that does not import AGENTS.md loads only CLAUDE.md. Source: <https://code.claude.com/docs/en/memory>.
3. **Measure before tuning: write `--output-format json` per iteration and log `total_cost_usd`, `num_turns` and `usage`.** Without this the 1M/10k estimate cannot be checked. Add `--max-budget-usd` (exists, print mode only) as a runaway cap. See topic 3. Sources: <https://code.claude.com/docs/en/headless>, <https://code.claude.com/docs/en/cli-reference>.
4. **Trim orientation reads in `prompt.md`.** Read `tasks.md` and `notes.md` first, then only the `design.md` section and the spec requirements the task names, instead of all of `proposal.md`, `design.md`, `specs/**`. Everything read is re-read from cache on every later turn, so each 10k tokens read early costs about 10k x remaining turns in cache reads. Principle: <https://code.claude.com/docs/en/costs> ("Write specific prompts"); the arithmetic is in "Corrections to the estimate".
5. **Keep verify output small.** Default Bash output is inlined up to about 30,000 characters; lower with `BASH_MAX_OUTPUT_LENGTH` (for example 10000) in the loop's environment and tell the iteration to run only the relevant tests with a quiet reporter. A PreToolUse hook that filters test output is the documented pattern (rtk already does this if installed). Sources: <https://code.claude.com/docs/en/tools-reference>, <https://code.claude.com/docs/en/env-vars>, <https://code.claude.com/docs/en/costs>.
6. **Try `--effort low` or `medium` for mechanical tasks (A/B with item 3).** Thinking is billed as output at $10/MTok on Sonnet 5.5 and cannot be turned off on it. Quality effect is unverified. Sources: <https://code.claude.com/docs/en/model-config>, <https://code.claude.com/docs/en/costs>.
7. **Do not change the model default.** Sonnet 5.5 is $2 in / $10 out; Haiku 5.5 is 20x cheaper but Anthropic positions it for classification, extraction and routing, not long agentic coding (capability for this loop unverified). Opus 5.5 is $4/$20.
8. **Leave cache TTL alone** and **do not add `--exclude-dynamic-system-prompt-sections`** (measured slightly worse for a same-machine, same-directory loop). See topic 1.
9. **Optional, API-key users only: `--bare`.** Minimal prompt, no hooks/skills/plugins/MCP/memory/CLAUDE.md. It never reads OAuth or keychain credentials, so it does not work on a subscription login. Not measured here (no API key available). Source: <https://code.claude.com/docs/en/headless#start-faster-with-bare-mode>.

Smaller levers, measured: `--disable-slash-commands` saved roughly 5-7k tokens of skill listing; `--setting-sources project` saved roughly 6k (drops user-level CLAUDE.md, skills, plugins and hooks, so it also drops rtk's output filtering and your conventions; not recommended without checking); `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` plus `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1` saved about 1k. `--strict-mcp-config` saved nothing here (no MCP servers configured).

## 1. Prompt caching across separate `claude -p` runs

- Claude Code requests caching automatically; the cache is server-side and keyed by exact prefix match (system prompt + tool definitions, then CLAUDE.md/auto memory, then conversation). Source: <https://code.claude.com/docs/en/prompt-caching>.
- Each model, and fast vs standard speed, has its own cache. Effort changes keep the cache on Sonnet 5.5. Source: same page.
- Cross-process sharing: "the cache is effectively scoped to one machine and directory." Sequential sessions share the prefix only when the startup git-status snapshot matches, because each conversation carries the branch and recent commits. Every Ralph iteration commits, so the snapshot differs between iterations; the system prompt/tools/CLAUDE.md prefix before it can still hit, the conversation part cannot. Source: same page, "Cache scope".
- TTL: unless you set one, the main conversation (including `-p`) gets **1 hour on a Claude subscription within plan usage** and **5 minutes with an API key, usage credits or a cloud provider**. Subagents, compaction and other helper requests default to 5 minutes. Each cache hit resets the timer. Source: same page, "Which TTL each request gets".
- Controls: `CLAUDE_CODE_PROMPT_CACHE_TTL` / `promptCacheTtl` (main), `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL`, `ENABLE_PROMPT_CACHING_1H=1` (both buckets), `FORCE_PROMPT_CACHING_5M=1`. Values `5m` or `1h`. Verify what a run wrote with `usage.cache_creation.ephemeral_1h_input_tokens` / `ephemeral_5m_input_tokens` in the JSON result. Sources: same page; <https://code.claude.com/docs/en/env-vars>; <https://code.claude.com/docs/en/agent-sdk/cost-tracking>.
- Prices (Sonnet 5.5, per MTok): input $2, 5-minute write $2.50 (1.25x), 1-hour write $4 (2x), cache read $0.10 (0.05x for Sonnet 5.5 and Opus 5.5; 0.1x for most other models), output $10. Source: <https://platform.claude.com/docs/en/about-claude/pricing>.
- Does the gap between iterations matter? Iterations start back to back, so the gap is seconds and a 5-minute TTL is enough. A pause longer than the TTL means the next iteration rewrites the fixed prefix once (about 27-37k tokens in my setup, roughly $0.07-0.15). That is small next to the per-turn costs, so do not buy the 1-hour TTL (2x write price) for this loop on an API key.
- Measured (subscription login, 1-turn `claude -p "reply with: ok"`, Sonnet): cache writes were reported under `ephemeral_1h_input_tokens`, matching the doc. Rerunning the identical command hit the cache in some runs (cache_read about 27k) and missed in others (about 27-29k tokens rewritten, sizes differing by a few hundred tokens between runs), so some part of the prefix is not byte-stable between invocations. I did not find the cause. About 9.8k tokens were billed as uncached input on every default run (the part after the last cache breakpoint). Treat the hit rate across iterations as something to read from your own logs (`cache_read_input_tokens` vs `cache_creation_input_tokens`), not assume.
- `--exclude-dynamic-system-prompt-sections` exists and "improves prompt-cache reuse across different users and machines"; it is ignored with `--system-prompt`. Measured here it was slightly worse for same-machine reruns (about 2.7k tokens re-written each time, cost $0.033 vs $0.022 warm), so skip it for Ralph. Source: <https://code.claude.com/docs/en/cli-reference>.

## 2. Fixed per-session overhead and how to shrink it

- No doc gives a token count for the system prompt or tool definitions. Unverified from docs; measured: about 37k tokens of fixed prefix in my setup with default flags, about 8.3k with `--tools "Bash,Read,Edit,Write,Glob,Grep"`, about 7.5k when that is combined with `--strict-mcp-config --disable-slash-commands --setting-sources project`. Run `/context` interactively or read the JSON `usage` of a trivial prompt to get your own number.
- What loads before the first prompt: CLAUDE.md, auto memory, MCP tool names, skill descriptions. Sources: <https://code.claude.com/docs/en/context-window>, <https://code.claude.com/docs/en/agent-sdk/agent-loop>. Core tool definitions (Bash, Read, Edit) are in every request; MCP tools are deferred by default via tool search.
- Skill listing budget: 1% of the context window by default (`skillListingBudgetFraction`), per-skill description cap 1536 characters (`skillListingMaxDescChars`); `SLASH_COMMAND_TOOL_CHAR_BUDGET` overrides. Sources: <https://code.claude.com/docs/en/settings-reference>, <https://code.claude.com/docs/en/env-vars>.
- CLAUDE.md: target under 200 lines; `@imports` "don't reduce its context cost, because imported files load together with the CLAUDE.md that imports them." Auto memory loads the first 200 lines or 25KB. Source: <https://code.claude.com/docs/en/memory>.
- Plugins' skills, commands, agents and hooks are appended after the prefix and do not invalidate it; plugin MCP servers follow MCP rules. Source: <https://code.claude.com/docs/en/prompt-caching>.

Flag and variable check against the CLI reference and env-var pages (<https://code.claude.com/docs/en/cli-reference>, <https://code.claude.com/docs/en/env-vars>):

| Item | Exists? | Notes |
| --- | --- | --- |
| `--bare` | yes | Skips hooks, skills, commands, subagents, plugins, MCP, auto memory, CLAUDE.md; only Bash/Read/Edit tools; no system reminders or skill list; API key only (no OAuth/keychain); "will become the default for `-p` in a future release". Equivalent to `CLAUDE_CODE_SIMPLE=1` |
| `--strict-mcp-config` | yes | Only MCP servers from `--mcp-config` |
| `--disallowedTools` / `--disallowed-tools` | yes | A bare tool name removes the tool from Claude's context; scoped rules like `Bash(rm *)` only deny calls |
| `--tools` | yes | Restricts built-in tools; `""` disables all; does not affect MCP tools. Docs note the default set on Linux/macOS/WSL leaves out Glob and Grep, so name them if wanted |
| `--setting-sources` | yes | `user`, `project`, `local` |
| `--exclude-dynamic-system-prompt-sections` | yes | See topic 1 |
| `--append-system-prompt` / `-file` | yes | Adds to the default prompt |
| `--system-prompt` / `-file` | yes | Replaces the prompt; also drops the git status snapshot. Not recommended: loses Claude Code's tool-use guidance (unverified effect on quality) |
| `--disable-slash-commands` | yes | Disables all skills and commands |
| `--max-turns`, `--max-budget-usd`, `--output-format`, `--effort`, `--fallback-model`, `--no-session-persistence`, `--settings`, `--mcp-config`, `--agents` | yes | |
| `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` | yes | Shorter prompt with abbreviated tool descriptions; newer models (including Sonnet 5.5) already use it by default. Measured: no change on Sonnet 5.5, as expected |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY`, `CLAUDE_CODE_DISABLE_CLAUDE_MDS`, `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `CLAUDE_CODE_DISABLE_BUNDLED_SKILLS`, `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS`, `CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH` | yes | `DISABLE_CLAUDE_MDS` removes project instructions entirely; not for this loop |
| `ENABLE_TOOL_SEARCH`, `MAX_MCP_OUTPUT_TOKENS` (default 25000), `BASH_MAX_OUTPUT_LENGTH` (default 30000, max 150000), `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` (default 25000), `CLAUDE_CODE_MAX_TURNS` | yes | |
| `DISABLE_TELEMETRY` | mentioned, row not read | Not relevant to tokens |

Notes:
- `--tools` and `--disallowedTools "<name>"` change the tool definitions in the request, so they change the cached prefix (fine: set once per loop, every iteration is identical).
- `--bare` also removes the hooks that rtk uses, so `Bash(rtk git ...)` allow entries become moot and test-output compression is lost; compare cost before adopting.
- Under `-p`, `.mcp.json` servers and project hooks run without a trust prompt unless `--bare` (<https://code.claude.com/docs/en/headless>). Relevant for safety, not tokens.

## 3. Cost caps and measuring real usage per iteration

- `--max-turns` (print mode only, no limit by default): counts each turn that has tool calls plus one final text-only turn; hitting it yields subtype `error_max_turns` with no `result` text. `CLAUDE_CODE_MAX_TURNS` sets it when the flag is absent. Sources: <https://code.claude.com/docs/en/agent-sdk/agent-loop>, <https://code.claude.com/docs/en/env-vars>.
- `--max-budget-usd` (print mode only): stops once client-side estimated spend reaches the cap; the response that crosses the cap still completes, so spend can exceed it by one response; yields `error_max_budget_usd`. Source: <https://code.claude.com/docs/en/cli-reference>, <https://code.claude.com/docs/en/agent-sdk/agent-loop>.
- `--output-format json` returns one object with `result`, `session_id`, `total_cost_usd`, `usage` (input, output, cache read, cache creation, `cache_creation.ephemeral_{5m,1h}_input_tokens`), `modelUsage` per model, `num_turns`, `subtype`. `stream-json` needs `--verbose`; its last line is the `result` message. All result subtypes, including errors, carry `total_cost_usd` and `usage`. Sources: <https://code.claude.com/docs/en/headless>, <https://code.claude.com/docs/en/agent-sdk/cost-tracking>, <https://code.claude.com/docs/en/agent-sdk/agent-loop>.
- Caveats from the docs: `total_cost_usd` is a client-side estimate at list price, not billing; per-step `output_tokens` is a placeholder, so read output from the result's `usage`/`modelUsage`; `usage` excludes subagents while `total_cost_usd` and `modelUsage` include them; on subscription plans the dollar figure "isn't relevant for billing". Sources: same, plus <https://code.claude.com/docs/en/costs>.
- Suggested capture in `ralph.sh` (replaces `| tee iter-N.log`): `claude "${claude_args[@]}" --output-format json "$prompt" > "$log_dir/iter-$i.json"`, then print `jq -r '"turns \(.num_turns) cost $\(.total_cost_usd) in \(.usage.input_tokens) read \(.usage.cache_read_input_tokens) write \(.usage.cache_creation_input_tokens) out \(.usage.output_tokens)"'` and `jq -r .result`. Interactive `/usage` also shows a `Prompt cache (main)` hit-rate line (v2.1.251+) but is not available headlessly.
- Trade-off: `json` prints nothing until the run ends; `stream-json --verbose` shows progress but needs a jq filter.

## 4. Model choice, effort, thinking, fast mode

Pricing per MTok (<https://platform.claude.com/docs/en/about-claude/pricing>):

| Model | Input | 5m write | 1h write | Cache read | Output |
| --- | --- | --- | --- | --- | --- |
| Haiku 5.5 (prompt up to 100k) | $0.10 | $0.125 | $0.20 | $0.01 | $0.50 |
| Haiku 5.5 (prompt over 100k) | $0.50 | $0.625 | $1 | $0.05 | $2.50 |
| Sonnet 5.5 | $2 | $2.50 | $4 | $0.10 | $10 |
| Opus 5.5 | $4 | $5 | $8 | $0.20 | $20 |
| Sonnet 4.6 / 4.5 | $3 | $3.75 | $6 | $0.30 | $15 |

- The `sonnet` alias resolves to Sonnet 5.5 on the Anthropic API, but to Sonnet 4.6 on Claude Platform on AWS and to Sonnet 4.5 on Bedrock, Google Cloud's Agent Platform and Foundry. On those the same loop costs about 1.5-3x more. Source: <https://code.claude.com/docs/en/model-config>. Set `RALPH_MODEL=claude-sonnet-5-5` to pin if that matters.
- Positioning (official): Sonnet 5.5 "the best combination of speed and intelligence"; Opus 5.5 "for long-running agentic coding and knowledge work"; Haiku 5.5 "for high-volume, latency-sensitive tasks such as classification, extraction, and routing". Source: <https://platform.claude.com/docs/en/about-claude/models/overview>. No first-party benchmark for loop-style implementation was read; Haiku suitability for this loop is **unverified**.
- Haiku 5.5 has a price cliff: prompts over 100k tokens cost 5x per input token. An iteration whose context grows past 100k loses most of the saving. Source: pricing page.
- Effort: levels `low`, `medium`, `high`, `xhigh`, `max` for Sonnet 5.5; Claude Code default for Sonnet 5.5 is `medium` (the Models overview lists `high` as the raw API default, so Claude Code sets its own). Headless: `--effort <level>` or `CLAUDE_CODE_EFFORT_LEVEL` (env wins over the flag; `auto`/`unset` sends nothing). Source: <https://code.claude.com/docs/en/model-config>, <https://code.claude.com/docs/en/cli-reference>.
- Thinking: Sonnet 5.5, Opus 5.5 and Haiku 5.5 always use adaptive reasoning. `MAX_THINKING_TOKENS` and `alwaysThinkingEnabled: false` have no effect on them; use effort instead. Thinking tokens bill as output. Source: <https://code.claude.com/docs/en/model-config>, <https://code.claude.com/docs/en/costs>.
- Changing effort mid-session keeps the cache on Sonnet 5.5, but a loop sets it once per run anyway. Source: <https://code.claude.com/docs/en/prompt-caching>.
- Fast mode: Opus 5.5, Opus 5 and Opus 4.8 only ("not available on Sonnet, Haiku"); $8/$40 for Opus 5.5; the docs list batch/CI and cost-sensitive work as better on standard mode. In `-p` it needs `--settings '{"fastMode": true}'`. Not a cost lever. Source: <https://code.claude.com/docs/en/fast-mode>.
- `--fallback-model` exists for overload/unavailability; not a cost lever.

## 5. Trimming orientation reads and keeping output small

- Costs scale with context size; Claude Code resends the full conversation every request and re-reads it from cache at the cached rate. Source: <https://code.claude.com/docs/en/costs> ("Why usage climbs in a long session").
- Specific prompts avoid broad scanning; give verification targets; test incrementally. Source: same page.
- CLAUDE.md: under 200 lines. Move path-specific instructions into `.claude/rules/` with `paths:` (loads on demand). Move workflow-specific instructions into skills (load on demand). Source: <https://code.claude.com/docs/en/memory>, <https://code.claude.com/docs/en/costs>.
- Tool result limits: Bash inline up to about 30,000 characters (larger output is saved to a file with a 2,000-character preview; failing commands get about 10,000 characters head-and-tail); `BASH_MAX_OUTPUT_LENGTH` max 150,000; `bashOutputMaxChars` setting up to 128,000 (v2.1.261+). One Read call returns at most 25,000 tokens and refuses a whole file over 256 KB. MCP results default to 25,000 tokens. Source: <https://code.claude.com/docs/en/tools-reference>, <https://code.claude.com/docs/en/env-vars>.
- Official example for small test output: a PreToolUse hook that rewrites `npm test`/`pytest`/`go test` to pipe through `grep -A 5 -E '(FAIL|ERROR|error:)' | head -100`, "reducing context from tens of thousands of tokens to hundreds." Source: <https://code.claude.com/docs/en/costs>. If a hook rewrites commands, the rewritten form must be in `--allowedTools` (already noted in `SKILL.md`).
- Auto-compaction summarizes history near the window limit. Haiku 5.5 compacts at about 967K tokens; the Sonnet 5.5 threshold was not in the part of the page I read (the page was truncated) and is unverified. Sonnet 5.5 has a 1M window, so one iteration will not normally compact. Sources: <https://code.claude.com/docs/en/model-config>, <https://platform.claude.com/docs/en/about-claude/models/overview>.
- Subagents keep verbose reads out of the main context, but each has its own system prompt/tools, gets a 5-minute TTL, and its spend counts toward the budget; not a good fit for a one-task loop. Source: <https://code.claude.com/docs/en/prompt-caching>, <https://code.claude.com/docs/en/costs>.

## 6. Other documented headless levers

- `--no-session-persistence`: no transcript saved; disk only, no token effect. Source: CLI reference.
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`: removes `run_in_background` and stops runs waiting up to 10 minutes on background work at exit (relevant if an iteration starts a dev server). Source: <https://code.claude.com/docs/en/headless#background-tasks-at-exit>, env-vars page.
- `--permission-prompts none` (v2.1.259+): denied requests are not retried, avoiding wasted turns on prompts that cannot be answered. Source: <https://code.claude.com/docs/en/headless>.
- `--max-budget-usd` + `--max-turns` together bound a runaway iteration (the existing 60-turn cap is high; the median iteration is likely far below it, so a lower cap such as 40 limits the tail; set it from logged `num_turns`).
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS` limits per-request output; higher values reduce context left before compaction. Source: env-vars page.
- Task granularity (design, not a flag): each iteration pays the fixed prefix and orientation again, while per-iteration context growth makes reads grow roughly quadratically in turns. Merging only trivially related tasks, as `prompt.md` already allows, is the balance; larger merges save orientation but raise per-turn read size.

## Corrections to the estimate

Estimate: about 1M cache-read tokens and 10k output per iteration, $0.30-1.00.

- **Cache reads: plausible, and could be higher.** Reads per iteration are about turns x (fixed prefix + context accumulated so far). Measured here: fixed prefix about 37k tokens with default flags; a 5-turn read-only task read 189k cache tokens (about 38k per turn) and cost $0.16 on its first (cold) run. At 25-40 turns with 20-60k of accumulated reads, 1-2.5M reads is realistic in a plugin-heavy setup, and about 0.5-1.2M with `--tools` restricted. I cannot confirm your number without your logs.
- **Cache reads are not the cost driver on Sonnet 5.5.** They cost $0.10/MTok (0.05x input, an unusually cheap ratio that applies to Sonnet 5.5 and Opus 5.5), so 1M reads is $0.10. On Sonnet 4.5/4.6 it would be $0.30.
- **Cost recomputed (Sonnet 5.5, list price).** 1M reads $0.10 + 70k tokens written once at the 5m rate $0.175 (1h rate: $0.28) + 10k output $0.10 (includes thinking) + about 10k uncached input $0.02 = **about $0.40** (about $0.50 with 1h writes). On Sonnet 4.6 the same token mix is about $0.74. So $0.30-1.00 is a reasonable band, with the centre near $0.40-0.50 on Sonnet 5.5; the top of the band needs older Sonnet, 1h writes, heavy output, or many turns. The write share (final context built once, plus the fixed prefix) and output are about as large as the reads, so cutting only reads does not cut the total proportionally. Whether your 70k written and 10k output are right is also unverified.
- **On a subscription** the dollar figure is a list-price estimate; actual use counts against plan limits (<https://code.claude.com/docs/en/costs>), and the main conversation gets the 1-hour TTL (writes at 2x input price in the estimate).
- Expected effect of recommendation 1: about -28k per turn of prefix. At 30 turns that is about 0.84M fewer cache reads ($0.08 at the Sonnet 5.5 read price) plus a smaller prefix write ($0.05-0.10 at 5m/1h rates). Savings are about 20-30% of the $0.40 baseline in my setup; measure with item 3 before relying on this.

## Verification of the implemented changes

Measured 2026-11-06 after implementing recommendations 1 (`--tools`), 2 (conditional AGENTS.md read) and the logging half of 3 (JSON output). One machine, subscription login, Sonnet 5.5 (`claude-sonnet-5-5` in the result JSON), cache writes at the 1-hour tier. Costs are the `total_cost_usd` list-price estimate.

**Setup.** A toy OpenSpec change in a fresh git repo on a feature branch: a short `AGENTS.md` naming a `./check.sh` verify command, a one-line proposal and design, a two-line spec, and two trivial tasks (create `hello.txt`, create `world.txt`). "Old" is `main`'s `ralph.sh` and `prompt.md` with only `--output-format json` added so cost was readable. "New" is the branch's script. Each side ran twice on a fresh copy of the repo, same allowed tools otherwise.

| Run | Iterations | Turns | Cost | Input | Cache read | Cache write | Output |
|---|---|---|---|---|---|---|---|
| Old 1 | 1 | 4 | $0.217 | 10,543 | 118,744 | 43,920 | 807 |
| Old 2 | 1 | 4 | $0.218 | 10,881 | 118,869 | 44,156 | 772 |
| New 1 | 1 | 12 | $0.087 | 1,900 | 96,215 | 12,886 | 2,160 |
| New 2 | 2 | 4 + 4 | $0.077 | 2,225 + 1,892 | 43,747 + 46,121 | 6,909 + 4,502 | 622 + 745 |

Every run ticked both tasks, committed, and `./check.sh` printed `OK`.

- **Saving: about 60-65% per run** in both pairs. The largest drop is cache write (about 44k to 5-13k tokens per iteration) and uncached input (about 10.5k to about 2k), which is the smaller prefix. This agrees in direction with the prediction in "Corrections to the estimate".
- **It is larger than the 20-30% predicted above.** On a toy task the fixed prefix is most of each iteration, so removing it matters more; a real change with larger reads and more turns will show a smaller share. Treat it as an upper bound, not an expected figure.
- **Turn count does not track cost.** New 1 took 3x the turns of Old 1 and still cost 60% less, because each turn re-read a smaller prefix.
- **Not isolated.** Rec 1 is the expected driver, but the three changes were measured together; the prompt change is too small to matter and none was ablated.
- **Quality was only checked at the level "tasks ticked, check passes".** No hard tasks, no multi-file change, no reviewer comparison. Run one real change with the new script and compare `num_turns`, `total_cost_usd` and tasks completed before relying on it.
- Sample is two runs per side on one machine; run-to-run spread within a side was small (old: $0.217 and $0.218).

## Not verified

- Token size of the system prompt and tool definitions (not documented; only my local measurement).
- Why identical invocations sometimes miss the cache.
- Whether Haiku 5.5, or lower effort, completes OpenSpec tasks reliably.
- The Sonnet 5.5 auto-compact threshold (model-config page read was truncated at 100,000 characters).
- Behaviour of `--bare` on cost (no API key available to test).
- `--tools` savings on machines with fewer plugins/skills; the tool-definition portion should be similar, but I did not test.
