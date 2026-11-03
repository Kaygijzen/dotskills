---
name: setup-dotskills
description: "Configure this repo for dotskills' engineering skills: set up its issue tracker and its MCP server, the label vocabulary, and the domain doc layout. Run once before first use of the other engineering skills."
disable-model-invocation: true
targets: [claude]
---

# Setup dotskills

Scaffold the per-repo configuration that the engineering skills assume:

- **Issue tracker**: where issues live (GitHub, GitLab, local markdown, or another tracker the user describes), and the **MCP server** the skills reach it through
- **Labels**: the strings used for the canonical label roles
- **Domain docs**: where `GLOSSARY.md` and ADRs live, and the consumer rules for reading them
- **Issue templates**: the spec and ticket bodies `to-tracker` writes, copied into the repo to edit
- **Agent conventions** and the **OpenSpec** flow: optional, asked about after the above

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write. This skill never sees or stores a token: the user runs every command that handles a credential.

## Process

### 1. Explore

Look at the current repo to understand its starting state. Read whatever exists; don't assume:

- `git remote -v` and `.git/config`: is this a GitHub or GitLab repo? Which one?
- MCP servers already configured: `claude mcp list`, and the project `.mcp.json`. A server for this repo's tracker that is already there gets reused; never add a second one.
- GitLab self-managed: the instance version (`https://<host>/api/v4/version`, or ask). The MCP server needs **GitLab 19.5** or newer, with MCP enabled for the instance. If it isn't, stop and say so.
- `AGENTS.md` and `CLAUDE.md` at the repo root: does either exist? Is there already an `## Agent skills` section in either?
- `GLOSSARY.md` and `GLOSSARY-MAP.md` at the repo root, and the legacy `CONTEXT.md` / `CONTEXT-MAP.md`. If a legacy file exists, offer to `git mv` it to its `GLOSSARY` name and rewrite those names in `docs/agents/domain.md`.
- `docs/adr/` and any `src/*/docs/adr/` directories
- `docs/agents/`: does this skill's prior output already exist?
- `.scratch/`: a sign that a local-markdown issue tracker convention is already in use
- Is the `triage` skill installed? (a `triage` skill folder alongside this one, or `triage` in your available skills.) This decides how many labels Section B covers.
- Monorepo signals: a `pnpm-workspace.yaml`, a `workspaces` field in `package.json`, or a populated `packages/*` with its own `src/`. These are present only in a genuinely large multi-package repo; their absence means single-context, which is almost every repo.

### 2. Present findings and ask

Summarise what's present and what's missing. Then take the sections in order. One section, one answer, then the next.

Lead each section with the recommended answer so the user can accept it in a word. Give a one-line explainer only when the choice genuinely branches; skip the section entirely when exploration already settled it (Section A2 for local markdown, Section C when there's no monorepo).

**Section A: Issue tracker.**

> Explainer: The "issue tracker" is where issues live for this repo. Skills like `to-tracker`, `wayfinder`, and `code-review` read from and write to it, through an MCP server that the next step sets up. Pick the place you actually track work for this repo.

If a `git remote` points at GitHub, propose GitHub. If one points at GitLab (`gitlab.com` or a self-hosted host), propose GitLab. Otherwise (or if the user prefers), offer:

- **GitHub**: the repo's GitHub Issues, through GitHub's remote MCP server
- **GitLab**: the repo's GitLab Issues, through GitLab's built-in MCP server (GitLab 19.5+)
- **Local markdown**: files under `.scratch/<feature>/` in this repo; no server needed (good for solo projects or repos without a remote)
- **Other** (Jira, Linear, etc.): the user describes the workflow and brings their own MCP server or CLI. Write it down as operations: `to-tracker` checks that the doc defines create, edit body and title, link a child to a parent, list a parent's children, ensure a label exists, and close with a comment.

Record the choice in `docs/agents/issue-tracker.md`. The GitHub and GitLab templates carry a "PRs as a request surface" flag, defaulted **off**. Leave it off and don't raise it: a user who wants external PRs in the triage queue can flip the flag in the file later.

A GitHub or GitLab tracker needs a reachable repo. When the user picks one and no `git remote` points at that host, get the repo URL from them and wire it up (`git init` if needed, `git remote add origin <url>`) before going further. Done when `gh repo view` / `glab repo view` prints the project from inside this directory. Without that CLI, the read-only check in the new session (step 5) confirms it instead.

**Section A2: MCP server.** Skipped for local markdown, and for a server exploration already found.

1. **Scope.** Recommend **user scope** (`-s user`): credentials stay per person, and one server works in every repo on that host. Offer **project scope** only when the team wants a shared server definition. Then print a `.mcp.json` snippet for the user to add, with credentials only as `${VAR}`, and leave writing the file to them.
2. **Command.** Print the command for the user to run with `! <command>`. Each one limits the tools to issues, which keeps context small and grants no access the skills don't need.
   - GitHub. The user first exports `GITHUB_PAT` (a personal access token with Issues read/write on this repo) in their shell profile. The headers go in **single quotes**, so the shell stores `${GITHUB_PAT}` itself and Claude Code expands it at connect time. Keep the name `GITHUB_PAT`: Claude Code blanks some credential-named variables in remote headers.

     ```
     claude mcp add -s user --transport http github https://api.githubcopilot.com/mcp/ \
       -H 'Authorization: Bearer ${GITHUB_PAT}' -H 'X-MCP-Toolsets: issues,labels'
     ```

   - GitLab, with OAuth:

     ```
     claude mcp add -s user --transport http GitLab https://<host>/api/v4/mcp \
       --header "X-Gitlab-Enabled-Mcp-Server-Toolsets: core,work_items"
     ```

     Then the user signs in with `claude mcp login GitLab`, or `/mcp` in a session. A personal access token must be fine-grained; legacy tokens get 403.
3. **Check.** `claude mcp get <name>` shows the server as configured. A project-scope server shows "pending approval" until the user approves it; say so. Tools load only in a new session, so the connection is checked there (step 5).

The server name is part of every tool id (`mcp__github__issue_write`): write it at the top of `docs/agents/issue-tracker.md` when it differs from the seed's.

**Section B: Labels.** `to-tracker` needs the `ready-for-agent` role on every tracker, so this section always runs.

Without `triage` installed, write a one-row `triage-labels.md`: the seed with only the `ready-for-agent` row. With `triage` installed, ask exactly one question:

> Do you want to keep the default triage labels? (recommended: **yes**)

The defaults are the five canonical roles, each label string equal to its name: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. On **yes**, write them as-is. Only if the user says no, usually because their tracker already uses other names (e.g. `bug:triage` for `needs-triage`), collect the overrides so `triage` applies existing labels instead of creating duplicates.

Labels are created on the tracker by the skills that use them (`to-tracker` ensures its label exists before its first push), because the MCP server isn't loaded in this session.

**Section C: Domain docs.** Default to **single-context** (one `GLOSSARY.md` + `docs/adr/` at the repo root). This fits almost every repo; write it without asking.

Offer **multi-context** (a root `GLOSSARY-MAP.md` pointing to per-context `GLOSSARY.md` files) only when exploration found monorepo signals. Then confirm which layout they want.

**Section D: Agent conventions.** Only ask when the repo has neither `AGENTS.md` nor `CLAUDE.md`. Offer to create them from the dotskills project template (`conventions/project-template/`, the same files `install.sh --init-project` copies). Find the template by resolving this skill folder's real path (it may be a symlink) and going up three levels to the dotskills root. Copy only files that don't exist yet; never overwrite. If the user says no, move on; step 4 then asks which file to create for the `## Agent skills` block.

**Section E: OpenSpec.** Ask whether this repo will use the OpenSpec flow (`grill-spec`, `ralph-apply`). If yes, check that `openspec/` exists at the repo root. If it doesn't, tell the user to run `openspec init`. Don't run it for them.

### 3. Confirm and edit

Show the user a draft of:

- The `## Agent skills` block to add to whichever of `CLAUDE.md` / `AGENTS.md` is being edited (see step 4 for selection rules)
- The contents of `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`, and `docs/agents/domain.md`

Let them edit before writing.

### 4. Write

**Pick the file to edit:**

- If `CLAUDE.md` exists, edit it.
- Else if `AGENTS.md` exists, edit it.
- If neither exists, ask the user which one to create; don't pick for them.

Never create `AGENTS.md` when `CLAUDE.md` already exists (or vice versa); always edit the one that's already there.

If an `## Agent skills` block already exists in the chosen file, update its contents in-place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

The block:

```markdown
## Agent skills

### Issue tracker

[tracker, and the MCP server and its scope, e.g. "GitHub Issues through the `github` MCP server (user scope)". With project scope, also the env var each teammate sets]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/agents/triage-labels.md`.

### Domain docs

[one-line summary of layout: "single-context" or "multi-context"]. See `docs/agents/domain.md`.
```

Then write the docs files using the seed templates in this skill folder as a starting point:

- [issue-tracker-github.md](./issue-tracker-github.md): GitHub issue tracker
- [issue-tracker-gitlab.md](./issue-tracker-gitlab.md): GitLab issue tracker
- [issue-tracker-local.md](./issue-tracker-local.md): local-markdown issue tracker
- [triage-labels.md](./triage-labels.md): label mapping
- [domain.md](./domain.md): domain doc consumer rules + layout

For "other" issue trackers, write `docs/agents/issue-tracker.md` from scratch using the user's description.

**Issue templates.** Copy `spec.md` and `ticket.md` from the `templates/` folder of the `to-tracker` skill (the sibling of this skill folder's real path) to `docs/agents/templates/`. Start each copy with the line `<!-- from dotskills to-tracker defaults; edit freely -->`. A copy that already exists is the user's: leave it as it is.

### 5. Done

List what is left for the user, only the items that apply:

- export `GITHUB_PAT` in the shell profile (GitHub)
- `claude mcp login GitLab`, or `/mcp` (GitLab)
- approve the project server (project scope)
- start a new session, then run `/to-tracker`: its first call is a read-only check of the connection

Then say which skills use the tracker (`to-tracker`, `wayfinder`, `code-review`), and that `docs/agents/*.md` and the templates in `docs/agents/templates/` can be edited directly. Re-running this skill is only necessary to switch issue trackers or restart from scratch.
