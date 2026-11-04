---
name: second-opinion
description: Get a second opinion from Opus on the hard question in this conversation; assembles the briefing from context and relays the answer.
argument-hint: "[the question, if not obvious from context]"
disable-model-invocation: true
targets: [claude]
---

Get a second opinion from Opus through the `ask-opus` subagent. It cannot see this conversation, so your job is a good briefing going in and an honest relay coming out.

1. **Gate.** If one or two lookups would answer the question, answer it yourself. Opus is for judgement, not lookups.
2. **Question.** Use `$ARGUMENTS` if given, else take it from the conversation. Ask only if it is still ambiguous. Name the answer type: decision, diagnosis or explanation.
3. **Gather.** Collect `file:line` pointers, exact error text, what was tried and ruled out, and constraints. Paste errors, not whole files or logs. Use Explore first only when the question needs a broad search, and put its conclusions in the briefing. Redact secrets, tokens and env values; reference them by `file:line`.
4. **Brief.** Write under about 300 words. Mark claims you have not verified, so Opus can test them. State your current hypothesis as a hypothesis, not as the question.
5. **Ask.** Spawn `ask-opus` in the foreground with the briefing. If you have no Agent tool (for example you are running inside a subagent), say so and stop.
6. **Relay.** Give the user Answer, Confidence, Reframe and Open; never drop Open or a low confidence. Summarise Evidence instead of pasting it. Treat the result as input, not a verdict: spot-check the one Evidence line the answer rests on before acting, and make no edits unless the user asked.
