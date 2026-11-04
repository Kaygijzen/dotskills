# Plan: rewrite `setup-dotskills` for MCP-backed trackers

Companion to [plan.md](plan.md) (`to-tracker`) and [follow-ups.md](follow-ups.md).

## Goal

`setup-dotskills` helps the user connect an MCP server for their issue tracker: GitHub, GitLab or Azure DevOps (ADO). `to-tracker` then calls the tracker through MCP tools instead of `gh`/`glab`. The local-markdown tracker stays as the option that needs no server.

## Phases

| Phase | Trackers | Why |
| --- | --- | --- |
| 1 | GitHub, GitLab, local | The MCP tools for every operation `to-tracker` needs are documented |
| 2 | Azure DevOps | Three facts are unverified (see the ADO section). Each one changes the design. Start phase 2 with a short test against a real ADO project, then write the seed |

Phase 2 is in this plan so that phase 1 doesn't block it: the docs are written per tracker, and `to-tracker` only names operations.

## Facts this plan relies on

Checked against the vendors' docs on 2026-11-03. Recheck before writing, because these servers change fast.

| | GitHub | GitLab |
| --- | --- | --- |
| Server | Remote `https://api.githubcopilot.com/mcp/` (trailing slash) | Built in, `https://<host>/api/v4/mcp`. GA from **GitLab 19.5**, so older self-managed instances have no server. MCP must be enabled for the top-level group (gitlab.com) or the instance |
| Auth | PAT in an `Authorization` header (documented route). OAuth for Claude Code: **unverified**, don't recommend it until it has been tested | OAuth, or a fine-grained PAT. Legacy PATs get 403 |
| Limit tools | `X-MCP-Toolsets: issues` header, or the URL path `/mcp/x/issues`; `X-MCP-Readonly` for read-only | `X-Gitlab-Enabled-Mcp-Server-Toolsets: core,work_items`. A tool-name-prefix header also exists; it changes tool ids, so don't use it |
| Create / edit body, labels, state | `issue_write` (create or update) | `save_work_item` (create when `work_item_iid` is omitted; `description`, `add_labels`/`remove_labels`, `state`) |
| Parent/child | `issue_write` create with `parent_issue_number`. `sub_issue_write` add/remove takes the issue **id**, not the number | `save_work_item` `parent_id` |
| Blocking | Not used: blocking is a soft `Blocked by:` line on every tracker (decided 2026-11-03). GitHub's dependency tools need `X-MCP-Features: issue_dependencies` | Not used, as for GitHub. `link_work_items` blocking is Premium-only and has no unlink tool |

Claude Code (verified): `claude mcp add -s user --transport http <name> <url> -H "<header>"`, `--client-id`, `--callback-port`. `claude mcp list` / `claude mcp get <name>` show status. `claude mcp login <name>` signs in from the shell. `.mcp.json` expands `${VAR}` in `url` and `headers`. Some credential-named variables (e.g. `NPM_TOKEN`) are forced empty in remote headers, so use a custom name such as `GITHUB_PAT`.

Sources:

- [github-mcp-server README](https://github.com/github/github-mcp-server) and its `docs/remote-server.md`
- [GitLab MCP server](https://docs.gitlab.com/user/model_context_protocol/mcp_server/), and the [tools reference](https://docs.gitlab.com/user/model_context_protocol/mcp_server_tools/)
- [Claude Code MCP docs](https://code.claude.com/docs/en/mcp)
- [Azure DevOps remote MCP server](https://learn.microsoft.com/en-us/azure/devops/mcp-server/remote-mcp-server), and [azure-devops-mcp](https://github.com/microsoft/azure-devops-mcp) `docs/TOOLSET.md`

Still unverified, to check in step 1 of the order:

- The `save_work_item` details in the second half of GitLab's tools page.
- Whether GitHub's dependency tools are enabled on the remote server today.

## MCP first, CLI only where MCP has a gap

Writing an MCP tool *and* a CLI command for every operation doubles the verification and the drift. Instead:

- Each tracker doc maps operations to **MCP tools**.
- A **CLI fallback** is written only for operations known to be missing from MCP:

  | Gap | Fallback |
  | --- | --- |
  | GitHub blocking, when the dependency tools are gated | `gh issue edit --add-blocked-by`, the REST API, or a `Blocked by:` line |
  | GitLab blocking on Free tier | a `Blocked by:` line in the body |
  | GitLab removing a blocker (no unlink tool) | `glab api` DELETE on the issue link. Recheck before writing |

- With no MCP server connected, `to-tracker` stops and points to `/setup-dotskills`. There is no full CLI mode.
- The **Wayfinding** and **PRs/MRs as a triage surface** sections stay CLI-only (`gh`/`glab`), with a note at the top of each saying so. This settles the conflict with plan.md commit 1: those sections are not touched.

## What changes in `setup-dotskills`

Line numbers refer to the current `skills/engineering/setup-dotskills/SKILL.md`.

### 1. Explore

Add:

- **Existing MCP servers.** Run `claude mcp list` and read the project `.mcp.json`. If a server for this tracker is already there, reuse it and don't add a second one.
- **GitLab version** (self-managed): 19.5 or newer, and MCP enabled. If not, stop with that message.
- **GitLab tier.** Below Premium there's no native blocking; record this in the doc, which then uses the text fallback.
- Phase 2: ADO remote hosts (`dev.azure.com`, `*.visualstudio.com`).

### 2. Section A: tracker choice

- The options are **GitHub**, **GitLab**, **Local markdown** and **Other**, and **Azure DevOps** in phase 2. With Other, the user describes the workflow and brings their own MCP or CLI. `to-tracker` checks that the doc defines every operation (plan.md 2.2).
- Rewrite the line-41 explainer:
  - It names `to-tracker`, `wayfinder` and `code-review` (not `to-tickets`, `triage`, `to-spec`).
  - It says the skills use the tracker through an MCP server set up in the next section.
- The "reachable repo" check (lines 46–52, `gh repo view` / `glab repo view`) stays as is. It runs once during setup, with a CLI the user may already have. When the CLI is missing, the check moves to the read-only call in the verify step.

### 3. New Section A2: MCP server

Skipped for local markdown.

1. **Server:**
   - GitHub: remote, PAT.
   - GitLab: built-in HTTP server, OAuth.
2. **Scope:**
   - Recommend **user scope** (`-s user`): per-person credentials, works in every repo.
   - Offer **project scope** only when the team wants a shared server definition. Then setup prints the `.mcp.json` snippet for the user to add, with credentials only as `${VAR}`. It does not write the file itself.
3. **Limit the tools** to issues / work items (`X-MCP-Toolsets: issues`; GitLab `core,work_items`). Less context, and no access the skills don't need.
4. **Credentials: the skill never sees or stores a token.**
   - GitLab: OAuth. After the add, the user runs `claude mcp login GitLab` or uses `/mcp`.
   - GitHub PAT: the user exports `GITHUB_PAT` in their shell profile. Setup prints the add command with the header in **single quotes**, so the user's shell does not expand the variable into the stored config:

     ```
     claude mcp add -s user --transport http github https://api.githubcopilot.com/mcp/ \
       -H 'Authorization: Bearer ${GITHUB_PAT}' -H 'X-MCP-Toolsets: issues'
     ```

     **To verify before shipping:** whether a user-scope server expands `${GITHUB_PAT}` at runtime like `.mcp.json` does. If it doesn't, the GitHub route is project scope with a `.mcp.json` snippet.
   - The user runs the commands with `! <command>`.
5. **Verify:**
   - `claude mcp get <name>` shows the server as configured.
   - Project-scope servers show "pending approval" until the user approves them. Say so.
   - MCP tools reliably load only in a **new session**. Setup ends with "start a new session, then run `/to-tracker`".
   - `to-tracker`'s first action in a session is one read-only call (read the repo or list one issue), before any write.

### 4. Tracker docs: operation → MCP tool

- Each seed (`issue-tracker-github.md`, `issue-tracker-gitlab.md`) maps every operation from plan.md 1.1 to an MCP tool and its parameters, with the CLI fallbacks from the table above. `issue-tracker-local.md` gets the file operations from plan.md 1.1–1.2.
- Tool ids depend on the server name (`mcp__github__issue_write`). The written `docs/agents/issue-tracker.md` names the server once at the top and refers to tools by short name.
- **GitHub:** create children with `issue_write` + `parent_issue_number`. Use `sub_issue_write`, which needs the issue id, only for re-parenting or removal, and say how to get the id.
- **GitLab:** with no unlink tool, a removed blocker uses the CLI fallback. Below Premium, all blocking is the text line.
- The "file only into the user's own repo" / fork check carries over to the MCP repo parameters.
- This replaces plan.md commit 1 (which was written for `gh`/`glab`).

### 5. Section B: labels

Follow-up 1 becomes required: `to-tracker` needs `ready-for-agent` on every tracker. Section B always writes at least that mapping, even without the `triage` skill.

- `to-tracker` creates the label when it's missing. Setup doesn't, because the MCP server isn't loaded in the setup session.
- Update the places listed in follow-ups.md item 1, and remove that item from follow-ups.md.

### 6. Write step and `## Agent skills` block

The `### Issue tracker` line names the tracker and the MCP server, e.g. "GitHub Issues through the `github` MCP server (user scope). See `docs/agents/issue-tracker.md`." With project scope, also name the env var each teammate must set.

### 7. Done step

List what's left for the user:

- export the env var (GitHub)
- `claude mcp login` (GitLab)
- approve the project server (project scope)
- start a new session

Then say which skills use the tracker, and that the templates and labels can be edited (section 8).

### 8. Configurable issue content: defaults, edited in files

**Approach.** Setup asks no questions about issue content. The defaults live in `to-tracker`'s folder (`templates/spec.md`, `templates/ticket.md`, moved from the old skills). Setup copies them to `docs/agents/templates/`, so the user sees and edits them in the repo.

Why:

- Least friction: nobody knows what they want in a ticket body before seeing one.
- Files in the repo are discoverable, reviewed in PRs and shared by the team.
- Editable at any time, without re-running setup.

| What | File | Default |
| --- | --- | --- |
| Spec (parent) body | `docs/agents/templates/spec.md` | `to-spec`'s current template |
| Ticket (child) body | `docs/agents/templates/ticket.md` | `to-tickets`'s current template |
| Labels per role | `docs/agents/triage-labels.md` | `ready-for-agent` |
| Extra labels on every pushed issue | the same file | none |
| Assignee, milestone, board | not configurable yet | add only when asked for |

**The skill owns what it needs to work.** It adds these outside the template, so a template edit can't break re-runs:

- the hidden `<!-- to-tracker:<key> -->` marker
- the parent link
- the blocking edges
- the `Source: #<n>` line

**Reading:**

- Use the repo template if it exists, else the built-in default. A missing file is never an error.
- Templates are markdown headings; the skill fills each section. A heading the user adds is filled too, or gets "n/a".
- A changed template shows up as body changes in the re-run review.

**Drift:**

- Copies carry `<!-- from dotskills to-tracker defaults; edit freely -->` and are never overwritten on a re-run.
- Improvements to the defaults don't reach existing copies. Accepted, because the visible files are the point.
- The alternative is to keep the defaults only in the skill, with no repo copy until the user asks for one. That avoids drift but hides the knob. Switch to it if the copies turn out to be noise.

### Phase 2: Azure DevOps

Before writing anything, test these three on a real ADO project:

1. **Blocking link type.** The link tool is `wit_work_item_link_write` (action `link`). Its docs don't list the supported link types; confirm that Predecessor/Successor works.
2. **Marker survival.** `System.Description` is HTML. Check that `<!-- to-tracker:<key> -->` survives a write and read. If it doesn't, use a tag `to-tracker:<key>` as the marker.
3. **Tool names.** The tools were recently consolidated into action dispatchers, and names differ between the remote docs and `TOOLSET.md` (`wit_query_by_wiql` vs `wiql`). Pin the names from a live `tools/list`.

Then:

- **Connect.**
  - Remote: `claude mcp add --transport http ado https://mcp.dev.azure.com/<org> --client-id <id> --callback-port 3118`. It needs an Entra-backed org and a custom Entra app registration (admin consent). Walk the user through the registration, possibly with the `wizard` skill.
  - Fallback: the local server, `npx -y @azure-devops/mcp <org> --authentication azcli`, which needs Node 20+ and `az login`.
  - Toolset `X-MCP-Toolsets: wit`; `X-MCP-Readonly` for the verify call.
- **Seed `issue-tracker-ado.md`:**

  | Concept | ADO |
  | --- | --- |
  | Issue | Work item; its type depends on the process template |
  | Spec / ticket types | Asked once in setup (default Agile: Feature / User Story; Scrum: Feature / Product Backlog Item; Basic: Epic / Issue). This is the one question setup must ask |
  | Parent | `wit_work_item_write` `add_child` |
  | Edit | `wit_work_item_write` `update` |
  | Labels | Tags (`System.Tags`); nothing to create |
  | Close | The template's done state |
  | Scope | Organization + project; optional area path and iteration, written to the doc |

- **Prerequisites** go into `docs/setup.md`: an Entra app registration (remote), or Node 20+ and `az` (local).

## Outside the skill

- **Claude Code only.** `install.sh --target codex` is not implemented, and `setup-dotskills/agents/openai.yaml` holds only display settings. So `claude mcp` commands are fine. Set `targets: [claude]` on `setup-dotskills` and `to-tracker`; the frontmatter supports it, and `portability_lint` in `scripts/validate.sh` then skips the Codex checks. Supporting other agents' MCP configs is follow-ups.md item 6.
- **Provenance.** After this rewrite, `setup-dotskills` is our own. Remove its `upstream.json` entry, and add a line to `THIRD_PARTY_NOTICES.md`: "`setup-dotskills` is derived from upstream `setup-matt-pocock-skills`". This is the same treatment as `to-tracker`.
- **`docs/setup.md` / README.** `gh`/`glab` become needed only for the fallbacks and the repo check. Mention GitLab 19.5+.
- **The repo's `mcp/` folder stays empty.** A plugin-bundled tracker server would share one config across all projects, which is wrong for per-repo trackers.
- **`to-tracker` (plan.md):**
  - Preconditions: the tracker's MCP server is connected, else stop and point to `/setup-dotskills`.
  - Its first call is the read-only check.
  - It creates the `ready-for-agent` label if it's missing.
  - plan.md 1.1's "verify gh/glab flags" becomes "verify MCP tool names and parameters", plus the listed CLI fallbacks.

## Order

The full order is in [plan.md, "Implementation order"](plan.md#implementation-order). This file covers:

- **Step 0: verify.** Recheck the "still unverified" list. Test first whether a user-scope header expands `${GITHUB_PAT}`, because the answer decides the GitHub credential route that §3 and §4 describe.
- **Step 1: tracker docs** (§4). Rewrite the GitHub, GitLab and local seeds. This is PR 1, commit 1, and replaces the old plan.md commit 1.
- **Step 3: the `setup-dotskills` rewrite** (§1–3, §5–7, and the copy step of §8). This is PR 2, after `to-tracker` (step 2) exists, because setup copies its templates. PR 2 also:
  - removes `setup-dotskills` from `upstream.json`
  - adds its line to `THIRD_PARTY_NOTICES.md`
  - sets `targets: [claude]`
  - removes item 1 from follow-ups.md
- **Step 4: ADO** (Phase 2). This is PR 3: the tests first, then the ADO seed, the Section A option and the prerequisites.

Manual test matrix for PR 1 and PR 2: local, GitHub, GitLab Premium, and GitLab Free (the text fallback). Before PR 2, test `to-tracker` with hand-written `docs/agents/*.md` files.

## Decisions still open

- **ADO default connection:** remote (an Entra app per org) or local (`azcli`)? Decide after the phase 2 tests.
